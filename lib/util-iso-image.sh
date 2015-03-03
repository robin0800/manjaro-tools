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
	if [[ ${initsys} == 'openrc' ]];then
		msg3 "Configuring OpenRC ...."
		for svc in ${start_openrc_live[@]}; do
			msg2 "Setting $svc ..."
			chroot $1 rc-update add $svc default &> /dev/null
		done
		msg3 "Done configuring OpenRC"
	else
		msg3 "Configuring SystemD ...."
		for svc in ${start_systemd_live[@]}; do
			msg2 "Setting $svc ..."
			chroot $1 systemctl enable $svc &> /dev/null
		done
		msg3 "Done configuring SystemD"
	fi
}

configure_lsb(){
	[[ -f $1/boot/grub/grub.cfg ]] && rm $1/boot/grub/grub.cfg
	if [ -e $1/etc/lsb-release ] ; then
		sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${iso_version}/" $1/etc/lsb-release
		sed -i -e "s/^.*DISTRIB_CODENAME.*/DISTRIB_CODENAME=${code_name}/" $1/etc/lsb-release
	fi
}

configure_dbus(){
	msg2 "Configuring dbus ...."
	# set unique machine-id
# 	dbus-uuidgen --ensure=/etc/machine-id
# 	ln -sf /etc/machine-id /var/lib/dbus/machine-id
	chroot $1 dbus-uuidgen --ensure=/var/lib/dbus/machine-id
}

configure_services(){
	if [[ ${initsys} == 'openrc' ]];then
		msg3 "Congiguring OpenRC ...."
		for svc in ${start_openrc[@]}; do
			msg2 "Setting $svc ..."
			chroot $1 rc-update add $svc default &> /dev/null
		done
		msg3 "Done configuring OpenRC"
	else
		msg3 "Configuring SystemD ...."
		for svc in ${start_systemd[@]}; do
			msg2 "Setting $svc ..."
			chroot $1 systemctl enable $svc &> /dev/null
		done
		msg3 "Done configuring SystemD"
	fi
}

# $1: chroot
# $2: user
configure_accountsservice(){
	msg2 "Configuring AccountsService ..."
	local path=$1/var/lib/AccountsService/users
	if [ -d "${path}" ] ; then
		echo "[User]" > ${path}/$2
		if [ -e "$1/usr/bin/openbox-session" ] ; then
			echo "XSession=openbox" >> ${path}/$2
		fi
		if [ -e "$1/usr/bin/startxfce4" ] ; then
			echo "XSession=xfce" >> ${path}/$2
		fi
		if [ -e "$1/usr/bin/cinnamon-session" ] ; then
			echo "XSession=cinnamon" >> ${path}/$2
		fi
		if [ -e "$1/usr/bin/mate-session" ] ; then
			echo "XSession=mate" >> ${path}/$2
		fi
		if [ -e "$1/usr/bin/enlightenment_start" ] ; then
			echo "XSession=enlightenment" >> ${path}/$2
		fi
		if [ -e "$1/usr/bin/startlxde" ] ; then
			echo "XSession=LXDE" >> ${path}/$2
		fi
		if [ -e "$1/usr/bin/lxqt-session" ] ; then
			echo "XSession=LXQt" >> ${path}/$2
		fi
		echo "Icon=/var/lib/AccountsService/icons/$2.png" >> ${path}/$2
	fi
}

