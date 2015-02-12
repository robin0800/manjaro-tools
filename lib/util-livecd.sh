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

# this util-livecd.sh gets copied to overlay-image/opt/livecd

check_ping(){
    echo $(LC_ALL=C ping -c 1 www.manjaro.org | grep "1 received")
}

configure_machine_id_live(){
# set unique machine-id
    echo "Setting machine-id ..." >> /tmp/livecd.log
    dbus-uuidgen --ensure=/etc/machine-id
    ln -sf /etc/machine-id /var/lib/dbus/machine-id
}

configure_translation_pkgs_live(){
    # Determind which language we are using
    local LNG_INST=$(cat $1/etc/locale.conf | grep LANG= | cut -d= -f2 | cut -d. -f1)

    [ -n "$LNG_INST" ] || LNG_INST="en"
    case "$LNG_INST" in
	be_BY)
	      #Belarusian
	      FIREFOX_LNG_INST="firefox-i18n-be"
	      THUNDER_LNG_INST="thunderbird-i18n-be"
	      LIBRE_LNG_INST="libreoffice-be"
	      HUNSPELL_LNG_INST=""
	      KDE_LNG_INST=""
	      ;;
	bg_BG)
	      #Bulgarian
	      FIREFOX_LNG_INST="firefox-i18n-bg"
	      THUNDER_LNG_INST="thunderbird-i18n-bg"
	      LIBRE_LNG_INST="libreoffice-bg"
	      HUNSPELL_LNG_INST=""
	      KDE_LNG_INST="kde-l10n-bg"
	      ;;
	de*)
	      #German
	      FIREFOX_LNG_INST="firefox-i18n-de"
	      THUNDER_LNG_INST="thunderbird-i18n-de"
	      LIBRE_LNG_INST="libreoffice-de"
	      HUNSPELL_LNG_INST="hunspell-de"
	      KDE_LNG_INST="kde-l10n-de"
	      ;;
	en*)
	      #English (disabled libreoffice-en-US)
	      FIREFOX_LNG_INST=""
	      THUNDER_LNG_INST=""
	      LIBRE_LNG_INST=""
	      HUNSPELL_LNG_INST="hunspell-en"
	      KDE_LNG_INST=""
	      ;;
	en_GB)
	      #British English
	      FIREFOX_LNG_INST="firefox-i18n-en-gb"
	      THUNDER_LNG_INST="thunderbird-i18n-en-gb"
	      LIBRE_LNG_INST="libreoffice-en-GB"
	      HUNSPELL_LNG_INST="hunspell-en"
	      KDE_LNG_INST=""
	      ;;
	es*)
	      #Espanol
	      FIREFOX_LNG_INST="firefox-i18n-es-es"
	      THUNDER_LNG_INST="thunderbird-i18n-es-es"
	      LIBRE_LNG_INST="libreoffice-es"
	      HUNSPELL_LNG_INST="hunspell-es"
	      KDE_LNG_INST="kde-l10n-es"
	      ;;
	es_AR)
	      #Espanol (Argentina)
	      FIREFOX_LNG_INST="firefox-i18n-es-ar"
	      THUNDER_LNG_INST="thunderbird-i18n-es-ar"
	      LIBRE_LNG_INST="libreoffice-es"
	      HUNSPELL_LNG_INST="hunspell-es"
	      KDE_LNG_INST="kde-l10n-es"
	      ;;
	fr*)
	      #Francais
	      FIREFOX_LNG_INST="firefox-i18n-fr"
	      THUNDER_LNG_INST="thunderbird-i18n-fr"
	      LIBRE_LNG_INST="libreoffice-fr"
	      HUNSPELL_LNG_INST="hunspell-fr"
	      KDE_LNG_INST="kde-l10n-fr"
	      ;;
	it*)
	      #Italian
	      FIREFOX_LNG_INST="firefox-i18n-it"
	      THUNDER_LNG_INST="thunderbird-i18n-it"
	      LIBRE_LNG_INST="libreoffice-it"
	      HUNSPELL_LNG_INST="hunspell-it"
	      KDE_LNG_INST="kde-l10n-it"
	      ;;
	pl_PL)
	      #Polish
	      FIREFOX_LNG_INST="firefox-i18n-pl"
	      THUNDER_LNG_INST="thunderbird-i18n-pl"
	      LIBRE_LNG_INST="libreoffice-pl"
	      HUNSPELL_LNG_INST="hunspell-pl"
	      KDE_LNG_INST="kde-l10n-pl"
	      ;;
	pt_BR)
	      #Brazilian Portuguese
	      FIREFOX_LNG_INST="firefox-i18n-pt-br"
	      THUNDER_LNG_INST="thunderbird-i18n-pt-br"
	      LIBRE_LNG_INST="libreoffice-pt-BR"
	      HUNSPELL_LNG_INST=""
	      KDE_LNG_INST="kde-l10n-pt_br"
	      ;;
	pt_PT)
	      #Portuguese
	      FIREFOX_LNG_INST="firefox-i18n-pt-pt"
	      THUNDER_LNG_INST="thunderbird-i18n-pt-pt"
	      LIBRE_LNG_INST="libreoffice-pt"
	      HUNSPELL_LNG_INST=""
	      KDE_LNG_INST="kde-l10n-pt"
	      ;;
	ro_RO)
	      #Romanian
	      FIREFOX_LNG_INST="firefox-i18n-ro"
	      THUNDER_LNG_INST="thunderbird-i18n-ro"
	      LIBRE_LNG_INST="libreoffice-ro"
	      HUNSPELL_LNG_INST="hunspell-ro"
	      KDE_LNG_INST="kde-l10n-ro"
	      ;;
	ru*)
	      #Russian
	      FIREFOX_LNG_INST="firefox-i18n-ru"
	      THUNDER_LNG_INST="thunderbird-i18n-ru"
	      LIBRE_LNG_INST="libreoffice-ru"
	      HUNSPELL_LNG_INST=""
	      KDE_LNG_INST="kde-l10n-ru"
	      ;;
	sv*)
	      #Swedish
	      FIREFOX_LNG_INST="firefox-i18n-sv-se"
	      THUNDER_LNG_INST="thunderbird-i18n-sv-se"
	      LIBRE_LNG_INST="libreoffice-sv"
	      HUNSPELL_LNG_INST=""
	      KDE_LNG_INST="kde-l10n-sv"
	      ;;
	tr*)
	      #Turkish
	      FIREFOX_LNG_INST="firefox-i18n-tr"
	      THUNDER_LNG_INST="thunderbird-i18n-tr"
	      LIBRE_LNG_INST="libreoffice-tr"
	      HUNSPELL_LNG_INST=""
	      KDE_LNG_INST="kde-l10n-tr"
	      ;;
	uk_UA)
	      #Ukrainian
	      FIREFOX_LNG_INST="firefox-i18n-uk"
	      THUNDER_LNG_INST="thunderbird-i18n-uk"
	      LIBRE_LNG_INST="libreoffice-uk"
	      HUNSPELL_LNG_INST=""
	      KDE_LNG_INST="kde-l10n-uk"
	      ;;
    esac
}

