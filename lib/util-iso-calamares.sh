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

write_machineid_conf(){
	local conf="$1/etc/calamares/modules/machineid.conf"
	if [[ ${initsys} == 'openrc' ]];then
		echo "systemd: false" > $conf
		echo "dbus: true" >> $conf
		echo "symlink: true" >> $conf
	else
		echo "systemd: true" > $conf
		echo "dbus: true" >> $conf
		echo "symlink: true" >> $conf
	fi
}

write_finished_conf(){
	local conf="$1/etc/calamares/modules/finished.conf"
	echo '---' > "$conf"
	echo 'restartNowEnabled: true' >> "$conf"
	echo 'restartNowChecked: false' >> "$conf"
	if [[ ${initsys} == 'openrc' ]];then
		echo 'restartNowCommand: "shutdown -r now"' >> "$conf"
	else
		echo 'restartNowCommand: "systemctl -i reboot"' >> "$conf"
	fi
}

write_bootloader_conf(){
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

write_services_conf(){
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

write_displaymanager_conf(){
	local conf="$1/etc/calamares/modules/displaymanager.conf"
	echo "displaymanagers:" > "$conf"
	echo "  - ${displaymanager}" >> "$conf"
	echo '' >> "$conf"
	if $(is_valid_de); then
		echo "defaultDesktopEnvironment:" >> "$conf"
		echo "    executable: \"${default_desktop_executable}\"" >> "$conf"
		echo "    desktopFile: \"${default_desktop_file}\"" >> "$conf"
	fi
	echo '' >> "$conf"
	echo "basicSetup: false" >> "$conf"
}

write_initcpio_conf(){
	local conf="$1/etc/calamares/modules/initcpio.conf"
	echo "---" > "$conf"
	echo "kernel: ${kernel}" >> "$conf"
}

write_unpack_conf(){
	local conf="$1/etc/calamares/modules/unpackfs.conf"
	echo "---" > "$conf"
	echo "unpack:" >> "$conf"
	echo "    -   source: \"/bootmnt/${iso_name}/${target_arch}/root-image.sqfs\"" >> "$conf"
	echo "        sourcefs: \"squashfs\"" >> "$conf"
	echo "        destination: \"\"" >> "$conf"
	if [[ -f /bootmnt/${iso_name}/${target_arch}/${profile}-image.sqfs ]];then
		echo "    -   source: \"/bootmnt/${iso_name}/${target_arch}/${profile}-image.sqfs\"" >> "$conf"
		echo "        sourcefs: \"squashfs\"" >> "$conf"
		echo "        destination: \"\"" >> "$conf"
	fi
}

write_users_conf(){
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

write_packages_conf(){
	local conf="$1/etc/calamares/modules/packages.conf"
	echo "---" > "$conf"
	echo "backend: pacman" >> "$conf"
}

write_welcome_conf(){
	local conf="$1/etc/calamares/modules/welcome.conf"
	echo "---" > "$conf" >> "$conf"
	echo "showSupportUrl:         true" >> "$conf"
	echo "showKnownIssuesUrl:     true" >> "$conf"
	echo "showReleaseNotesUrl:    true" >> "$conf"
	echo '' >> "$conf"
	echo "requirements:" >> "$conf"
	echo "requiredStorage:    5.5" >> "$conf"
	echo "requiredRam:        1.0" >> "$conf"
	echo "check:" >> "$conf"
	echo "  - storage" >> "$conf"
	echo "  - ram" >> "$conf"
	echo "  - power" >> "$conf"
	echo "  - internet" >> "$conf"
	echo "  - root" >> "$conf"
	echo "required:" >> "$conf"
	echo "  - storage" >> "$conf"
	echo "  - ram" >> "$conf"
	echo "  - root" >> "$conf"
	${cal_netinstall} && echo "  - internet" >> "$conf"
}

write_settings_conf(){
	local conf="$1/etc/calamares/settings.conf"
	echo "---" > "$conf"
	echo "modules-search: [ local ]" >> "$conf"
	echo '' >> "$conf"
	echo "instances:" >> "$conf"
	echo '' >> "$conf"
	echo "sequence:" >> "$conf"
	echo "- show:" >> "$conf"
	echo "  - welcome" >> "$conf"
	${cal_netinstall} && echo "  - netinstall" >> "$conf"
	echo "  - locale" >> "$conf"
	echo "  - keyboard" >> "$conf"
	echo "  - partition" >> "$conf"
	echo "  - users" >> "$conf"
	echo "  - summary" >> "$conf"
	echo "- exec:" >> "$conf"
	echo "  - partition" >> "$conf"
	echo "  - mount" >> "$conf"
	if ${cal_netinstall};then
		if ${cal_unpackfs};then
			echo "  - unpackfs" >> "$conf"
			echo "  - networkcfg" >> "$conf"
			echo "  - packages" >> "$conf"
		else
			# take out networkcfg once a new PR has been merged
			echo "  - networkcfg" >> "$conf"
			echo "  - chrootcfg" >> "$conf"
		fi
	else
		echo "  - unpackfs" >> "$conf"
		echo "  - networkcfg" >> "$conf"
	fi
	echo "  - machineid" >> "$conf"
	echo "  - fstab" >> "$conf"
	echo "  - locale" >> "$conf"
	echo "  - keyboard" >> "$conf"
	echo "  - localegen" >> "$conf"
	echo "  - luksopenswaphookcfg" >> "$conf"
	echo "  - luksbootkeyfile" >> "$conf"
	echo "  - initcpiocfg" >> "$conf"
	echo "  - initcpio" >> "$conf"
	echo "  - users" >> "$conf"
	echo "  - displaymanager" >> "$conf"
	echo "  - hardwarecfg" >> "$conf"
	echo "  - networkcfg" >> "$conf"
	echo "  - hwclock" >> "$conf"
	echo "  - services" >> "$conf"
	echo "  - grubcfg" >> "$conf"
	echo "  - bootloader" >> "$conf"
	echo "  - postcfg" >> "$conf"
	echo "  - umount" >> "$conf"
	echo "- show:" >> "$conf"
	echo "  - finished" >> "$conf"
	echo '' >> "$conf"
	echo "branding: ${iso_name}" >> "$conf"
	echo '' >> "$conf"
	echo "prompt-install: false" >> "$conf"
	echo '' >> "$conf"
	echo "dont-chroot: false" >> "$conf"
}

write_chrootcfg_conf(){
	local conf="$1/etc/calamares/modules/chrootcfg.conf"
	echo "---" > "$conf"
	echo "requirements:" >> "$conf"
	echo "    - directory: /etc" >> "$conf"
	echo "    - directory: /var/log" >> "$conf"
	echo "    - directory: /var/cache/pacman/pkg" >> "$conf"
	echo "    - directory: /var/lib/pacman" >> "$conf"
	echo '' >> "$conf"
	echo "packages:" >> "$conf"
	echo "    - pacman" >> "$conf"
	echo "    - ${kernel}" >> "$conf"
	# take out until a new PR has been merged
# 	echo '' >> "$conf"
# 	echo "keyrings:" >> "$conf"
# 	echo "    - archlinux" >> "$conf"
# 	echo "    - manjaro" >> "$conf"
}

write_netinstall_conf(){
	local conf="$1/etc/calamares/modules/netinstall.conf"
	echo "---" > "$conf"
	echo "groupsUrl: ${cal_netgroups}" >> "$conf"
}

configure_calamares(){
	msg2 "Configuring Calamares ..."

	mkdir -p $1/etc/calamares/modules

	write_settings_conf "$1"

	write_welcome_conf "$1"

	write_packages_conf "$1"

	write_bootloader_conf "$1"

	write_unpack_conf "$1"

	write_displaymanager_conf "$1"

	write_initcpio_conf "$1"

	write_machineid_conf "$1"

	write_finished_conf "$1"

	write_netinstall_conf "$1"

	write_chrootcfg_conf "$1"

	write_services_conf "$1"
	write_users_conf "$1"
}
