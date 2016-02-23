#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# $1: new branch
mount_root_image(){
	msg2 "${iso_fs}: mount [root-image] on [%s]" "${1##*/}"
	mount -t aufs -o br="$1":${work_dir}/root-image=ro none "$1"
}

mount_custom_image(){
	msg2 "${iso_fs}: mount [%s] on [%s-image]" "${1##*/}" "${custom}"
	mount -t aufs -o br="$1":${work_dir}/${custom}-image=ro:${work_dir}/root-image=ro none "$1"
}

# $1: image path
umount_image(){
	if mountpoint -q "$1";then
		msg2 "${iso_fs}: unmount %s" "${1##*/}"
		umount $1
	fi
	find $1 -name '.wh.*' -delete &> /dev/null
}