install_localization_live(){
    if [ -e "/bootmnt/${install_dir}/${arch}/lng-image.sqfs" ] ; then
      echo "install translation packages" >> /tmp/livecd.log
      configure_translation_pkgs_live
      ${PACMAN_LNG} -Sy
      if [ -e "/bootmnt/${install_dir}/${arch}/kde-image.sqfs" ] ; then
	  ${PACMAN_LNG} -S ${KDE_LNG_INST} &> /dev/null
      fi
      if [ -e "/usr/bin/firefox" ] ; then
	  ${PACMAN_LNG} -S ${FIREFOX_LNG_INST} &> /dev/null
      fi
      if [ -e "/usr/bin/thunderbird" ] ; then
	  ${PACMAN_LNG} -S ${THUNDER_LNG_INST} &> /dev/null
      fi
      if [ -e "/usr/bin/libreoffice" ] ; then
	  ${PACMAN_LNG} -S ${LIBRE_LNG_INST} &> /dev/null
      fi
      if [ -e "/usr/bin/hunspell" ] ; then
	  ${PACMAN_LNG} -S ${HUNSPELL_LNG_INST} &> /dev/null
      fi
    fi
}

configure_swap_live(){
    local swapdev="$(fdisk -l 2>/dev/null | grep swap | cut -d' ' -f1)"
    if [ -e "${swapdev}" ]; then
	swapon ${swapdev}
	echo "${swapdev} swap swap defaults 0 0 #configured by manjaro-tools" >>/etc/fstab
    fi
}

# TODO: review sudoers
configure_sudo_live(){
    chown root:root /etc/sudoers
    sed -i -e 's|# %wheel ALL=(ALL) ALL|%wheel ALL=(ALL) ALL|g' /etc/sudoers
    sed -e 's|# root ALL=(ALL) ALL|root ALL=(ALL) ALL|' -i /etc/sudoers
    echo "${username} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    chmod 440 /etc/sudoers
}

