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

[[ -r ${LIBDIR}/util-iso-calamares.sh ]] && source ${LIBDIR}/util-iso-calamares.sh
[[ -r ${LIBDIR}/util-iso-image.sh ]] && source ${LIBDIR}/util-iso-image.sh

copy_initcpio(){
    cp /usr/lib/initcpio/hooks/miso* $1/usr/lib/initcpio/hooks
    cp /usr/lib/initcpio/install/miso* $1/usr/lib/initcpio/install
    cp mkinitcpio.conf $1/etc/mkinitcpio-${manjaroiso}.conf
}

copy_overlay_root(){
    msg2 "Copying overlay ..."
    cp -a --no-preserve=ownership overlay/* $1
}

copy_overlay_desktop(){
    msg2 "Copying ${desktop}-overlay ..."
    cp -a --no-preserve=ownership ${desktop}-overlay/* ${work_dir}/${desktop}-image
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
    
    # fix script permissions
    chmod +x $1/livecd
    chmod +x $1/mhwd-live
    
    cp ${BINDIR}/chroot-run $1

    # fix paths
    sed -e "s|${LIBDIR}|/opt/livecd|g" -i $1/chroot-run
}

copy_livecd_helpers(){
    msg2 "Copying livecd helpers ..."	
    [[ ! -d $1 ]] && mkdir -p $1
    cp ${LIBDIR}/util-livecd.sh $1
    cp ${LIBDIR}/util-msg.sh $1
    cp ${LIBDIR}/util-mount.sh $1
    cp ${LIBDIR}/util.sh $1

    
    if [[ -f ${USER_CONFIG}/manjaro-tools.conf ]]; then
	msg2 "Copying ${USER_CONFIG}/manjaro-tools.conf ..."
	cp ${USER_CONFIG}/manjaro-tools.conf $1
    else
	msg2 "Copying ${manjaro_tools_conf} ..."
	cp ${manjaro_tools_conf} $1
    fi 
}

copy_cache_lng(){
    msg2 "Copying lng cache ..."
    cp ${cache_dir_lng}/* ${work_dir}/lng-image/opt/livecd/lng
}

copy_cache_xorg(){
    msg2 "Copying xorg pkgs cache ..."
    cp ${cache_dir_xorg}/* ${work_dir}/pkgs-image/opt/livecd/pkgs
}

prepare_cachedirs(){
    [[ ! -d "${cache_dir_iso}" ]] && mkdir -p "${cache_dir_iso}"
    [[ ! -d "${cache_dir_xorg}" ]] && mkdir -p "${cache_dir_xorg}"
    [[ ! -d "${cache_dir_lng}" ]] && mkdir -p "${cache_dir_lng}"
}

clean_cache(){
    msg "Cleaning [$1] ..."
    find "$1" -name '*.pkg.tar.xz' -delete &>/dev/null
}

clean_up(){
    if [[ -d ${work_dir} ]];then
	msg "Removing [${work_dir}] ..."
	rm -r ${work_dir}
    fi
}

configure_desktop_image(){
    msg3 "Configuring [${desktop}-image]"
    
    configure_plymouth "${work_dir}/${desktop}-image"
	
    configure_displaymanager "${work_dir}/${desktop}-image"
	
    configure_services "${work_dir}/${desktop}-image"
	
    msg3 "Done configuring [${desktop}-image]"
}

configure_livecd_image(){
    msg3 "Configuring [livecd-image]"
        
    configure_hostname "${work_dir}/livecd-image"
    
    configure_hosts "${work_dir}/livecd-image"
    
    configure_accountsservice "${work_dir}/livecd-image" "${username}"
    
    configure_user "${work_dir}/livecd-image"
    
    configure_calamares "${work_dir}/livecd-image"
    
    configure_services_live "${work_dir}/livecd-image"    
        
    msg3 "Done configuring [livecd-image]"
}

# $1: work_dir
gen_boot_image(){
	local _kernver=$(cat $1/usr/lib/modules/*-MANJARO/version)
        chroot-run $1 \
		  /usr/bin/mkinitcpio -k ${_kernver} \
		  -c /etc/mkinitcpio-${manjaroiso}.conf \
		  -g /boot/${img_name}.img
}

make_repo(){
    repo-add ${work_dir}/pkgs-image/opt/livecd/pkgs/gfx-pkgs.db.tar.gz ${work_dir}/pkgs-image/opt/livecd/pkgs/*pkg*z
}

# $1: work dir
# $2: cache dir
# $3: pkglist
download_to_cache(){
    pacman -v --config "${pacman_conf}" \
	      --arch "${arch}" --root "$1" \
	      --cache $2 \
	      -Syw $3 --noconfirm
}

# Build ISO
make_iso() {
    msg "Start [Build ISO]"
    touch "${work_dir}/iso/.miso"
    
    mkiso ${iso_args[*]} iso "${work_dir}" "${cache_dir_iso}/${iso_file}"

    chown -R "${OWNER}:users" "${cache_dir_iso}"
    msg "Done [Build ISO]"
}

# $1: file
make_checksum(){
    cd ${cache_dir_iso}
        msg "Creating [${checksum_mode}sum] ..."
        local cs=$(${checksum_mode}sum $1)
        msg2 "${checksum_mode}sum: ${cs}"
        echo "${cs}" > $1.${checksum_mode}
        msg "Done [${checksum_mode}sum]"
    cd ..
}

# $1: new branch
aufs_mount_root_image(){
    msg2 "mount root-image"
    mount -t aufs -o br=$1:${work_dir}/root-image=ro none $1
}

# $1: add branch
aufs_append_root_image(){
    msg2 "append root-image"
    mount -t aufs -o remount,append:${work_dir}/root-image=ro none $1
}

# $1: add branch
aufs_mount_de_image(){
    msg2 "mount ${desktop}-image"
    mount -t aufs -o br=$1:${work_dir}/${desktop}-image=ro none $1
}

# $1: del branch
aufs_remove_image(){
    if mountpoint -q $1;then
        msg2 "Unmount ${1##*/}"
	umount $1
    fi
}

