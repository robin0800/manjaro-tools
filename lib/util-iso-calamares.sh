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

write_calamares_dm_conf(){
    # write the conf to livecd-image/etc/calamares ?
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
    local conf="$1/usr/share/calamares/modules/initcpio.conf"
    if [ ! -e $conf ] ; then
        echo "---" > "$conf"
        echo "kernel: ${manjaro_kernel}" >> "$conf"
    else
        sed -e "s|_kernel_|$manjaro_kernel|g" -i "$conf"
    fi

}

configure_installer () {
    sed -i "s|_root-image_|/bootmnt/${install_dir}/${arch}/root-image.sqfs|g" $1
    sed -i "s|_desktop-image_|/bootmnt/${install_dir}/${arch}/${custom}-image.sqfs|g" $1
    echo "QT_STYLE_OVERRIDE=gtk" >> /etc/environment
}

configure_calamares(){
    if [[ -f $1/usr/bin/calamares ]];then
	msg2 "Configuring Calamares ..."
	mkdir -p $1/etc/calamares/modules
	local conf="$1/usr/share/calamares/modules/unpackfs.conf"
	if [ ! -e $conf ] ; then
	    echo "---" > "$conf"
	    echo "unpack:" >> "$conf"
	    echo "    -   source: \"/bootmnt/${install_dir}/${arch}/root-image.sqfs\"" >> "$conf"
	    echo "        sourcefs: \"squashfs\"" >> "$conf"
	    echo "        destination: \"\"" >> "$conf"
	    echo "    -   source: \"/bootmnt/${install_dir}/${arch}/${custom}-image.sqfs\"" >> "$conf"
	    echo "        sourcefs: \"squashfs\"" >> "$conf"
	    echo "        destination: \"\"" >> "$conf"
        else
            configure_installer "$conf"
	fi

	write_calamares_dm_conf $1
	write_calamares_initcpio_conf $1
        [[ "${initsys}" -eq "openrc" ]] && write_calamares_machineid_conf $1

	mkdir -p $1/home/${username}/Desktop
	cp $1/usr/share/applications/calamares.desktop $1/home/${username}/Desktop/calamares.desktop
	chmod a+x $1/home/${username}/Desktop/calamares.desktop
    fi
}

configure_thus(){
    if [[ -f $1/usr/bin/thus ]];then
        msg2 "Configuring Thus ..."
	local conf="$1/etc/thus.conf"
	local rel=$(cat $1/etc/lsb-release | grep DISTRIB_RELEASE | cut -d= -f2)
	sed -i "s|_version_|$rel|g" $conf
	sed -i "s|_kernel_|$manjaro_kernel|g" $conf
	configure_installer "$conf"
	mkdir -p $1/home/${username}/Desktop
	cp $1/usr/share/applications/thus.desktop $1/home/${username}/Desktop/thus.desktop
	chmod a+x $1/home/${username}/Desktop/thus.desktop
    fi
}
