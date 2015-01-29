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
    local _conf="$1/etc/calamares/modules/machineid.conf"
    
    echo "systemd: false" > $_conf
    echo "dbus: true" >> $_conf
    echo "symlink: false" >> $_conf
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

configure_installer () {
    cmd=$(echo "QT_STYLE_OVERRIDE=gtk" >> /etc/environment)
    if [ -e "$1" ] ; then
	sed -i "s|_root-image_|/bootmnt/${install_dir}/_ARCH_/root-image.sqfs|g" $1

	if [ -e "/bootmnt/${install_dir}/${arch}/xfce-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/xfce-image.sqfs|g" $1
	    $cmd
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/gnome-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/gnome-image.sqfs|g" $1
	    $cmd
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/cinnamon-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/cinnamon-image.sqfs|g" $1
	    $cmd
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/openbox-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/openbox-image.sqfs|g" $1
	    $cmd
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/mate-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/mate-image.sqfs|g" $1
	    $cmd
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/kde-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/kde-image.sqfs|g" $1
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/lxde-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/lxde-image.sqfs|g" $1
	    $cmd
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/lxqt-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/lxqt-image.sqfs|g" $1
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/enlightenment-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/enlightenment-image.sqfs|g" $1
	    $cmd
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/pekwm-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/pekwm-image.sqfs|g" $1
	    $cmd
	fi
	if [ -e "/bootmnt/${install_dir}/${arch}/custom-image.sqfs" ] ; then
	    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/_ARCH_/custom-image.sqfs|g" $1
	fi
	if [ "${arch}" == "i686" ] ; then
	    sed -i "s|_ARCH_|i686|g" $1
	else
	    sed -i "s|_ARCH_|x86_64|g" $1
	fi
    fi
}

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
        [[ "${initsys}" == "openrc" ]] && write_calamares_machineid_conf $1
        
        configure_installer "$UNPACKFS"
	mkdir -p $1/home/${username}/Desktop
	cp $1/usr/share/applications/calamares.desktop $1/home/${username}/Desktop/calamares.desktop
	chmod a+x $1/home/${username}/Desktop/calamares.desktop
    fi
}

configure_thus(){
    if [[ -f $1/usr/bin/thus ]];then
        msg2 "Configuring Thus ..."
	local conf_file="$1/etc/thus.conf"
	local rel=$(cat $1/etc/lsb-release | grep DISTRIB_RELEASE | cut -d= -f2)
	sed -i "s|_version_|$rel|g" $conf_file
	sed -i "s|_kernel_|$manjaro_kernel|g" $conf_file
	configure_installer "$conf_file"
	mkdir -p $1/home/${username}/Desktop
	cp $1/usr/share/applications/thus.desktop $1/home/${username}/Desktop/thus.desktop
	chmod a+x $1/home/${username}/Desktop/thus.desktop
    fi
}
