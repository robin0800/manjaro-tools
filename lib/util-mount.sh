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
	echo $(perl -ane 'printf("%s:%s\n", @F[0,1]) if $F[0] =~ m#^UUID=#;' $1/etc/fstab)
# 	perl -ane 'printf("%s:%s\n", @F[0,1]) if $F[0] =~ m#^/dev#;' $1/etc/fstab	
# 	perl -ane 'printf("%s:%s\n", @F[0,1]) if $F[0] =~ m#^LABEL=#;' $1/etc/fstab
}

get_os(){
	local detected=( "$(os-prober | tr ' ' '_' | paste -s -d ' ')" )
	echo ${detected[@]}
}

get_os_name(){
        local str=$1
        str="${str#*:}"
        str="${str#*:}"
        str="${str//:/}"
        echo "$str"
}

chroot_part_mount() {
	mount "$@" && CHROOT_ACTIVE_PART_MOUNTS=("$2" "${CHROOT_ACTIVE_PART_MOUNTS[@]}")
	msg2 "active_mounts: ${CHROOT_ACTIVE_PART_MOUNTS[@]}"
}

chroot_mount_partitions(){
	for os in $(get_os);do
		case "${os##*:}" in
			'linux')
				msg "Detected OS: $(get_os_name $os)"
                                
				CHROOT_ACTIVE_PART_MOUNTS=()
				CHROOT_ACTIVE_MOUNTS=()
				
				[[ $(trap -p EXIT) ]] && die 'Error! Attempting to overwrite existing EXIT trap'
				trap 'trap_handler' EXIT

				chroot_part_mount ${os%%:*} $1
				local mounts=$(parse_fstab "$1")
				
				for entry in ${mounts[@]}; do
					entry=${entry//UUID=}
					local dev=${entry%:*}
					local mp=${entry#*:}
					case "${entry#*:}" in
						'/'|'/home'|'swap') continue ;;
						*) chroot_part_mount "/dev/disk/by-uuid/${dev}" "$1${mp}" ;;
					esac
				done
				
				chroot_mount_conditional "! mountpoint -q '$1'" "$1" "$1" --bind &&
				chroot_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
				chroot_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
# 				ignore_error chroot_mount_conditional "[[ -d '$1/sys/firmware/efi/efivars' ]]" \
# 					efivarfs "$1/sys/firmware/efi/efivars" -t efivarfs -o nosuid,noexec,nodev &&
				chroot_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&
				chroot_mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
				chroot_mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
				chroot_mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
				chroot_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
				chroot_mount /etc/resolv.conf "$1/etc/resolv.conf" --bind
			;;
		esac
	done
}

chroot_mount() {
	mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
	msg2 "active_mounts: ${CHROOT_ACTIVE_MOUNTS[@]}"
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

chroot_part_umount() {
	umount "${CHROOT_ACTIVE_PART_MOUNTS[@]}"
	unset CHROOT_ACTIVE_PART_MOUNTS
}

chroot_api_umount() {
	umount "${CHROOT_ACTIVE_MOUNTS[@]}"
	unset CHROOT_ACTIVE_MOUNTS
}

trap_handler(){
    chroot_api_umount
    chroot_part_umount
}