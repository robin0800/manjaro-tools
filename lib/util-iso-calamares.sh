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

write_calamares_machineid_conf(){
	if [[ ${initsys} == 'openrc' ]];then
		local conf="$1/etc/calamares/modules/machineid.conf"
		echo "systemd: false" > $conf
		echo "dbus: true" >> $conf
		echo "symlink: false" >> $conf
	fi
}

write_calamares_finished_conf(){
	local conf="$1/etc/calamares/modules/finished.conf"
	echo '---' > "$conf"
	echo 'restartNowEnabled: true' >> "$conf"
	echo 'restartNowChecked: false' >> "$conf"
	echo 'restartNowCommand: "shutdown -r now"' >> "$conf"
}

write_calamares_bootloader_conf(){
	source "$1/etc/mkinitcpio.d/${kernel}.preset"
	local conf="$1/etc/calamares/modules/bootloader.conf"
	echo '---' > "$conf"
	echo "efiBootLoader: \"${efi_boot_loader}\"" >> "$conf"
	echo "kernel: \"$(echo ${ALL_kver} | sed s'|/boot||')\"" >> "$conf"
	echo "img: \"$(echo ${default_image} | sed s'|/boot||')\"" >> "$conf"
	echo "fallback: \"$(echo ${fallback_image} | sed s'|/boot||')\"" >> "$conf"
	echo 'timeout: "10"' >> "$conf"
	echo "kernelLine: \", with ${kernel}\"" >> "$conf"
	echo "fallbackKernelLine: \", with ${kernel} (fallback initramfs)\"" >> "$conf"
	echo 'grubInstall: "grub-install"' >> "$conf"
	echo 'grubMkconfig: "grub-mkconfig"' >> "$conf"
	echo 'grubCfg: "/boot/grub/grub.cfg"' >> "$conf"
	echo '#efiBootloaderId: "dirname"' >> "$conf"
}

write_calamares_services_conf(){
	local conf="$1/etc/calamares/modules/services.conf"
	echo '---' >  "$conf"
	echo '' >> "$conf"
	if [[ ${initsys} == 'openrc' ]];then
		echo 'services:' >> "$conf"
		for s in ${start_openrc[@]};do
			echo '   - name: '"$s" >> "$conf"
			echo '     mandatory: false' >> "$conf"
			echo '' >> "$conf"
		done
		echo 'targets:' >> "$conf"
		echo '    - name: "graphical"' >> "$conf"
		echo '      mandatory: false' >> "$conf"
		echo '' >> "$conf"
		echo 'disable:' >> "$conf"
		for s in ${disable_openrc[@]};do
			echo '   - name: '"$s" >> "$conf"
			echo '     mandatory: false' >> "$conf"
			echo '' >> "$conf"
		done
	else
		echo 'services:' > "$conf"
		for s in ${start_systemd[@]};do
			echo '    - name: '"$s" >> "$conf"
			echo '      mandatory: false' >> "$conf"
			echo '' >> "$conf"
		done
		echo 'targets:' >> "$conf"
		echo '    - name: "graphical"' >> "$conf"
		echo '      mandatory: true' >> "$conf"
		echo '' >> "$conf"
		echo 'disable:' >> "$conf"
		for s in ${disable_systemd[@]};do
			echo '    - name: '"$s" >> "$conf"
			echo '      mandatory: false' >> "$conf"
			echo '' >> "$conf"
		done
	fi
}

write_calamares_displaymanager_conf(){
	local conf="$1/etc/calamares/modules/displaymanager.conf"
	echo "displaymanagers:" > "$conf"
	echo "  - ${displaymanager}" >> "$conf"
	echo '' >> "$conf"
	if [[ ${default_desktop_executable} != "none" ]] && [[ ${default_desktop_file} != "none" ]]; then
		echo "defaultDesktopEnvironment:" >> "$conf"
		echo "    executable: \"${default_desktop_executable}\"" >> "$conf"
		echo "    desktopFile: \"${default_desktop_file}\"" >> "$conf"
	fi
	echo '' >> "$conf"
	echo "basicSetup: false" >> "$conf"
}

write_calamares_initcpio_conf(){
	local conf="$1/etc/calamares/modules/initcpio.conf"
	echo "---" > "$conf"
	echo "kernel: ${kernel}" >> "$conf"
}

