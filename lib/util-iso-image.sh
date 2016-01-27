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

copy_overlay(){
	msg2 "Copying ${1##*/} ..."
	if [[ -L $1 ]];then
		cp -a --no-preserve=ownership $1/* $2
	else
		cp -LR $1/* $2
	fi
}

copy_startup_scripts(){
	msg2 "Copying startup scripts ..."
	cp ${DATADIR}/scripts/livecd $1
	cp ${DATADIR}/scripts/mhwd-live $1
	chmod +x $1/livecd
	chmod +x $1/mhwd-live
}

write_profile_conf_entries(){
	local conf=$1/profile.conf
	echo '' >> ${conf}
	echo '# custom image name' >> ${conf}
	echo "custom=${custom}" >> ${conf}
	echo '' >> ${conf}
	echo '# iso_name' >> ${conf}
	echo "iso_name=${iso_name}" >> ${conf}
}

copy_livecd_helpers(){
	msg2 "Copying livecd helpers ..."
	[[ ! -d $1 ]] && mkdir -p $1
	cp ${LIBDIR}/util-live.sh $1
	cp ${LIBDIR}/util-msg.sh $1
	cp ${LIBDIR}/util.sh $1
	cp ${DATADIR}/scripts/kbd-model-map $1

	cp ${profile_conf} $1

	write_profile_conf_entries $1
}

copy_cache_mhwd(){
	msg2 "Copying mhwd package cache ..."
	rsync -v --files-from="$1/cache-packages.txt" /var/cache/pacman/pkg "$1/opt/livecd/pkgs"
}

gen_pw(){
	echo $(perl -e 'print crypt($ARGV[0], "password")' ${password})
}

# $1: chroot
configure_user(){
	# set up user and password
	msg2 "Creating user: ${username} password: ${password} ..."
	if [[ -n ${password} ]];then
		chroot $1 useradd -m -G ${addgroups} -p $(gen_pw) ${username}
	else
		chroot $1 useradd -m -G ${addgroups} ${username}
	fi
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
	if ${plymouth_boot};then
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
		;;
	esac
}

# $1: chroot
configure_lsb(){
	[[ -f $1/boot/grub/grub.cfg ]] && rm $1/boot/grub/grub.cfg
	if [ -e $1/etc/lsb-release ] ; then
		msg2 "Configuring lsb-release"
		sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${dist_release}/" $1/etc/lsb-release
		sed -i -e "s/^.*DISTRIB_CODENAME.*/DISTRIB_CODENAME=${dist_codename}/" $1/etc/lsb-release
	fi
}

configure_services(){
	case ${initsys} in
		'openrc')
			msg3 "Configuring [${initsys}] ...."
			for svc in ${start_openrc[@]}; do
				msg2 "Setting $svc ..."
				chroot $1 rc-update add $svc default &> /dev/null
			done
			msg3 "Done configuring [${initsys}]"
		;;
		'systemd')
			msg3 "Configuring [${initsys}] ...."
			for svc in ${start_systemd[@]}; do
				msg2 "Setting $svc ..."
				chroot $1 systemctl enable $svc &> /dev/null
			done
			sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' $1/etc/systemd/logind.conf
			sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' $1/etc/systemd/logind.conf
			msg3 "Done configuring [${initsys}]"
		;;
		*)
			msg3 "Unsupported: [${initsys}]!"
		;;
	esac
}

# $1: chroot
configure_environment(){
	case ${custom} in
		cinnamon|gnome|i3|lxde|mate|netbook|openbox|pantheon|xfce|xfce-minimal)
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

load_desktop_map(){
	local _space="s| ||g" _clean=':a;N;$!ba;s/\n/ /g' _com_rm="s|#.*||g" \
		file=${DATADIR}/desktop.map
        msg3 "Loading [$file] ..."
	local desktop_map=$(sed "$_com_rm" "$file" \
			| sed "$_space" \
			| sed "$_clean")
        echo ${desktop_map}
}

