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

set_mkinicpio_hooks(){
    if ! ${pxe_boot};then
        msg2 "Removing pxe hooks"
        sed -e 's/miso_pxe_common miso_pxe_http //' \
        -e 's/memdisk //' -i $1
    fi
    if ! ${plymouth_boot};then
        msg2 "Removing plymouth hook"
        sed -e 's/plymouth //' -i $1
    fi
    if ${use_overlayfs};then
        sed -e 's/miso /miso_overlayfs /' -i $1
    fi
}

set_silent_switch_root(){
    sed -e 's|"$@"|"$@" >/dev/null 2>&1|' -i $1/usr/lib/initcpio/init
}

copy_initcpio(){
    msg2 "Copying initcpio ..."
    cp /usr/lib/initcpio/hooks/miso* $2/usr/lib/initcpio/hooks
    cp /usr/lib/initcpio/install/miso* $2/usr/lib/initcpio/install
    cp $1/mkinitcpio.conf $2/etc/mkinitcpio-${iso_name}.conf
    set_mkinicpio_hooks "$2/etc/mkinitcpio-${iso_name}.conf"
    set_silent_switch_root "$2"
}

# $1: work_dir
gen_boot_image(){
    local _kernver=$(cat $1/usr/lib/modules/*/version)
    chroot-run $1 \
        /usr/bin/mkinitcpio -k ${_kernver} \
        -c /etc/mkinitcpio-${iso_name}.conf \
        -g /boot/${iso_name}.img
}

copy_preloader_efi(){
    msg2 "Copying efi loaders ..."
    cp $1/usr/share/efitools/efi/PreLoader.efi $2/bootx64.efi
    cp $1/usr/share/efitools/efi/HashTool.efi $2/
}

copy_loader_efi(){
    cp $1/usr/lib/systemd/boot/efi/systemd-bootx64.efi $2/loader.efi
}

is_intel_ucode(){
    if [[ -f $1/iso/${iso_name}/boot/intel_ucode.img ]] ; then
        return 0
    else
        return 1
    fi
}

copy_ucode(){
    cp $1/boot/intel-ucode.img $2/intel_ucode.img
    cp $1/usr/share/licenses/intel-ucode/LICENSE $2/intel_ucode.LICENSE
}

copy_boot_images(){
    msg2 "Copying boot images ..."
    cp $1/iso/${iso_name}/boot/x86_64/${iso_name} $1/efiboot/EFI/miso/${iso_name}.efi
    cp $1/iso/${iso_name}/boot/x86_64/${iso_name}.img $1/efiboot/EFI/miso/${iso_name}.img
    if $(is_intel_ucode "$1"); then
        cp $1/iso/${iso_name}/boot/intel_ucode.img $1/efiboot/EFI/miso/intel_ucode.img
    fi
}

write_efi_loader_conf(){
    prepare_dir "$1"
    local conf=$1/loader.conf
    msg2 "Writing %s ..." "${conf##*/}"
    echo 'timeout 3' > ${conf}
    echo "default ${iso_name}-${target_arch}-free" >> ${conf}
}

gen_boot_args(){
    local args=(quiet)
    if ${plymouth_boot};then
        args+=(splash)
    fi
    echo ${args[@]}
}

write_usb_efi_loader_entry(){
    prepare_dir "$1/iso/loader/entries"
    local drv='free' switch="$2"
    [[ ${switch} == 'yes' ]] && drv='nonfree'
    local fn=${iso_name}-${target_arch}-${drv}.conf
    local conf=$1/iso/loader/entries/${fn}
    msg2 "Writing %s ..." "${fn}"
    echo "title   ${dist_name} Linux ${target_arch} UEFI USB (${drv})" > ${conf}
    echo "linux   /${iso_name}/boot/${target_arch}/${iso_name}" >> ${conf}
    if $(is_intel_ucode "$1") ; then
        echo "initrd  /${iso_name}/boot/intel_ucode.img" >> ${conf}
    fi
    echo "initrd  /${iso_name}/boot/${target_arch}/${iso_name}.img" >> ${conf}
    echo "options misobasedir=${iso_name} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo overlay=${drv} nonfree=${switch} $(gen_boot_args)" >> ${conf}
}

