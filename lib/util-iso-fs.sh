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
aufs_mount_root_image(){
	msg2 "mount [root-image] on [${1##*/}]"
	mount -t aufs -o br="$1":${work_dir}/root-image=ro none "$1"
}

# $1: add branch
aufs_append_root_image(){
	msg2 "append [root-image] on [${1##*/}]"
	mount -t aufs -o remount,append:${work_dir}/root-image=ro none "$1"
}

# $1: add branch
aufs_mount_custom_image(){
	msg2 "mount [${1##*/}] on [${custom}-image]"
	mount -t aufs -o br="$1":${work_dir}/${custom}-image=ro none "$1"
}

# $1: del branch
aufs_remove_image(){
	if mountpoint -q "$1";then
		msg2 "unmount ${1##*/}"
		umount $1
	fi
}

# $1: image path
aufs_clean(){
	find $1 -name '.wh.*' -delete &> /dev/null
}

umount_image_handler(){
	aufs_remove_image "${work_dir}/livecd-image"
	aufs_remove_image "${work_dir}/${custom}-image"
	aufs_remove_image "${work_dir}/root-image"
	aufs_remove_image "${work_dir}/pkgs-image"
	aufs_remove_image "${work_dir}/lng-image"
	aufs_remove_image "${work_dir}/boot-image"
}
