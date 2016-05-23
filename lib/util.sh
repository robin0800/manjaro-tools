#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

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
	done < "$2"
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
	done < "$1"
	echo ${repos[@]}
}

check_user_repos_conf(){
	local repositories=$(get_repos "$1") uri='file://'
	for repo in ${repositories[@]}; do
		msg2 "parsing repo [%s] ..." "${repo}"
		parse_section "${repo}" "$1"
		[[ ${pc_value} == $uri* ]] && die "Using local repositories is not supported!"
	done
}

read_set(){
	local _space="s| ||g" \
		_clean=':a;N;$!ba;s/\n/ /g' \
		_com_rm="s|#.*||g"

	stack=$(sed "$_com_rm" "$1.set" \
		| sed "$_space" \
		| sed "$_clean")
}

# $1: sets_dir
list_sets(){
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
	eval "case $2 in
		$(list_sets $1)) is_buildset=true; read_set $1/$2 ;;
		*) is_buildset=false ;;
	esac"
}

get_edition(){
	local result=$(find ${run_dir} -maxdepth 2 -name "$1") path
	[[ -z $result ]] && die "%s is not a valid profile or buildset!" "$1"
	path=${result%/*}
	echo ${path##*/}
}

in_array() {
	local needle=$1; shift
	local item
	for item in "$@"; do
		[[ $item = $needle ]] && return 0 # Found
	done
	return 1 # Not Found
}

get_timer(){
	echo $(date +%s)
}

get_timer_ms(){
	echo $(date +%s%3N)
}

# $1: start timer
elapsed_time(){
	echo $(echo $1 $(get_timer) | awk '{ printf "%0.2f",($2-$1)/60 }')
}

# $1: start timer
elapsed_time_ms(){
	echo $(echo $1 $(get_timer_ms) | awk '{ printf "%0.3f",($2-$1)/1000 }')
}

show_elapsed_time(){
	info "Time %s: %s minutes" "$1" "$(elapsed_time $2)"
}

lock() {
	eval "exec $1>"'"$2"'
	if ! flock -n $1; then
		stat_busy "$3"
		flock $1
		stat_done
	fi
}

