#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

copy_overlay(){
    if [[ -e $1 ]]; then
        msg2 "Copying [%s] ..." "${1##*/}"
        if [[ -L $1 ]]; then
            cp -a --no-preserve=ownership $1/* $2
        else
            cp -LR $1/* $2
        fi
    fi
}

add_svc_rc(){
    if [[ -f $1/etc/init.d/$2 ]]; then
        msg2 "Setting %s ..." "$2"
        chroot $1 rc-update add $2 default &>/dev/null
    fi
}

add_svc_sd(){
    if [[ -f $1/etc/systemd/system/$2.service ]] || \
    [[ -f $1/usr/lib/systemd/system/$2.service ]]; then
        msg2 "Setting %s ..." "$2"
        chroot $1 systemctl enable $2 &>/dev/null
    fi
    if [[ -f $1/etc/systemd/system/$2 ]] || \
    [[ -f $1/usr/lib/systemd/system/$2 ]]; then
        msg2 "Setting %s ..." "$2"
        chroot $1 systemctl enable $2 &>/dev/null
    fi
}

set_xdm(){
    if [[ -f $1/etc/conf.d/xdm ]]; then
        local conf='DISPLAYMANAGER="'${displaymanager}'"'
        sed -i -e "s|^.*DISPLAYMANAGER=.*|${conf}|" $1/etc/conf.d/xdm
    fi
}

configure_mhwd_drivers(){
    local path=$1${mhwd_repo}/ \
        drv_path=$1/var/lib/mhwd/db/pci/graphic_drivers
    info "Configuring mhwd db ..."
    if  [ -z "$(ls $path | grep nvidia-390xx-utils 2> /dev/null)" ]; then
        msg2 "Disabling Nvidia 390xx driver"
        mkdir -p $drv_path/nvidia-390xx/
        echo "" > $drv_path/nvidia-390xx/MHWDCONFIG
        msg2 "Disabling Nvidia 390xx Bumblebee driver"
        mkdir -p $drv_path/hybrid-intel-nvidia-390xx-bumblebee/
        echo "" > $drv_path/hybrid-intel-nvidia-390xx-bumblebee/MHWDCONFIG
    fi
    if  [ -z "$(ls $path | grep nvidia-utils 2> /dev/null)" ]; then
        msg2 "Disabling Nvidia driver"
        mkdir -p $drv_path/nvidia/
        echo "" > $drv_path/nvidia/MHWDCONFIG
        msg2 "Disabling Nvidia AMD Prime driver"
        mkdir -p $drv_path/hybrid-amd-nvidia-prime/
        echo "" > $drv_path/hybrid-amd-nvidia-prime/MHWDCONFIG
        msg2 "Disabling Nvidia Intel Prime driver"
        mkdir -p $drv_path/hybrid-intel-nvidia-prime/
        echo "" > $drv_path/hybrid-intel-nvidia-prime/MHWDCONFIG  
    fi
    if  [ -z "$(ls $path | grep nvidia-470xx-utils 2> /dev/null)" ]; then
        msg2 "Disabling Nvidia 470xx driver"
        mkdir -p $drv_path/nvidia-470xx/
        echo "" > $drv_path/nvidia-470xx/MHWDCONFIG
        msg2 "Disabling Nvidia 470xx AMD Prime driver"
        mkdir -p $drv_path/hybrid-amd-nvidia-470xx-prime/
        echo "" > $drv_path/hybrid-amd-nvidia-470xx-prime/MHWDCONFIG
        msg2 "Disabling Nvidia 470xx Intel Prime driver"
        mkdir -p $drv_path/hybrid-intel-nvidia-470xx-prime/
        echo "" > $drv_path/hybrid-intel-nvidia-470xx-prime/MHWDCONFIG        
    fi
    local drv_path=$1/var/lib/mhwd/db/pci/network_drivers
    if  [ -z "$(ls $path | grep broadcom-wl 2> /dev/null)" ]; then
        msg2 "Disabling broadcom-wl driver"
        mkdir -p $drv_path/broadcom-wl/
        echo "" > $drv_path/broadcom-wl/MHWDCONFIG
    fi
    if  [ -z "$(ls $path | grep rt3562sta 2> /dev/null)" ]; then
        msg2 "Disabling rt3562sta driver"
        mkdir -p $drv_path/rt3562sta/
        echo "" > $drv_path/rt3562sta/MHWDCONFIG
    fi
    if  [ -z "$(ls $path | grep r8168 2> /dev/null)" ]; then
        msg2 "Disabling r8168 driver"
        mkdir -p $drv_path/r8168/
        echo "" > $drv_path/r8168/MHWDCONFIG
    fi
}

configure_lsb(){
    if [ -e $1/etc/lsb-release ] ; then
        msg2 "Configuring lsb-release"
        sed -i -e "s/^.*DISTRIB_RELEASE.*/DISTRIB_RELEASE=${dist_release}/" $1/etc/lsb-release
        sed -i -e "s/^.*DISTRIB_CODENAME.*/DISTRIB_CODENAME=${dist_codename}/" $1/etc/lsb-release
    fi
}