write_dvd_efi_loader_entry(){
    prepare_dir "$1/efiboot/loader/entries"
    local drv='free' switch="$2"
    [[ ${switch} == 'yes' ]] && drv='nonfree'
    local fn=${iso_name}-${target_arch}-${drv}.conf
    local conf=$1/efiboot/loader/entries/${fn}
    msg2 "Writing %s ..." "${fn}"
    echo "title   ${dist_name} Linux ${target_arch} UEFI DVD (${drv})" > ${conf}
    echo "linux   /EFI/miso/${iso_name}.efi" >> ${conf}
    if $(is_intel_ucode "$1") ; then
        echo "initrd  /EFI/miso/intel_ucode.img" >> ${conf}
    fi
    echo "initrd  /EFI/miso/${iso_name}.img" >> ${conf}
    echo "options misobasedir=${iso_name} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo overlay=${drv} nonfree=${switch} $(gen_boot_args)" >> ${conf}
}

copy_isolinux_bin(){
    msg2 "Copying isolinux bios binaries ..."
    cp $1/usr/lib/syslinux/bios/{{isolinux,isohdpfx}.bin,{ldlinux,gfxboot,whichsys,mboot,hdt,chain,libcom32,libmenu,libutil,libgpl}.c32} $2/iso/isolinux
}

gen_initrd_arg(){
    local path="/${iso_name}/boot/${target_arch}/${iso_name}.img"
    local arg="initrd=${path}"
    if $(is_intel_ucode "$1") ; then
        arg="initrd=/${iso_name}/boot/intel_ucode.img,${path}"
    fi
    echo $arg
}

write_isolinux_cfg(){
    local conf=$1/iso/isolinux/isolinux.cfg
    msg2 "Writing %s ..." "${conf##*/}"

    echo "default start" > ${conf}
    echo "implicit 1" >> ${conf}
    echo "display isolinux.msg" >> ${conf}
    echo "ui gfxboot bootlogo isolinux.msg" >> ${conf}
    echo "prompt   1" >> ${conf}
    echo "timeout  200" >> ${conf}

    echo '' >> ${conf}
    echo "label start" >> ${conf}
    echo "  kernel /${iso_name}/boot/${target_arch}/${iso_name}" >> ${conf}
    echo "  append $(gen_initrd_arg "$1") misobasedir=${iso_name} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo overlay=free $(gen_boot_args) showopts" >> ${conf}
    echo '' >> ${conf}

    if ${nonfree_mhwd};then
        echo "label nonfree" >> ${conf}
        echo "  kernel /${iso_name}/boot/${target_arch}/${iso_name}" >> ${conf}
        echo "  append $(gen_initrd_arg "$1") misobasedir=${iso_name} misolabel=${iso_label} nouveau.modeset=0 i915.modeset=1 radeon.modeset=0 nonfree=yes logo.nologo overlay=nonfree $(gen_boot_args) showopts" >> ${conf}
        echo '' >> ${conf}
    fi

    echo "label harddisk" >> ${conf}
    echo "  com32 whichsys.c32" >> ${conf}
    echo "  append -iso- chain.c32 hd0" >> ${conf}
    echo '' >> ${conf}

    echo "label hdt" >> ${conf}
    echo "  kernel hdt.c32" >> ${conf}
    echo '' >> ${conf}

    echo "label memtest" >> ${conf}
    echo "  kernel memtest" >> ${conf}
}

write_isolinux_msg(){
    local conf=$1/iso/isolinux/isolinux.msg
    msg2 "Writing %s ..." "${conf##*/}"

    echo "Welcome to ${dist_name} Linux!" > ${conf}
    echo '' >> ${conf}
    echo "To start the system enter 'start' and press <return>" >> ${conf}
    echo '' >> ${conf}
    echo '' >> ${conf}
    echo "Available boot options:" >> ${conf}
    echo "start                    - Start ${dist_name} Live System" >> ${conf}
    if ${nonfree_mhwd};then
        echo "nonfree                  - Start with proprietary drivers" >> ${conf}
    fi
    echo "harddisk                 - Boot from local hard disk" >> ${conf}
    echo "hdt                      - Run Hardware Detection Tool" >> ${conf}
    echo "memtest                  - Run Memory Test" >> ${conf}
}

update_isolinux_cfg(){
    local conf=$1/iso/isolinux/isolinux.cfg
    msg2 "Updating %s ..." "${conf##*/}"
    sed -e "s|%ISO_LABEL%|${iso_label}|g;
            s|%ISO_NAME%|${iso_name}|g;
            s|%ARCH%|${target_arch}|g" -i ${conf}
}