# $1: chroot
configure_displaymanager(){
	msg2 "Configuring Displaymanager ..."
	case ${displaymanager} in
		'lightdm')
			chroot $1 groupadd -r autologin
			local conf=$1/etc/lightdm/lightdm.conf
			if [ -e "$1/usr/bin/openbox-session" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=openbox/' ${conf}
			fi
			if [ -e "$1/usr/bin/startxfce4" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=xfce/' ${conf}
			fi
			if [ -e "$1/usr/bin/cinnamon-session" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=cinnamon/' ${conf}
			fi
			if [ -e "$1/usr/bin/mate-session" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=mate/' ${conf}
			fi
			if [ -e "$1/usr/bin/enlightenment_start" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=enlightenment/' ${conf}
			fi
			if [ -e "$1/usr/bin/startlxde" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=LXDE/' ${conf}
			fi
			if [ -e "$1/usr/bin/lxqt-session" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=lxqt/' ${conf}
			fi
			if [ -e "$1/usr/bin/pekwm" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=pekwm/' ${conf}
			fi
			if [ -e "$1/usr/bin/i3" ] ; then
				sed -i -e 's/^.*user-session=.*/user-session=i3/' ${conf}
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
			if [ -e "$1/usr/bin/startxfce4" ] ; then
				sed -i 's|default.desktop|xfce.desktop|g' ${conf}
			fi
			if [ -e "$1/usr/bin/cinnamon-session" ] ; then
				sed -i 's|default.desktop|cinnamon.desktop|g' ${conf}
			fi
			if [ -e "$1/usr/bin/openbox-session" ] ; then
				sed -i 's|default.desktop|openbox.desktop|g' ${conf}
			fi
			if [ -e "$1/usr/bin/mate-session" ] ; then
				sed -i 's|default.desktop|mate.desktop|g' ${conf}
			fi
			if [ -e "$1/usr/bin/startlxde" ] ; then
				sed -i 's|default.desktop|LXDE.desktop|g' ${conf}
			fi
			if [ -e "$1/usr/bin/lxqt-session" ] ; then
				sed -i 's|default.desktop|lxqt.desktop|g' ${conf}
			fi
			if [ -e "$1/usr/bin/enlightenment_start" ] ; then
				sed -i 's|default.desktop|enlightenment.desktop|g' ${conf}
			fi
		;;
		'sddm')
			local conf=$1/etc/sddm.conf
			if [ -e "$1/usr/bin/startxfce4" ] ; then
				sed -i -e 's|^Session=.*|Session=xfce.desktop|' ${conf}
			fi
			if [ -e "$1/usr/bin/cinnamon-session" ] ; then
				sed -i -e 's|^Session=.*|Session=cinnamon.desktop|' ${conf}
			fi
			if [ -e "$1/usr/bin/openbox-session" ] ; then
				sed -i -e 's|^Session=.*|Session=openbox.desktop|' ${conf}
			fi
			if [ -e "$1/usr/bin/mate-session" ] ; then
				sed -i -e 's|^Session=.*|Session=mate.desktop|' ${conf}
			fi
			if [ -e "$1/usr/bin/lxsession" ] ; then
				sed -i -e 's|^Session=.*|Session=LXDE.desktop|' ${conf}
			fi
			if [ -e "$1/usr/bin/lxqt-session" ] ; then
				sed -i -e 's|^Session=.*|Session=lxqt.desktop|' ${conf}
			fi
			if [ -e "$1/usr/bin/enlightenment_start" ] ; then
				sed -i -e 's|^Session=.*|Session=enlightenment.desktop|' ${conf}
			fi
			if [ -e "$1/usr/bin/startkde" ] ; then
				sed -i -e 's|^Session=.*|Session=plasma.desktop|' ${conf}
			fi
		;;
		'lxdm')
			local conf=$1/etc/lxdm/lxdm.conf
			if [ -e "$1/usr/bin/openbox-session" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/openbox-session|' ${conf}
			fi
			if [ -e "$1/usr/bin/startxfce4" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/startxfce4|' ${conf}
			fi
			if [ -e "$1/usr/bin/cinnamon-session" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/cinnamon-session|' ${conf}
			fi
			if [ -e "$1/usr/bin/mate-session" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/mate-session|' ${conf}
			fi
			if [ -e "$1/usr/bin/enlightenment_start" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/enlightenment_start|' ${conf}
			fi
			if [ -e "$1/usr/bin/startlxde" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/lxsession|' ${conf}
			fi
			if [ -e "$1/usr/bin/lxqt-session" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/lxqt-session|' ${conf}
			fi
			if [ -e "$1/usr/bin/pekwm" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/pekwm|' ${conf}
			fi
			if [ -e "$1/usr/bin/i3" ] ; then
				sed -i -e 's|^.*session=.*|session=/usr/bin/i3|' ${conf}
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