configure_branding_old(){
    msg2 "Configuring branding"
    echo "---
componentName:  manjaro

# This selects between different welcome texts. When false, uses
# the traditional 'Welcome to the %1 installer.', and when true,
# uses 'Welcome to the Calamares installer for %1.'. This allows
# to distinguish this installer from other installers for the
# same distribution.
welcomeStyleCalamares:   ${welcomestyle}

# Should the welcome image (productWelcome, below) be scaled
# up beyond its natural size? If false, the image does not grow
# with the window but remains the same size throughout (this
# may have surprising effects on HiDPI monitors).
welcomeExpandingLogo:   ${welcomelogo}

# Size and expansion policy for Calamares.
#  - "normal" or unset, expand as needed, use *windowSize*
#  - "fullscreen", start as large as possible, ignore *windowSize*
#  - "noexpand", never expand, use *windowSize*
windowExpanding:    ${windowexp}

# Size of Calamares window, expressed as w,h. Both w and h
# may be either pixels (suffix px) or font-units (suffix em).
#   e.g.    "800px,600px"
#           "60em,480px"
# This setting is ignored if "fullscreen" is selected for
# *windowExpanding*, above. If not set, use constants defined
# in CalamaresUtilsGui, 800x520.
windowSize: ${windowsize}

# Placement of Calamares window. Either "center" or "free".
# Whether "center" actually works does depend on the window
# manager in use (and only makes sense if you're not using
# *windowExpanding* set to "fullscreen").
windowPlacement: ${windowplacement}

# These are strings shown to the user in the user interface.
# There is no provision for translating them -- since they
# are names, the string is included as-is.
#
# The four Url strings are the Urls used by the buttons in
# the welcome screen, and are not shown to the user. Clicking
# on the "Support" button, for instance, opens the link supportUrl.
# If a Url is empty, the corresponding button is not shown.
#
# bootloaderEntryName is how this installation / distro is named
# in the boot loader (e.g. in the GRUB menu).
strings:
    productName:         ${dist_name} Linux
    shortProductName:    ${dist_name}
    version:             ${dist_release}
    shortVersion:        ${dist_release}
    versionedName:       ${dist_name} Linux ${dist_release} "\"${dist_codename}"\"
    shortVersionedName:  ${dist_name} ${dist_release}
    bootloaderEntryName: ${dist_name}

# These images are loaded from the branding module directory.
#
# productIcon is used as the window icon, and will (usually) be used
#       by the window manager to represent the application. This image
#       should be square, and may be displayed by the window manager
#       as small as 16x16 (but possibly larger).
# productLogo is used as the logo at the top of the left-hand column
#       which shows the steps to be taken. The image should be square,
#       and is displayed at 80x80 pixels (also on HiDPI).
# productWelcome is shown on the welcome page of the application in
#       the middle of the window, below the welcome text. It can be
#       any size and proportion, and will be scaled to fit inside
#       the window. Use 'welcomeExpandingLogo' to make it non-scaled.
#       Recommended size is 320x150.
images:
    productLogo:         "logo.png"
    productIcon:         "logo.png"
    productWelcome:      "languages.png"

# The slideshow is displayed during execution steps (e.g. when the
# installer is actually writing to disk and doing other slow things).
slideshow:               "show.qml"

# There are two available APIs for the slideshow:
#  - 1 (the default) loads the entire slideshow when the installation-
#      slideshow page is shown and starts the QML then. The QML
#      is never stopped (after installation is done, times etc.
#      continue to fire).
#  - 2 loads the slideshow on startup and calls onActivate() and
#      onLeave() in the root object. After the installation is done,
#      the show is stopped (first by calling onLeave(), then destroying
#      the QML components).
slideshowAPI: 1

# Colors for text and background components.
#
#  - sidebarBackground is the background of the sidebar
#  - sidebarText is the (foreground) text color
#  - sidebarTextHighlight sets the background of the selected (current) step.
#    Optional, and defaults to the application palette.
#  - sidebarSelect is the text color of the selected step.
#
style:
   sidebarBackground:    "\"${sidebarbackground}"\"
   sidebarText:          "\"${sidebartext}"\"
   sidebarTextSelect:    "\"${sidebartextselect}"\"
   sidebarTextHighlight: "\"${sidebartexthighlight}"\"" > $1/usr/share/calamares/branding/manjaro/branding.desc
}

