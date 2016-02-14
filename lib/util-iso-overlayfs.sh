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
	msg2 "overlayfs: mount [root-image] on [%s]" "${1##*/}"
	mkdir -p "${work_dir}/work"
	mount -t overlay overlay -olowerdir="${work_dir}/root-image",upperdir="$1",workdir="${work_dir}/work" "$1"
}

mount_custom_image(){
	msg2 "overlayfs: mount [%s] on [%s-image]" "${1##*/}" "${custom}"
	mkdir -p "${work_dir}/work"
	mount -t overlay overlay -olowerdir="${work_dir}/${custom}-image":"${work_dir}/root-image",upperdir="$1",workdir="${work_dir}/work" "$1"
}

umount_image(){
	if mountpoint -q "$1";then
		msg2 "overlayfs: unmount %s" "${1##*/}"
		umount $1
		rm -rf "${work_dir}/work"
	fi
}
