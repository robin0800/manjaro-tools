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
	local conf="$1/etc/calamares/modules/machineid.conf"
	echo "systemd: false" > $conf
	echo "dbus: true" >> $conf
	echo "symlink: false" >> $conf
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
	echo "kernelLine: \", with ${kernel}\"" >> "$conf"
	echo "fallbackKernelLine: \", with ${kernel} (fallback initramfs)\"" >> "$conf"
	echo 'timeout: "10"' >> "$conf"
	echo 'grubInstall: "grub-install"' >> "$conf"
	echo 'grubMkconfig: "grub-mkconfig"' >> "$conf"
	echo 'grubCfg: "/boot/grub/grub.cfg"' >> "$conf"
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
	fi
}

write_calamares_dm_conf(){
	local conf="$1/etc/calamares/modules/displaymanager.conf"
	echo "displaymanagers:" > "$conf"
	echo "  - ${displaymanager}" >> "$conf"
	echo '' >> "$conf"
	echo '#executable: "startkde"' >> "$conf"
	echo '#desktopFile: "plasma"' >> "$conf"
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
}

brand_calamares_settings_conf(){
	local conf="$1/usr/share/calamares/settings.conf"
	local branding="$1/usr/share/calamares/branding/manjaro-${custom}"
	if [[ -d $branding ]];then
		sed -i -e "s|branding: manjaro|branding: manjaro-${custom}|g" "$conf"
	fi
}

configure_calamares(){
	if [[ -f $1/usr/bin/calamares ]];then
		msg2 "Configuring Calamares ..."
		mkdir -p $1/etc/calamares/modules
		write_calamares_bootloader_conf $1
		write_calamares_unpack_conf $1
		write_calamares_dm_conf $1
		write_calamares_initcpio_conf $1
		brand_calamares_settings_conf $1
		if [[ ${initsys} == 'openrc' ]];then
			write_calamares_machineid_conf $1
			write_calamares_finished_conf $1
		fi
		write_calamares_services_conf $1
		write_calamares_users_conf $1

		mkdir -p $1/home/${username}/Desktop
		if [[ -f $1/usr/bin/kdesu ]];then
			sed -i -e 's|sudo|kdesu|g' $1/usr/share/applications/calamares.desktop
		fi
		cp $1/usr/share/applications/calamares.desktop $1/home/${username}/Desktop/calamares.desktop
		chmod a+x $1/home/${username}/Desktop/calamares.desktop
	fi
}

configure_thus(){
	if [[ -f $1/usr/bin/thus ]];then
		msg2 "Configuring Thus ..."
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
		mkdir -p $1/home/${username}/Desktop
		if [[ -f $1/usr/bin/kdesu ]];then
			sed -i -e 's|sudo|kdesu|g' $1/usr/share/applications/thus.desktop
		fi
		cp $1/usr/share/applications/thus.desktop $1/home/${username}/Desktop/thus.desktop
		chmod a+x $1/home/${username}/Desktop/thus.desktop
	fi
}

configure_cli(){
	if [[ -f $1/usr/bin/setup ]]||[[ -L $1/usr/bin/setup ]];then
		msg2 "Configuring cli-installer ..."
		if [[ ! -f $1/home/${username}/Desktop/installer-launcher-cli.desktop ]];then
			cp $1/etc/skel/Desktop/installer-launcher-cli.desktop \
			$1/home/${username}/Desktop/installer-launcher-cli.desktop
		fi
		chmod a+x $1/home/${username}/Desktop/installer-launcher-cli.desktop
	fi
}
