#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

import(){
	[[ -r $1 ]] && source $1
}

get_timer(){
	echo $(date +%s)
}

# $1: start timer
elapsed_time(){
	echo $(echo $1 $(get_timer) | awk '{ printf "%0.2f",($2-$1)/60 }')
}

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


# $1: section
parse_section() {
	local is_section=0
	while read line; do
	[[ $line =~ ^\ {0,}# ]] && continue
		[[ -z "$line" ]] && continue
		if [ $is_section == 0 ]; then
			if [[ $line =~ ^\[.*?\] ]]; then
				line=${line:1:$((${#line}-2))}
				section=${line// /}
				if [[ $section == $1 ]]; then
					is_section=1
					continue
				fi
				continue
			fi
		elif [[ $line =~ ^\[.*?\] && $is_section == 1 ]]; then
			break
		else
			pc_key=${line%%=*}
			pc_key=${pc_key// /}
			pc_value=${line##*=}
			pc_value=${pc_value## }
			eval "$pc_key='$pc_value'"
		fi
	done < "${pacman_conf}"
}

get_repos() {
	local section repos=() filter='^\ {0,}#'
	while read line; do
		[[ $line =~ "${filter}" ]] && continue
		[[ -z "$line" ]] && continue
		if [[ $line =~ ^\[.*?\] ]]; then
			line=${line:1:$((${#line}-2))}
			section=${line// /}
			case ${section} in
				"options") continue ;;
				*) repos+=("${section}") ;;
			esac
		fi
	done < "${pacman_conf}"
	echo ${repos[@]}
}

clean_pacman_conf(){
	local repositories=$(get_repos) uri='file://'
	msg "Cleaning [$1/etc/pacman.conf] ..."
	for repo in ${repositories[@]}; do
		case ${repo} in
			'options'|'core'|'extra'|'community'|'multilib') continue ;;
			*)
				msg2 "parsing [${repo}] ..."
				parse_section ${repo}
				if [[ ${pc_value} == $uri* ]]; then
					msg2 "Removing local repo [${repo}] ..."
					sed -i "/^\[${repo}/,/^Server/d" $1/etc/pacman.conf
				fi
			;;
		esac
	done
	msg "Done cleaning [$1/etc/pacman.conf]"
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

	[[ -z ${branch} ]] && branch='stable'

	[[ -z ${arch} ]] && arch=$(uname -m)

	[[ -z ${cache_dir} ]] && cache_dir='/var/cache/manjaro-tools'

	[[ -z ${chroots_dir} ]] && chroots_dir='/var/lib/manjaro-tools'

	[[ -z ${sets_dir} ]] && sets_dir="${SYSCONFDIR}/sets"

	###################
	# buildtree
	###################

	[[ -z ${repo_tree[@]} ]] && repo_tree=('core' 'extra' 'community' 'multilib' 'openrc')

	[[ -z ${host_tree} ]] && host_tree='https://github.com/manjaro'

	[[ -z ${host_tree_abs} ]] && host_tree_abs='https://projects.archlinux.org/git/svntogit'

	###################
	# buildpkg
	###################

	[[ -z ${buildset_pkg} ]] && buildset_pkg='default'

	[[ -z ${build_mirror} ]] && build_mirror='http://mirror.netzspielplatz.de/manjaro/packages'

	[[ -z ${blacklist_trigger[@]} ]] && blacklist_trigger=('eudev' 'upower-pm-utils' 'eudev-systemdcompat')

	[[ -z ${blacklist[@]} ]] && blacklist=('libsystemd')

	###################
	# buildiso
	###################

	[[ -z ${buildset_iso} ]] && buildset_iso='default'

	##### iso settings #####

	if [[ -z ${dist_release} ]];then
		source /etc/lsb-release
		dist_release=${DISTRIB_RELEASE}
	fi

	if [[ -z ${dist_codename} ]];then
		source /etc/lsb-release
		dist_codename="${DISTRIB_CODENAME}"
	fi

	[[ -z ${dist_branding} ]] && dist_branding="MJRO"

	[[ -z ${dist_version} ]] && dist_version=$(date +%Y.%m)

	[[ -z ${dist_name} ]] && dist_name="Manjaro"

	[[ -z ${iso_name} ]] && iso_name="manjaro"

	iso_label="${dist_branding}${dist_release//.}"
	iso_label="${iso_label//_}"	# relace all _
	iso_label="${iso_label//-}"	# relace all -
	iso_label="${iso_label^^}"	# all uppercase
	iso_label="${iso_label::8}"	# limit to 8 characters

	[[ -z ${iso_publisher} ]] && iso_publisher='Manjaro Linux <http://www.manjaro.org>'

	[[ -z ${iso_app_id} ]] && iso_app_id='Manjaro Linux Live/Rescue CD'

	[[ -z ${iso_compression} ]] && iso_compression='xz'

	[[ -z ${iso_checksum} ]] && iso_checksum='md5'

	return 0
}

load_profile_config(){

	[[ -f $1 ]] || return 1

	profile_conf="$1"

	[[ -r ${profile_conf} ]] && source ${profile_conf}

	[[ -z ${initsys} ]] && initsys="systemd"

	[[ -z ${displaymanager} ]] && displaymanager="none"

	[[ -z ${kernel} ]] && kernel="linux318"

	[[ -z ${efi_boot_loader} ]] && efi_boot_loader="grub"

	[[ -z ${efi_part_size} ]] && efi_part_size="31M"

	[[ -z ${hostname} ]] && hostname="manjaro"

	[[ -z ${username} ]] && username="manjaro"

	[[ -z ${plymouth_theme} ]] && plymouth_theme="manjaro-elegant"

	[[ -z ${password} ]] && password="manjaro"

	if [[ -z ${addgroups} ]];then
		addgroups="video,audio,power,disk,storage,optical,network,lp,scanner,wheel"
	fi

	if [[ -z ${start_systemd[@]} ]];then
		start_systemd=('bluetooth' 'cronie' 'ModemManager' 'NetworkManager' 'org.cups.cupsd' 'tlp' 'tlp-sleep')
	fi

	if [[ -z ${start_openrc[@]} ]];then
		start_openrc=('acpid' 'bluetooth' 'consolekit' 'cronie' 'cupsd' 'dbus' 'syslog-ng' 'NetworkManager')
	fi

	if [[ -z ${start_systemd_live[@]} ]];then
		start_systemd_live=('livecd' 'mhwd-live' 'pacman-init' 'pacman-boot')
	fi

	if [[ -z ${start_openrc_live[@]} ]];then
		start_openrc_live=('livecd' 'mhwd-live' 'pacman-init' 'pacman-boot')
	fi

	return 0
}

prepare_dir(){
	[[ ! -d $1 ]] && mkdir -p $1
}

clean_dir(){
	if [[ -d $1 ]]; then
		msg "Cleaning [$1] ..."
		rm -r $1/*
	fi
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

# $1: buildset
# $2: sets_dir
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

# $1: file
# $2: exit code
check_sanity(){
	if [[ ! -f $1 ]]; then
		eval "$2"
	fi
}
