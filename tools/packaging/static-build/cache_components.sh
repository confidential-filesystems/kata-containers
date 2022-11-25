#!/bin/bash
# Copyright (c) 2022 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o nounset
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${script_dir}/../scripts/lib.sh"

export KATA_BUILD_CC="${KATA_BUILD_CC:-}"
export qemu_cc_tarball_name="kata-static-qemu-cc.tar.gz"

cache_qemu_artifacts() {
	source "${script_dir}/qemu/build-static-qemu-cc.sh"
	local current_qemu_version=$(get_from_kata_deps "assets.hypervisor.qemu.version")
	create_cache_asset "${qemu_cc_tarball_name}" "${current_qemu_version}"
	local qemu_sha=$(calc_qemu_files_sha256sum)
        echo "${current_qemu_version} ${qemu_sha}" > "latest"
}

cache_clh_artifacts() {
	local binary="cloud-hypervisor"
	local binary_path="$(echo $script_dir | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,')"
	echo "binary path $binary_path"
	local current_cloud_hypervisor_version=$(get_from_kata_deps "assets.hypervisor.cloud_hypervisor.version")
	local clh_binary_path="${binary_path}/tools/packaging/kata-deploy/local-build/build/cc-cloud-hypervisor/builddir/cloud-hypervisor"
	if [ -f "${clh_binary_path}/cloud-hypervisor" ]; then
		cp "${clh_binary_path}/${binary}" .
	else
		cloud_hypervisor_build_path="${binary_path}/cloud-hypervisor"
		cp "${cloud_hypervisor_build_path}/${binary}" .
	fi
	create_cache_asset "${binary}" "${current_cloud_hypervisor_version}"
	echo "${current_cloud_hypervisor_version}"  > "latest"
}

cache_kernel_artifacts() {
	local current_kernel_version=$(get_from_kata_deps "assets.kernel.version" | cut -c2- )
	local gral_path="$(echo $script_dir | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,' | sed 's,/*[^/]\+/*$,,')"
	local kernel_config_file="${gral_path}/tools/packaging/kernel/kata_config_version"
	local kernel_config="$(cat ${kernel_config_file})"
	echo "${current_kernel_version} ${kernel_config}" > "latest"
	local kernel_path="${gral_path}/tools/packaging/kata-deploy/local-build/build/cc-kernel/destdir/opt/confidential-containers/share/kata-containers"
	local vmlinux_binary_name="vmlinux-${current_kernel_version}-${kernel_config}"
	ls ${kernel_path}
	local vmlinux_file="${kernel_path}/${vmlinux_binary_name}"
	if [ -f "${vmlinux_file}" ]; then
		cp -a "${vmlinux_file}" .
		create_cache_asset "${vmlinux_binary_name}" "${current_kernel_version}"
	fi
	local vmlinuz_binary_name="vmlinuz-${current_kernel_version}-${kernel_config}"
	local vmlinuz_file="${kernel_path}/${vmlinuz_binary_name}"
	if [ -f "${vmlinuz_file}" ]; then
		cp -a "${vmlinuz_file}" .
		create_cache_asset "${vmlinuz_binary_name}" "${current_kernel_version}"
	fi
}

create_cache_asset() {
	local component_name="$1"
	local component_version="$2"

	sudo chown -R "${USER}:${USER}" .
	sha256sum "${component_name}" > "sha256sum-${component_name}"
	cat "sha256sum-${component_name}"
}

help() {
echo "$(cat << EOF
Usage: $0 "[options]"
	Description:
	Builds the cache of several kata components.
	Options:
		-c	Cloud hypervisor cache
		-k	Kernel cache
		-q	Qemu cache
		-h	Shows help
EOF
)"
}

main() {
	local cloud_hypervisor_component="${cloud_hypervisor_component:-}"
	local qemu_component="${qemu_component:-}"
	local kernel_component="${kernel_component:-}"
	local OPTIND
	while getopts ":ckqh:" opt
	do
		case "$opt" in
		c)
			cloud_hypervisor_component="1"
			;;
		k)
			kernel_component="1"
			;;
		q)
			qemu_component="1"
			;;
		h)
			help
			exit 0;
			;;
		:)
			echo "Missing argument for -$OPTARG";
			help
			exit 1;
			;;
		esac
	done
	shift $((OPTIND-1))

	[[ -z "${cloud_hypervisor_component}" ]] && \
	[[ -z "${kernel_component}" ]] && \
	[[ -z "${qemu_component}" ]] && \
		help && die "Must choose at least one option"

	mkdir -p "${WORKSPACE}/artifacts"
	pushd "${WORKSPACE}/artifacts"
	echo "Artifacts:"

	[ "${cloud_hypervisor_component}" == "1" ] && cache_clh_artifacts
	[ "${kernel_component}" == "1" ] && cache_kernel_artifacts
	[ "${qemu_component}" == "1" ] && cache_qemu_artifacts

	ls -la "${WORKSPACE}/artifacts/"
	popd
	sync
}

main "$@"
