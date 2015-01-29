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
    if [[ -f $1/usr/bin/openrc ]];then
	local _hostname='hostname="'${hostname}'"'
	sed -i -e "s|^.*hostname=.*|${_hostname}|" $1/etc/conf.d/hostname
    else
	echo ${hostname} > $1/etc/hostname
    fi
}

# $1: chroot
configure_plymouth(){
    if [ -e $1/etc/plymouth/plymouthd.conf ] ; then
	msg2 "Setting plymouth $plymouth_theme ...."
	sed -i -e "s/^.*Theme=.*/Theme=$plymouth_theme/" $1/etc/plymouth/plymouthd.conf
    fi
}

configure_services_live(){
   if [[ -f ${work_dir}/root-image/usr/bin/openrc ]];then
      msg2 "Congiguring OpenRC ...."
      for svc in ${start_openrc_live[@]}; do
	  if [[ -f $1/etc/init.d/$svc ]]; then
	      msg2 "Setting $svc ..."
	      [[ ! -d  $1/etc/runlevels/{boot,default} ]] && mkdir -p $1/etc/runlevels/{boot,default}
	      chroot $1 rc-update add $svc default &> /dev/null
	  fi
      done
   else
      msg2 "Congiguring SystemD ...."
      for svc in ${start_systemd_live[@]}; do
	  msg2 "Setting $svc ..."
	  chroot $1 systemctl enable $svc &> /dev/null
      done
   fi
}

configure_services(){
   if [[ -f ${work_dir}/root-image/usr/bin/openrc ]];then
      msg2 "Congiguring OpenRC ...."
      for svc in ${start_openrc[@]}; do
	  if [[ -f $1/etc/init.d/$svc ]]; then
	      msg2 "Setting $svc ..."
	      [[ ! -d  $1/etc/runlevels/{boot,default} ]] && mkdir -p $1/etc/runlevels/{boot,default}
	      chroot $1 rc-update add $svc default &> /dev/null
	  fi
      done
   else
      msg2 "Congiguring SystemD ...."
      for svc in ${start_systemd[@]}; do
	  msg2 "Setting $svc ..."
	  chroot $1 systemctl enable $svc &> /dev/null
      done
   fi
}

# $1: chroot
# $2: user
configure_accountsservice(){
    msg2 "Configuring AcooutsService ..."
    if [ -d "$1/var/lib/AccountsService/users" ] ; then
	echo "[User]" > $1/var/lib/AccountsService/users/$2
	if [ -e "$1/usr/bin/openbox-session" ] ; then
	    echo "XSession=openbox" >> $1/var/lib/AccountsService/users/$2
	fi
	if [ -e "$1/usr/bin/startxfce4" ] ; then
	    echo "XSession=xfce" >> $1/var/lib/AccountsService/users/$2
	fi
	if [ -e "$1/usr/bin/cinnamon-session" ] ; then
	    echo "XSession=cinnamon" >> $1/var/lib/AccountsService/users/$2
	fi
	if [ -e "$1/usr/bin/mate-session" ] ; then
	    echo "XSession=mate" >> $1/var/lib/AccountsService/users/$2
	fi
	if [ -e "$1/usr/bin/enlightenment_start" ] ; then
	    echo "XSession=enlightenment" >> $1/var/lib/AccountsService/users/$2
	fi
	if [ -e "$1/usr/bin/startlxde" ] ; then
	    echo "XSession=LXDE" >> $1/var/lib/AccountsService/users/$2
	fi
	if [ -e "$1/usr/bin/lxqt-session" ] ; then
	    echo "XSession=LXQt" >> $1/var/lib/AccountsService/users/$2
	fi
	echo "Icon=/var/lib/AccountsService/icons/$2.png" >> $1/var/lib/AccountsService/users/$2
    fi
}

# $1: chroot
configure_hosts(){
      sed -e "s|localhost.localdomain|localhost.localdomain ${hostname}|" -i $1/etc/hosts
}