update_isolinux_msg(){
    local conf=$1/iso/isolinux/isolinux.msg
    msg2 "Updating %s ..." "${conf##*/}"
    sed -e "s|%DIST_NAME%|${dist_name}|g" -i ${conf}
}

write_isomounts(){
    local file=$1/isomounts
    echo '# syntax: <img> <arch> <mount point> <type> <kernel argument>' > ${file}
    echo '' >> ${file}
    msg2 "Writing live entry ..."
    echo "${target_arch}/live-image.sqfs ${target_arch} / squashfs" >> ${file}
    if [[ -f ${packages_mhwd} ]] ; then
        msg2 "Writing mhwd entry ..."
        echo "${target_arch}/mhwd-image.sqfs ${target_arch} / squashfs" >> ${file}
    fi
    if [[ -f "${packages_custom}" ]] ; then
        msg2 "Writing %s entry ..." "${profile}"
        echo "${target_arch}/${profile}-image.sqfs ${target_arch} / squashfs" >> ${file}
    fi
    msg2 "Writing root entry ..."
    echo "${target_arch}/root-image.sqfs ${target_arch} / squashfs" >> ${file}
}

################################# testing syslinux efi ####################################

copy_syslinux_efi(){
    msg2 "Copying syslinux efi binaries ..."
    cp $1/usr/lib/syslinux/efi64/{ldlinux.e64,*.c32} $2
    cp $1/usr/lib/syslinux/efi64/syslinux.efi $2/bootx64.efi
    cp ${DATADIR}/isolinux/back800x600.jpg $2/splash.jpg
}

write_syslinux_cfg(){
    local conf=$1/syslinux.cfg
    msg2 "Writing %s ..." "syslinux.cfg"
    echo "DEFAULT free" > $conf
    echo "PROMPT 1" >> $conf
    echo "TIMEOUT 200" >> $conf
    echo "#KBDMAP de.ktl" >> $conf
    echo "" >> $conf
    echo "UI vesamenu.c32" >> $conf
    echo "" >> $conf
    echo "MENU TITLE ${dist_name} Linux" >> $conf
    echo "MENU BACKGROUND splash.jpg" >> $conf
    echo "" >> $conf
    echo "MENU COLOR border       30;44   #40ffffff #a0000000 std" >> $conf
    echo "MENU COLOR title        1;36;44 #9033ccff #a0000000 std" >> $conf
    echo "MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all" >> $conf
    echo "MENU COLOR unsel        37;44   #50ffffff #a0000000 std" >> $conf
    echo "MENU COLOR help         37;40   #c0ffffff #a0000000 std" >> $conf
    echo "MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std" >> $conf
    echo "MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std" >> $conf
    echo "MENU COLOR msg07        37;40   #90ffffff #a0000000 std" >> $conf
    echo "MENU COLOR tabmsg       31;40   #30ffffff #00000000 std" >> $conf
    echo "" >> $conf
    echo "LABEL free" >> $conf
    echo "    MENU LABEL ${dist_name} Linux ${target_arch}" >> $conf
    case $2 in
        usb)
            echo "    LINUX /EFI/miso/${iso_name}.efi" >> $conf
            echo "    INITRD /EFI/miso/${iso_name}.img" >> $conf
        ;;
        dvd)
            echo "    LINUX /${iso_name}/boot/${target_arch}/${iso_name}" >> $conf
            echo "    INITRD /${iso_name}/boot/${target_arch}/${iso_name}.img" >> $conf
        ;;
    esac
    if ${nonfree_mhwd};then
        echo "    APPEND misobasedir=${iso_name} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo nonfree=yes overlay=nonfree $(gen_boot_args)" >> $conf
    else
        echo "    APPEND misobasedir=${iso_name} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo nonfree=no overlay=nonfree $(gen_boot_args)" >> $conf
    fi
    echo "" >> $conf
    echo "LABEL hdt" >> $conf
    echo "        MENU LABEL HDT (Hardware Detection Tool)" >> $conf
    echo "        COM32 hdt.c32" >> $conf
    echo "" >> $conf
    echo "LABEL reboot" >> $conf
    echo "        MENU LABEL Reboot" >> $conf
    echo "        COM32 reboot.c32" >> $conf
    echo "" >> $conf
    echo "LABEL poweroff" >> $conf
    echo "        MENU LABEL Poweroff" >> $conf
    echo "        COM32 poweroff.c32" >> $conf
}
