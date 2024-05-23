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

InitrdFileSrc=kata-ubuntu-20.04-sev.initrd
InitrdFileTgt=herve-test-sev-1.initrd

#
echo "" && echo "" && echo ""
cd ${CurrDir}/
if [ ${OP} == 'agent' ]; then
  (echo 123456) | scp -r ${SourceDir}/src/agent/* ./src/agent/
fi

if [ ${OP} == 'initrd' ]; then
  mkdir -p ./target
  cd ./target/
  (echo 123456) | scp ${SourceDir}/target/${InitrdFileSrc} ./
  mkdir -p initrd_dir
  rm -rf ./initrd_dir/*
  cd ./initrd_dir/
  zcat ../${InitrdFileSrc} | cpio -idmv
  #exit 1
fi

#
echo "" && echo "" && echo ""
cd ${CurrDir}/
cd ./src/agent/
# https://github.com/kata-containers/kata-containers/blob/main/docs/Developer-Guide.md#build-a-custom-kata-agent---optional
arch=$(uname -m)
rustup target add "${arch}-unknown-linux-musl"
ln -s /usr/bin/g++ /bin/musl-g++
rm -rf ./target/x86_64-unknown-linux-musl/release/kata-agent*
# https://github.com/kata-containers/kata-containers/issues/5044
# make clean
# make LIBC=gnu
mkdir SEALED_SECRET=yes -p ${CurrDir}/../../install
export seccomp_install_path=${CurrDir}/../../install
export gperf_install_path=${CurrDir}/../../install
echo ${seccomp_install_path} ${gperf_install_path}
# export GOPATH="${GOPATH:-$HOME/go}"
# ../../ci/install_libseccomp.sh ${seccomp_install_path} ${gperf_install_path}
export LIBSECCOMP_LIB_PATH="${seccomp_install_path}/lib"
make
if [ -s ./target/x86_64-unknown-linux-musl/release/kata-agent ]; then
	echo "compile kata-agent succ ."
else
    echo "ERROR: compile kata-agent fail !"
    exit 1;
fi
cp ./target/x86_64-unknown-linux-musl/release/kata-agent ${CurrDir}/target/

#
echo "" && echo "" && echo ""
cd ${CurrDir}/
cd ./target/initrd_dir/
cp ../kata-agent ./sbin/init
rm -f ../${InitrdFileTgt}
find . | cpio -H newc -o | gzip -9 > ../${InitrdFileTgt}
if [ -s ../${InitrdFileTgt} ]; then
	echo "build ../${InitrdFileTgt} succ ."
else
    echo "ERROR: build ../${InitrdFileTgt} fail !"
    exit 1;
fi
cd ${CurrDir}/
ls -al ./target/

# initrd = "/home/cfs/work/herve.pang/cc/kata-containers/target/herve-test-sev-1.initrd"
# vi /opt/kata/share/defaults/kata-containers/configuration-qemu-snp.toml

#
cd ${CurrDir}/
echo "" && echo "" && echo ""
exit 0
#end.