umount_image_handler(){
    aufs_remove_image "${work_dir}/livecd-image"
    aufs_remove_image "${work_dir}/${desktop}-image"
    aufs_remove_image "${work_dir}/root-image"
    aufs_remove_image "${work_dir}/pkgs-image"
    aufs_remove_image "${work_dir}/lng-image"
    aufs_remove_image "${work_dir}/boot-image"
}

mkiso_error_handler(){
    umount_image_handler
    die "Exiting..."
}

# Base installation (root-image)
make_image_root() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
    
	msg "Prepare [Base installation] (root-image)"

	mkiso ${create_args[*]} -p "${packages}" -i "root-image" create "${work_dir}" || mkiso_error_handler
	
	pacman -Qr "${work_dir}/root-image" > "${work_dir}/root-image/root-image-pkgs.txt"
	
	if [ -e ${work_dir}/root-image/boot/grub/grub.cfg ] ; then
	    rm ${work_dir}/root-image/boot/grub/grub.cfg
	fi
	if [ -e ${work_dir}/root-image/etc/lsb-release ] ; then
	    sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${iso_version}/" ${work_dir}/root-image/etc/lsb-release
	fi
	
	copy_overlay_root "${work_dir}/root-image"
		
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [Base installation] (root-image)"
    fi
}

