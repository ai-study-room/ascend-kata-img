#!/bin/sh

set -x

mount -t sysfs -o ro none /root/rootfs-ubuntu-5-15-63/sys
mount -t tmpfs  none /root/rootfs-ubuntu-5-15-63/tmp
mount -t proc -o ro none /root/rootfs-ubuntu-5-15-63/proc
mount -o bind,ro /dev /root/rootfs-ubuntu-5-15-63/dev
mount -t devpts none /root/rootfs-ubuntu-5-15-63/dev/pts
