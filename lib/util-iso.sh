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
configure_machine_id(){
# set unique machine-id
    msg2 "Setting machine-id ..."
    chroot $1 dbus-uuidgen --ensure=/etc/machine-id
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
	    sed -i -e "s/^.*Theme=.*/Theme=$plymouth_theme/" $1/etc/plymouth/plymouthd.conf
    fi
}

configure_services_live(){
   if [[ -f ${work_dir}/root-image/usr/bin/openrc ]];then
      msg2 "Congiguring OpenRC ...."
      for svc in ${start_openrc_live[@]}; do
	  if [[ -f $1/etc/init.d/$svc ]]; then
	      msg2 "Setting $svc ..."
	      [[ ! -d  $1/etc/runlevels/default ]] && mkdir -p $1/etc/runlevels/default
	      ln -sf /etc/init.d/$svc $1/etc/runlevels/default/$svc
	  fi
      done
   else
      msg2 "Congiguring SystemD ...."
      for svc in ${start_systemd_live[@]}; do
# 	  if [[ -f $1/usr/lib/systemd/system/$svc ]];then
	      msg2 "Setting $svc ..."
	      chroot $1 systemctl enable $svc &> /dev/null
# 	  fi
      done
   fi
}

configure_services(){
   if [[ -f ${work_dir}/root-image/usr/bin/openrc ]];then
      msg2 "Congiguring OpenRC ...."
      for svc in ${start_openrc[@]}; do
	  if [[ -f $1/etc/init.d/$svc ]]; then
	      msg2 "Setting $svc ..."
	      [[ ! -d  $1/etc/runlevels/default ]] && mkdir -p $1/etc/runlevels/default
	      ln -sf /etc/init.d/$svc $1/etc/runlevels/default/$svc
	  fi
      done
   else
      msg2 "Congiguring SystemD ...."
      for svc in ${start_systemd[@]}; do
# 	  if [[ -f $1/usr/lib/systemd/system/$svc ]];then
	      msg2 "Setting $svc ..."
	      chroot $1 systemctl enable $svc &> /dev/null
# 	 fi
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
	;;
	'kdm')
	    sed -i -e "s/^.*AutoLoginUser=.*/AutoLoginUser=${username}/" $1/usr/share/config/kdm/kdmrc
	    sed -i -e "s/^.*AutoLoginPass=.*/AutoLoginPass=${password}/" $1/usr/share/config/kdm/kdmrc
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
	    sed -i -e "s|^User=.*|User=${username}|" $1/etc/sddm.conf
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
	    sed -i -e "s/^.*autologin=.*/autologin=${username}/" $1/etc/lxdm/lxdm.conf
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
	;;
	*) 
	    msg2 "No displaymanager used"
	    break
	;;
    esac
    
    if [ ${initsys} == 'openrc' ];then
	local _conf_xdm='DISPLAYMANAGER="'${displaymanager}'"'
	sed -i -e "s|^.*DISPLAYMANAGER=.*|${_conf_xdm}|" $1/etc/conf.d/xdm
	[[ ! -d  $1/etc/runlevels/default ]] && mkdir -p $1/etc/runlevels/default
	ln -sf /etc/init.d/xdm $1/etc/runlevels/default/xdm
    else
	if [ -e $1/etc/plymouth/plymouthd.conf ] ; then
	    displaymanager=${displaymanager}-plymouth
	fi
	chroot $1 systemctl enable ${displaymanager} &> /dev/null
    fi
    
    msg2 "Configured: ${displaymanager}"
    
}

write_calamares_dm_conf(){
    # write the conf to overlay-image/etc/calamares ?
    local cdm="$1/etc/calamares/modules/displaymanager.conf"
    
    echo "displaymanagers:" > "$cdm"
    echo "  - ${displaymanager}" >> "$cdm"
    echo '' >> "$cdm"
    echo '#executable: "startkde"' >> "$cdm"
    echo '#desktopFile: "plasma"' >> "$cdm"
    echo '' >> "$cdm"
    echo "basicSetup: false" >> "$cdm"
}

write_calamares_initcpio_conf(){
	local INITCPIO="$1/usr/share/calamares/modules/initcpio.conf"
	if [ ! -e $INITCPIO ] ; then
	    echo "---" > "$INITCPIO"
	    echo "kernel: ${manjaro_kernel}" >> "$INITCPIO"
	fi  
}

