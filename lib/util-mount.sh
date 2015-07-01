#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

ignore_error() {
	"$@" 2>/dev/null
	return 0
}

parse_fstab(){
# 	perl -ane 'printf("Device: %s\nMountpoint: %s\n", @F[0,1]) if $F[0] =~ m#^/dev#;' $1
	mounts=$(perl -ane 'printf("%s:%s\n", @F[0,1]) if $F[0] =~ m#^UUID=#;' $1)
# 	perl -ane 'printf("Device: %s\nMountpoint: %s\n", @F[0,1]) if $F[0] =~ m#^LABEL=#;' $1
}

get_os(){
	local detected=( "$(os-prober | tr ' ' '_' | paste -s -d ' ')" )
	echo ${detected[@]}
}

chroot_mount_partitions(){
	for os in $(get_os);do
		if [[ "${os##*:}" == 'linux' ]];then
			mount ${os%%:*} $1
			parse_fstab "$1/etc/fstab"
			#umount $1
		fi
	done
	local m_args=()
	for entry in ${mounts[@]};do
		entry=${entry//UUID=}
		local dev=${entry%:*}
		m_args+=("$dev")
		if [[ "${entry#*:}" != '/' && "${entry#*:}" != 'none' ]];then
			local mp=$1${entry#*:}
			m_args+=("$mp")
			mount /dev/disk/by-uuid/${m_args[@]}
		fi
		unset m_args
	done
}

chroot_mount() {
	mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
}

chroot_mount_conditional() {
	local cond=$1; shift
	if eval "$cond"; then
		chroot_mount "$@"
	fi
}

chroot_api_mount() {
	CHROOT_ACTIVE_MOUNTS=()
	[[ $(trap -p EXIT) ]] && die 'Error! Attempting to overwrite existing EXIT trap'
	trap 'chroot_api_umount' EXIT

	chroot_mount_conditional "! mountpoint -q '$1'" "$1" "$1" --bind &&
	chroot_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
	chroot_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
# 	ignore_error chroot_mount_conditional "[[ -d '$1/sys/firmware/efi/efivars' ]]" \
# 	   efivarfs "$1/sys/firmware/efi/efivars" -t efivarfs -o nosuid,noexec,nodev &&
	chroot_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&
	chroot_mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
	chroot_mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
	chroot_mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
	chroot_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
}

chroot_api_umount() {
	umount "${CHROOT_ACTIVE_MOUNTS[@]}"
	unset CHROOT_ACTIVE_MOUNTS
}