make_image_desktop() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
    
	msg "Prepare [${desktop} installation] (${desktop}-image)"
	
	mkdir -p ${work_dir}/${desktop}-image
	
	umount_image_handler
	
	aufs_mount_root_image "${work_dir}/${desktop}-image"

	mkiso ${create_args[*]} -i "${desktop}-image" -p "${packages_de}" create "${work_dir}" || mkiso_error_handler

	pacman -Qr "${work_dir}/${desktop}-image" > "${work_dir}/${desktop}-image/${desktop}-image-pkgs.txt"
	
	cp "${work_dir}/${desktop}-image/${desktop}-image-pkgs.txt" ${cache_dir_iso}/${img_name}-${desktop}-${iso_version}-${arch}-pkgs.txt
	
	[[ -d ${desktop}-overlay ]] && copy_overlay_desktop
	
	configure_desktop_image
	
        umount_image_handler
	
	rm -R ${work_dir}/${desktop}-image/.wh*
	
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [${desktop} installation] (${desktop}-image)"
    fi
}

make_image_livecd() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
    
	msg "Prepare [livecd-image]"
	
	mkdir -p ${work_dir}/livecd-image
	
        umount_image_handler
	
	if [ -n "${desktop}" ] ; then
	    aufs_mount_de_image "${work_dir}/livecd-image"
	    aufs_append_root_image "${work_dir}/livecd-image"
	else
	    aufs_mount_root_image "${work_dir}/livecd-image"
	fi
	
	mkiso ${create_args[*]} -i "livecd-image" -p "${packages_livecd}" create "${work_dir}" || mkiso_error_handler
	
	pacman -Qr "${work_dir}/livecd-image" > "${work_dir}/livecd-image/livecd-image-pkgs.txt"
	
	copy_overlay_livecd "${work_dir}/livecd-image"

	# copy over setup helpers and config loader
        copy_livecd_helpers "${work_dir}/livecd-image/opt/livecd"
        
        copy_startup_scripts "${work_dir}/livecd-image/usr/bin"
        
	configure_livecd_image
       	
	# Clean up GnuPG keys?
	rm -rf "${work_dir}/livecd-image/etc/pacman.d/gnupg"
	
        umount_image_handler
	
	rm -R ${work_dir}/livecd-image/.wh*
	
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done [livecd-image]"
    fi
}

make_image_xorg() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [pkgs-image]"
	
	mkdir -p ${work_dir}/pkgs-image/opt/livecd/pkgs
	
	umount_image_handler
	
	if [[ -n "${desktop}" ]] ; then
	    aufs_mount_de_image "${work_dir}/pkgs-image"
	    aufs_append_root_image "${work_dir}/pkgs-image"
	else
	    aufs_mount_root_image "${work_dir}/pkgs-image"
	fi
	
	download_to_cache "${work_dir}/pkgs-image" "${cache_dir_xorg}" "${packages_xorg}"
	copy_cache_xorg
	
	if [[ -n "${packages_xorg_cleanup}" ]]; then
	    for xorg_clean in ${packages_xorg_cleanup}; do  
		rm ${work_dir}/pkgs-image/opt/livecd/pkgs/${xorg_clean}
	    done
	fi
	
	cp pacman-gfx.conf ${work_dir}/pkgs-image/opt/livecd
	rm -r ${work_dir}/pkgs-image/var
	
	make_repo "${work_dir}/pkgs-image/opt/livecd/pkgs/gfx-pkgs" "${work_dir}/pkgs-image/opt/livecd/pkgs"
	
	configure_xorg_drivers "${work_dir}/pkgs-image"
	
        umount_image_handler
	
	rm -R ${work_dir}/pkgs-image/.wh*
	
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [pkgs-image]"
    fi
}

