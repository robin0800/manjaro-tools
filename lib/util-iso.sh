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

import ${LIBDIR}/util-iso-image.sh
import ${LIBDIR}/util-iso-boot.sh
import ${LIBDIR}/util-iso-calamares.sh
import ${LIBDIR}/util-pac-conf.sh

# $1: image path
squash_image_dir() {
	if [[ ! -d "$1" ]]; then
		error "$1 is not a directory"
		return 1
	fi
	local timer=$(get_timer) path=${work_dir}/iso/${iso_name}/${arch}
	local sq_img="${path}/${1##*/}.sqfs"
	mkdir -p ${path}
	msg "Generating SquashFS image for %s" "${1}"
	if [[ -f "${sq_img}" ]]; then
		local has_changed_dir=$(find ${1} -newer ${sq_img})
		msg2 "Possible changes for %s ..." "${1}"  >> /tmp/buildiso.debug
		msg2 "%s" "${has_changed_dir}" >> /tmp/buildiso.debug
		if [[ -n "${has_changed_dir}" ]]; then
			msg2 "SquashFS image %s is not up to date, rebuilding..." "${sq_img}"
			rm "${sq_img}"
		else
			msg2 "SquashFS image %s is up to date, skipping." "${sq_img}"
			return
		fi
	fi
	local highcomp="-b 256K -Xbcj x86"
	[[ "${iso_compression}" != "xz" ]] && highcomp=""
	msg2 "Creating SquashFS image. This may take some time..."
	local used_kernel=$(echo ${kernel} | cut -c 6)
	if [[ "${1##*/}" == "mhwd-image" && ${used_kernel} -ge "4" ]]; then
		mksquashfs "${1}" "${sq_img}" -noappend -comp lz4 || die "Exit ..."
	else
		mksquashfs "${1}" "${sq_img}" -noappend -comp ${iso_compression} ${highcomp} || die "Exit ..."
	fi
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}

run_xorriso(){
	msg "Creating ISO image..."
	local efi_boot_args=()
	if [[ -f "${work_dir}/iso/EFI/miso/${iso_name}.img" ]]; then
		msg2 "Setting efi args. El Torito detected."
		efi_boot_args=("-eltorito-alt-boot"
				"-e EFI/miso/${iso_name}.img"
				"-isohybrid-gpt-basdat"
				"-no-emul-boot")
	fi

	xorriso -as mkisofs \
		-iso-level 3 -rock -joliet \
		-max-iso9660-filenames -omit-period \
		-omit-version-number \
		-relaxed-filenames -allow-lowercase \
		-volid "${iso_label}" \
		-appid "${iso_app_id}" \
		-publisher "${iso_publisher}" \
		-preparer "Prepared by manjaro-tools/${0##*/}" \
		-eltorito-boot isolinux/isolinux.bin \
		-eltorito-catalog isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-isohybrid-mbr "${work_dir}/iso/isolinux/isohdpfx.bin" \
		${efi_boot_args[@]} \
		-output "${iso_dir}/${iso_file}" \
		"${work_dir}/iso/"
}

# Build ISO
make_iso() {
	msg "Start [Build ISO]"
	touch "${work_dir}/iso/.miso"
	for d in $(find "${work_dir}" -maxdepth 1 -type d -name '[^.]*'); do
		if [[ "$d" != "${work_dir}/iso" ]] && \
			[[ "${d##*/}" != "iso" ]] && \
			[[ "${d##*/}" != "efiboot" ]] && \
			[[ "$d" != "${work_dir}" ]]; then
			squash_image_dir "$d"
		fi
	done

	msg "Making bootable image"
	# Sanity checks
	[[ ! -d "${work_dir}/iso" ]] && die "[%s/iso] doesn't exist. What did you do?!" "${work_dir}"
	if [[ -f "${iso_dir}/${iso_file}" ]]; then
		msg2 "Removing existing bootable image..."
		rm -rf "${iso_dir}/${iso_file}"
	fi
	run_xorriso
	msg "Done [Build ISO]"
}

# $1: file
make_checksum(){
	cd ${iso_dir}
		msg "Creating [%s] sum ..." "${iso_checksum}"
		local cs=$(${iso_checksum}sum $1)
		msg2 "%s sum: %s" "${iso_checksum}" "${cs}"
		echo "${cs}" > $1.${iso_checksum}
		msg "Done [%s] sum" "${iso_checksum}"
	cd ..
}

