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
	if [ ${initsys} == 'openrc' ];then
            write_calamares_machineid_conf $1
	fi
    fi
}
