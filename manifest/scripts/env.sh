#!/bin/sh

set -x


export USE_DOCKER=true
export EXTRA_PKGS="chrony make curl pciutils apt dpkg python3 software-properties-common kmod net-tools udev build-essential vim"
export ROOTFS_DIR=/root/rootfs-ubuntu-5-15-63/
export AGENT_SOURCE_BIN=/root/gopath/src/github.com/kata-containers/kata-containers/src/agent/target/aarch64-unknown-linux-musl/release/kata-agent

