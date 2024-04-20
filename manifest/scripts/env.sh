#!/bin/sh

set -x

if [ -z $ROOTFS ];then
	echo "[WARNING] the ROOTFS will use default value"
	ROOTFS=`pwd`/rootfs-ubuntu-5-15-63
fi

if [ -z AGENT_BIN ];then
	AGENT_BIN=/root/gopath/src/github.com/kata-containers/kata-containers/src/agent/target/aarch64-unknown-linux-musl/release/kata-agent
fi

export USE_DOCKER=true
export EXTRA_PKGS="chrony make curl pciutils apt dpkg python3 software-properties-common kmod net-tools udev build-essential vim"
export ROOTFS_DIR=$ROOTFS
export AGENT_SOURCE_BIN="$AGENT_BIN"