slock() {
	eval "exec $1>"'"$2"'
	if ! flock -sn $1; then
		stat_busy "$3"
		flock -s $1
		stat_done
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

copy_mirrorlist(){
	cp -a /etc/pacman.d/mirrorlist "$1/etc/pacman.d/"
}

copy_keyring(){
	if [[ -d /etc/pacman.d/gnupg ]] && [[ ! -d $1/etc/pacman.d/gnupg ]]; then
		cp -a /etc/pacman.d/gnupg "$1/etc/pacman.d/"
	fi
}

load_vars() {
	local var

	[[ -f $1 ]] || return 1

	for var in {SRC,SRCPKG,PKG,LOG}DEST MAKEFLAGS PACKAGER CARCH GPGKEY; do
		[[ -z ${!var} ]] && eval $(grep -a "^${var}=" "$1")
	done

	return 0
}

prepare_dir(){
	[[ ! -d $1 ]] && mkdir -p $1
}

version_gen(){
	local y=$(date +%Y) m=$(date +%m) ver
	ver=${y:2}.$m
	echo $ver
}

# $1: chroot
get_branch(){
	echo $(cat "$1/etc/pacman-mirrors.conf" | grep '^Branch = ' | sed 's/Branch = \s*//g')
}

# $1: chroot
# $2: branch
set_branch(){
	info "Setting mirrorlist branch: %s" "$2"
	sed -e "s|/stable|/$2|g" -i "$1/etc/pacman.d/mirrorlist"
}

init_common(){
	[[ -z ${branch} ]] && branch='stable'

	[[ -z ${arch} ]] && arch=$(uname -m)

	[[ -z ${cache_dir} ]] && cache_dir='/var/cache/manjaro-tools'

	[[ -z ${chroots_dir} ]] && chroots_dir='/var/lib/manjaro-tools'

	[[ -z ${log_dir} ]] && log_dir='/var/log/manjaro-tools'

	[[ -z ${build_mirror} ]] && build_mirror='http://mirror.netzspielplatz.de/manjaro/packages'
}

init_buildtree(){
	tree_dir=${cache_dir}/pkgtree

	tree_dir_abs=${tree_dir}/packages-archlinux

	[[ -z ${repo_tree[@]} ]] && repo_tree=('core' 'extra' 'community' 'multilib' 'openrc')

	[[ -z ${host_tree} ]] && host_tree='https://github.com/manjaro'

	[[ -z ${host_tree_abs} ]] && host_tree_abs='https://projects.archlinux.org/git/svntogit'
}

init_buildpkg(){
	chroots_pkg="${chroots_dir}/buildpkg"

	sets_dir_pkg="${SYSCONFDIR}/pkg.d"

	[[ -d ${USERCONFDIR}/pkg.d ]] && sets_dir_pkg=${USERCONFDIR}/pkg.d

	[[ -z ${buildset_pkg} ]] && buildset_pkg='default'

	cache_dir_pkg=${cache_dir}/pkg
}

get_iso_label(){
	local label="$1"
	label="${label//_}"	# relace all _
	label="${label//-}"	# relace all -
	label="${label^^}"	# all uppercase
	label="${label::8}"	# limit to 8 characters
	echo ${label}
}

get_codename(){
	source /etc/lsb-release
	echo "${DISTRIB_CODENAME}"
}

init_buildiso(){
	chroots_iso="${chroots_dir}/buildiso"

	sets_dir_iso="${SYSCONFDIR}/iso.d"

	[[ -d ${USERCONFDIR}/iso.d ]] && sets_dir_iso=${USERCONFDIR}/iso.d

	[[ -z ${buildset_iso} ]] && buildset_iso='default'

	cache_dir_iso="${cache_dir}/iso"

	##### iso settings #####

	[[ -z ${dist_release} ]] && dist_release=$(version_gen)

	[[ -z ${dist_codename} ]] && dist_codename=$(get_codename)

	[[ -z ${dist_branding} ]] && dist_branding="MJRO"

	[[ -z ${dist_name} ]] && dist_name="Manjaro"

	iso_name=${dist_name,,}

	iso_label=$(get_iso_label "${dist_branding}${dist_release//.}")

	[[ -z ${iso_publisher} ]] && iso_publisher='Manjaro Linux <http://www.manjaro.org>'

	[[ -z ${iso_app_id} ]] && iso_app_id='Manjaro Linux Live/Rescue CD'

	[[ -z ${iso_compression} ]] && iso_compression='xz'

	[[ -z ${iso_checksum} ]] && iso_checksum='md5'

	[[ -z ${initsys} ]] && initsys="systemd"

	[[ -z ${kernel} ]] && kernel="linux44"

	[[ -z ${use_overlayfs} ]] && use_overlayfs='true'

	[[ -z ${profile_repo} ]] && profile_repo='manjaro-tools-iso-profiles'
}

init_deployiso(){

	[[ -z ${remote_target} ]] && remote_target="/home/frs/project"

	[[ -z ${remote_project} ]] && remote_project="manjaro-testing"

	[[ -z ${remote_user} ]] && remote_user="[SetUser]"

	[[ -z ${remote_url} ]] && remote_url="sourceforge.net"

	[[ -z ${limit} ]] && limit=100

	[[ -z ${tracker_url} ]] && tracker_url=""

	[[ -z ${piece_size} ]] && piece_size=21
}

load_config(){

	[[ -f $1 ]] || return 1

	manjaro_tools_conf="$1"

	[[ -r ${manjaro_tools_conf} ]] && source ${manjaro_tools_conf}

	init_common

	init_buildtree

	init_buildpkg

	init_buildiso

	init_deployiso

	return 0
}

reset_profile(){
	unset displaymanager
	unset autologin
	unset multilib
	unset pxe_boot
	unset plymouth_boot
	unset nonfree_xorg
	unset efi_boot_loader
	unset efi_part_size
	unset hostname
	unset username
	unset plymouth_theme
	unset password
	unset addgroups
	unset start_systemd
	unset disable_systemd
	unset start_openrc
	unset disable_openrc
	unset start_systemd_live
	unset start_openrc_live
	unset packages_custom
	unset packages_mhwd
}

is_valid_bool(){
	case $1 in
		'true'|'false') return 0 ;;
		*) return 1 ;;
	esac
}

check_profile_vars(){
	if ! is_valid_bool "${autologin}";then
		die "autologin only accepts true/false value!"
	fi
	if ! is_valid_bool "${multilib}";then
		die "multilib only accepts true/false value!"
	fi
	if ! is_valid_bool "${nonfree_xorg}";then
		die "nonfree_xorg only accepts true/false value!"
	fi
	if ! is_valid_bool "${plymouth_boot}";then
		die "plymouth_boot only accepts true/false value!"
	fi
	if ! is_valid_bool "${pxe_boot}";then
		die "pxe_boot only accepts true/false value!"
	fi
}