make_image_lng() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [lng-image]"
	mkdir -p ${work_dir}/lng-image/opt/livecd/lng
	
	umount_image_handler
	
	if [[ -n "${desktop}" ]] ; then
	    aufs_mount_de_image "${work_dir}/lng-image"
	    aufs_append_root_image "${work_dir}/lng-image"
	else
	    aufs_mount_root_image "${work_dir}/lng-image"
	fi

	if [[ -n ${packages_lng_kde} ]]; then
	    download_to_cache "${work_dir}/lng-image" "${cache_dir_lng}" "${packages_lng} ${packages_lng_kde}"
	    copy_cache_lng
	else
	    download_to_cache "${work_dir}/lng-image" "${cache_dir_lng}" "${packages_lng}"
	    copy_cache_lng
	fi
	
	if [[ -n "${packages_lng_cleanup}" ]]; then
	    for lng_clean in ${packages_lng_cleanup}; do
		rm ${work_dir}/lng-image/opt/livecd/lng/${lng_clean}
	    done
	fi
	
	cp pacman-lng.conf ${work_dir}/lng-image/opt/livecd
	rm -r ${work_dir}/lng-image/var
	
	make_repo ${work_dir}/lng-image/opt/livecd/lng/lng-pkgs ${work_dir}/lng-image/opt/livecd/lng
	
	umount_image_handler
	
	rm -R ${work_dir}/lng-image/.wh*
	
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [lng-image]"
    fi
}

# Prepare ${install_dir}/boot/
make_image_boot() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
    
	msg "Prepare [${install_dir}/boot]"
	mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
        
        cp ${work_dir}/root-image/boot/memtest86+/memtest.bin ${work_dir}/iso/${install_dir}/boot/${arch}/memtest
	
	cp ${work_dir}/root-image/boot/vmlinuz* ${work_dir}/iso/${install_dir}/boot/${arch}/${manjaroiso}
        mkdir -p ${work_dir}/boot-image
        
        umount_image_handler
        
        if [ ! -z "${desktop}" ] ; then
	    aufs_mount_de_image "${work_dir}/boot-image"
	    aufs_append_root_image "${work_dir}/boot-image"
	else
	    aufs_mount_root_image "${work_dir}/boot-image"
        fi
        
        copy_initcpio "${work_dir}/boot-image"
        
        gen_boot_image "${work_dir}/boot-image"
        
        mv ${work_dir}/boot-image/boot/${img_name}.img ${work_dir}/iso/${install_dir}/boot/${arch}/${img_name}.img
        cp ${work_dir}/boot-image/boot/intel-ucode.img ${work_dir}/iso/${install_dir}/boot/intel_ucode.img
        cp ${work_dir}/boot-image/usr/share/licenses/intel-ucode/LICENSE ${work_dir}/iso/${install_dir}/boot/intel_ucode.LICENSE
                
        umount_image_handler
        
        rm -R ${work_dir}/boot-image
        
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [${install_dir}/boot]"
    fi
}

# Prepare /EFI
make_efi() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [${install_dir}/boot/EFI]"
        mkdir -p ${work_dir}/iso/EFI/boot
        cp ${work_dir}/root-image/usr/lib/prebootloader/PreLoader.efi ${work_dir}/iso/EFI/boot/bootx64.efi
        cp ${work_dir}/root-image/usr/lib/prebootloader/HashTool.efi ${work_dir}/iso/EFI/boot/

        cp ${work_dir}/root-image/usr/lib/gummiboot/gummibootx64.efi ${work_dir}/iso/EFI/boot/loader.efi

        mkdir -p ${work_dir}/iso/loader/entries
        cp efiboot/loader/loader.conf ${work_dir}/iso/loader/
        cp efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${work_dir}/iso/loader/entries/
        cp efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${work_dir}/iso/loader/entries/

        sed "s|%MISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            efiboot/loader/entries/${manjaroiso}-x86_64-usb.conf > ${work_dir}/iso/loader/entries/${manjaroiso}-x86_64.conf

        sed "s|%MISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            efiboot/loader/entries/${manjaroiso}-x86_64-nonfree-usb.conf > ${work_dir}/iso/loader/entries/${manjaroiso}-x86_64-nonfree.conf

        # EFI Shell 2.0 for UEFI 2.3+ ( http://sourceforge.net/apps/mediawiki/tianocore/index.php?title=UEFI_Shell )
        curl -k -o ${work_dir}/iso/EFI/shellx64_v2.efi https://svn.code.sf.net/p/edk2/code/trunk/edk2/ShellBinPkg/UefiShell/X64/Shell.efi
        # EFI Shell 1.0 for non UEFI 2.3+ ( http://sourceforge.net/apps/mediawiki/tianocore/index.php?title=Efi-shell )
        curl -k -o ${work_dir}/iso/EFI/shellx64_v1.efi https://svn.code.sf.net/p/edk2/code/trunk/edk2/EdkShellBinPkg/FullShell/X64/Shell_Full.efi
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done [${install_dir}/boot/EFI]"
    fi
}

