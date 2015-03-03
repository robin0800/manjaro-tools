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

write_loader_conf(){
	local conf=$1/loader.conf
	echo 'timeout 3' > ${conf}
	echo "default ${dist_iso}-${arch}" >> ${conf}
}

write_efi_shellv1_conf(){
	local conf=$1/uefi-shell-v1-${arch}.conf
	echo "title  UEFI Shell ${arch} v1" > ${conf}
	echo "efi    /EFI/shellx64_v1.efi" >> ${conf}
}

write_efi_shellv2_conf(){
	local conf=$1/uefi-shell-v2-${arch}.conf
	echo "title  UEFI Shell ${arch} v2" > ${conf}
	echo "efi    /EFI/shellx64_v2.efi" >> ${conf}
}

write_dvd_conf(){
	local conf=$1/${dist_iso}-${arch}-dvd.conf
	echo "title   Manjaro Linux ${arch} UEFI DVD (default)" > ${conf}
	echo "linux   /EFI/miso/${dist_iso}.efi" >> ${conf}
	echo "initrd  /EFI/miso/intel_ucode.img" >> ${conf}
	echo "initrd  /EFI/miso/${img_name}.img" >> ${conf}
	echo "options misobasedir=${install_dir} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo overlay=free" >> ${conf}
}

write_dvd_nonfree_conf(){
	local conf=$1/${dist_iso}-${arch}-nonfree-dvd.conf
	echo "title   Manjaro Linux ${arch} UEFI DVD (nonfree)" > ${conf}
	echo "linux   /EFI/miso/${dist_iso}.efi" >> ${conf}
	echo "initrd  /EFI/miso/intel_ucode.img" >> ${conf}
	echo "initrd  /EFI/miso/${img_name}.img" >> ${conf}
	echo "options misobasedir=${install_dir} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo overlay=nonfree nonfree=yes" >> ${conf}
}

write_usb_conf(){
	local conf=$1/${dist_iso}-${arch}-usb.conf
	echo "title   Manjaro Linux ${arch} UEFI USB (default)" > ${conf}
	echo "linux   /${install_dir}/boot/${arch}/${dist_iso}" >> ${conf}
	echo "initrd  /${install_dir}/boot/intel_ucode.img" >> ${conf}
	echo "initrd  /${install_dir}/boot/${arch}/${img_name}.img" >> ${conf}
	echo "options misobasedir=${install_dir} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo overlay=free" >> ${conf}
}

write_usb_nonfree_conf(){
	local conf=$1/${dist_iso}-${arch}-nonfree-usb.conf
	echo "title   Manjaro Linux ${arch} UEFI USB (nonfree)" > ${conf}
	echo "linux   /${install_dir}/boot/${arch}/${dist_iso}" >> ${conf}
	echo "initrd  /${install_dir}/boot/intel_ucode.img" >> ${conf}
	echo "initrd  /${install_dir}/boot/${arch}/${img_name}.img" >> ${conf}
	echo "options misobasedir=${install_dir} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo overlay=nonfree nonfree=yes" >> ${conf}
}

write_isolinux_cfg(){
	local conf=$1/isolinux.cfg
	echo "default start" > ${conf}
	echo "implicit 1" >> ${conf}
	echo "display isolinux.msg" >> ${conf}
	echo "ui gfxboot bootlogo isolinux.msg" >> ${conf}
	echo "prompt   1" >> ${conf}
	echo "timeout  200" >> ${conf}
	echo '' >> ${conf}
	echo "label start" >> ${conf}
	echo "  kernel /${install_dir}/boot/${arch}/${dist_iso}" >> ${conf}
	echo "  append initrd=/${install_dir}/boot/intel_ucode.img,/${install_dir}/boot/${arch}/${img_name}.img misobasedir=${install_dir} misolabel=${iso_label} nouveau.modeset=1 i915.modeset=1 radeon.modeset=1 logo.nologo overlay=free quiet splash showopts" >> ${conf}
	echo '' >> ${conf}
	echo "label nonfree" >> ${conf}
	echo "  kernel /${install_dir}/boot/${arch}/${dist_iso}" >> ${conf}
	echo "  append initrd=/${install_dir}/boot/intel_ucode.img,/${install_dir}/boot/${arch}/${img_name}.img misobasedir=${install_dir} misolabel=${iso_label} nouveau.modeset=0 i915.modeset=1 radeon.modeset=0 nonfree=yes logo.nologo overlay=nonfree quiet splash showopts" >> ${conf}
	echo '' >> ${conf}
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
