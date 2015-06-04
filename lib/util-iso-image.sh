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

gen_pw(){
	echo $(perl -e 'print crypt($ARGV[0], "password")' ${password})
}

# $1: chroot
configure_user(){
	# set up user and password
	msg2 "Creating user: ${username} password: ${password} ..."
	chroot $1 useradd -m -g users -G ${addgroups} -p $(gen_pw) ${username}
}

# $1: chroot
configure_hostname(){
	msg2 "Setting hostname: ${hostname} ..."
	if [[ ${initsys} == 'openrc' ]];then
		local _hostname='hostname="'${hostname}'"'
		sed -i -e "s|^.*hostname=.*|${_hostname}|" $1/etc/conf.d/hostname
	else
		echo ${hostname} > $1/etc/hostname
	fi
}

# $1: chroot
configure_hosts(){
	sed -e "s|localhost.localdomain|localhost.localdomain ${hostname}|" -i $1/etc/hosts
}

# $1: chroot
configure_plymouth(){
	if ${is_plymouth};then
		msg2 "Setting plymouth $plymouth_theme ...."
		sed -i -e "s/^.*Theme=.*/Theme=$plymouth_theme/" $1/etc/plymouth/plymouthd.conf
	fi
}

configure_services_live(){
	case ${initsys} in
		'openrc')
			msg3 "Configuring [${initsys}] ...."
			for svc in ${start_openrc_live[@]}; do
				msg2 "Setting $svc ..."
				chroot $1 rc-update add $svc default &> /dev/null
			done
			msg3 "Done configuring [${initsys}]"
		;;
		'systemd')
			msg3 "Configuring [${initsys}] ...."
			for svc in ${start_systemd_live[@]}; do
				msg2 "Setting $svc ..."
				chroot $1 systemctl enable $svc &> /dev/null
			done
			msg3 "Done configuring [${initsys}]"
		;;
		*)
			msg3 "Unsupported: [${initsys}]!"
			break
		;;
	esac
}

# $1: chroot
configure_lsb(){
	[[ -f $1/boot/grub/grub.cfg ]] && rm $1/boot/grub/grub.cfg
	if [ -e $1/etc/lsb-release ] ; then
		sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${dist_release}/" $1/etc/lsb-release
		sed -i -e "s/^.*DISTRIB_CODENAME.*/DISTRIB_CODENAME=${dist_codename}/" $1/etc/lsb-release
	fi
}

# configure_dbus(){
# 	msg2 "Configuring dbus ...."
# 	# set unique machine-id
# # 	dbus-uuidgen --ensure=/etc/machine-id
# # 	ln -sf /etc/machine-id /var/lib/dbus/machine-id
# 	chroot $1 dbus-uuidgen --ensure=/var/lib/dbus/machine-id
# }

configure_services(){
	case ${initsys} in
		'openrc')
			msg3 "Congiguring [${initsys}] ...."
			for svc in ${start_openrc[@]}; do
				msg2 "Setting $svc ..."
				chroot $1 rc-update add $svc default &> /dev/null
			done
			msg3 "Done configuring [${initsys}]"
		;;
		'systemd')
			msg3 "Congiguring [${initsys}] ...."
			for svc in ${start_systemd[@]}; do
				msg2 "Setting $svc ..."
				chroot $1 systemctl enable $svc &> /dev/null
			done
			msg3 "Done configuring [${initsys}]"
		;;
		*)
			msg3 "Unsupported: [${initsys}]!"
			break
		;;
	esac
}

# $1: chroot
configure_environment(){
	case ${custom} in
		gnome|xfce|openbox|enlightenment|cinnamon|pekwm|lxde|mate)
			echo "QT_STYLE_OVERRIDE=gtk" >> $1/etc/environment
		;;
	esac
}

# $1: chroot
# $2: user
configure_accountsservice(){
	msg2 "Configuring AccountsService ..."
	local path=$1/var/lib/AccountsService/users
	if [ -d "${path}" ] ; then
		echo "[User]" > ${path}/$2
		echo "XSession=${default_desktop_file}" >> ${path}/$2
		echo "Icon=/var/lib/AccountsService/icons/$2.png" >> ${path}/$2
	fi
}

