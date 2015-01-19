#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

##
#  usage : in_array( $needle, $haystack )
# return : 0 - found
#          1 - not found
##
in_array() {
    local needle=$1; shift
    local item
    for item in "$@"; do
	[[ $item = $needle ]] && return 0 # Found
    done
    return 1 # Not Found
}

# $1: sofile
# $2: soarch
process_sofile() {
    # extract the library name: libfoo.so
    local soname="${1%.so?(+(.+([0-9])))}".so
    # extract the major version: 1
    soversion="${1##*\.so\.}"
    if [[ "$soversion" = "$1" ]] && (($IGNORE_INTERNAL)); then
	continue
    fi
    if ! in_array "${soname}=${soversion}-$2" ${soobjects[@]}; then
	# libfoo.so=1-64
	msg "${soname}=${soversion}-$2"
	soobjects+=("${soname}=${soversion}-$2")
    fi
}

##
#  usage : get_full_version( [$pkgname] )
# return : full version spec, including epoch (if necessary), pkgver, pkgrel
##
get_full_version() {
    # set defaults if they weren't specified in buildfile
    pkgbase=${pkgbase:-${pkgname[0]}}
    epoch=${epoch:-0}
    if [[ -z $1 ]]; then
	if [[ $epoch ]] && (( ! $epoch )); then
	    echo $pkgver-$pkgrel
	else
	    echo $epoch:$pkgver-$pkgrel
	fi
    else
	for i in pkgver pkgrel epoch; do
	    local indirect="${i}_override"
	    eval $(declare -f package_$1 | sed -n "s/\(^[[:space:]]*$i=\)/${i}_override=/p")
	    [[ -z ${!indirect} ]] && eval ${indirect}=\"${!i}\"
	done
	if (( ! $epoch_override )); then
	    echo $pkgver_override-$pkgrel_override
	else
	    echo $epoch_override:$pkgver_override-$pkgrel_override
	fi
    fi
}

##
#  usage: find_cached_package( $pkgname, $pkgver, $arch )
#
#    $pkgver can be supplied with or without a pkgrel appended.
#    If not supplied, any pkgrel will be matched.
##
find_cached_package() {
    local searchdirs=("$PWD" "$PKGDEST") results=()
    local targetname=$1 targetver=$2 targetarch=$3
    local dir pkg pkgbasename pkgparts name ver rel arch size r results

    for dir in "${searchdirs[@]}"; do
	[[ -d $dir ]] || continue

	for pkg in "$dir"/*.pkg.tar.xz; do
	    [[ -f $pkg ]] || continue

	    # avoid adding duplicates of the same inode
	    for r in "${results[@]}"; do
		[[ $r -ef $pkg ]] && continue 2
	    done

	    # split apart package filename into parts
	    pkgbasename=${pkg##*/}
	    pkgbasename=${pkgbasename%.pkg.tar?(.?z)}

	    arch=${pkgbasename##*-}
	    pkgbasename=${pkgbasename%-"$arch"}

	    rel=${pkgbasename##*-}
	    pkgbasename=${pkgbasename%-"$rel"}

	    ver=${pkgbasename##*-}
	    name=${pkgbasename%-"$ver"}

	    if [[ $targetname = "$name" && $targetarch = "$arch" ]] &&
			    pkgver_equal "$targetver" "$ver-$rel"; then
		results+=("$pkg")
	    fi
	done
    done

    case ${#results[*]} in
	    0)
		return 1
	    ;;
	    1)
		printf '%s\n' "$results"
		return 0
	    ;;
	    *)
		error 'Multiple packages found:'
		printf '\t%s\n' "${results[@]}" >&2
		return 1
	    ;;
    esac
}

##
# usage: pkgver_equal( $pkgver1, $pkgver2 )
##
pkgver_equal() {
	local left right

	if [[ $1 = *-* && $2 = *-* ]]; then
		# if both versions have a pkgrel, then they must be an exact match
		[[ $1 = "$2" ]]
	else
		# otherwise, trim any pkgrel and compare the bare version.
		[[ ${1%%-*} = "${2%%-*}" ]]
	fi
}

check_root() {
    (( EUID == 0 )) && return
    if type -P sudo >/dev/null; then
	exec sudo -- "$@"
    else
	exec su root -c "$(printf ' %q' "$@")"
    fi
}

load_vars() {
    local var
    
    [[ -f $1 ]] || return 1

    for var in {SRC,SRCPKG,PKG,LOG}DEST MAKEFLAGS PACKAGER CARCH GPGKEY; do
	    [[ -z ${!var} ]] && eval $(grep "^${var}=" "$1")
    done
    
    return 0
}

