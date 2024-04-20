#!/bin/sh

set -x

if [ -z $ROOTFS ];then
	echo "[WARNING] ROOTFS is null, will use the default value"
	ROOTFS=`pwd`/rootfs-ubuntu-5-15-63
fi

umount $ROOTFS/tmp
umount $ROOTFS/proc
umount $ROOTFS/sys
umount $ROOTFS/dev/pts
umount $ROOTFS/dev