detect_desktop_env(){
	local xs=$1/usr/share/xsessions ex=$1/usr/bin key val map=( $(load_desktop_map) )
	if [[ "${default_desktop_executable}" == "none" ]] || \
		[[ ${default_desktop_file} == "none" ]]; then
		msg2 "Trying to detect desktop environment ..."
		for item in "${map[@]}";do
			key=${item%:*}
			val=${item#*:}
			if [[ -f $xs/$key.desktop ]] && [[ -f $ex/$val ]];then
				default_desktop_file="$key"
				default_desktop_executable="$val"
			fi
		done
	fi
	msg2 "Detected: ${default_desktop_file}"
}

configure_mhwd(){
	if [[ ${arch} == "x86_64" ]];then
		if ! ${multilib};then
			msg2 "Disable mhwd lib32 support"
			echo 'MHWD64_IS_LIB32="false"' > $1/etc/mhwd-x86_64.conf
		fi
	fi
}

# $1: chroot
configure_displaymanager(){
	msg2 "Configuring Displaymanager ..."
	# Try to detect desktop environment
	detect_desktop_env "$1"
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
				sed -i -e 's/pam_systemd.so/pam_ck_connector.so nox11/' $1/etc/pam.d/lightdm-greeter
			fi
			local greeters=$(ls $1/etc/lightdm/*greeter.conf) name
			for g in ${greeters[@]};do
				name=${g##*/}
				name=${name%%.*}
				case ${name} in
					'lightdm-deepin-greeter'|'lightdm-kde-greeter')
						sed -i -e "s/^.*greeter-session=.*/greeter-session=${name}/" ${conf}
					;;
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
		*)
			msg3 "Unsupported: [${displaymanager}]!"
		;;
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
configure_mhwd_drivers(){
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
		if [[ $(basename "${image}") != "mhwd-image" ]];then
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

configure_sysctl(){
	if [[ ${initsys} == 'openrc' ]];then
		msg2 "Configuring sysctl for openrc"
		touch $1/etc/sysctl.conf
		local conf=$1/etc/sysctl.d/100-manjaro.conf
		echo '# Virtual memory setting (swap file or partition)' > ${conf}
		echo 'vm.swappiness = 30' >> ${conf}
		echo '# Enable the SysRq key' >> ${conf}
		echo 'kernel.sysrq = 1' >> ${conf}
	fi
}

configure_time(){
    if [[ ${initsys} == 'openrc' ]];then
        rm $1/etc/runlevels/boot/hwclock
    fi
}

# $1: chroot
configure_systemd_live(){
	if [[ ${initsys} == 'systemd' ]];then
		msg2 "Configuring systemd for livecd"
		sed -i 's/#\(Storage=\)auto/\1volatile/' $1/etc/systemd/journald.conf
		sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' $1/etc/systemd/logind.conf
		sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' $1/etc/systemd/logind.conf
		sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' $1/etc/systemd/logind.conf
		# Prevent some services to be started in the livecd
		echo 'File created by manjaro-tools. See systemd-update-done.service(8).' \
		     | tee "${path}/etc/.updated" >"${path}/var/.updated"
	fi
}

# Remove pamac auto-update when the network is up, it locks de pacman db when booting in the livecd
# $1: chroot
configure_pamac_live() {
	rm -f $1/etc/NetworkManager/dispatcher.d/99_update_pamac_tray
}

configure_root_image(){
	msg "Configuring [root-image]"
	configure_lsb "$1"
	configure_mhwd "$1"
	configure_sysctl "$1"
	configure_time "$1"
	msg "Done configuring [root-image]"
}

configure_custom_image(){
	msg "Configuring [${custom}-image]"
	configure_plymouth "$1"
	configure_displaymanager "$1"
	configure_services "$1"
	configure_environment "$1"
	msg "Done configuring [${custom}-image]"
}

configure_live_image(){
	msg "Configuring [live-image]"
	configure_hostname "$1"
	configure_hosts "$1"
	configure_accountsservice "$1" "${username}"
	configure_user "$1"
	configure_services_live "$1"
	configure_systemd_live "$1"
	configure_calamares "$1"
	configure_thus "$1"
	configure_pamac_live "$1"
	msg "Done configuring [live-image]"
}

make_repo(){
	repo-add $1/opt/livecd/pkgs/gfx-pkgs.db.tar.gz $1/opt/livecd/pkgs/*pkg*z
}

# $1: work dir
# $2: pkglist
download_to_cache(){
	chroot-run \
		  -r "${mountargs_ro}" \
		  -w "${mountargs_rw}" \
		  -B "${build_mirror}/${branch}" \
		  "$1" \
		  pacman -v -Syw $2 --noconfirm || return 1
	chroot-run \
		  -r "${mountargs_ro}" \
		  -w "${mountargs_rw}" \
		  -B "${build_mirror}/${branch}" \
		  "$1" \
		  pacman -v -Sp $2 --noconfirm > "$1"/cache-packages.txt
	sed -ni '/.pkg.tar.xz/p' "$1"/cache-packages.txt
	sed -i "s/.*\///" "$1"/cache-packages.txt
}

# $1: image path
# $2: packages
chroot_create(){
	[[ "$1" == "${work_dir}/root-image" ]] && local flag="-L"
	setarch "${arch}" \
		mkchroot ${mkchroot_args[*]} ${flag} $@
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