load_config(){

    [[ -f $1 ]] || return 1
    
    manjaro_tools_conf="$1"

    [[ -r ${manjaro_tools_conf} ]] && source ${manjaro_tools_conf}
    
    ######################
    # common
    ######################
    
    if [[ -n ${branch} ]];then
	branch=${branch}
    else
	branch='stable'
    fi
    
    if [[ -n ${arch} ]]; then
	arch=${arch}
    else
	arch=$(uname -m)
    fi
    
    if [[ -n ${cache_dir} ]];then
	cache_dir=${cache_dir}
    else
	cache_dir='/var/cache/manjaro-tools'
    fi
    
    ###################
    # buildtree
    ###################
    
    if [[ -n ${repo_tree} ]];then
	repo_tree=${repo_tree}
    else
	repo_tree=(core extra community multilib openrc)
    fi
    
    if [[ -n ${host_tree} ]];then
	host_tree=${host_tree}
    else
	host_tree='https://github.com/manjaro'
    fi   
    
    if [[ -n ${host_tree_abs} ]];then
	host_tree_abs=${host_tree_abs}
    else
	host_tree_abs='https://projects.archlinux.org/git/svntogit/packages'
    fi   
    
    ###################
    # buildpkg
    ###################
    
    if [[ -n ${chroots_pkg} ]];then
	chroots_pkg=${chroots_pkg}
    else
	chroots_pkg='/opt/buildpkg'
    fi
        
    if [[ -n ${sets_dir_pkg} ]];then
	sets_dir_pkg=${sets_dir_pkg}
    else
	sets_dir_pkg="${SYSCONFDIR}/sets/pkg"
    fi
    
    if [[ -n ${buildset_pkg} ]];then
	buildset_pkg=${buildset_pkg}
    else
	buildset_pkg='default'
    fi

    if [[ -n ${build_mirror} ]];then
	build_mirror=${build_mirror}
    else
	build_mirror='http://mirror.netzspielplatz.de/manjaro/packages'
    fi
    
    if [[ -n ${blacklist_trigger[@]} ]];then
	blacklist_trigger=${blacklist_trigger[@]}
    else
	blacklist_trigger=('eudev' 'upower-pm-utils' 'eudev-systemdcompat')
    fi
    
    if [[ -n ${blacklist[@]} ]];then
	blacklist=${blacklist[@]}
    else
	blacklist=('libsystemd')
    fi
    
    ###################
    # buildiso
    ###################
    
    if [[ -n ${chroots_iso} ]];then
	chroots_iso=${chroots_iso}
    else
	chroots_iso='/opt/buildiso'
    fi
        
    if [[ -n ${sets_dir_iso} ]];then
	sets_dir_iso=${sets_dir_iso}
    else
	sets_dir_iso="${SYSCONFDIR}/sets/iso"
    fi
    
    if [[ -n ${buildset_iso} ]];then
	buildset_iso=${buildset_iso}
    else
	buildset_iso='default'
    fi
    
    if [[ -n ${iso_label} ]];then
	iso_label=${iso_label}
    else
	source /etc/lsb-release
	iso_label="MJRO${DISTRIB_RELEASE//.}"
    fi

    if [[ -n ${iso_version} ]];then
	iso_version=${iso_version}
    else	
	source /etc/lsb-release
	iso_version=${DISTRIB_RELEASE}
    fi

    if [[ -n ${manjaro_kernel} ]];then
	manjaro_kernel=${manjaro_kernel}
    else
	manjaro_kernel="linux317"
    fi

    manjaro_kernel_ver=${manjaro_kernel#*linux}
    
    if [[ -n ${manjaro_version} ]];then
	manjaro_version=${manjaro_version}
    else
	manjaro_version=$(date +%Y.%m)
    fi
    
    if [[ -n ${manjaroiso} ]];then
	manjaroiso=${manjaroiso}
    else
	manjaroiso="manjaroiso"
    fi
    
    if [[ -n ${code_name} ]];then
	code_name=${code_name}
    else
	source /etc/lsb-release
	code_name="${DISTRIB_CODENAME}"
    fi
    
    if [[ -n ${img_name} ]];then
	img_name=${img_name}
    else
	img_name=manjaro
    fi
    
    if [[ -n ${hostname} ]];then
	hostname=${hostname}
    else
	hostname="manjaro"
    fi
    
    if [[ -n ${username} ]];then
	username=${username}
    else
	username="manjaro"
    fi
    
    if [[ -n ${install_dir} ]];then
	install_dir=${install_dir}
    else
	install_dir=manjaro
    fi
    
    if [[ -n ${plymouth_theme} ]];then
	plymouth_theme=${plymouth_theme}
    else
	plymouth_theme=manjaro-elegant
    fi
    
    if [[ -n ${compression} ]];then
	compression=${compression}
    else
	compression=xz
    fi
    
    if [[ -n ${password} ]];then
	password=${password}
    else
	password="manjaro"
    fi
    
    if [[ -n ${addgroups} ]];then
	addgroups=${addgroups}
    else
	addgroups="video,audio,power,disk,storage,optical,network,lp,scanner"
    fi

    if [[ -n ${start_systemd} ]];then
	start_systemd=${start_systemd}
    else
	start_systemd=('cronie' 'org.cups.cupsd' 'tlp' 'tlp-sleep')
    fi
    
    if [[ -n ${start_openrc} ]];then
	start_openrc=${start_openrc}
    else
	start_openrc=('cronie' 'cupsd' 'metalog' 'dbus' 'consolekit' 'acpid')
    fi
    
    if [[ -n ${start_systemd_live} ]];then
	start_systemd_live=${start_systemd_live}
    else
	start_systemd_live=('bluez' 'NetworkManager' 'ModemManager')
    fi
    
    if [[ -n ${start_openrc_live} ]];then
	start_openrc_live=${start_openrc_live}
    else
	start_openrc_live=('bluetooth' 'networkmanager')
    fi
    
    return 0
}

# $1: sets_dir
load_sets(){
    local prof temp
    for item in $(ls $1/*.set); do
	temp=${item##*/}
	prof=${prof:-}${prof:+|}${temp%.set}
    done
    echo $prof
}

# $1: sets_dir
# $2: buildset
eval_buildset(){
    eval "case $1 in
	    $(load_sets $2)) is_buildset=true ;;
	    *) is_buildset=false ;;
	esac"
}

load_user_info(){
    OWNER=${SUDO_USER:-$USER}

    if [[ -n $SUDO_USER ]]; then
	eval "USER_HOME=~$SUDO_USER"
    else
	USER_HOME=$HOME
    fi
    
    USER_CONFIG="$USER_HOME/.config"
}
