// Copyright (c) 2023 Intel Corporation
//
// SPDX-License-Identifier: Apache-2.0
//

use anyhow::{anyhow, Result};
use kata_types::mount::KATA_VIRTUAL_VOLUME_IMAGE_GUEST_PULL;
use kata_types::mount::{ImagePullVolume, StorageDevice};
use protocols::agent::Storage;
use std::sync::Arc;
use tracing::instrument;

use crate::image_rpc;
use crate::storage::{StorageContext, StorageHandler};

use super::{common_storage_handler, new_device};

// Convenience function to obtain the scope logger.
fn sl() -> slog::Logger {
    slog_scope::logger().new(o!("subsystem" => "cgroups"))
}

#[derive(Debug)]
pub struct ImagePullHandler {}

impl ImagePullHandler {
    fn get_image_info(storage: &Storage) -> Result<ImagePullVolume> {
        for option in storage.driver_options.iter() {
            if let Some((key, value)) = option.split_once('=') {
                if key == KATA_VIRTUAL_VOLUME_IMAGE_GUEST_PULL {
                    let imagepull_volume: ImagePullVolume = serde_json::from_str(value)?;
                    return Ok(imagepull_volume);
                }
            }
        }
        info!(sl(), "confilesystem13 - get_image_info(): No image_guest_pull");
        Err(anyhow!("missing Image information for ImagePull volume"))
    }
}

#[async_trait::async_trait]
impl StorageHandler for ImagePullHandler {
    #[instrument]
    async fn create_device(
        &self,
        mut storage: Storage,
        ctx: &mut StorageContext,
        ie_data: &mut image_rs::extra::token::InternalExtraData,
    ) -> Result<Arc<dyn StorageDevice>> {
        info!(sl(), "confilesystem13 - create_device(): ie_data.container_name = {:?}, ie_data.controller_crp_token.len() = {:?}",
            ie_data.container_name, ie_data.controller_crp_token.len());

        //Currently the image metadata is not used to pulling image in the guest.
        let image_pull_volume = Self::get_image_info(&storage)?;
        info!(sl(), "confilesystem13 - create_device(): image_pull_volume = {:?}", image_pull_volume);
        debug!(ctx.logger, "image_pull_volume = {:?}", image_pull_volume);
        let image_name = storage.source();
        debug!(ctx.logger, "image_name = {:?}", image_name);

        let cid = ctx
            .cid
            .clone()
            .ok_or_else(|| anyhow!("failed to get container id"))?;
        let image_service = image_rpc::ImageService::singleton().await?;
        let bundle_path = image_service
            .pull_image_for_container(image_name, &cid, &image_pull_volume.metadata, ie_data)
            .await?;

        storage.source = bundle_path;
        storage.options = vec!["bind".to_string(), "ro".to_string()];

        common_storage_handler(ctx.logger, &storage)?;

        new_device(storage.mount_point)
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use kata_types::mount::{ImagePullVolume, KATA_VIRTUAL_VOLUME_IMAGE_GUEST_PULL};
    use protocols::agent::Storage;

    use crate::storage::image_pull_handler::ImagePullHandler;

    #[test]
    fn test_get_image_info() {
        let mut res = HashMap::new();
        res.insert("key1".to_string(), "value1".to_string());
        res.insert("key2".to_string(), "value2".to_string());

        let image_pull = ImagePullVolume {
            metadata: res.clone(),
        };

        let image_pull_str = serde_json::to_string(&image_pull);
        assert!(image_pull_str.is_ok());

        let storage = Storage {
            driver: KATA_VIRTUAL_VOLUME_IMAGE_GUEST_PULL.to_string(),
            driver_options: vec![format!("image_guest_pull={}", image_pull_str.ok().unwrap())],
            ..Default::default()
        };

        match ImagePullHandler::get_image_info(&storage) {
            Ok(image_info) => {
                assert_eq!(image_info.metadata, res);
            }
            Err(e) => panic!("err = {}", e),
        }
    }
}