# Prepare kernel.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [${install_dir}/iso/EFI]"
        mkdir -p ${work_dir}/iso/EFI/miso
        truncate -s 31M ${work_dir}/iso/EFI/miso/${img_name}.img
        mkfs.vfat -n MISO_EFI ${work_dir}/iso/EFI/miso/${img_name}.img

        mkdir -p ${work_dir}/efiboot
        mount ${work_dir}/iso/EFI/miso/${img_name}.img ${work_dir}/efiboot

        mkdir -p ${work_dir}/efiboot/EFI/miso
        cp ${work_dir}/iso/${install_dir}/boot/x86_64/${manjaroiso} ${work_dir}/efiboot/EFI/miso/${manjaroiso}.efi
        cp ${work_dir}/iso/${install_dir}/boot/x86_64/${img_name}.img ${work_dir}/efiboot/EFI/miso/${img_name}.img
        cp ${work_dir}/iso/${install_dir}/boot/intel_ucode.img ${work_dir}/efiboot/EFI/miso/intel_ucode.img

        mkdir -p ${work_dir}/efiboot/EFI/boot
        cp ${work_dir}/root-image/usr/lib/prebootloader/PreLoader.efi ${work_dir}/efiboot/EFI/boot/bootx64.efi
        cp ${work_dir}/root-image/usr/lib/prebootloader/HashTool.efi ${work_dir}/efiboot/EFI/boot/

        cp ${work_dir}/root-image/usr/lib/gummiboot/gummibootx64.efi ${work_dir}/efiboot/EFI/boot/loader.efi

        mkdir -p ${work_dir}/efiboot/loader/entries
        cp efiboot/loader/loader.conf ${work_dir}/efiboot/loader/
        cp efiboot/loader/entries/uefi-shell-v2-x86_64.conf ${work_dir}/efiboot/loader/entries/
        cp efiboot/loader/entries/uefi-shell-v1-x86_64.conf ${work_dir}/efiboot/loader/entries/

        sed "s|%MISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            efiboot/loader/entries/${manjaroiso}-x86_64-dvd.conf > ${work_dir}/efiboot/loader/entries/${manjaroiso}-x86_64.conf

        sed "s|%MISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g" \
            efiboot/loader/entries/${manjaroiso}-x86_64-nonfree-dvd.conf > ${work_dir}/efiboot/loader/entries/${manjaroiso}-x86_64-nonfree.conf

        cp ${work_dir}/iso/EFI/shellx64_v2.efi ${work_dir}/efiboot/EFI/
        cp ${work_dir}/iso/EFI/shellx64_v1.efi ${work_dir}/efiboot/EFI/

        umount ${work_dir}/efiboot
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done [${install_dir}/iso/EFI]"
    fi
}