# $1: chroot
configure_calamares(){
    if [[ -f $1/usr/bin/calamares ]];then
	msg2 "Configuring Calamares ..."
	mkdir -p $1/etc/calamares/modules            
	local UNPACKFS="$1/usr/share/calamares/modules/unpackfs.conf"            
	if [ ! -e $UNPACKFS ] ; then                              
	    echo "---" > "$UNPACKFS"
	    echo "unpack:" >> "$UNPACKFS"
	    echo "    -   source: \"/bootmnt/${install_dir}/${arch}/root-image.sqfs\"" >> "$UNPACKFS"
	    echo "        sourcefs: \"squashfs\"" >> "$UNPACKFS"
	    echo "        destination: \"\"" >> "$UNPACKFS"
	    echo "    -   source: \"/bootmnt/${install_dir}/${arch}/${desktop}-image.sqfs\"" >> "$UNPACKFS"
	    echo "        sourcefs: \"squashfs\"" >> "$UNPACKFS"
	    echo "        destination: \"\"" >> "$UNPACKFS"                
	fi
	
	write_calamares_dm_conf $1
	write_calamares_initcpio_conf $1
    fi
}

copy_initcpio(){
    cp /usr/lib/initcpio/hooks/miso* ${work_dir}/boot-image/usr/lib/initcpio/hooks
    cp /usr/lib/initcpio/install/miso* ${work_dir}/boot-image/usr/lib/initcpio/install
    cp mkinitcpio.conf ${work_dir}/boot-image/etc/mkinitcpio-${manjaroiso}.conf
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
	    msg2 "Custom overlay-livecd found ..."
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
    cp ${cache_lng}/* ${work_dir}/lng-image/opt/livecd/lng
}

copy_cache_pkgs(){
    msg2 "Copying pkgs cache ..."
    cp ${cache_pkgs}/* ${work_dir}/pkgs-image/opt/livecd/pkgs
}

prepare_buildiso(){
    mkdir -p "${target_dir}"
    mkdir -p "${cache_pkgs}"
    mkdir -p "${cache_lng}"
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

# $1: chroot
configure_livecd_image(){
    msg2 "Configuring [$1]"
    
    configure_displaymanager "$1"
    
    configure_accountsservice "$1" "${username}"
    
    configure_user "$1"
    
    configure_calamares "$1"
    
    ${auto_svc_conf} && configure_services_live "$1"
    
    configure_machine_id "$1"
    
    configure_hostname "$1"
    
    configure_hosts "$1"
    
    configure_plymouth "$1"
    
    msg2 "Done configuring [$1]"
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
    
    mkiso ${iso_args[*]} iso "${work_dir}" "${iso_file}"
    chown -R "${iso_owner}:users" "${target_dir}"
    msg "Done [Build ISO]"
}

# $1: new branch
aufs_mount_root_image(){
    msg2 "mount root-image"
    mount -t aufs -o br=$1:${work_dir}/root-image=ro none $1
}

# $1: del branch
aufs_remove_image(){
    if mountpoint -q $1;then
	mount -o remount,mod:$1=ro ${work_dir}/root-image
	mount -o remount,del:$1 ${work_dir}/root-image
    fi
}

# $1: add branch
aufs_append_de_image(){
    msg2 "mount ${desktop}-image"
    mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none $1
}

# Base installation (root-image)
make_root_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
    
	msg "Prepare [Base installation] (root-image)"
	
	mkiso ${create_args[*]} -p "${packages}" -i "root-image" create "${work_dir}" || die "Please check you Packages file! Exiting." 
	
	pacman -Qr "${work_dir}/root-image" > "${work_dir}/root-image/root-image-pkgs.txt"
		
# 	cp ${work_dir}/root-image/etc/locale.gen.bak ${work_dir}/root-image/etc/locale.gen
	
	if [ -e ${work_dir}/root-image/boot/grub/grub.cfg ] ; then
	    rm ${work_dir}/root-image/boot/grub/grub.cfg
	fi
# 	if [ -e ${work_dir}/root-image/etc/plymouth/plymouthd.conf ] ; then
# 	    sed -i -e "s/^.*Theme=.*/Theme=$plymouth_theme/" ${work_dir}/root-image/etc/plymouth/plymouthd.conf
# 	fi
	if [ -e ${work_dir}/root-image/etc/lsb-release ] ; then
	    sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${iso_version}/" ${work_dir}/root-image/etc/lsb-release
	fi
	
	copy_overlay_root "${work_dir}/root-image"
	
	# Clean up GnuPG keys
	rm -rf "${work_dir}/root-image/etc/pacman.d/gnupg"
		
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [Base installation] (root-image)"
    fi
}

