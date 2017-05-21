#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

write_repo_conf(){
    local repos=$(find $USER_HOME -type f -name "repo_info")
    local path name
    [[ -z ${repos[@]} ]] && run_dir=${DATADIR}/iso-profiles && return 1
    for r in ${repos[@]}; do
        path=${r%/repo_info}
        name=${path##*/}
        echo "run_dir=$path" > ${MT_USERCONFDIR}/$name.conf
    done
}

load_run_dir(){
    [[ -f ${MT_USERCONFDIR}/$1.conf ]] || write_repo_conf
    [[ -r ${MT_USERCONFDIR}/$1.conf ]] && source ${MT_USERCONFDIR}/$1.conf
    return 0
}

load_profile(){
    local profdir="$1"
    local profile_conf="$profdir/profile.conf"

    [[ -f ${profile_conf} ]] || return 1

    [[ -r ${profile_conf} ]] && source ${profile_conf}

    [[ -z ${displaymanager} ]] && displaymanager="none"

    [[ -z ${autologin} ]] && autologin="true"
    [[ ${displaymanager} == 'none' ]] && autologin="false"

    [[ -z ${multilib} ]] && multilib="true"

    [[ -z ${nonfree_mhwd} ]] && nonfree_mhwd="true"

    [[ -z ${efi_boot_loader} ]] && efi_boot_loader="grub"

    [[ -z ${hostname} ]] && hostname="manjaro"

    [[ -z ${username} ]] && username="manjaro"

    [[ -z ${password} ]] && password="manjaro"

    [[ -z ${login_shell} ]] && login_shell='/bin/bash'

    if [[ -z ${addgroups} ]];then
        addgroups="video,power,storage,optical,network,lp,scanner,wheel,sys"
    fi

    if [[ -z ${enable_systemd[@]} ]];then
        enable_systemd=('bluetooth' 'cronie' 'ModemManager' 'NetworkManager' 'org.cups.cupsd' 'tlp' 'tlp-sleep')
    fi

    if [[ -z ${enable_openrc[@]} ]];then
        enable_openrc=('acpid' 'bluetooth' 'elogind' 'cronie' 'cupsd' 'dbus' 'syslog-ng' 'NetworkManager')
    fi

    if [[ ${displaymanager} != "none" ]]; then
        enable_openrc+=('xdm')
        enable_systemd+=("${displaymanager}")
    fi

    [[ -z ${netinstall} ]] && netinstall='false'

    [[ -z ${chrootcfg} ]] && chrootcfg='false'

    enable_live=('manjaro-live' 'pacman-init')
    if ${netinstall};then
        enable_live+=('mhwd-live-net' 'mirrors-live-net')
    else
        enable_live+=('mhwd-live' 'mirrors-live')
    fi

    netgroups="https://raw.githubusercontent.com/manjaro/calamares-netgroups/master"

    [[ -z ${geoip} ]] && geoip='true'

    [[ -z ${smb_workgroup} ]] && smb_workgroup=''

    basic='true'
    [[ -z ${extra} ]] && extra='false'

    ${extra} && basic='false'

    root_list=${run_dir}/shared/Packages-Root
    root_overlay="${run_dir}/shared/${os_id}/root-overlay"
    if [[ -e "$profdir/root-overlay" ]];then
        root_overlay="$profdir/root-overlay"
    fi

    mhwd_list=${run_dir}/shared/Packages-Mhwd

    desktop_list=$profdir/Packages-Desktop
    if [[ -e "$profdir/desktop-overlay" ]];then
        desktop_overlay="$profdir/desktop-overlay"
    fi

    live_list="${run_dir}/shared/Packages-Live"
    if [[ -f "$profdir/Packages-Live" ]];then
        live_list="$profdir/Packages-Live"
    fi

    live_overlay="${run_dir}/shared/${os_id}/live-overlay"
    if [[ -e "$profdir/live-overlay" ]];then
        live_overlay="$profdir/live-overlay"
    fi

    if ${netinstall};then
        sort -u ${run_dir}/shared/Packages-Net ${live_list} > ${tmp_dir}/packages-live-net.list
        live_list=${tmp_dir}/packages-live-net.list
    else
        chrootcfg="false"
    fi

    return 0
}

reset_profile(){
    unset displaymanager
    unset autologin
    unset multilib
    unset nonfree_mhwd
    unset efi_boot_loader
    unset hostname
    unset username
    unset password
    unset addgroups
    unset enable_systemd
    unset disable_systemd
    unset enable_openrc
    unset disable_openrc
    unset enable_live
    unset login_shell
    unset netinstall
    unset chrootcfg
    unset geoip
    unset extra
    unset root_list
    unset desktop_list
    unset mhwd_list
    unset live_list
    unset root_overlay
    unset desktop_overlay
    unset live_overlay
}

# $1: file name
load_pkgs(){
    info "Loading Packages: [%s] ..." "${1##*/}"

    local _init _init_rm
    case "${initsys}" in
        'openrc')
            _init="s|>openrc||g"
            _init_rm="s|>systemd.*||g"
        ;;
        *)
            _init="s|>systemd||g"
            _init_rm="s|>openrc.*||g"
        ;;
    esac

    local _multi _nonfree_default _nonfree_multi _arch _arch_rm _nonfree_i686 _nonfree_x86_64 _basic _basic_rm _extra _extra_rm

    if ${basic};then
        _basic="s|>basic||g"
    else
        _basic_rm="s|>basic.*||g"
    fi

    if ${extra};then
        _extra="s|>extra||g"
    else
        _extra_rm="s|>extra.*||g"
    fi

    case "${target_arch}" in
        "i686")
            _arch="s|>i686||g"
            _arch_rm="s|>x86_64.*||g"
            _multi="s|>multilib.*||g"
            _nonfree_multi="s|>nonfree_multilib.*||g"
            _nonfree_x86_64="s|>nonfree_x86_64.*||g"
            if ${nonfree_mhwd};then
                _nonfree_default="s|>nonfree_default||g"
                _nonfree_i686="s|>nonfree_i686||g"

            else
                _nonfree_default="s|>nonfree_default.*||g"
                _nonfree_i686="s|>nonfree_i686.*||g"
            fi
        ;;
        *)
            _arch="s|>x86_64||g"
            _arch_rm="s|>i686.*||g"
            _nonfree_i686="s|>nonfree_i686.*||g"
            if ${multilib};then
                _multi="s|>multilib||g"
                if ${nonfree_mhwd};then
                    _nonfree_default="s|>nonfree_default||g"
                    _nonfree_x86_64="s|>nonfree_x86_64||g"
                    _nonfree_multi="s|>nonfree_multilib||g"
                else
                    _nonfree_default="s|>nonfree_default.*||g"
                    _nonfree_multi="s|>nonfree_multilib.*||g"
                    _nonfree_x86_64="s|>nonfree_x86_64.*||g"
                fi
            else
                _multi="s|>multilib.*||g"
                if ${nonfree_mhwd};then
                    _nonfree_default="s|>nonfree_default||g"
                    _nonfree_x86_64="s|>nonfree_x86_64||g"
                    _nonfree_multi="s|>nonfree_multilib.*||g"
                else
                    _nonfree_default="s|>nonfree_default.*||g"
                    _nonfree_x86_64="s|>nonfree_x86_64.*||g"
                    _nonfree_multi="s|>nonfree_multilib.*||g"
                fi
            fi
        ;;
    esac

    local _edition _edition_rm
    case "${edition}" in
        'sonar')
            _edition="s|>sonar||g"
            _edition_rm="s|>manjaro.*||g"
        ;;
        *)
            _edition="s|>manjaro||g"
            _edition_rm="s|>sonar.*||g"
        ;;
    esac

    local _blacklist="s|>blacklist.*||g" \
        _kernel="s|KERNEL|$kernel|g" \
        _used_kernel=${kernel:5:2} \
        _space="s| ||g" \
        _clean=':a;N;$!ba;s/\n/ /g' \
        _com_rm="s|#.*||g" \
        _purge="s|>cleanup.*||g" \
        _purge_rm="s|>cleanup||g"

    packages=($(sed "$_com_rm" "$1" \
            | sed "$_space" \
            | sed "$_blacklist" \
            | sed "$_purge" \
            | sed "$_init" \
            | sed "$_init_rm" \
            | sed "$_arch" \
            | sed "$_arch_rm" \
            | sed "$_nonfree_default" \
            | sed "$_multi" \
            | sed "$_nonfree_i686" \
            | sed "$_nonfree_x86_64" \
            | sed "$_nonfree_multi" \
            | sed "$_kernel" \
            | sed "$_edition" \
            | sed "$_edition_rm" \
            | sed "$_basic" \
            | sed "$_basic_rm" \
            | sed "$_extra" \
            | sed "$_extra_rm" \
            | sed "$_clean"))

    if [[ $1 == "${mhwd_list}" ]]; then

        [[ ${_used_kernel} < "42" ]] && local _amd="s|xf86-video-amdgpu||g"

        packages_cleanup=($(sed "$_com_rm" "$1" \
            | grep cleanup \
            | sed "$_purge_rm" \
            | sed "$_kernel" \
            | sed "$_clean" \
            | sed "$_amd"))
    fi
}