load_profile_config(){

	[[ -f $1 ]] || return 1

	profile_conf="$1"

	[[ -r ${profile_conf} ]] && source ${profile_conf}

	[[ -z ${displaymanager} ]] && displaymanager="none"

	[[ -z ${autologin} ]] && autologin="true"
	[[ ${displaymanager} == 'none' ]] && autologin="false"

	[[ -z ${multilib} ]] && multilib="true"

	[[ -z ${pxe_boot} ]] && pxe_boot="true"

	[[ -z ${plymouth_boot} ]] && plymouth_boot="true"
	[[ ${initsys} == 'openrc' ]] && plymouth_boot="false"

	[[ -z ${nonfree_xorg} ]] && nonfree_xorg="true"

	[[ -z ${efi_boot_loader} ]] && efi_boot_loader="grub"

	[[ -z ${efi_part_size} ]] && efi_part_size="31M"

	[[ -z ${hostname} ]] && hostname="manjaro"

	[[ -z ${username} ]] && username="manjaro"

	[[ -z ${plymouth_theme} ]] && plymouth_theme="manjaro-elegant"

	[[ -z ${password} ]] && password="manjaro"

	if [[ -z ${addgroups} ]];then
		addgroups="video,power,disk,storage,optical,network,lp,scanner,wheel"
	fi

	if [[ -z ${start_systemd[@]} ]];then
		start_systemd=('bluetooth' 'cronie' 'ModemManager' 'NetworkManager' 'org.cups.cupsd' 'tlp' 'tlp-sleep')
	fi

	[[ -z ${disable_systemd[@]} ]] && disable_systemd=('pacman-init')

	if [[ -z ${start_openrc[@]} ]];then
		start_openrc=('acpid' 'bluetooth' 'cgmanager' 'consolekit' 'cronie' 'cupsd' 'dbus' 'syslog-ng' 'NetworkManager')
	fi

	[[ -z ${disable_openrc[@]} ]] && disable_openrc=('pacman-init')

	if [[ -z ${start_systemd_live[@]} ]];then
		start_systemd_live=('manjaro-live' 'mhwd-live' 'pacman-init')
	fi

	if [[ -z ${start_openrc_live[@]} ]];then
		start_openrc_live=('manjaro-live' 'mhwd-live' 'pacman-init')
	fi

	check_profile_vars

	return 0
}

clean_dir(){
	if [[ -d $1 ]]; then
		msg "Cleaning [%s] ..." "$1"
		rm -r $1/*
	fi
}

write_repo_conf(){
	local repos=$(find $USER_HOME -type f -name ".buildiso")
	local path name
	[[ -z ${repos[@]} ]] && run_dir=${DATADIR}/iso-profiles && return 1
	for r in ${repos[@]}; do
		path=${r%/.*}
		name=${path##*/}
		echo "run_dir=$path" > ${USERCONFDIR}/$name.conf
	done
}

load_user_info(){
	OWNER=${SUDO_USER:-$USER}

	if [[ -n $SUDO_USER ]]; then
		eval "USER_HOME=~$SUDO_USER"
	else
		USER_HOME=$HOME
	fi

	USERCONFDIR="$USER_HOME/.config/manjaro-tools"
	prepare_dir "${USERCONFDIR}"
}

load_run_dir(){
	[[ -f ${USERCONFDIR}/$1.conf ]] || write_repo_conf
	[[ -r ${USERCONFDIR}/$1.conf ]] && source ${USERCONFDIR}/$1.conf
	return 0
}

show_version(){
	msg "manjaro-tools"
	msg2 "version: %s" "${version}"
}

show_config(){
	if [[ -f ${USERCONFDIR}/manjaro-tools.conf ]]; then
		msg2 "user_config: %s" "${USERCONFDIR}/manjaro-tools.conf"
	else
		msg2 "manjaro_tools_conf: %s" "${manjaro_tools_conf}"
	fi
}

# $1: chroot
kill_chroot_process(){
	# enable to have more debug info
	#msg "machine-id (etc): $(cat $1/etc/machine-id)"
	#[[ -e $1/var/lib/dbus/machine-id ]] && msg "machine-id (lib): $(cat $1/var/lib/dbus/machine-id)"
	#msg "running processes: "
	#lsof | grep $1

	local prefix="$1" flink pid name
	for root_dir in /proc/*/root; do
		flink=$(readlink $root_dir)
		if [ "x$flink" != "x" ]; then
			if [ "x${flink:0:${#prefix}}" = "x$prefix" ]; then
				# this process is in the chroot...
				pid=$(basename $(dirname "$root_dir"))
				name=$(ps -p $pid -o comm=)
				info "Killing chroot process: %s (%s)" "$name" "$pid"
				kill -9 "$pid"
			fi
		fi
	done
}

create_min_fs(){
	msg "Creating install root at %s" "$1"
	mkdir -m 0755 -p $1/var/{cache/pacman/pkg,lib/pacman,log} $1/{dev,run,etc}
	mkdir -m 1777 -p $1/tmp
	mkdir -m 0555 -p $1/{sys,proc}
}

is_valid_init(){
	case $1 in
		'openrc'|'systemd') return 0 ;;
		*) return 1 ;;
	esac
}

is_valid_arch_pkg(){
	case $1 in
		'i686'|'x86_64'|'multilib') return 0 ;;
		*) return 1 ;;
	esac
}

is_valid_arch_iso(){
	case $1 in
		'i686'|'x86_64') return 0 ;;
		*) return 1 ;;
	esac
}

is_valid_branch(){
	case $1 in
		'stable'|'testing'|'unstable') return 0 ;;
		*) return 1 ;;
	esac
}

run(){
	if ${is_buildset};then
		for item in ${stack[@]};do
			$1 $item
		done
	else
		$1 $2
	fi
}