make_de_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [${desktop} installation] (${desktop}-image)"
	
	mkdir -p ${work_dir}/${desktop}-image
	
	if [[ -n "$(mount -l | grep ${desktop}-image)" ]]; then
	    umount -l ${work_dir}/${desktop}-image
	fi
	
	aufs_mount_root_image "${work_dir}/${desktop}-image"

	mkiso ${create_args[*]} -i "${desktop}-image" -p "${packages_de}" create "${work_dir}" || die "Please check you Packages-${desktop} file! Exiting."

	pacman -Qr "${work_dir}/${desktop}-image" > "${work_dir}/${desktop}-image/${desktop}-image-pkgs.txt"
	
	cp "${work_dir}/${desktop}-image/${desktop}-image-pkgs.txt" ${target_dir}/${img_name}-${desktop}-${iso_version}-${arch}-pkgs.txt
	
	[[ -d ${desktop}-overlay ]] && copy_overlay_desktop
	
	${auto_svc_conf} && configure_services "${work_dir}/${desktop}-image"
	
	# Clean up GnuPG keys
	rm -rf "${work_dir}/${desktop}-image/etc/pacman.d/gnupg"
	
# 	sleep 10
	
	umount -l ${work_dir}/${desktop}-image
	
	rm -R ${work_dir}/${desktop}-image/.wh*
	
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [${desktop} installation] (${desktop}-image)"
    fi
}

make_livecd_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [livecd-image]"
	
	mkdir -p ${work_dir}/livecd-image
	
	if [ -n "$(mount -l | grep livecd-image)" ]; then
	    umount -l ${work_dir}/livecd-image
	fi
	
	aufs_mount_root_image "${work_dir}/livecd-image"
	
	if [ -n "${desktop}" ] ; then
	    aufs_append_de_image "${work_dir}/livecd-image"
	fi
	
	mkiso ${create_args[*]} -i "livecd-image" -p "${livecd_packages}" create "${work_dir}" || die "Please check you Packages-Livecd file! Exiting."

	pacman -Qr "${work_dir}/livecd-image" > "${work_dir}/livecd-image/livecd-image-pkgs.txt"
	
	copy_overlay_livecd "${work_dir}/livecd-image"
	
	configure_livecd_image "${work_dir}/livecd-image"

        # copy over setup helpers and config loader
        copy_livecd_helpers "${work_dir}/livecd-image/opt/livecd"
        
        copy_startup_scripts "${work_dir}/livecd-image/usr/bin"
        
        cp ${work_dir}/root-image/etc/pacman.d/mirrorlist ${work_dir}/livecd-image/etc/pacman.d/mirrorlist
        sed -i "s/#Server/Server/g" ${work_dir}/livecd-image/etc/pacman.d/mirrorlist
       	
	# Clean up GnuPG keys?
	rm -rf "${work_dir}/livecd-image/etc/pacman.d/gnupg"
	
	umount -l ${work_dir}/livecd-image
	
	rm -R ${work_dir}/livecd-image/.wh*
	
        : > ${work_dir}/build.${FUNCNAME}
	msg "Done [livecd-image]"
    fi
}

configure_xorg_drivers(){
	# Disable Catalyst if not present
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep catalyst-utils 2> /dev/null)" ]; then
	    msg2 "Disabling Catalyst driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/catalyst/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/catalyst/MHWDCONFIG
	fi
	
	# Disable Nvidia if not present
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep nvidia-utils 2> /dev/null)" ]; then
	    msg2 "Disabling Nvidia driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia/MHWDCONFIG
	fi
	
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep nvidia-utils 2> /dev/null)" ]; then
	    msg2 "Disabling Nvidia Bumblebee driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/hybrid-intel-nvidia-bumblebee/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/hybrid-intel-nvidia-bumblebee/MHWDCONFIG
	fi
	
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep nvidia-304xx-utils 2> /dev/null)" ]; then
	    msg2 "Disabling Nvidia 304xx driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia-304xx/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia-304xx/MHWDCONFIG
	fi
	
	if  [ -z "$(ls ${work_dir}/pkgs-image/opt/livecd/pkgs/ | grep nvidia-340xx-utils 2> /dev/null)" ]; then
	    msg2 "Disabling Nvidia 340xx driver"
	    mkdir -p ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia-340xx/
	    touch ${work_dir}/pkgs-image/var/lib/mhwd/db/pci/graphic_drivers/nvidia-340xx/MHWDCONFIG
	fi
}