# Base installation (root-image)
make_image_root() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [Base installation] (root-image)"
		local path="${work_dir}/root-image"
		mkdir -p ${path}

		if ! chroot_create "${path}" "${packages}"; then
			umount_image "${path}"
			die "Exit %s" "${FUNCNAME}"
		fi

		pacman -Qr "${path}" > "${path}/root-image-pkgs.txt"
		copy_overlay "${profile_dir}/root-overlay" "${path}"
		configure_root_image "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"
		clean_up_image "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [Base installation] (root-image)"
	fi
}

make_image_custom() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [%s installation] (%s-image)" "${custom}" "${custom}"
		local path="${work_dir}/${custom}-image"
		mkdir -p ${path}

		mount_root_image "${path}"

		if ! chroot_create "${path}" "${packages}"; then
			umount_image "${path}"
			die "Exit %s" "${FUNCNAME}"
		fi

		pacman -Qr "${path}" > "${path}/${custom}-image-pkgs.txt"
		cp "${path}/${custom}-image-pkgs.txt" ${iso_dir}/$(gen_iso_fn)-pkgs.txt
		[[ -e ${profile_dir}/${custom}-overlay ]] && copy_overlay "${profile_dir}/${custom}-overlay" "${path}"
		configure_custom_image "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"

		umount_image "${path}"

		clean_up_image "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [%s installation] (%s-image)" "${custom}" "${custom}"
	fi
}

make_image_live() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [live installation] (live-image)"
		local path="${work_dir}/live-image"
		mkdir -p ${path}

		if [[ -n "${custom}" ]] ; then
			mount_custom_image "${path}"
		else
			mount_root_image "${path}"
		fi

		if ! chroot_create "${path}" "${packages}"; then
			umount_image "${path}"
			die "Exit %s" "${FUNCNAME}"
		fi

		pacman -Qr "${path}" > "${path}/live-image-pkgs.txt"
		copy_overlay "${profile_dir}/live-overlay" "${path}"
		# copy over setup helpers and config loader
		copy_livecd_helpers "${path}/opt/livecd"
		copy_startup_scripts "${path}/usr/bin"
		configure_live_image "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"

		umount_image "${path}"

		# Clean up GnuPG keys
		rm -rf "${path}/etc/pacman.d/gnupg"
		clean_up_image "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [live-image]"
	fi
}

make_image_mhwd() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [drivers repository] (mhwd-image)"
		local path="${work_dir}/mhwd-image"
		mkdir -p ${path}/opt/livecd/pkgs

		if [[ -n "${custom}" ]] ; then
			mount_custom_image "${path}"
		else
			mount_root_image "${path}"
		fi

		${is_custom_pac_conf} && clean_pacman_conf "${path}"

		if ! download_to_cache "${path}" "${packages}"; then
			umount_image "${path}"
			die "Exit %s" "${FUNCNAME}"
		fi

		copy_cache_mhwd "${work_dir}/mhwd-image"

		if [[ -n "${packages_cleanup}" ]]; then
			for mhwd_clean in ${packages_cleanup}; do
				rm ${path}/opt/livecd/pkgs/${mhwd_clean}
			done
		fi
		cp ${DATADIR}/pacman-gfx.conf ${path}/opt/livecd
		make_repo "${path}"
		configure_mhwd_drivers "${path}"

		umount_image "${path}"

		rm -r ${path}/var
		rm -rf "${path}/etc"
		rm -f "${path}/cache-packages.txt"

		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [drivers repository] (mhwd-image)"
	fi
}

make_image_boot() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [%s/boot]" "${iso_name}"
		local path_iso="${work_dir}/iso/${iso_name}/boot"
		mkdir -p ${path_iso}/${arch}
		cp ${work_dir}/root-image/boot/memtest86+/memtest.bin ${path_iso}/${arch}/memtest
		cp ${work_dir}/root-image/boot/vmlinuz* ${path_iso}/${arch}/${iso_name}
		local path="${work_dir}/boot-image"
		mkdir -p ${path}

		if [[ -n "${custom}" ]] ; then
			mount_custom_image "${path}"
		else
			mount_root_image "${path}"
		fi

		copy_initcpio "${profile_dir}" "${path}" || die "Failed to copy initcpio."

		if ! gen_boot_image "${path}"; then
			umount_image "${path}"
			die "Exit %s" "${FUNCNAME}"
		fi

		mv ${path}/boot/${iso_name}.img ${path_iso}/${arch}/${iso_name}.img
		[[ -f ${path}/boot/intel-ucode.img ]] && copy_ucode "${path}" "${path_iso}"

		umount_image "${path}"

		rm -R ${path}
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [%s/boot]" "${iso_name}"
	fi
}