configure_env_live(){
    echo "BROWSER=/usr/bin/xdg-open" >> /etc/environment
    echo "BROWSER=/usr/bin/xdg-open" >> /etc/skel/.bashrc
    echo "BROWSER=/usr/bin/xdg-open" >> /etc/profile

    # add TERM var

    if [ -e "/usr/bin/mate-session" ] ; then
	echo "TERM=mate-terminal" >> /etc/environment
	echo "TERM=mate-terminal" >> /etc/profile
    fi

    ## FIXME - Workaround to launch mate-terminal
    if [ -e "/usr/bin/mate-session" ] ; then
	sed -i -e "s~^.*Exec=.*~Exec=mate-terminal -e 'sudo setup'~" "/etc/skel/Desktop/installer-launcher-cli.desktop"
	sed -i -e "s~^.*Terminal=.*~Terminal=false~" "/etc/skel/Desktop/installer-launcher-cli.desktop"
    fi

    ## FIXME - Workaround to match theme with QT5
#     cmd=$(echo "QT_STYLE_OVERRIDE=gtk" >> /etc/environment)
#     if [ -e "/bootmnt/${install_dir}/${arch}/xfce-image.sqfs" ] ; then
# 	$cmd
#     elif [ -e "/bootmnt/${install_dir}/${arch}/gnome-image.sqfs" ] ; then
# 	$cmd
#     elif [ -e "/bootmnt/${install_dir}/${arch}/cinnamon-image.sqfs" ] ; then
# 	$cmd
#     elif [ -e "/bootmnt/${install_dir}/${arch}/openbox-image.sqfs" ] ; then
# 	$cmd
#     elif [ -e "/bootmnt/${install_dir}/${arch}/mate-image.sqfs" ] ; then
# 	$cmd
#     elif [ -e "/bootmnt/${install_dir}/${arch}/lxde-image.sqfs" ] ; then
# 	$cmd
#     elif [ -e "/bootmnt/${install_dir}/${arch}/enlightenment-image.sqfs" ] ; then
# 	$cmd
#     elif [ -e "/bootmnt/${install_dir}/${arch}/pekwm-image.sqfs" ] ; then
# 	$cmd
#     fi
    if [[ -f "/bootmnt/${install_dir}/${arch}/${custom}-image.sqfs" ]]; then
        case ${custom} in
            gnome|xfce|openbox|enlightenment|cinnamon|pekwm|lxde|mate)
                echo "QT_STYLE_OVERRIDE=gtk" >> /etc/environment
            ;;
            *) break ;;
        esac
    fi
}

configure_user_root_live(){
    # set up root password
    echo "root:${password}" | chroot $1 chpasswd
}

configure_alsa_live(){
    echo "configure alsa" >> /tmp/livecd.log
    # amixer binary
    local alsa_amixer="chroot $1 /usr/bin/amixer"

    # enable all known (tm) outputs
    $alsa_amixer -c 0 sset "Master" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Front" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Side" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Surround" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Center" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "LFE" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Headphone" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Speaker" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "PCM" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Line" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "External" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "FM" 50% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Master Mono" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Master Digital" 70% unmute &>/dev/null
    $alsa_amixer -c 0 sset "Analog Mix" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Aux" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Aux2" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM Center" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM Front" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM LFE" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM Side" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM Surround" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Playback" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "PCM,1" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "DAC" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "DAC,0" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "DAC,0" -12dB &> /dev/null
    $alsa_amixer -c 0 sset "DAC,1" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "DAC,1" -12dB &> /dev/null
    $alsa_amixer -c 0 sset "Synth" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "CD" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Wave" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Music" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "AC97" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "Analog Front" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "VIA DXS,0" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "VIA DXS,1" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "VIA DXS,2" 70% unmute &> /dev/null
    $alsa_amixer -c 0 sset "VIA DXS,3" 70% unmute &> /dev/null

    # set input levels
    $alsa_amixer -c 0 sset "Mic" 70% mute &>/dev/null
    $alsa_amixer -c 0 sset "IEC958" 70% mute &>/dev/null

    # special stuff
    $alsa_amixer -c 0 sset "Master Playback Switch" on &>/dev/null
    $alsa_amixer -c 0 sset "Master Surround" on &>/dev/null
    $alsa_amixer -c 0 sset "SB Live Analog/Digital Output Jack" off &>/dev/null
    $alsa_amixer -c 0 sset "Audigy Analog/Digital Output Jack" off &>/dev/null
}

configure_displaymanager_live(){
    if [[ -f /usr/bin/lightdm ]];then
	gpasswd -a ${username} autologin &> /dev/null
	sed -i -e 's/^.*autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
	sed -i -e "s/^.*autologin-user=.*/autologin-user=${username}/" /etc/lightdm/lightdm.conf
    elif [[ -f /usr/bin/kdm ]];then
	sed -i -e "s/^.*AutoLoginUser=.*/AutoLoginUser=${username}/" /usr/share/config/kdm/kdmrc
	sed -i -e "s/^.*AutoLoginPass=.*/AutoLoginPass=${password}/" /usr/share/config/kdm/kdmrc
	xdg-icon-resource forceupdate --theme hicolor &> /dev/null
	[[ -e "/usr/bin/update-desktop-database" ]] && update-desktop-database -q
    elif [[ -f /usr/bin/sddm ]];then
	sed -i -e "s|^User=.*|User=${username}|" /etc/sddm.conf
    elif [[ -f /usr/bin/lxdm ]];then
	sed -i -e "s/^.*autologin=.*/autologin=${username}/" /etc/lxdm/lxdm.conf
    fi
}
