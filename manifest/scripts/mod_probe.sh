#!/usr/bin/bash

set -x

MOD_DEP_CONFIG="/lib/modules/updates/mod.dep"

if [ ! -f $MOD_DEP_CONFIG ];then
	echo "MOD_DEP_CONFIG file is not exists."
fi

cat $MOD_DEP_CONFIG | while read line
do
	ko=$line.ko

	if ! modinfo $line > /dev/null 2>&1;then
		if [ -f "/lib/modules/updates/$ko" ];then
			insmod /lib/modules/updates/$ko
		fi
	fi

	if modinfo $line >/dev/null 2>&1
	then
		echo "load $ko sucessed."
	else
		echo "load $ko failed"
	fi
done

