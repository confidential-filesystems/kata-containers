#!/bin/bash

echo "" && echo "" && echo ""
OP=build
if [ $1 ]; then
  OP=$1
  shift
fi
echo OP=${OP}

CurrDir=$(cd "$(dirname "$0")"; pwd)

SourceDir=phf@10.12.32.134://home/phf/phf_dell/security-compute/code5/kata-containers
ROOTFS_DIR=/home/cfs/work/herve.pang/cc/kata-containers/target/initrd_dir

InitrdFileTgt=herve-test-sev-1.initrd

#
echo "" && echo "" && echo ""
cd ${CurrDir}/
if [ ${OP} == 'agent' ]; then
  (echo 123456) | scp -r ${SourceDir}/src/agent/* ./src/agent/
fi

export seccomp_install_path=/home/cfs/work/herve.pang/install/
export LIBSECCOMP_LIB_PATH="${seccomp_install_path}/lib"

#
echo "" && echo "" && echo ""
cd ./src/agent/
make clean
make SEALED_SECRET=yes

cp ./target/x86_64-unknown-linux-musl/release/kata-agent ${ROOTFS_DIR}/sbin/init
cd ../../

#
cd ${CurrDir}/
echo "" && echo "" && echo ""
exit 0
#end.