configure_branding(){
    msg2 "Configuring branding"
    echo "# SPDX-FileCopyrightText: no
# SPDX-License-Identifier: CC0-1.0
#
# Product branding information. This influences some global
# user-visible aspects of Calamares, such as the product
# name, window behavior, and the slideshow during installation.
#
# Additional styling can be done using the stylesheet.qss
# file, also in the branding directory.
---
componentName:  manjaro


### WELCOME / OVERALL WORDING
#
# These settings affect some overall phrasing and looks,
# which are most visible in the welcome page.

# This selects between different welcome texts. When false, uses
# the traditional "Welcome to the %1 installer.", and when true,
# uses "Welcome to the Calamares installer for %1." This allows
# to distinguish this installer from other installers for the
# same distribution.
welcomeStyleCalamares:   ${welcomestyle}

# Should the welcome image (productWelcome, below) be scaled
# up beyond its natural size? If false, the image does not grow
# with the window but remains the same size throughout (this
# may have surprising effects on HiDPI monitors).
welcomeExpandingLogo:   ${welcomelogo}

### WINDOW CONFIGURATION
#
# The settings here affect the placement of the Calamares
# window through hints to the window manager and initial
# sizing of the Calamares window.

# Size and expansion policy for Calamares.
#  - "normal" or unset, expand as needed, use *windowSize*
#  - "fullscreen", start as large as possible, ignore *windowSize*
#  - "noexpand", don't expand automatically, use *windowSize*
windowExpanding:    ${windowexp}

# Size of Calamares window, expressed as w,h. Both w and h
# may be either pixels (suffix px) or font-units (suffix em).
#   e.g.    "800px,600px"
#           "60em,480px"
# This setting is ignored if "fullscreen" is selected for
# *windowExpanding*, above. If not set, use constants defined
# in CalamaresUtilsGui, 800x520.
windowSize: ${windowsize}

# Placement of Calamares window. Either "center" or "free".
# Whether "center" actually works does depend on the window
# manager in use (and only makes sense if you're not using
# *windowExpanding* set to "fullscreen").
windowPlacement: ${windowplacement}

### PANELS CONFIGURATION
#
# Calamares has a main content area, and two panels (navigation
# and progress / sidebar). The panels can be controlled individually,
# or switched off. If both panels are switched off, the layout of
# the main content area loses its margins, on the assumption that
# you're doing something special.

# Kind of sidebar (panel on the left, showing progress).
#  - "widget" or unset, use traditional sidebar (logo, items)
#  - "none", hide it entirely
#  - "qml", use calamares-sidebar.qml from branding folder
# In addition, you **may** specify a side, separated by a comma,
# from the kind. Valid sides are:
#  - "left" (if not specified, uses this)
#  - "right"
#  - "top"
#  - "bottom"
# For instance, "widget,right" is valid; so is "qml", which defaults
# to putting the sidebar on the left. Also valid is "qml,top".
# While "widget,top" is valid, the widgets code is **not** flexible
# and results will be terrible.
sidebar: qml

# Kind of navigation (button panel on the bottom).
#  - "widget" or unset, use traditional navigation
#  - "none", hide it entirely
#  - "qml", use calamares-navigation.qml from branding folder
# In addition, you **may** specify a side, separated by a comma,
# from the kind. The same sides are valid as for *sidebar*,
# except the default is *bottom*.
navigation: widget


### STRINGS, IMAGES AND COLORS
#
# This section contains the "branding proper" of names
# and images, rather than global-look settings.

# These are strings shown to the user in the user interface.
# There is no provision for translating them -- since they
# are names, the string is included as-is.
#
# The four Url strings are the Urls used by the buttons in
# the welcome screen, and are not shown to the user. Clicking
# on the "Support" button, for instance, opens the link supportUrl.
# If a Url is empty, the corresponding button is not shown.
#
# bootloaderEntryName is how this installation / distro is named
# in the boot loader (e.g. in the GRUB menu).
#
# These strings support substitution from /etc/os-release
# if KDE Frameworks 5.58 are available at build-time. When
# enabled, @{var-name} is replaced by the equivalent value
# from os-release. All the supported var-names are in all-caps,
# and are listed on the FreeDesktop.org site,
#       https://www.freedesktop.org/software/systemd/man/os-release.html
# Note that ANSI_COLOR and CPE_NAME don't make sense here, and
# are not supported (the rest are). Remember to quote the string
# if it contains substitutions, or you'll get YAML exceptions.
#
# The *Url* entries are used on the welcome page, and they
# are visible as buttons there if the corresponding *show* keys
# are set to "true" (they can also be overridden).
strings:
    productName:         ${dist_name} Linux
    shortProductName:    ${dist_name}
    version:             ${dist_release}
    shortVersion:        ${dist_release}
    versionedName:       ${dist_name} Linux ${dist_release} "\"${dist_codename}"\"
    shortVersionedName:  ${dist_name} ${dist_release}
    bootloaderEntryName: ${dist_name}


# These images are loaded from the branding module directory.
#
# productBanner is an optional image, which if present, will be shown
#       on the welcome page of the application, above the welcome text.
#       It is intended to have a width much greater than height.
#       It is displayed at 64px height (also on HiDPI).
#       Recommended size is 64px tall, and up to 460px wide.
# productIcon is used as the window icon, and will (usually) be used
#       by the window manager to represent the application. This image
#       should be square, and may be displayed by the window manager
#       as small as 16x16 (but possibly larger).
# productLogo is used as the logo at the top of the left-hand column
#       which shows the steps to be taken. The image should be square,
#       and is displayed at 80x80 pixels (also on HiDPI).
# productWallpaper is an optional image, which if present, will replace
#       the normal solid background on every page of the application.
#       It can be any size and proportion,
#       and will be tiled to fit the entire window.
#       For a non-tiled wallpaper, the size should be the same as
#       the overall window, see *windowSize* above (800x520).
# productWelcome is shown on the welcome page of the application in
#       the middle of the window, below the welcome text. It can be
#       any size and proportion, and will be scaled to fit inside
#       the window. Use `welcomeExpandingLogo` to make it non-scaled.
#       Recommended size is 320x150.
#
# These filenames can also use substitutions from os-release (see above).
images:
    # productBanner:       "banner.png"
    productIcon:         "logo_small.svg"
    productLogo:         "logo.svg"
    # productWallpaper:    "wallpaper.png"
    productWelcome:      "welcome/mascot.svg"

# Colors for text and background components.
#
#  - SidebarBackground is the background of the sidebar
#  - SidebarText is the (foreground) text color
#  - SidebarBackgroundCurrent sets the background of the current step.
#    Optional, and defaults to the application palette.
#  - SidebarTextCurrent is the text color of the current step.
#
# These colors can **also** be set through the stylesheet, if the
# branding component also ships a stylesheet.qss. Then they are
# the corresponding CSS attributes of #sidebarApp.
style:
   sidebarBackground:    "\"${sidebarbackground}"\"
   sidebarText:          "\"${sidebartext}"\"
   sidebarTextSelect:    "\"${sidebartextselect}"\"
   sidebarTextHighlight: "\"${sidebartexthighlight}"\"

### SLIDESHOW
#
# The slideshow is displayed during execution steps (e.g. when the
# installer is actually writing to disk and doing other slow things).

# The slideshow can be a QML file (recommended) which can display
# arbitrary things -- text, images, animations, or even play a game --
# during the execution step. The QML **is** abruptly stopped when the
# execution step is done, though, so maybe a game isn't a great idea.
#
# The slideshow can also be a sequence of images (not recommended unless
# you don't want QML at all in your Calamares). The images are displayed
# at a rate of 1 every 2 seconds during the execution step.
#
# To configure a QML file, list a single filename:
#   slideshow:               "show.qml"
# To configure images, like the filenames (here, as an inline list):
#   slideshow: [ "/etc/calamares/slideshow/0.png", "/etc/logo.png" ]
slideshow:               "slideshow/SlideShow.qml"

# There are two available APIs for a QML slideshow:
#  - 1 (the default) loads the entire slideshow when the installation-
#      slideshow page is shown and starts the QML then. The QML
#      is never stopped (after installation is done, times etc.
#      continue to fire).
#  - 2 loads the slideshow on startup and calls onActivate() and
#      onLeave() in the root object. After the installation is done,
#      the show is stopped (first by calling onLeave(), then destroying
#      the QML components).
#
# An image slideshow does not need to have the API defined.
slideshowAPI: 2


# These options are to customize online uploading of logs to pastebins:
#  - type      : Defines the kind of pastebin service to be used. Currently
#                it accepts two values:
#                - none    :    disables the pastebin functionality
#                - fiche   :    use fiche pastebin server
#  - url       : Defines the address of pastebin service to be used.
#                Takes string as input. Important bits are the host and port,
#                the scheme is not used.
#  - sizeLimit : Defines maximum size limit (in KiB) of log file to be pasted.
#                The option must be set, to have the log option work.
#                Takes integer as input. If < 0, no limit will be forced,
#                else only last (approximately) 'n' KiB of log file will be pasted.
#                Please note that upload size may be slightly over the limit (due
#                to last minute logging), so provide a suitable value.
uploadServer :
    type :    "fiche"
    url :     "http://termbin.com:9999"
    sizeLimit : -1" > $1/usr/share/calamares/branding/manjaro/branding.desc
}