# $1: chroot
configure_displaymanager(){
	msg2 "Configuring Displaymanager ..."
	# Try to detect desktop environment
	if [[ "${default_desktop_executable}" == "none" ]] || [[ ${default_desktop_file} == "none" ]]; then
		msg2 "No default desktop environment set, trying to detect it."
		if [ -e "$1/usr/bin/startkde" ] && [ -e "$1/usr/share/xsessions/plasma.desktop" ]; then
			default_desktop_executable="startkde"
			default_desktop_file="plasma"
			msg2 "Detected Plasma 5 desktop environment"
		elif [ -e "$1/usr/bin/startkde" ] && [ -e "$1/usr/share/xsessions/kde-plasma.desktop" ]; then
			default_desktop_executable="startkde"
			default_desktop_file="kde-plasma"
			msg2 "Detected KDE Plasma 4 desktop environment"
		elif [ -e "$1/usr/bin/gnome-session" ] && [ -e "$1/usr/share/xsessions/gnome.desktop" ]; then
			default_desktop_executable="gnome-session"
			default_desktop_file="gnome"
			msg2 "Detected Gnome desktop environment"
		elif [ -e "$1/usr/bin/startxfce4" ] && [ -e "$1/usr/share/xsessions/xfce.desktop" ]; then
			default_desktop_executable="startxfce4"
			default_desktop_file="xfce"
			msg2 "Detected Xfce desktop environment"
		elif [ -e "$1/usr/bin/cinnamon-session" ] && [ -e "$1/usr/share/xsessions/cinnamon-session.desktop" ]; then
			default_desktop_executable="cinnamon-session"
			default_desktop_file="cinnamon-session"
			msg2 "Detected Cinnamon desktop environment"
		elif [ -e "$1/usr/bin/mate-session" ] && [ -e "$1/usr/share/xsessions/mate.desktop" ]; then
			default_desktop_executable="mate-session"
			default_desktop_file="mate"
			msg2 "Detected Mate desktop environment"
		elif [ -e "$1/usr/bin/enlightenment_start" ] && [ -e "$1/usr/share/xsessions/enlightenment.desktop" ]; then
			default_desktop_executable="enlightenment_start"
			default_desktop_file="enlightenment"
			msg2 "Detected Enlightenment desktop environment"
		elif [ -e "$1/usr/bin/lxsession" ] && [ -e "$1/usr/share/xsessions/LXDE.desktop" ]; then
			default_desktop_executable="lxsession"
			default_desktop_file="LXDE"
			msg2 "Detected LXDE desktop environment"
		elif [ -e "$1/usr/bin/startlxde" ] && [ -e "$1/usr/share/xsessions/LXDE.desktop" ]; then
			default_desktop_executable="startlxde"
			default_desktop_file="LXDE"
			msg2 "Detected LXDE desktop environment"
		elif [ -e "$1/usr/bin/lxqt-session" ] && [ -e "$1/usr/share/xsessions/lxqt.desktop" ]; then
			default_desktop_executable="lxqt-session"
			default_desktop_file="lxqt"
			msg2 "Detected LXQt desktop environment"
		elif [ -e "$1/usr/bin/pekwm" ] && [ -e "$1/usr/share/xsessions/pekwm.desktop" ]; then
			default_desktop_executable="pekwm"
			default_desktop_file="pekwm"
			msg2 "Detected PekWM desktop environment"
		elif [ -e "$1/usr/bin/pantheon-session" ] && [ -e "$1/usr/share/xsessions/pantheon.desktop" ]; then
			default_desktop_executable="pantheon-session"
			default_desktop_file="pantheon"
			msg2 "Detected Pantheon desktop environment"
		elif [ -e "$1/usr/bin/budgie-session" ] && [ -e "$1/usr/share/xsessions/budgie-session.desktop" ]; then
			default_desktop_executable="budgie-session"
			default_desktop_file="budgie-session"
			msg2 "Detected Budgie desktop environment"
		elif [ -e "$1/usr/bin/i3" ] && [ -e "$1/usr/share/xsessions/i3.desktop" ]; then
			default_desktop_executable="i3"
			default_desktop_file="i3"
			msg2 "Detected i3 desktop environment"
		elif [ -e "$1/usr/bin/openbox-session" ] && [ -e "$1/usr/share/xsessions/openbox.desktop" ]; then
			default_desktop_executable="openbox-session"
			default_desktop_file="openbox"
			msg2 "Detected Openbox desktop environment"
		else
			default_desktop_executable="none"
			default_desktop_file="none"
			msg2 "No desktop environment detected"
		fi
	fi
	# Configure display manager
	case ${displaymanager} in
		'lightdm')
			chroot $1 groupadd -r autologin
			local conf=$1/etc/lightdm/lightdm.conf
			if [[ ${default_desktop_executable} != "none" ]] && [[ ${default_desktop_file} != "none" ]]; then
				sed -i -e "s/^.*user-session=.*/user-session=$default_desktop_file/" ${conf}
			fi
			if [[ ${initsys} == 'openrc' ]];then
				sed -i -e 's/^.*minimum-vt=.*/minimum-vt=7/' ${conf}
			fi
			local greeters=$(ls $1/etc/lightdm/*greeter.conf)
			for g in ${greeters[@]};do
				case ${g##*/} in
					'lxqt-lightdm-greeter.conf')
						sed -i -e "s/^.*greeter-session=.*/greeter-session=lxqt-lightdm-greeter/" ${conf}
					;;
					'lightdm-kde-greeter.conf')
						sed -i -e "s/^.*greeter-session=.*/greeter-session=lightdm-kde-greeter/" ${conf}
					;;
					*) break ;;
				esac
			done
		;;
		'gdm')
			configure_accountsservice $1 "gdm"
		;;
		'mdm')
			local conf=$1/etc/mdm/custom.conf
			if [[ ${default_desktop_executable} != "none" ]] && [[ ${default_desktop_file} != "none" ]]; then
				sed -i "s|default.desktop|$default_desktop_file.desktop|g" ${conf}
			fi
		;;
		'sddm')
			local conf=$1/etc/sddm.conf
			if [[ ${default_desktop_executable} != "none" ]] && [[ ${default_desktop_file} != "none" ]]; then
				sed -i -e "s|^Session=.*|Session=$default_desktop_file.desktop|" ${conf}
			fi
		;;
		'lxdm')
			local conf=$1/etc/lxdm/lxdm.conf
			if [[ ${default_desktop_executable} != "none" ]] && [[ ${default_desktop_file} != "none" ]]; then
				sed -i -e "s|^.*session=.*|session=/usr/bin/$default_desktop_executable|" ${conf}
			fi
		;;
		*) break ;;
	esac
	if [[ ${displaymanager} != "none" ]];then
		if [[ ${initsys} == 'openrc' ]];then
			local conf='DISPLAYMANAGER="'${displaymanager}'"'
			sed -i -e "s|^.*DISPLAYMANAGER=.*|${conf}|" $1/etc/conf.d/xdm
			chroot $1 rc-update add xdm default &> /dev/null
		else
			local service=${displaymanager}
			if [[ -f $1/etc/plymouth/plymouthd.conf && \
				-f $1/usr/lib/systemd/system/${displaymanager}-plymouth.service ]]; then
				service=${displaymanager}-plymouth
			fi
			chroot $1 systemctl enable ${service} &> /dev/null
		fi
	fi
	msg2 "Configured: ${displaymanager}"
}

