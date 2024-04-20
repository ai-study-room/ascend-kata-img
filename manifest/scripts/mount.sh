#!/bin/sh

set -x

if [ -z $ROOTFS ];then
	echo "[WARNING] the ROOTFS is null, will use default value"
	ROOTFS=`pwd`/rootfs-ubuntu-5-15-63
fi

mount -t sysfs -o ro none $ROOTFS/sys
mount -t tmpfs  none $ROOTFS/tmp
mount -t proc -o ro none $ROOTFS/proc
mount -o bind,ro /dev $ROOTFS/dev
mount -t devpts none $ROOTFS/dev/pts
