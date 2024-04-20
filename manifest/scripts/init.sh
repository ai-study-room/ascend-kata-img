#!/bin/sh

set -x

groupadd HwHiAiUser
useradd -g HwHiAiUser -d /home/HwHiAiUser -m HwHiAiUser -s /bin/bash

if [ ! -d /var/log ];then
	mkdir -p /var/log
fi

dpkg -i /root/linux-headers-5.15.63_5.15.63-1_arm64.deb
dpkg -i /root/linux-libc-dev_5.15.63-1_arm64.deb
