#!/bin/sh

set -x

if [ -z $ROOTFS_DIR ];then
	ROOTFS_DIR=/root/rootfs-ubuntu-5-15-63
fi

if [ -z $KATA_REPO ];then
	KATA_REPO=/root/gopath/src/github.com/kata-containers/kata-containers
fi

if [ -z $MANIFEST ];then
	MANIFEST_DIR=/root
fi

cp $MANIFEST_DIR/Ascend-hdk-910b-npu-driver_23.0.3_linux-aarch64.run $ROOTFS_DIR/root/

#COPY the linux header and libc deb files
cp $KATA_REPO/tools/packaging/kernel/linux-libc-dev_5.15.63-1_arm64.deb  $ROOTFS_DIR/root/
cp $KATA_REPO/tools/packaging/kernel/linux-headers-5.15.63_5.15.63-1_arm64.deb $ROOTFS_DIR/root/
cp $MANIFEST_DIR/init.sh $ROOTFS_DIR/root/

#COPY the npu driver mod probe script and configuration files
cp $MANIFEST_DIR/mod_probe.sh $ROOTFS_DIR/usr/local/bin/
if [ ! -d $ROOTFS_DIR/lib/modules/updates ];then
	mkdir -p $ROOTFS_DIR/lib/modules/updates
fi
cp $MANIFEST_DIR/mod.dep $ROOTFS_DIR/lib/modules/updates/

#COPY the kata-agent and docker runtime
cp $MANIFEST_DIR/Ascend-docker-runtime_5.0.0.5_linux-aarch64.run $ROOTFS_DIR/root/
cp $MANIFEST_DIR/kata-agent.service $ROOTFS_DIR/etc/systemd/system/
cp $MANIFEST_DIR/kata-containers.target $ROOTFS_DIR/etc/systemd/system/
cp $KATA_REPO/src/agent/target/aarch64-unknown-linux-musl/release/kata-agent $ROOTFS_DIR/usr/bin/
chmod +x $ROOTFS_DIR/usr/bin/kata-agent