write_calamares_unpack_conf(){
	local conf="$1/etc/calamares/modules/unpackfs.conf"
	echo "---" > "$conf"
	echo "unpack:" >> "$conf"
	echo "    -   source: \"/bootmnt/${iso_name}/${arch}/root-image.sqfs\"" >> "$conf"
	echo "        sourcefs: \"squashfs\"" >> "$conf"
	echo "        destination: \"\"" >> "$conf"
	echo "    -   source: \"/bootmnt/${iso_name}/${arch}/${custom}-image.sqfs\"" >> "$conf"
	echo "        sourcefs: \"squashfs\"" >> "$conf"
	echo "        destination: \"\"" >> "$conf"
}

write_calamares_users_conf(){
	local conf="$1/etc/calamares/modules/users.conf"
	echo "---" > "$conf"
	echo "userGroup:      users" >> "$conf"
	echo "defaultGroups:" >> "$conf"
	local IFS=','
	for g in ${addgroups[@]};do
		echo "    - $g" >> "$conf"
	done
	unset IFS
	echo "autologinGroup: autologin" >> "$conf"
	echo "sudoersGroup:   wheel" >> "$conf"
	echo "setRootPassword: true" >> "$conf"
}

brand_calamares_settings_conf(){
	local conf="$1/usr/share/calamares/settings.conf"
	if [[ -f $conf ]];then
		if [[ -d $1/usr/share/calamares/branding/${iso_name}-${custom} ]];then
			sed -i -e "s|^.*branding:.*|branding: ${iso_name}-${custom}|" "$conf"
		elif [[ -d $1/usr/share/calamares/branding/${iso_name} ]];then
			sed -i -e "s|^.*branding:.*|branding: ${iso_name}|" "$conf"
		fi
	fi
}

configure_calamares(){
	msg2 "Configuring Calamares ..."
	mkdir -p $1/etc/calamares/modules
	write_calamares_bootloader_conf $1
	write_calamares_unpack_conf $1
	write_calamares_displaymanager_conf $1
	write_calamares_initcpio_conf $1
	brand_calamares_settings_conf $1
	if [[ ${initsys} == 'openrc' ]];then
		write_calamares_machineid_conf $1
		write_calamares_finished_conf $1
	fi
	write_calamares_services_conf $1
	write_calamares_users_conf $1

	if [[ -f $1/usr/share/applications/calamares.desktop && -f $1/usr/bin/kdesu ]];then
		sed -i -e 's|sudo|kdesu|g' $1/usr/share/applications/calamares.desktop
	fi
}

configure_thus(){
	msg2 "Configuring Thus ..."
	source "$1/etc/mkinitcpio.d/${kernel}.preset"
	local conf="$1/etc/thus.conf"
	echo "[distribution]" > "$conf"
	echo "DISTRIBUTION_NAME = \"${dist_name} Linux\"" >> "$conf"
	echo "DISTRIBUTION_VERSION = \"${dist_release}\"" >> "$conf"
	echo "SHORT_NAME = \"${dist_name}\"" >> "$conf"
	echo "[install]" >> "$conf"
	echo "LIVE_MEDIA_SOURCE = \"/bootmnt/${iso_name}/${arch}/root-image.sqfs\"" >> "$conf"
	echo "LIVE_MEDIA_DESKTOP = \"/bootmnt/${iso_name}/${arch}/${custom}-image.sqfs\"" >> "$conf"
	echo "LIVE_MEDIA_TYPE = \"squashfs\"" >> "$conf"
	echo "LIVE_USER_NAME = \"${username}\"" >> "$conf"
	echo "KERNEL = \"${kernel}\"" >> "$conf"
	echo "VMLINUZ = \"$(echo ${ALL_kver} | sed s'|/boot/||')\"" >> "$conf"
	echo "INITRAMFS = \"$(echo ${default_image} | sed s'|/boot/||')\"" >> "$conf"
	echo "FALLBACK = \"$(echo ${fallback_image} | sed s'|/boot/||')\"" >> "$conf"

	if [[ -f $1/usr/share/applications/thus.desktop && -f $1/usr/bin/kdesu ]];then
		sed -i -e 's|sudo|kdesu|g' $1/usr/share/applications/thus.desktop
	fi
}
