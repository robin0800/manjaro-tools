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
	if [[ ${initsys} == 'openrc' ]];then
		local conf="$1/etc/calamares/modules/servicescfg.conf"
		echo '---' >  "$conf"
		echo '' >> "$conf"
		echo 'services:' >> "$conf"
		echo '    enabled:' >> "$conf"
		for s in ${enable_openrc[@]};do
			echo "      - name: $s" >> "$conf"
			echo '        runlevel: default' >> "$conf"
		done
		if [[ -n ${disable_openrc[@]} ]];then
			echo '    disabled:' >> "$conf"
			for s in ${disable_openrc[@]};do
				echo "      - name: $s" >> "$conf"
				echo '        runlevel: default' >> "$conf"
				echo '' >> "$conf"
			done
		fi
	else
		local conf="$1/etc/calamares/modules/services.conf"
		echo '---' >  "$conf"
		echo '' >> "$conf"
		echo 'services:' > "$conf"
		for s in ${enable_systemd[@]};do
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
	if [[ -f "${packages_custom}" ]] ; then
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
	if ${netinstall};then
		echo "  - internet" >> "$conf"
	fi
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
	${netinstall} && echo "  - netinstall" >> "$conf"
	echo "  - locale" >> "$conf"
	echo "  - keyboard" >> "$conf"
	echo "  - partition" >> "$conf"
	echo "  - users" >> "$conf"
	echo "  - summary" >> "$conf"
	echo "- exec:" >> "$conf"
	echo "  - partition" >> "$conf"
	echo "  - mount" >> "$conf"
	if ${netinstall};then
		if ${unpackfs};then
			echo "  - unpackfs" >> "$conf"
			echo "  - networkcfg" >> "$conf"
			echo "  - packages" >> "$conf"
		else
			echo "  - chrootcfg" >> "$conf"
			echo "  - networkcfg" >> "$conf"
		fi
	else
		echo "  - unpackfs" >> "$conf"
		echo "  - networkcfg" >> "$conf"
	fi
	echo "  - machineid" >> "$conf"
	echo "  - fstab" >> "$conf"
	echo "  - locale" >> "$conf"
	echo "  - keyboard" >> "$conf"
	echo "  - localecfg" >> "$conf"
	echo "  - luksopenswaphookcfg" >> "$conf"
	echo "  - luksbootkeyfile" >> "$conf"
	echo "  - initcpiocfg" >> "$conf"
	echo "  - initcpio" >> "$conf"
	echo "  - users" >> "$conf"
	echo "  - displaymanager" >> "$conf"
	echo "  - mhwdcfg" >> "$conf"
	echo "  - hwclock" >> "$conf"
	if [[ ${initsys} == 'systemd' ]];then
		echo "  - services" >> "$conf"
	else
		echo "  - servicescfg" >> "$conf"
	fi
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

write_mhwdcfg_conf(){
	local conf="$1/etc/calamares/modules/mhwdcfg.conf"
	echo "---" > "$conf"
	echo "identifier:" >> "$conf"
	echo "    net:" >> "$conf"
	echo "      - 200" >> "$conf"
	echo "      - 280" >> "$conf"
	echo "    video:" >> "$conf"
	echo "      - 300" >> "$conf"
	echo '' >> "$conf"
	echo "bus:" >> "$conf"
	echo "    - pci" >> "$conf"
	echo "    - usb" >> "$conf"
	echo '' >> "$conf"
	if ${nonfree_xorg};then
		echo "driver: nonfree" >> "$conf"
	else
		echo "driver: free" >> "$conf"
	fi
	echo '' >> "$conf"
	if ${netinstall};then
		if ${unpackfs};then
			echo "local: true" >> "$conf"
		else
			echo "local: false" >> "$conf"
		fi
	else
		echo "local: true" >> "$conf"
	fi
	echo '' >> "$conf"
	echo 'repo: /opt/pacman-mhwd.conf' >> "$conf"
}

write_chrootcfg_conf(){
	local conf="$1/etc/calamares/modules/chrootcfg.conf" mode='"0o755"'
	echo "---" > "$conf"
	echo "requirements:" >> "$conf"
	echo "    - name: /etc" >> "$conf"
	echo "      mode: ${mode}" >> "$conf"
	echo "    - name: /var/cache/pacman/pkg" >> "$conf"
	echo "      mode: ${mode}" >> "$conf"
	echo "    - name: /var/lib/pacman" >> "$conf"
	echo "      mode: ${mode}" >> "$conf"
	echo '' >> "$conf"
	echo "keyrings:" >> "$conf"
	echo "    - archlinux" >> "$conf"
	echo "    - manjaro" >> "$conf"
}

write_postcfg_conf(){
	local conf="$1/etc/calamares/modules/postcfg.conf"
	echo "---" > "$conf"
	echo "keyrings:" >> "$conf"
	echo "    - archlinux" >> "$conf"
	echo "    - manjaro" >> "$conf"
}

get_yaml(){
	local args=() ext="yaml" yaml
	if ${unpackfs};then
		args+=("hybrid")
	else
		args+=('netinstall')
	fi
	[[ ${initsys} == 'openrc' ]] && args+=("${initsys}")
	[[ ${edition} == 'sonar' ]] && args+=("${edition}")
	for arg in ${args[@]};do
		yaml=${yaml:-}${yaml:+-}${arg}
	done
	echo "${yaml}.${ext}"
}

write_netinstall_conf(){
	local conf="$1/etc/calamares/modules/netinstall.conf"
	echo "---" > "$conf"
	echo "groupsUrl: ${netgroups}/$(get_yaml)" >> "$conf"
}

write_grubcfg_conf(){
	local conf="$1/etc/calamares/modules/grubcfg.conf"
	echo "---" > "$conf"
	echo "overwrite: false" >> "$conf"
	echo '' >> "$conf"
	echo "defaults:" >> "$conf"
	echo "    GRUB_TIMEOUT: 5" >> "$conf"
	echo '    GRUB_DEFAULT: "saved"' >> "$conf"
	echo "    GRUB_DISABLE_SUBMENU: true" >> "$conf"
	echo '    GRUB_TERMINAL_OUTPUT: "console"' >> "$conf"
	echo "    GRUB_DISABLE_RECOVERY: true" >> "$conf"
	if ${plymouth_boot};then
		echo '' >> "$conf"
		echo "plymouth_theme: ${plymouth_theme}"
	fi
}

configure_calamares(){
	msg2 "Configuring Calamares ..."

	mkdir -p $1/etc/calamares/modules

	write_settings_conf "$1"

	write_welcome_conf "$1"

	write_packages_conf "$1"

	write_bootloader_conf "$1"

	write_mhwdcfg_conf "$1"

	write_unpack_conf "$1"

	write_displaymanager_conf "$1"

	write_initcpio_conf "$1"

	write_machineid_conf "$1"

	write_finished_conf "$1"

	write_netinstall_conf "$1"

	write_chrootcfg_conf "$1"

	write_postcfg_conf "$1"

	write_grubcfg_conf "$1"

	write_services_conf "$1"
	write_users_conf "$1"
}