make_pkgs_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [pkgs-image]"
	
	mkdir -p ${work_dir}/pkgs-image/opt/livecd/pkgs
	
	if [[ -n "$(mount -l | grep pkgs-image)" ]]; then
	    umount -l ${work_dir}/pkgs-image
	fi

	aufs_mount_root_image "${work_dir}/pkgs-image"
	
	if [[ -n "${desktop}" ]] ; then
	    aufs_append_de_image "${work_dir}/pkgs-image"
	fi
	
	download_to_cache "${work_dir}/pkgs-image" "${cache_pkgs}" "${packages_xorg}"
	copy_cache_pkgs	
	
	if [[ -n "${packages_xorg_cleanup}" ]]; then
	    for xorg_clean in ${packages_xorg_cleanup}; do  
		rm ${work_dir}/pkgs-image/opt/livecd/pkgs/${xorg_clean}
	    done
	fi
	
	cp pacman-gfx.conf ${work_dir}/pkgs-image/opt/livecd
	rm -r ${work_dir}/pkgs-image/var
	
	make_repo "${work_dir}/pkgs-image/opt/livecd/pkgs/gfx-pkgs" "${work_dir}/pkgs-image/opt/livecd/pkgs"
	
	configure_xorg_drivers
	
	umount -l ${work_dir}/pkgs-image
	
	rm -R ${work_dir}/pkgs-image/.wh*
	
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [pkgs-image]"
    fi
}

make_lng_image() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
	msg "Prepare [lng-image]"
	mkdir -p ${work_dir}/lng-image/opt/livecd/lng
	
	if [[ -n "$(mount -l | grep lng-image)" ]]; then
	    umount -l ${work_dir}/lng-image
	fi
	
	aufs_mount_root_image "${work_dir}/lng-image"
	
	if [[ -n "${desktop}" ]] ; then
	    aufs_append_de_image "${work_dir}/lng-image"
	fi

	if [[ -n ${packages_lng_kde} ]]; then
	    download_to_cache "${work_dir}/lng-image" "${cache_lng}" "${packages_lng} ${packages_lng_kde}"
	    copy_cache_lng
	else
	    download_to_cache "${work_dir}/lng-image" "${cache_lng}" "${packages_lng}"
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
	
	umount -l ${work_dir}/lng-image
	
	rm -R ${work_dir}/lng-image/.wh*
	
	: > ${work_dir}/build.${FUNCNAME}
	msg "Done [lng-image]"
    fi
}