# Prepare /EFI
make_efi() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [%s/boot/EFI]" "${iso_name}"
		local path_iso="${work_dir}/iso"
		local path_efi="${path_iso}/EFI"
		mkdir -p ${path_efi}/boot
		copy_efi_loaders "${work_dir}/root-image" "${path_efi}/boot"
		mkdir -p ${path_iso}/loader/entries
		write_loader_conf "${path_iso}/loader"
		write_efi_shellv1_conf "${path_iso}/loader/entries"
		write_efi_shellv2_conf "${path_iso}/loader/entries"
		write_usb_conf "${path_iso}/loader/entries"
		write_usb_nonfree_conf "${path_iso}/loader/entries"
		copy_efi_shells "${path_efi}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [%s/boot/EFI]" "${iso_name}"
	fi
}

# Prepare kernel.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [%s/iso/EFI]" "${iso_name}"
		local path_iso="${work_dir}/iso"
		mkdir -p ${path_iso}/EFI/miso
		truncate -s ${efi_part_size} ${path_iso}/EFI/miso/${iso_name}.img
		mkfs.vfat -n MISO_EFI ${path_iso}/EFI/miso/${iso_name}.img
		mkdir -p ${work_dir}/efiboot
		mount ${path_iso}/EFI/miso/${iso_name}.img ${work_dir}/efiboot
		local path_efi="${work_dir}/efiboot/EFI"
		mkdir -p ${path_efi}/miso
		copy_boot_images "${path_iso}/${iso_name}/boot" "${path_efi}/miso"
		mkdir -p ${path_efi}/boot
		copy_efi_loaders "${work_dir}/root-image" "${path_efi}/boot"
		local efi_loader=${work_dir}/efiboot/loader
		mkdir -p ${efi_loader}/entries
		write_loader_conf "${efi_loader}"
		write_efi_shellv1_conf "${efi_loader}/entries"
		write_efi_shellv2_conf "${efi_loader}/entries"
		write_dvd_conf "${efi_loader}/entries"
		write_dvd_nonfree_conf "${efi_loader}/entries"
		copy_efi_shells "${path_efi}"
		umount ${work_dir}/efiboot
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [%s/iso/EFI]" "${iso_name}"
	fi
}

# Prepare /isolinux
make_isolinux() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [%s/iso/isolinux]" "${iso_name}"
		local path=${work_dir}/iso/isolinux
		mkdir -p ${path}
		copy_overlay "${DATADIR}/isolinux" "${path}"
		write_isolinux_cfg "${path}"
		write_isolinux_msg "${path}"
		if [[ -e ${profile_dir}/isolinux-overlay ]]; then
			copy_overlay "${profile_dir}/isolinux-overlay" "${path}"
			update_isolinux_cfg "${profile_dir}/isolinux-overlay" "${path}"
			update_isolinux_msg "${profile_dir}/isolinux-overlay" "${path}"
		fi
		copy_isolinux_bin "${work_dir}/root-image" "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [%s/iso/isolinux]" "${iso_name}"
	fi
}

make_isomounts() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Creating [isomounts]"
		write_isomounts "${work_dir}/iso/${iso_name}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done creating [isomounts]"
	fi
}

get_shared_list(){
	local path
	case ${edition} in
		sonar|netrunner) path=${run_dir}/shared/${edition}/Packages-Desktop ;;
		*) path=${run_dir}/shared/manjaro/Packages-Desktop ;;
	esac
	echo $path
}