# $1: chroot
configure_displaymanager(){

    msg2 "Configuring Displaymanager ..."

    case ${displaymanager} in
	'lightdm')
	    chroot $1 groupadd -r autologin
	    if [ -e "$1/usr/bin/openbox-session" ] ; then
		  sed -i -e 's/^.*user-session=.*/user-session=openbox/' $1/etc/lightdm/lightdm.conf
	    fi
	    if [ -e "$1/usr/bin/startxfce4" ] ; then
	      sed -i -e 's/^.*user-session=.*/user-session=xfce/' $1/etc/lightdm/lightdm.conf
	    fi
	    if [ -e "$1/usr/bin/cinnamon-session" ] ; then
		  sed -i -e 's/^.*user-session=.*/user-session=cinnamon/' $1/etc/lightdm/lightdm.conf
	    fi
	    if [ -e "$1/usr/bin/mate-session" ] ; then
		  sed -i -e 's/^.*user-session=.*/user-session=mate/' $1/etc/lightdm/lightdm.conf
	    fi
	    if [ -e "$1/usr/bin/enlightenment_start" ] ; then
		  sed -i -e 's/^.*user-session=.*/user-session=enlightenment/' $1/etc/lightdm/lightdm.conf
	    fi
	    if [ -e "$1/usr/bin/startlxde" ] ; then
		  sed -i -e 's/^.*user-session=.*/user-session=LXDE/' $1/etc/lightdm/lightdm.conf
	    fi
	    if [ -e "$1/usr/bin/lxqt-session" ] ; then
		  sed -i -e 's/^.*user-session=.*/user-session=lxqt/' $1/etc/lightdm/lightdm.conf
	    fi
	    if [ -e "$1/usr/bin/pekwm" ] ; then
		  sed -i -e 's/^.*user-session=.*/user-session=pekwm/' $1/etc/lightdm/lightdm.conf
	    fi
	    if [ -e "$1/usr/bin/i3" ] ; then
		  sed -i -e 's/^.*user-session=.*/user-session=i3/' $1/etc/lightdm/lightdm.conf
	    fi
	;;
	'gdm')
	    configure_accountsservice $1 "gdm"
	;;
	'mdm')
	    if [ -e "$1/usr/bin/startxfce4" ] ; then
		sed -i 's|default.desktop|xfce.desktop|g' $1/etc/mdm/custom.conf
	    fi
	    if [ -e "$1/usr/bin/cinnamon-session" ] ; then
		sed -i 's|default.desktop|cinnamon.desktop|g' $1/etc/mdm/custom.conf
	    fi
	    if [ -e "$1/usr/bin/openbox-session" ] ; then
		sed -i 's|default.desktop|openbox.desktop|g' $1/etc/mdm/custom.conf
	    fi
	    if [ -e "$1/usr/bin/mate-session" ] ; then
		sed -i 's|default.desktop|mate.desktop|g' $1/etc/mdm/custom.conf
	    fi
	    if [ -e "$1/usr/bin/startlxde" ] ; then
		sed -i 's|default.desktop|LXDE.desktop|g' $1/etc/mdm/custom.conf
	    fi
	    if [ -e "$1/usr/bin/lxqt-session" ] ; then
		sed -i 's|default.desktop|lxqt.desktop|g' $1/etc/mdm/custom.conf
	    fi
	    if [ -e "$1/usr/bin/enlightenment_start" ] ; then
		sed -i 's|default.desktop|enlightenment.desktop|g' $1/etc/mdm/custom.conf
	    fi
	;;
	'sddm')
	    if [ -e "$1/usr/bin/startxfce4" ] ; then
		sed -i -e 's|^Session=.*|Session=xfce.desktop|' $1/etc/sddm.conf
	    fi
	    if [ -e "$1/usr/bin/cinnamon-session" ] ; then
		sed -i -e 's|^Session=.*|Session=cinnamon.desktop|' $1/etc/sddm.conf
	    fi
	    if [ -e "$1/usr/bin/openbox-session" ] ; then
		sed -i -e 's|^Session=.*|Session=openbox.desktop|' $1/etc/sddm.conf
	    fi
	    if [ -e "$1/usr/bin/mate-session" ] ; then
		sed -i -e 's|^Session=.*|Session=mate.desktop|' $1/etc/sddm.conf
	    fi
	    if [ -e "$1/usr/bin/lxsession" ] ; then
		sed -i -e 's|^Session=.*|Session=LXDE.desktop|' $1/etc/sddm.conf
	    fi
	    if [ -e "$1/usr/bin/lxqt-session" ] ; then
		sed -i -e 's|^Session=.*|Session=lxqt.desktop|' $1/etc/sddm.conf
	    fi
	    if [ -e "$1/usr/bin/enlightenment_start" ] ; then
		sed -i -e 's|^Session=.*|Session=enlightenment.desktop|' $1/etc/sddm.conf
	    fi
	    if [ -e "$1/usr/bin/startkde" ] ; then
		sed -i -e 's|^Session=.*|Session=plasma.desktop|' $1/etc/sddm.conf
	    fi
	;;
	'lxdm')
	    if [ -e "$1/usr/bin/openbox-session" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/openbox-session|' $1/etc/lxdm/lxdm.conf
	    fi
	    if [ -e "$1/usr/bin/startxfce4" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/startxfce4|' $1/etc/lxdm/lxdm.conf
	    fi
	    if [ -e "$1/usr/bin/cinnamon-session" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/cinnamon-session|' $1/etc/lxdm/lxdm.conf
	    fi
	    if [ -e "$1/usr/bin/mate-session" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/mate-session|' $1/etc/lxdm/lxdm.conf
	    fi
	    if [ -e "$1/usr/bin/enlightenment_start" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/enlightenment_start|' $1/etc/lxdm/lxdm.conf
	    fi
	    if [ -e "$1/usr/bin/startlxde" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/lxsession|' $1/etc/lxdm/lxdm.conf
	    fi
	    if [ -e "$1/usr/bin/lxqt-session" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/lxqt-session|' $1/etc/lxdm/lxdm.conf
	    fi
	    if [ -e "$1/usr/bin/pekwm" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/pekwm|' $1/etc/lxdm/lxdm.conf
	    fi
	    if [ -e "$1/usr/bin/i3" ] ; then
		sed -i -e 's|^.*session=.*|session=/usr/bin/i3|' $1/etc/lxdm/lxdm.conf
	    fi
	;;
	*)
	    break
	;;
    esac

    if [[ ${initsys} == 'openrc' ]];then
	local conf='DISPLAYMANAGER="'${displaymanager}'"'
	sed -i -e "s|^.*DISPLAYMANAGER=.*|${conf}|" $1/etc/conf.d/xdm
	[[ ! -d  $1/etc/runlevels/default ]] && mkdir -p $1/etc/runlevels/default
	chroot $1 rc-update add xdm default &> /dev/null
    else
	if [[ -f $1/etc/plymouth/plymouthd.conf ]] ; then
	    chroot $1 systemctl enable ${displaymanager}-plymouth &> /dev/null
	else
	    chroot $1 systemctl enable ${displaymanager} &> /dev/null
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