gen_boot_img(){
	local _kernver=$(cat ${work_dir}/boot-image/usr/lib/modules/*-MANJARO/version)
        chroot-run ${work_dir}/boot-image \
		  /usr/bin/mkinitcpio -k ${_kernver} \
		  -c /etc/mkinitcpio-${manjaroiso}.conf \
		  -g /boot/${img_name}.img
}

# Prepare ${install_dir}/boot/
make_boot() {
    if [[ ! -e ${work_dir}/build.${FUNCNAME} ]]; then
    
	msg "Prepare [${install_dir}/boot]"
	mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
        
        cp ${work_dir}/root-image/boot/memtest86+/memtest.bin ${work_dir}/iso/${install_dir}/boot/${arch}/memtest
	
	cp ${work_dir}/root-image/boot/vmlinuz* ${work_dir}/iso/${install_dir}/boot/${arch}/${manjaroiso}
        mkdir -p ${work_dir}/boot-image
        
        if [ ! -z "$(mount -l | grep boot-image)" ]; then
           umount -l ${work_dir}/boot-image/{proc,sys,dev}
           umount ${work_dir}/boot-image
        fi
        
        msg2 "mount root-image"
        mount -t aufs -o br=${work_dir}/boot-image:${work_dir}/root-image=ro none ${work_dir}/boot-image
        
        if [ ! -z "${desktop}" ] ; then
             msg2 "mount ${desktop}-image"
             mount -t aufs -o remount,append:${work_dir}/${desktop}-image=ro none ${work_dir}/boot-image
        fi
        
        copy_initcpio
        
        gen_boot_img
        
        mv ${work_dir}/boot-image/boot/${img_name}.img ${work_dir}/iso/${install_dir}/boot/${arch}/${img_name}.img
        cp ${work_dir}/boot-image/boot/intel-ucode.img ${work_dir}/iso/${install_dir}/boot/intel_ucode.img
        cp ${work_dir}/boot-image/usr/share/licenses/intel-ucode/LICENSE ${work_dir}/iso/${install_dir}/boot/intel_ucode.LICENSE
                
        umount ${work_dir}/boot-image
        
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

load_desktop_definition(){
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
    if [ -e Packages-Custom ] ; then
    	pkgsfile="Packages-Custom"
    fi
    desktop=${pkgsfile#*-}
    desktop=${desktop,,}
}

get_pkglist_xorg(){
    if [ "${arch}" == "i686" ]; then
	packages_xorg=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni||g" | sed "s|>nonfree_x64.*||g" | sed "s|>nonfree_uni||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	packages_free=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g" | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni||g" | sed "s|>nonfree_x64.*||g" | sed "s|>nonfree_uni.*||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	packages_nonfree=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g" | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni.*||g" | sed "s|>nonfree_x64.*||g" | sed "s|>nonfree_uni||g" | sed "s|^.*catalyst-legacy.*||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	packages_xorg=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>free_x64||g" | sed "s|>free_uni||g" | sed "s|>nonfree_uni||g" | sed "s|>nonfree_x64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	packages_free=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g" | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>free_x64||g" | sed "s|>free_uni||g" | sed "s|>nonfree_uni.*||g" | sed "s|>nonfree_x64.*||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
	packages_nonfree=$(sed "s|#.*||g" Packages-Xorg | sed "s| ||g" | sed "s|>dvd.*||g" | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>free_x64.*||g" | sed "s|>free_uni.*||g" | sed "s|>nonfree_uni||g" | sed "s|>nonfree_x64||g" | sed "s|^.*catalyst-legacy.*||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
    packages_xorg_cleanup=$(sed "s|#.*||g" Packages-Xorg | grep cleanup | sed "s|>cleanup||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
}

get_pkglist_lng(){
    if [ "${arch}" == "i686" ]; then
	packages_lng=$(sed "s|#.*||g" Packages-Lng | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|>kde.*||g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	packages_lng=$(sed "s|#.*||g" Packages-Lng | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>cleanup.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|>kde.*||g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
    packages_lng_cleanup=$(sed "s|#.*||g" Packages-Lng | grep cleanup | sed "s|>cleanup||g")
    packages_lng_kde=$(sed "s|#.*||g" Packages-Lng | grep kde | sed "s|>kde||g" | sed ':a;N;$!ba;s/\n/ /g')
}

get_pkglist_de(){
    if [ "${arch}" == "i686" ]; then
	packages_de=$(sed "s|#.*||g" "${pkgsfile}" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	packages_de=$(sed "s|#.*||g" "${pkgsfile}" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
}

get_pkglist(){
    if [ "${arch}" == "i686" ]; then
	packages=$(sed "s|#.*||g" Packages | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	packages=$(sed "s|#.*||g" Packages | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
}

get_pkglist_livecd(){
    if [ "${arch}" == "i686" ]; then
	livecd_packages=$(sed "s|#.*||g" "Packages-Livecd" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>x86_64.*||g" | sed "s|>i686||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    elif [ "${arch}" == "x86_64" ]; then
	livecd_packages=$(sed "s|#.*||g" "Packages-Livecd" | sed "s| ||g" | sed "s|>dvd.*||g"  | sed "s|>blacklist.*||g" | sed "s|>i686.*||g" | sed "s|>x86_64||g" | sed "s|KERNEL|$manjaro_kernel|g" | sed ':a;N;$!ba;s/\n/ /g')
    fi
}

load_packages(){
    get_pkglist

    if [ -e Packages-Xorg ] ; then
	get_pkglist_xorg
    fi

    if [ -e Packages-Lng ] ; then
	get_pkglist_lng
    fi

    if [ -e "${pkgsfile}" ] ; then
	get_pkglist_de
    fi

    if [[ -f Packages-Livecd ]]; then
	get_pkglist_livecd
    fi
}

compress_images(){
    # install common
    make_boot
    if [ "${arch}" == "x86_64" ]; then
	make_efi
	make_efiboot
    fi
    make_isolinux

    make_isomounts
    make_iso
}

make_images(){
    # install basic
    make_root_image

    # install DE(s)
    if [ -e "${pkgsfile}" ] ; then
	make_de_image
    fi

    # install xorg-drivers
    if [ -e Packages-Xorg ] ; then
	make_pkgs_image
    fi
    
    # install translations
    if [ -e Packages-Lng ] ; then
	make_lng_image
    fi
    
    # install overlay
    if [[ -f Packages-Livecd ]]; then
	make_livecd_image
    fi
}