# $1: file name
load_pkgs(){
	info "Loading Packages: [%s] ..." "${1##*/}"

	local _init _init_rm _multi _nonfree_default _nonfree_multi _arch _arch_rm _nonfree_i686 _nonfree_x86_64

	if [[ ${initsys} == 'openrc' ]];then
		_init="s|>openrc||g"
		_init_rm="s|>systemd.*||g"
	else
		_init="s|>systemd||g"
		_init_rm="s|>openrc.*||g"
	fi
	if [[ "${arch}" == "i686" ]]; then
		_arch="s|>i686||g"
		_arch_rm="s|>x86_64.*||g"
		_multi="s|>multilib.*||g"
		_nonfree_multi="s|>nonfree_multilib.*||g"
		_nonfree_x86_64="s|>nonfree_x86_64.*||g"
		if ${nonfree_xorg};then
			_nonfree_default="s|>nonfree_default||g"
			_nonfree_i686="s|>nonfree_i686||g"

		else
			_nonfree_default="s|>nonfree_default.*||g"
			_nonfree_i686="s|>nonfree_i686.*||g"
		fi
	else
		_arch="s|>x86_64||g"
		_arch_rm="s|>i686.*||g"
		_nonfree_i686="s|>nonfree_i686.*||g"
		if ${multilib};then
			_multi="s|>multilib||g"
			if ${nonfree_xorg};then
				_nonfree_default="s|>nonfree_default||g"
				_nonfree_x86_64="s|>nonfree_x86_64||g"
				_nonfree_multi="s|>nonfree_multilib||g"
			else
				_nonfree_default="s|>nonfree_default.*||g"
				_nonfree_multi="s|>nonfree_multilib.*||g"
				_nonfree_x86_64="s|>nonfree_x86_64.*||g"
			fi
		else
			_multi="s|>multilib.*||g"
			if ${nonfree_xorg};then
				_nonfree_default="s|>nonfree_default||g"
				_nonfree_x86_64="s|>nonfree_x86_64||g"
				_nonfree_multi="s|>nonfree_multilib.*||g"
			else
				_nonfree_default="s|>nonfree_default.*||g"
				_nonfree_x86_64="s|>nonfree_x86_64.*||g"
				_nonfree_multi="s|>nonfree_multilib.*||g"
			fi
		fi
	fi
	local _blacklist="s|>blacklist.*||g" \
		_kernel="s|KERNEL|$kernel|g" \
		_used_kernel=${kernel:5:2} \
		_space="s| ||g" \
		_clean=':a;N;$!ba;s/\n/ /g' \
		_com_rm="s|#.*||g" \
		_purge="s|>cleanup.*||g" \
		_purge_rm="s|>cleanup||g"

	local list

	if [[ $1 == "${packages_custom}" ]];then
		sort -u $(get_shared_list) ${packages_custom} > ${work_dir}/pkgs_merged
		list=${work_dir}/pkgs_merged
	else
		list=$1
	fi

	packages=$(sed "$_com_rm" "$list" \
			| sed "$_space" \
			| sed "$_blacklist" \
			| sed "$_purge" \
			| sed "$_init" \
			| sed "$_init_rm" \
			| sed "$_arch" \
			| sed "$_arch_rm" \
			| sed "$_nonfree_default" \
			| sed "$_multi" \
			| sed "$_nonfree_i686" \
			| sed "$_nonfree_x86_64" \
			| sed "$_nonfree_multi" \
			| sed "$_kernel" \
			| sed "$_clean")

	if [[ ${1##*/} == 'Packages-Mhwd' ]]; then
		packages_cleanup=$(sed "$_com_rm" "$1" \
			| grep cleanup \
			| sed "$_purge_rm" \
			| sed "$_kernel" \
			| sed "$_clean")
		[[ ${_used_kernel} < "42" ]] && packages_cleanup="$packages_cleanup xf86-video-amdgpu"
	fi
}

check_custom_pacman_conf(){
	if [[ -f $1/pacman-${pacman_conf_arch}.conf ]]; then
		pacman_conf="$1/pacman-${pacman_conf_arch}.conf"
		is_custom_pac_conf=true
	else
		pacman_conf="${DATADIR}/pacman-${pacman_conf_arch}.conf"
		is_custom_pac_conf=false
	fi
}

eval_custom(){
	local name=${1##*/}
	name=${name#*-}
	custom=${name,,}
}

# $1: profile
check_profile_sanity(){
	local keyfiles=("$1/profile.conf" "$1/mkinitcpio.conf" "$1/Packages-Root" "$1/Packages-Live")
	local keydirs=("$1/root-overlay" "$1/live-overlay")
	local has_keyfiles=false has_keydirs=false
	for f in ${keyfiles[@]}; do
		if [[ -f $f ]];then
			has_keyfiles=true
		else
			has_keyfiles=false
			break
		fi
	done
	for d in ${keydirs[@]}; do
		if [[ -d $d ]];then
			has_keydirs=true
		else
			has_keydirs=false
			break
		fi
	done
	if ! ${has_keyfiles} && ! ${has_keydirs};then
		die "Profile [%s] sanity check failed!" "$1"
	fi

	local files=$(ls $1/Packages*)
	for f in ${files[@]};do
		case $f in
			$1/Packages-Root|$1/Packages-Live|$1/Packages-Mhwd) continue ;;
			*) packages_custom="$f" ;;
		esac
	done

	eval_custom "${packages_custom}"

	[[ -f "$1/Packages-Mhwd" ]] && packages_mhwd=$1/Packages-Mhwd
}

check_requirements(){
	[[ -f ${run_dir}/.buildiso ]] || die "%s is not a valid iso profiles directory!" "${run_dir}"
	if ! $(is_valid_arch_iso ${arch});then
		die "%s is not a valid arch!" "${arch}"
	fi
	if ! $(is_valid_branch ${branch});then
		die "%s is not a valid branch!" "${branch}"
	fi

	local iso_kernel=${kernel:5:1} host_kernel=$(uname -r)

	if [[ ${iso_kernel} < "4" ]] || [[ ${host_kernel%%*.} < "4" ]];then
		use_overlayfs='false'
	fi

	if ${use_overlayfs};then
		iso_fs="overlayfs"
	else
		iso_fs="aufs"
	fi
}

check_profile_vars(){
	if ! is_valid_init "${initsys}";then
		die "initsys only accepts openrc/systemd value!"
	fi
	if ! is_valid_bool "${autologin}";then
		die "autologin only accepts true/false value!"
	fi
	if ! is_valid_bool "${multilib}";then
		die "multilib only accepts true/false value!"
	fi
	if ! is_valid_bool "${nonfree_xorg}";then
		die "nonfree_xorg only accepts true/false value!"
	fi
	if ! is_valid_bool "${plymouth_boot}";then
		die "plymouth_boot only accepts true/false value!"
	fi
	if ! is_valid_bool "${pxe_boot}";then
		die "pxe_boot only accepts true/false value!"
	fi
}

# $1: profile
load_profile(){
	profile_dir=$1
	local prof=${1##*/}
	info "Profile: [%s]" "$prof"
	check_profile_sanity "${profile_dir}"
	load_profile_config "${profile_dir}/profile.conf" || die "%s is not a valid profile!" "${profile_dir}"
	check_profile_vars

	iso_file=$(gen_iso_fn).iso

	check_custom_pacman_conf "${profile_dir}"

	mkchroot_args+=(-C ${pacman_conf} -S ${mirrors_conf} -B "${build_mirror}/${branch}" -K)
	work_dir=${chroots_iso}/$prof/${arch}

	iso_dir="${cache_dir_iso}/${edition}/$prof/${dist_release}/${arch}"

	prepare_dir "${iso_dir}"
}

compress_images(){
	local timer=$(get_timer)
	make_iso
	make_checksum "${iso_file}"
	chown -R "${OWNER}:users" "${iso_dir}"
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}

build_images(){
	local timer=$(get_timer)
	load_pkgs "${profile_dir}/Packages-Root"
	make_image_root
	if [[ -f "${packages_custom}" ]] ; then
		load_pkgs "${packages_custom}"
		make_image_custom
	fi
	if [[ -f ${profile_dir}/Packages-Live ]]; then
		load_pkgs "${profile_dir}/Packages-Live"
		make_image_live
	fi
	if [[ -f ${profile_dir}/Packages-Mhwd ]] ; then
		load_pkgs "${profile_dir}/Packages-Mhwd"
		make_image_mhwd
	fi
	make_image_boot
	if [[ "${arch}" == "x86_64" ]]; then
		make_efi
		make_efiboot
	fi
	make_isolinux
	make_isomounts
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}

make_profile(){
	eval_edition "$1"
	load_profile "${run_dir}/${edition}/$1"

	msg "Start building [%s]" "$1"
	import ${LIBDIR}/util-iso-${iso_fs}.sh
	${clean_first} && chroot_clean "${work_dir}"
	if ${iso_only}; then
		[[ ! -d ${work_dir} ]] && die "Create images: buildiso -p %s -x" "$1"
		compress_images
		exit 1
	fi
	if ${images_only}; then
		build_images
		warning "Continue compress: buildiso -p %s -zc ..." "$1"
		exit 1
	else
		build_images
		compress_images
	fi
	unset_profile
	msg "Finished building [%s]" "$1"
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}