configure_polkit_user_rules(){
    msg2 "Configuring polkit user rules"
    echo "/* Stop asking the user for a password while they are in a live session
 */
polkit.addRule(function(action, subject) {
    if (subject.user == \"${username}\")
    {
        return polkit.Result.YES;
    }
});" > $1/etc/polkit-1/rules.d/49-nopasswd-live.rules
}

configure_logind(){
    msg2 "Configuring logind ..."
    local conf=$1/etc/systemd/logind.conf
    sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' "$conf"
    sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' "$conf"
    sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' "$conf"
}

configure_journald(){
    msg2 "Configuring journald ..."
    local conf=$1/etc/systemd/journald.conf
    sed -i 's/#\(Storage=\)auto/\1volatile/' "$conf"
}

disable_srv_live(){
    for srv in ${disable_systemd_live[@]}; do
         enable_systemd_live=(${enable_systemd_live[@]//*$srv*})
    done
}

configure_services(){
    info "Configuring services"
    use_apparmor="false"
    apparmor_boot_args=""
    enable_systemd_live=(${enable_systemd_live[@]} ${enable_systemd[@]})

    [[ ! -z $disable_systemd_live ]] && disable_srv_live

    for svc in ${enable_systemd_live[@]}; do
        add_svc_sd "$1" "$svc"
        [[ "$svc" == "apparmor" ]] && use_apparmor="true"
    done

    if [[ ${use_apparmor} == 'true' ]]; then
        msg2 "Enable apparmor kernel parameters"
        apparmor_boot_args="'apparmor=1' 'security=apparmor'"
    fi

    info "Done configuring services"
}

write_live_session_conf(){
    local path=$1${SYSCONFDIR}
    [[ ! -d $path ]] && mkdir -p $path
    local conf=$path/live.conf
    msg2 "Writing %s" "${conf##*/}"
    echo '# live session configuration' > ${conf}
    echo '' >> ${conf}
    echo '# autologin' >> ${conf}
    echo "autologin=${autologin}" >> ${conf}
    echo '' >> ${conf}
    echo '# login shell' >> ${conf}
    echo "login_shell=${login_shell}" >> ${conf}
    echo '' >> ${conf}
    echo '# live username' >> ${conf}
    echo "username=${username}" >> ${conf}
    echo '' >> ${conf}
    echo '# live password' >> ${conf}
    echo "password=${password}" >> ${conf}
    echo '' >> ${conf}
    echo '# live group membership' >> ${conf}
    echo "addgroups='${addgroups}'" >> ${conf}
    if [[ -n ${smb_workgroup} ]]; then
        echo '' >> ${conf}
        echo '# samba workgroup' >> ${conf}
        echo "smb_workgroup=${smb_workgroup}" >> ${conf}
    fi
}

configure_hosts(){
    sed -e "s|localhost.localdomain|localhost.localdomain ${hostname}|" -i $1/etc/hosts
}

configure_system(){
    configure_logind "$1"
    configure_journald "$1"

    # Prevent some services to be started in the livecd
    echo 'File created by manjaro-tools. See systemd-update-done.service(8).' \
    | tee "${path}/etc/.updated" >"${path}/var/.updated"

    msg2 "Disable systemd-gpt-auto-generator"
    ln -sf /dev/null "${path}/usr/lib/systemd/system-generators/systemd-gpt-auto-generator"
    echo ${hostname} > $1/etc/hostname
}

configure_thus(){
    msg2 "Configuring Thus ..."
    source "$1/etc/mkinitcpio.d/${kernel}.preset"
    local conf="$1/etc/thus.conf"
    echo "[distribution]" > "$conf"
    echo "DISTRIBUTION_NAME = \"${dist_name} Linux\"" >> "$conf"
    echo "DISTRIBUTION_VERSION = \"${dist_release}\"" >> "$conf"
    echo "SHORT_NAME = \"${dist_name}\"" >> "$conf"
    echo "[install]" >> "$conf"
    echo "LIVE_MEDIA_SOURCE = \"/run/miso/bootmnt/${iso_name}/${target_arch}/rootfs.sfs\"" >> "$conf"
    echo "LIVE_MEDIA_DESKTOP = \"/run/miso/bootmnt/${iso_name}/${target_arch}/desktopfs.sfs\"" >> "$conf"
    echo "LIVE_MEDIA_TYPE = \"squashfs\"" >> "$conf"
    echo "LIVE_USER_NAME = \"${username}\"" >> "$conf"
    echo "KERNEL = \"${kernel}\"" >> "$conf"
    echo "VMLINUZ = \"$(echo ${ALL_kver} | sed s'|/boot/||')\"" >> "$conf"
    echo "INITRAMFS = \"$(echo ${default_image} | sed s'|/boot/||')\"" >> "$conf"
    echo "FALLBACK = \"$(echo ${fallback_image} | sed s'|/boot/||')\"" >> "$conf"

#    if [[ -f $1/usr/share/applications/thus.desktop && -f $1/usr/bin/kdesu ]]; then
#        sed -i -e 's|sudo|kdesu|g' $1/usr/share/applications/thus.desktop
#    fi
}

configure_live_image(){
    msg "Configuring [livefs]"
    configure_hosts "$1"
    configure_system "$1"
    configure_services "$1"
    configure_calamares "$1"
#    [[ ${edition} == "sonar" ]] && configure_thus "$1"
    write_live_session_conf "$1"
    msg "Done configuring [livefs]"
}

make_repo(){
    repo-add $1${mhwd_repo}/mhwd.db.tar.gz $1${mhwd_repo}/*pkg.tar*
}

copy_from_cache(){
    local list="${tmp_dir}"/mhwd-cache.list
    chroot-run \
        -r "${mountargs_ro}" \
        -w "${mountargs_rw}" \
        -B "${build_mirror}/${target_branch}" \
        "$1" \
        pacman -v -Syw $2 --noconfirm || return 1
    chroot-run \
        -r "${mountargs_ro}" \
        -w "${mountargs_rw}" \
        -B "${build_mirror}/${target_branch}" \
        "$1" \
        pacman -v -Sp $2 --noconfirm > "$list"
    sed -ni '/pkg.tar/p' "$list"
    sed -i "s/.*\///" "$list"

    msg2 "Copying mhwd package cache ..."
    rsync -v --files-from="$list" /var/cache/pacman/pkg "$1${mhwd_repo}"
}

chroot_create(){
    [[ "${1##*/}" == "rootfs" ]] && local flag="-L"
    setarch "${target_arch}" \
        mkchroot ${mkchroot_args[*]} ${flag} $@
}

clean_iso_root(){
    msg2 "Deleting isoroot [%s] ..." "${1##*/}"
    rm -rf --one-file-system "$1"
}

chroot_clean(){
    msg "Cleaning up ..."
    for image in "$1"/*fs; do
        [[ -d ${image} ]] || continue
        local name=${image##*/}
        if [[ $name != "mhwdfs" ]]; then
            msg2 "Deleting chroot [%s] (%s) ..." "$name" "${1##*/}"
            lock 9 "${image}.lock" "Locking chroot '${image}'"
            if [[ "$(stat -f -c %T "${image}")" == btrfs ]]; then
                { type -P btrfs && btrfs subvolume delete "${image}"; } #&> /dev/null
            fi
        rm -rf --one-file-system "${image}"
        fi
    done
    exec 9>&-
    rm -rf --one-file-system "$1"
}

clean_up_image(){
    msg2 "Cleaning [%s]" "${1##*/}"

    local path
    if [[ ${1##*/} == 'mhwdfs' ]]; then
        path=$1/var
        if [[ -d $path/lib/mhwd ]]; then
            mv $path/lib/mhwd $1 &> /dev/null
        fi
        if [[ -d $path ]]; then
            find "$path" -mindepth 0 -delete &> /dev/null
        fi
        if [[ -d $1/mhwd ]]; then
            mkdir -p $path/lib
            mv $1/mhwd $path/lib &> /dev/null
        fi
        path=$1/etc
        if [[ -d $path ]]; then
            find "$path" -mindepth 0 -delete &> /dev/null
        fi
    else
        [[ -f "$1/etc/locale.gen.bak" ]] && mv "$1/etc/locale.gen.bak" "$1/etc/locale.gen"
        [[ -f "$1/etc/locale.conf.bak" ]] && mv "$1/etc/locale.conf.bak" "$1/etc/locale.conf"
        path=$1/boot
        if [[ -d "$path" ]]; then
            find "$path" -name 'initramfs*.img' -delete &> /dev/null
        fi
        path=$1/var/lib/pacman/sync
        if [[ -d $path ]]; then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$1/var/cache/pacman/pkg
        if [[ -d $path ]]; then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$1/var/log
        if [[ -d $path ]]; then
            find "$path" -type f -delete &> /dev/null
        fi
        path=$1/var/tmp
        if [[ -d $path ]]; then
            find "$path" -mindepth 1 -delete &> /dev/null
        fi
        path=$1/tmp
        if [[ -d $path ]]; then
            find "$path" -mindepth 1 -delete &> /dev/null
        fi
    fi
	find "$1" -name *.pacnew -name *.pacsave -name *.pacorig -delete
	file=$1/boot/grub/grub.cfg
        if [[ -f "$file" ]]; then
            rm $file
        fi
}
