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

[[ -r ${LIBDIR}/util-iso-image.sh ]] && source ${LIBDIR}/util-iso-image.sh
[[ -r ${LIBDIR}/util-iso-boot.sh ]] && source ${LIBDIR}/util-iso-boot.sh
[[ -r ${LIBDIR}/util-iso-calamares.sh ]] && source ${LIBDIR}/util-iso-calamares.sh

# check_run_dir(){
# 	if [[ ! -f shared/Packages-Systemd ]] || [[ ! -f shared/Packages-Openrc ]];then
# 		die "${0##*/} is not run in a valid iso-profiles folder!"
# 	fi
# }

copy_overlay_root(){
	msg2 "Copying overlay ..."
	cp -a --no-preserve=ownership overlay/* $1
}

copy_overlay_custom(){
	msg2 "Copying ${custom}-overlay ..."
	cp -a --no-preserve=ownership ${custom}-overlay/* ${work_dir}/${custom}-image
}

copy_overlay_livecd(){
	msg2 "Copying overlay-livecd ..."
	if [[ -L overlay-livecd ]];then
		cp -a --no-preserve=ownership overlay-livecd/* $1
	else
		msg2 "Copying custom overlay-livecd ..."
		cp -LR overlay-livecd/* $1
	fi
}

copy_startup_scripts(){
	msg2 "Copying startup scripts ..."
	cp ${PKGDATADIR}/scripts/livecd $1
	cp ${PKGDATADIR}/scripts/mhwd-live $1
	chmod +x $1/livecd
	chmod +x $1/mhwd-live
}

write_profile_conf_entries(){
	local conf=$1/profile.conf
	echo '' >> ${conf}
	echo '# custom image name' >> ${conf}
	echo "custom=${custom}" >> ${conf}
	echo '' >> ${conf}
	echo '# iso_name' >> ${conf}
	echo "iso_name=${iso_name}" >> ${conf}
}

copy_livecd_helpers(){
	msg2 "Copying livecd helpers ..."
	[[ ! -d $1 ]] && mkdir -p $1
	cp ${LIBDIR}/util-livecd.sh $1
	cp ${LIBDIR}/util-msg.sh $1
	cp ${LIBDIR}/util.sh $1
	cp ${PKGDATADIR}/scripts/kbd-model-map $1

	cp ${profile_conf} $1

	write_profile_conf_entries $1
}

copy_cache_lng(){
	msg2 "Copying language package cache ..."
	rsync -v --files-from="${work_dir}/lng-image/cache-packages.txt" /var/cache/pacman/pkg "${work_dir}/lng-image/opt/livecd/lng"
	rm -f "${work_dir}/lng-image/cache-packages.txt"
}

copy_cache_xorg(){
	msg2 "Copying xorg package cache ..."
	rsync -v --files-from="${work_dir}/pkgs-image/cache-packages.txt" /var/cache/pacman/pkg "${work_dir}/pkgs-image/opt/livecd/pkgs"
	rm -f "${work_dir}/pkgs-image/cache-packages.txt"
}

prepare_cachedirs(){
	prepare_dir "${cache_dir_iso}"
}

# $1: image path
squash_image_dir() {
	if [[ ! -d "$1" ]]; then
		error "$1 is not a directory"
		return 1
	fi
	local timer=$(get_timer) path=${work_dir}/iso/${iso_name}/${arch}
	local sq_img="${path}/$(basename ${1}).sqfs"
	mkdir -p ${path}
	msg "Generating SquashFS image for '${1}'"
	if [[ -f "${sq_img}" ]]; then
		local has_changed_dir=$(find ${1} -newer ${sq_img})
		msg2 "Possible changes for ${1}..." >> /tmp/buildiso.debug
		msg2 "${has_changed_dir}" >> /tmp/buildiso.debug
		if [[ -n "${has_changed_dir}" ]]; then
			msg2 "SquashFS image '${sq_img}' is not up to date, rebuilding..."
			rm "${sq_img}"
		else
			msg2 "SquashFS image '${sq_img}' is up to date, skipping."
			return
		fi
	fi
	local highcomp="-b 256K -Xbcj x86"
	[[ "${iso_compression}" != "xz" ]] && highcomp=""
	msg2 "Creating SquashFS image. This may take some time..."
	mksquashfs "${1}" "${sq_img}" -noappend -comp ${iso_compression} ${highcomp}
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer}) minutes"
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
			-output "${cache_dir_iso}/${iso_file}" \
			"${work_dir}/iso/"
}

# Build ISO
make_iso() {
	msg "Start [Build ISO]"
	touch "${work_dir}/iso/.miso"
	for d in $(find "${work_dir}" -maxdepth 1 -type d -name '[^.]*'); do
		if [[ "$d" != "${work_dir}/iso" ]] && \
			[[ "$(basename "$d")" != "iso" ]] && \
			[[ "$(basename "$d")" != "efiboot" ]] && \
			[[ "$d" != "${work_dir}" ]]; then
			squash_image_dir "$d" || die "Exit ..."
		fi
	done

	msg "Making bootable image"
	# Sanity checks
	[[ ! -d "${work_dir}/iso" ]] && die "[${work_dir}/iso] doesn't exist. What did you do?!"
	if [[ -f "${cache_dir_iso}/${iso_file}" ]]; then
		msg2 "Removing existing bootable image..."
		rm -rf "${cache_dir_iso}/${iso_file}"
	fi

	run_xorriso

	chown -R "${OWNER}:users" "${cache_dir_iso}"
	msg "Done [Build ISO]"
}

# $1: file
make_checksum(){
	cd ${cache_dir_iso}
		msg "Creating [${iso_checksum}sum] ..."
		local cs=$(${iso_checksum}sum $1)
		msg2 "${iso_checksum}sum: ${cs}"
		echo "${cs}" > $1.${iso_checksum}
		msg "Done [${iso_checksum}sum]"
	cd ..
}

# Base installation (root-image)
make_image_root() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [Base installation] (root-image)"
		local path="${work_dir}/root-image"
		mkdir -p ${path}
		chroot_create "${path}" "${packages}"
		clean_up_image "${path}"
		pacman -Qr "${path}" > "${path}/root-image-pkgs.txt"
		configure_lsb "${path}"
		copy_overlay_root "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [Base installation] (root-image)"
	fi
}

make_image_custom() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${custom} installation] (${custom}-image)"
		local path="${work_dir}/${custom}-image"
		mkdir -p ${path}
		if [[ ${use_overlayfs} == "true" ]];then
			mkdir -p "${work_dir}/work"
			mount -t overlay overlay -olowerdir="${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
		else
			umount_image_handler
			aufs_mount_root_image "${path}"
		fi
		chroot_create "${path}" "${packages}"
		clean_up_image "${path}"
		pacman -Qr "${path}" > "${path}/${custom}-image-pkgs.txt"
		cp "${path}/${custom}-image-pkgs.txt" ${cache_dir_iso}/${iso_name}-${custom}-${dist_release}-${arch}-pkgs.txt
		[[ -d ${custom}-overlay ]] && copy_overlay_custom
		configure_custom_image "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"
		if [[ ${use_overlayfs} == "true" ]];then
			umount "${path}"
			rm -rf "${work_dir}/work"
		else
			umount_image_handler
			aufs_clean "${path}"
		fi
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [${custom} installation] (${custom}-image)"
	fi
}

make_image_livecd() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [livecd installation] (livecd-image)"
		local path="${work_dir}/livecd-image"
		mkdir -p ${path}
		if [[ ${use_overlayfs} == "true" ]];then
			mkdir -p "${work_dir}/work"
			if [[ -n "${custom}" ]] ; then
				mount -t overlay overlay -olowerdir="${work_dir}/${custom}-image":"${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
			else
				mount -t overlay overlay -olowerdir="${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
			fi
		else
			umount_image_handler
			if [[ -n "${custom}" ]] ; then
				aufs_mount_custom_image "${path}"
				aufs_append_root_image "${path}"
			else
				aufs_mount_root_image "${path}"
			fi
		fi
		chroot_create "${path}" "${packages}"
		clean_up_image "${path}"
		pacman -Qr "${path}" > "${path}/livecd-image-pkgs.txt"
		copy_overlay_livecd "${path}"
		# copy over setup helpers and config loader
		copy_livecd_helpers "${path}/opt/livecd"
		copy_startup_scripts "${path}/usr/bin"
		configure_livecd_image "${path}"
		${is_custom_pac_conf} && clean_pacman_conf "${path}"
		# Clean up GnuPG keys?
		rm -rf "${path}/etc/pacman.d/gnupg"
		if [[ ${use_overlayfs} == "true" ]];then
			umount "${path}"
			rm -rf "${work_dir}/work"
		else
			umount_image_handler
			aufs_clean "${path}"
		fi
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [livecd-image]"
	fi
}

make_image_xorg() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [pkgs-image]"
		local path="${work_dir}/pkgs-image"
		mkdir -p ${path}/opt/livecd/pkgs
		if [[ ${use_overlayfs} == "true" ]];then
			mkdir -p "${work_dir}/work"
			if [[ -n "${custom}" ]] ; then
				mount -t overlay overlay -olowerdir="${work_dir}/${custom}-image":"${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
			else
				mount -t overlay overlay -olowerdir="${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
			fi
		else
			umount_image_handler
			if [[ -n "${custom}" ]] ; then
				aufs_mount_custom_image "${path}"
				aufs_append_root_image "${path}"
			else
				aufs_mount_root_image "${path}"
			fi
		fi
		download_to_cache "${path}" "${packages_xorg}"
		copy_cache_xorg
		if [[ -n "${packages_xorg_cleanup}" ]]; then
			for xorg_clean in ${packages_xorg_cleanup}; do
				rm ${path}/opt/livecd/pkgs/${xorg_clean}
			done
		fi
		cp ${PKGDATADIR}/pacman-gfx.conf ${path}/opt/livecd
		rm -r ${path}/var
		make_repo "${path}/opt/livecd/pkgs/gfx-pkgs" "${path}/opt/livecd/pkgs"
		configure_xorg_drivers "${path}"
		if [[ ${use_overlayfs} == "true" ]];then
			umount "${path}"
			rm -rf "${work_dir}/work"
		else
			umount_image_handler
			aufs_clean "${path}"
		fi
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [pkgs-image]"
	fi
}

make_image_lng() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [lng-image]"
		local path="${work_dir}/lng-image"
		mkdir -p ${path}/opt/livecd/lng
		if [[ ${use_overlayfs} == "true" ]];then
			mkdir -p "${work_dir}/work"
			if [[ -n "${custom}" ]] ; then
				mount -t overlay overlay -olowerdir="${work_dir}/${custom}-image":"${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
			else
				mount -t overlay overlay -olowerdir="${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
			fi
		else
			umount_image_handler
			if [[ -n "${custom}" ]] ; then
				aufs_mount_custom_image "${path}"
				aufs_append_root_image "${path}"
			else
				aufs_mount_root_image "${path}"
			fi
		fi
		if [[ -n ${packages_lng_kde} ]]; then
			download_to_cache "${path}" "${packages_lng} ${packages_lng_kde}"
			copy_cache_lng
		else
			download_to_cache "${path}" "${packages_lng}"
			copy_cache_lng
		fi
		if [[ -n "${packages_lng_cleanup}" ]]; then
			for lng_clean in ${packages_lng_cleanup}; do
				rm ${path}/opt/livecd/lng/${lng_clean}
			done
		fi
		cp ${PKGDATADIR}/pacman-lng.conf ${path}/opt/livecd
		rm -r ${path}/var
		make_repo ${path}/opt/livecd/lng/lng-pkgs ${path}/opt/livecd/lng
		if [[ ${use_overlayfs} == "true" ]];then
			umount "${path}"
			rm -rf "${work_dir}/work"
		else
			umount_image_handler
			aufs_clean "${path}"
		fi
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [lng-image]"
	fi
}

make_image_boot() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${iso_name}/boot]"
		local path_iso="${work_dir}/iso/${iso_name}/boot"
		mkdir -p ${path_iso}/${arch}
		cp ${work_dir}/root-image/boot/memtest86+/memtest.bin ${path_iso}/${arch}/memtest
		cp ${work_dir}/root-image/boot/vmlinuz* ${path_iso}/${arch}/${iso_name}
		local path="${work_dir}/boot-image"
		mkdir -p ${path}
		if [[ ${use_overlayfs} == "true" ]];then
			mkdir -p "${work_dir}/work"
			if [[ -n "${custom}" ]] ; then
				mount -t overlay overlay -olowerdir="${work_dir}/${custom}-image":"${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
			else
				mount -t overlay overlay -olowerdir="${work_dir}/root-image",upperdir="${path}",workdir="${work_dir}/work" "${path}"
			fi
		else
			umount_image_handler
			if [[ -n "${custom}" ]] ; then
				aufs_mount_custom_image "${path}"
				aufs_append_root_image "${path}"
			else
				aufs_mount_root_image "${path}"
			fi
		fi
		copy_initcpio "${path}" || die "Failed to copy initcpio."
		gen_boot_image "${path}"
		mv ${path}/boot/${iso_name}.img ${path_iso}/${arch}/${iso_name}.img
		[[ -f ${path}/boot/intel-ucode.img ]] && copy_ucode "${path}" "${path_iso}"
		if [[ ${use_overlayfs} == "true" ]];then
			umount "${path}"
			rm -rf "${work_dir}/work"
		else
			umount_image_handler
		fi
		rm -R ${path}
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [${iso_name}/boot]"
	fi
}

# Prepare /EFI
make_efi() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${iso_name}/boot/EFI]"
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
		msg "Done [${iso_name}/boot/EFI]"
	fi
}

# Prepare kernel.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${iso_name}/iso/EFI]"
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
		msg "Done [${iso_name}/iso/EFI]"
	fi
}

# Prepare /isolinux
make_isolinux() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Prepare [${iso_name}/iso/isolinux]"
		local path=${work_dir}/iso/isolinux
		mkdir -p ${path}
		cp -a --no-preserve=ownership isolinux/* ${path}
		write_isolinux_cfg "${path}"
		write_isolinux_msg "${path}"
		if [[ -e isolinux-overlay ]]; then
			msg2 "isolinux overlay found. Overwriting files ..."
			cp -a --no-preserve=ownership isolinux-overlay/* ${path}
			update_isolinux_cfg "${path}"
			update_isolinux_msg "${path}"
		fi
		copy_isolinux_bin "${work_dir}/root-image" "${path}"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done [${iso_name}/iso/isolinux]"
	fi
}

make_isomounts() {
	if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
		msg "Creating [isomounts]"
		write_isomounts "${work_dir}/iso/${iso_name}/isomounts"
		: > ${work_dir}/build.${FUNCNAME}
		msg "Done creating [isomounts]"
	fi
}

# $1: file name
load_pkgs(){
	msg3 "Loading Packages: [$1] ..."
	if [[ "${arch}" == "i686" ]]; then
		packages=$(sed "s|#.*||g" "$1" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|KERNEL|$kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	elif [[ "${arch}" == "x86_64" ]]; then
		packages=$(sed "s|#.*||g" "$1" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|KERNEL|$kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	fi
}

load_pkgs_xorg(){
	msg3 "Loading Packages: [Packages-Xorg] ..."
	if [[ "${arch}" == "i686" ]]; then
		packages_xorg=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni||g" | sed "s|>nonfree_x64.*||g" | sed "s|>nonfree_uni||g" | sed "s|KERNEL|$kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	elif [[ "${arch}" == "x86_64" ]]; then
		packages_xorg=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>free_x64||g" | sed "s|>free_uni||g" | sed "s|>nonfree_uni||g" | sed "s|>nonfree_x64||g" | sed "s|KERNEL|$kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	fi
	packages_xorg_cleanup=$(sed "s|#.*||g" Packages-Xorg | grep cleanup | sed "s|>cleanup||g" | sed "s|KERNEL|$kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
}

load_pkgs_lng(){
	msg3 "Loading Packages: [Packages-Lng] ..."
	if [[ "${arch}" == "i686" ]]; then
		packages_lng=$(sed "s|#.*||g" Packages-Lng | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>kde.*||g" | sed ':a;N;$!ba;s/\n/ /g')
	elif [[ "${arch}" == "x86_64" ]]; then
		packages_lng=$(sed "s|#.*||g" Packages-Lng | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>kde.*||g" | sed ':a;N;$!ba;s/\n/ /g')
	fi
	packages_lng_cleanup=$(sed "s|#.*||g" Packages-Lng | grep cleanup | sed "s|>cleanup||g")
	packages_lng_kde=$(sed "s|#.*||g" Packages-Lng | grep kde | sed "s|>kde||g" | sed ':a;N;$!ba;s/\n/ /g')
}

check_chroot_version(){
	[[ -f ${work_dir}/root-image/.manjaro-tools ]] && local chroot_version=$(cat ${work_dir}/root-image/.manjaro-tools)
	[[ ${version} != $chroot_version ]] && clean_first=true
}

check_plymouth(){
	is_plymouth=false
	source mkinitcpio.conf
	for h in ${HOOKS[@]};do
		[[ $h == 'plymouth' ]] && is_plymouth=true
	done
}

check_custom_pacman_conf(){
	if [[ -f pacman-${pacman_conf_arch}.conf ]]; then
		pacman_conf="pacman-${pacman_conf_arch}.conf"
		is_custom_pac_conf=true
	else
		pacman_conf="${PKGDATADIR}/pacman-${pacman_conf_arch}.conf"
		is_custom_pac_conf=false
	fi
}

# $1: profile
load_profile(){
	msg3 "Profile: [$1]"
	load_profile_config 'profile.conf'
	local files=$(ls Packages*)
	for f in ${files[@]};do
		case $f in
			Packages|Packages-Livecd|Packages-Xorg|Packages-Lng) continue ;;
			*) packages_custom="$f" ;;
		esac
	done
	custom=${packages_custom#*-}
	custom=${custom,,}
	iso_file="${iso_name}-${custom}-${dist_release}-${arch}.iso"

	check_custom_pacman_conf

	mkchroot_args+=(-C ${pacman_conf} -S ${mirrors_conf} -B "${build_mirror}/${branch}" -K)
	work_dir=${chroots_iso}/$1/${arch}

	check_plymouth

	[[ -d ${work_dir}/root-image ]] && check_chroot_version
}

compress_images(){
	local timer=$(get_timer)
	make_iso
	make_checksum "${iso_file}"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer}) minutes"
}

build_images(){
	local timer=$(get_timer)
	load_pkgs "Packages"
	make_image_root
	if [[ -f "${packages_custom}" ]] ; then
		load_pkgs "${packages_custom}"
		make_image_custom
	fi
	if [[ -f Packages-Livecd ]]; then
		load_pkgs "Packages-Livecd"
		make_image_livecd
	fi
	if [[ -f Packages-Xorg ]] ; then
		load_pkgs_xorg
		make_image_xorg
	fi
	if [[ -f Packages-Lng ]] ; then
		load_pkgs_lng
		make_image_lng
	fi
	make_image_boot
	if [[ "${arch}" == "x86_64" ]]; then
		make_efi
		make_efiboot
	fi
	make_isolinux
	make_isomounts
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer}) minutes"
}

make_profile(){
	msg "Start building [$1]"
	cd $1
		load_profile "$1"
		${clean_first} && chroot_clean "${work_dir}"
		if ${iso_only}; then
			[[ ! -d ${work_dir} ]] && die "Create images: buildiso -p ${buildset_iso} -i"
			compress_images
			exit 1
		fi
		if ${images_only}; then
			build_images
			warning "Continue compress: buildiso -p ${buildset_iso} -sc ..."
			exit 1
		else
			build_images
			compress_images
		fi
	cd ..
	msg "Finished building [$1]"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}

build_iso(){
	if ${is_buildset};then
		for prof in $(cat ${sets_dir_iso}/${buildset_iso}.set); do
			check_profile "$prof" "break"
			make_profile "$prof"
		done
	else
		check_profile "${buildset_iso}" 'die "Profile sanity check failed."'
		make_profile "${buildset_iso}"
	fi
}