# $1: chroot
configure_xorg_drivers(){
	# Disable Catalyst if not present
	if  [ -z "$(ls $1/opt/livecd/pkgs/ | grep catalyst-utils 2> /dev/null)" ]; then
		msg2 "Disabling Catalyst driver"
		mkdir -p $1/var/lib/mhwd/db/pci/graphic_drivers/catalyst/
		touch $1/var/lib/mhwd/db/pci/graphic_drivers/catalyst/MHWDCONFIG
	fi
	# Disable Nvidia if not present
	if  [ -z "$(ls $1/opt/livecd/pkgs/ | grep nvidia-utils 2> /dev/null)" ]; then
		msg2 "Disabling Nvidia driver"
		mkdir -p $1/var/lib/mhwd/db/pci/graphic_drivers/nvidia/
		touch $1/var/lib/mhwd/db/pci/graphic_drivers/nvidia/MHWDCONFIG
	fi
	if  [ -z "$(ls $1/opt/livecd/pkgs/ | grep nvidia-utils 2> /dev/null)" ]; then
		msg2 "Disabling Nvidia Bumblebee driver"
		mkdir -p $1/var/lib/mhwd/db/pci/graphic_drivers/hybrid-intel-nvidia-bumblebee/
		touch $1/var/lib/mhwd/db/pci/graphic_drivers/hybrid-intel-nvidia-bumblebee/MHWDCONFIG
	fi
	if  [ -z "$(ls $1/opt/livecd/pkgs/ | grep nvidia-304xx-utils 2> /dev/null)" ]; then
		msg2 "Disabling Nvidia 304xx driver"
		mkdir -p $1/var/lib/mhwd/db/pci/graphic_drivers/nvidia-304xx/
		touch $1/var/lib/mhwd/db/pci/graphic_drivers/nvidia-304xx/MHWDCONFIG
	fi
	if  [ -z "$(ls $1/opt/livecd/pkgs/ | grep nvidia-340xx-utils 2> /dev/null)" ]; then
		msg2 "Disabling Nvidia 340xx driver"
		mkdir -p $1/var/lib/mhwd/db/pci/graphic_drivers/nvidia-340xx/
		touch $1/var/lib/mhwd/db/pci/graphic_drivers/nvidia-340xx/MHWDCONFIG
	fi
}