# Prepare /isolinux
make_isolinux() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [${install_dir}/iso/isolinux]"
	mkdir -p ${work_dir}/iso/isolinux
        cp -a --no-preserve=ownership isolinux/* ${work_dir}/iso/isolinux
        if [[ -e isolinux-overlay ]]; then
	    msg2 "isolinux overlay found. Overwriting files."
            cp -a --no-preserve=ownership isolinux-overlay/* ${work_dir}/iso/isolinux
        fi
        if [[ -e ${work_dir}/root-image/usr/lib/syslinux/bios/ ]]; then
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/isolinux.bin ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/isohdpfx.bin ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/ldlinux.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/gfxboot.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/whichsys.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/mboot.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/hdt.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/chain.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/libcom32.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/libmenu.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/libutil.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/bios/libgpl.c32 ${work_dir}/iso/isolinux/
        else
            cp ${work_dir}/root-image/usr/lib/syslinux/isolinux.bin ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/isohdpfx.bin ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/gfxboot.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/whichsys.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/mboot.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/hdt.c32 ${work_dir}/iso/isolinux/
            cp ${work_dir}/root-image/usr/lib/syslinux/chain.c32 ${work_dir}/iso/isolinux/
        fi
        sed -i "s|%MISO_LABEL%|${iso_label}|g;
                s|%INSTALL_DIR%|${install_dir}|g;
                s|%ARCH%|${arch}|g" ${work_dir}/iso/isolinux/isolinux.cfg
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done [${install_dir}/iso/isolinux]"
    fi
}

# Process isomounts
make_isomounts() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Process [isomounts]"
        sed "s|@ARCH@|${arch}|g" isomounts > ${work_dir}/iso/${install_dir}/isomounts
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done processing [isomounts]"
    fi
}

# $1: file name
load_pkgs(){
    msg "Loading Packages: [$1] ..."
    
    if [ "${arch}" == "i686" ]; then
	packages_livecd=$(sed "s|#.*||g" $1 | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	packages_livecd=$(sed "s|#.*||g" $1 | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
}

load_pkgs_xorg(){
    msg "Loading Packages: [Packages-Xorg] ..."
    
    if [ "${arch}" == "i686" ]; then
	packages_xorg=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni||g" | sed "s|>nonfree_x64.*||g" | sed "s|>nonfree_uni||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	packages_xorg=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>free_x64||g" | sed "s|>free_uni||g" | sed "s|>nonfree_uni||g" | sed "s|>nonfree_x64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
    packages_xorg_cleanup=$(sed "s|#.*||g" Packages-Xorg | grep cleanup | sed "s|>cleanup||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
}

load_pkgs_lng(){
    msg "Loading Packages: [Packages-Lng] ..."

    if [ "${arch}" == "i686" ]; then
	packages_lng=$(sed "s|#.*||g" Packages-Lng | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>kde.*||g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	packages_lng=$(sed "s|#.*||g" Packages-Lng | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>kde.*||g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
    packages_lng_cleanup=$(sed "s|#.*||g" Packages-Lng | grep cleanup | sed "s|>cleanup||g")
    packages_lng_kde=$(sed "s|#.*||g" Packages-Lng | grep kde | sed "s|>kde||g" | sed ':a;N;$!ba;s/\n/ /g')
}

# $1: profile
load_profile(){
    msg "Loading Profile [$1] ..."

#     local files=$(ls Packages*)
#     
#     for f in ${files[@]};do
#         case $f in
#             Packages|Packages-Livecd) continue ;;
#             *) pkgsfile="$f"; msg2 "desktop list: $f" ;;
#         esac
#     done
    if [ -e Packages-Xfce ] ; then
	pkgsfile="Packages-Xfce"
    fi
    if [ -e Packages-Kde ] ; then
    	pkgsfile="Packages-Kde"
    fi
    if [ -e Packages-Gnome ] ; then
   	pkgsfile="Packages-Gnome" 
    fi
    if [ -e Packages-Cinnamon ] ; then
   	pkgsfile="Packages-Cinnamon" 
    fi
    if [ -e Packages-Openbox ] ; then
  	pkgsfile="Packages-Openbox"  
    fi
    if [ -e Packages-Lxde ] ; then
 	pkgsfile="Packages-Lxde"   
    fi
    if [ -e Packages-Lxqt ] ; then
    	pkgsfile="Packages-Lxqt"
    fi
    if [ -e Packages-Mate ] ; then
    	pkgsfile="Packages-Mate"
    fi
    if [ -e Packages-Enlightenment ] ; then
    	pkgsfile="Packages-Enlightenment"
    fi
    if [ -e Packages-Net ] ; then
   	pkgsfile="Packages-Net" 
    fi
    if [ -e Packages-PekWM ] ; then
	pkgsfile="Packages-PekWM"
    fi
    if [ -e Packages-Kf5 ] ; then
	pkgsfile="Packages-Kf5"
    fi
    if [ -e Packages-i3 ] ; then
	pkgsfile="Packages-i3"
    fi
    if [ -e Packages-Custom ] ; then
    	pkgsfile="Packages-Custom"
    fi

    desktop=${pkgsfile#*-}
    desktop=${desktop,,}
    
    displaymanager=$(cat displaymanager)
    initsys=$(cat initsys)

    iso_file="${img_name}-${desktop}-${iso_version}-${arch}.iso"

    if [[ -f pacman-${pacman_conf_arch}.conf ]]; then
	pacman_conf="pacman-${pacman_conf_arch}.conf"
    else
	pacman_conf="${PKGDATADIR}/pacman-${pacman_conf_arch}.conf"
    fi
    create_args+=(-C ${pacman_conf})
    
    work_dir=${chroots_iso}/$1/${arch}
}

compress_images(){
    make_isomounts
    make_iso
    make_checksum "${iso_file}"
}

build_images(){
    load_pkgs "Packages"
    make_image_root
    
    if [[ -f "${pkgsfile}" ]] ; then
	load_pkgs "${pkgsfile}"
	make_image_desktop
    fi

    if [[ -f Packages-Xorg ]] ; then
	load_pkgs_xorg
	make_image_xorg
    fi
    
    if [[ -f Packages-Lng ]] ; then
	load_pkgs_lng
	make_image_lng
    fi
    
    if [[ -f Packages-Livecd ]]; then
	load_pkgs "Packages-Livecd"
	make_image_livecd
    fi   
    
    make_image_boot
    if [[ "${arch}" == "x86_64" ]]; then
	make_efi
	make_efiboot
    fi
    make_isolinux
}

build_profile(){
    ${clean_first} && clean_up

    ${clean_cache_xorg} && clean_cache "${cache_dir_xorg}"
    ${clean_cache_lng} && clean_cache "${cache_dir_lng}"

    if ${iso_only}; then
	[[ ! -d ${work_dir} ]] && die "You need to create images first eg. buildiso -p <name> -i"
	compress_images
	exit 1
    fi

    if ${images_only}; then
	build_images
	warning "Continue with eg. buildiso -p <name> -sc ..."
	exit 1
    else
	build_images
	compress_images
    fi
}

# run_log(){
# 
#     logfile=${cache_dir_iso}/${buildset_iso}.log
#     
#     logpipe=$(mktemp -u "/tmp/logpipe.XXXXXXXX")
#     mkfifo "$logpipe"
#     
#     tee "$logfile" < "$logpipe" &
#     local teepid=$!
# 
#     $1 &> "$logpipe"
# 
#     wait $teepid
#     rm "$logpipe"
# }

build_iso(){
    if ${is_buildset};then
	msg3 "Start building [${buildset_iso}]"
	for prof in $(cat ${sets_dir_iso}/${buildset_iso}.set); do
	    [[ -f $prof/initsys ]] || break
	    cd $prof
		load_profile "$prof"
		build_profile
	    cd ..
	done
	msg3 "Finished building [${buildset_iso}]"
    else
	[[ -f ${buildset_iso}/initsys ]] || die "${buildset_iso} is not a valid profile!"
	cd ${buildset_iso}    
	    load_profile "${buildset_iso}"
	    build_profile
	cd ..
    fi
}
