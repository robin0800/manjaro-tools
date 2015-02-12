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
        echo '    mandatory: true' >> "$conf"
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
    echo "kernel: ${manjaro_kernel}" >> "$conf"
}

write_calamares_unpack_conf(){
    local conf="$1/etc/calamares/modules/unpackfs.conf"

    echo "---" > "$conf"
    echo "unpack:" >> "$conf"
    echo "    -   source: \"/bootmnt/${install_dir}/${arch}/root-image.sqfs\"" >> "$conf"
    echo "        sourcefs: \"squashfs\"" >> "$conf"
    echo "        destination: \"\"" >> "$conf"
    echo "    -   source: \"/bootmnt/${install_dir}/${arch}/${custom}-image.sqfs\"" >> "$conf"
    echo "        sourcefs: \"squashfs\"" >> "$conf"
    echo "        destination: \"\"" >> "$conf"
}

configure_calamares(){
    if [[ -f $1/usr/bin/calamares ]];then
	msg2 "Configuring Calamares ..."

	mkdir -p $1/etc/calamares/modules

        write_calamares_unpack_conf $1

	write_calamares_dm_conf $1
	write_calamares_initcpio_conf $1

        if [[ ${initsys} == 'openrc' ]];then
            write_calamares_machineid_conf $1
            write_calamares_finished_conf $1
        fi

        write_calamares_services_conf $1

	mkdir -p $1/home/${username}/Desktop

	cp $1/usr/share/applications/calamares.desktop $1/home/${username}/Desktop/calamares.desktop
	chmod a+x $1/home/${username}/Desktop/calamares.desktop
#         chown ${username}:users $1/home/${username}/Desktop/calamares.desktop
	echo "QT_STYLE_OVERRIDE=gtk" >> $1/etc/environment
    fi
}

configure_thus(){
    if [[ -f $1/usr/bin/thus ]];then
        msg2 "Configuring Thus ..."
	local conf="$1/etc/thus.conf"
	local rel=$(cat $1/etc/lsb-release | grep DISTRIB_RELEASE | cut -d= -f2)
	sed -i "s|_version_|$rel|g" $conf
	sed -i "s|_kernel_|$manjaro_kernel|g" $conf
	
	sed -i "s|_root-image_|/bootmnt/${install_dir}/${arch}/root-image.sqfs|g" $conf
	sed -i "s|_desktop-image_|/bootmnt/${install_dir}/${arch}/${custom}-image.sqfs|g" $conf
	echo "QT_STYLE_OVERRIDE=gtk" >> $1/etc/environment

	mkdir -p $1/home/${username}/Desktop

	cp $1/usr/share/applications/thus.desktop $1/home/${username}/Desktop/thus.desktop
	chmod a+x $1/home/${username}/Desktop/thus.desktop
# 	chown ${username}:users $1/home/${username}/Desktop/thus.desktop
    fi
}