chroot_clean(){
	msg "Cleaning up ..."
	for image in "$1"/*-image; do
		[[ -d ${image} ]] || continue
		if [[ $(basename "${image}") != "pkgs-image" ]] || \
		[[ $(basename "${image}") != "lng-image" ]];then
			msg2 "Deleting chroot '$(basename "${image}")'..."
			lock 9 "${image}.lock" "Locking chroot '${image}'"
			if [[ "$(stat -f -c %T "${image}")" == btrfs ]]; then
				{ type -P btrfs && btrfs subvolume delete "${image}"; } &> /dev/null
			fi
		rm -rf --one-file-system "${image}"
		fi
	done
	exec 9>&-
	rm -rf --one-file-system "$1"
}

configure_custom_image(){
	msg "Configuring [${custom}-image]"
	configure_plymouth "$1"
	configure_displaymanager "$1"
	configure_services "$1"
	configure_environment "$1"
	msg "Done configuring [${custom}-image]"
}

configure_livecd_image(){
	msg "Configuring [livecd-image]"
	configure_hostname "$1"
	configure_hosts "$1"
	configure_accountsservice "$1" "${username}"
	configure_user "$1"
	configure_services_live "$1"
	configure_calamares "$1"
	configure_thus "$1"
	configure_cli "$1"
	msg "Done configuring [livecd-image]"
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
			--cache $2 -Syw $3 --noconfirm
}

# $1: image path
# $2: packages
chroot_create(){
	[[ "$1" == "${work_dir}/root-image" ]] && local flag="-L"
	setarch "${arch}" \
		mkchroot ${mkchroot_args[*]} ${flag} \
			$@ || die "Failed to retrieve one or more packages!"
}

# $1: new branch
aufs_mount_root_image(){
	msg2 "mount [root-image] on [${1##*/}]"
	mount -t aufs -o br="$1":${work_dir}/root-image=ro none "$1"
}

# $1: add branch
aufs_append_root_image(){
	msg2 "append [root-image] on [${1##*/}]"
	mount -t aufs -o remount,append:${work_dir}/root-image=ro none "$1"
}

# $1: add branch
aufs_mount_custom_image(){
	msg2 "mount [${1##*/}] on [${custom}-image]"
	mount -t aufs -o br="$1":${work_dir}/${custom}-image=ro none "$1"
}

# $1: del branch
aufs_remove_image(){
	if mountpoint -q "$1";then
		msg2 "unmount ${1##*/}"
		umount $1
	fi
}

# $1: image path
aufs_clean(){
	find $1 -name '.wh.*' -delete &> /dev/null
}

umount_image_handler(){
	aufs_remove_image "${work_dir}/livecd-image"
	aufs_remove_image "${work_dir}/${custom}-image"
	aufs_remove_image "${work_dir}/root-image"
	aufs_remove_image "${work_dir}/pkgs-image"
	aufs_remove_image "${work_dir}/lng-image"
	aufs_remove_image "${work_dir}/boot-image"
}

# $1: image path
clean_up_image(){
	msg2 "Cleaning up [${1##*/}]"
	[[ -d "$1/boot/" ]] && find "$1/boot" -name 'initramfs*.img' -delete &> /dev/null
	[[ -f "$1/etc/locale.gen.bak" ]] && mv "$1/etc/locale.gen.bak" "$1/etc/locale.gen"
	[[ -f "$1/etc/locale.conf.bak" ]] && mv "$1/etc/locale.conf.bak" "$1/etc/locale.conf"

	find "$1/var/lib/pacman" -maxdepth 1 -type f -delete &> /dev/null
	find "$1/var/lib/pacman/sync" -type f -delete &> /dev/null
	find "$1/var/cache/pacman/pkg" -type f -delete &> /dev/null
	find "$1/var/log" -type f -delete &> /dev/null
	find "$1/var/tmp" -mindepth 1 -delete &> /dev/null
	find "$1/tmp" -mindepth 1 -delete &> /dev/null

# 	find "${work_dir}" -name *.pacnew -name *.pacsave -name *.pacorig -delete
}
