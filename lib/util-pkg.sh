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

preconf_arm(){
	local conf_dir=/tmp tarch="$1" desc="$2" flags="$3"
	cp "${DATADIR}/pacman-arm.conf" "$conf_dir/pacman-$tarch.conf"
	cp "${DATADIR}/makepkg-arm.conf" "$conf_dir/makepkg-$tarch.conf"
	sed -i "$conf_dir/makepkg-$tarch.conf" \
		-e "s|@CARCH[@]|$tarch|g" \
		-e "s|@CHOST[@]|$desc|g" \
		-e "s|@CARCHFLAGS[@]|$flags|g"
	sed -i "$conf_dir/pacman-$tarch.conf" -e "s|@CARCH[@]|$tarch|g"

	work_dir="${chroots_pkg}/${target_branch}/$tarch"
	pkg_dir="${cache_dir_pkg}/${target_branch}/$tarch"

	makepkg_conf="$conf_dir/makepkg-$tarch.conf"
	pacman_conf="$conf_dir/pacman-$tarch.conf"
}

preconf(){
	local arch="$1"
	work_dir="${chroots_pkg}/${target_branch}/${target_arch}"
	pkg_dir="${cache_dir_pkg}/${target_branch}/${target_arch}"
	if [[ "$pac_conf_arch" == 'multilib' ]];then
		target_arch='x86_64'
		is_multilib=true
	else
		is_multilib=false
	fi
	makepkg_conf="${DATADIR}/makepkg-${target_arch}.conf"
	pacman_conf="${DATADIR}/pacman-$arch.conf"
}

# $1: target_arch
configure_chroot_arch(){
	if ! is_valid_arch_pkg "$1";then
		die "%s is not a valid arch!" "$1"
	fi
	if ! is_valid_branch "${target_branch}";then
		die "%s is not a valid branch!" "${target_branch}"
	fi
	local conf_arch chost_desc cflags
	case "$1" in
		'arm')
			conf_arch="$1"
			chost_desc="armv5tel-unknown-linux-gnueabi"
			cflags="-march=armv5te "
			preconf_arm "$conf_arch" "$chost_desc" "$cflags"
		;;
		'armv6h')
			conf_arch="$1"
			chost_desc="armv6l-unknown-linux-gnueabihf"
			cflags="-march=armv6 -mfloat-abi=hard -mfpu=vfp "
			preconf_arm "$conf_arch" "$chost_desc" "$cflags"
		;;
		'armv7h')
			conf_arch="$1"
			chost_desc="armv7l-unknown-linux-gnueabihf"
			cflags="-march=armv7-a -mfloat-abi=hard -mfpu=vfpv3-d16 "
			preconf_arm "$conf_arch" "$chost_desc" "$cflags"
		;;
		'aarch64')
			conf_arch="$1"
			chost_desc="aarch64-unknown-linux-gnu"
			cflags="-march=armv8-a "
			preconf_arm "$conf_arch" "$chost_desc" "$cflags"
		;;
		'multilib')
			conf_arch='multilib'
			preconf "$conf_arch"
		;;
		*)
			conf_arch='default'
			preconf "$conf_arch"
		;;
	esac

	mirrors_conf="${DATADIR}/pacman-mirrors-${target_branch}.conf"
}

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

check_build(){
	find_pkg $1
	[[ ! -f $1/PKGBUILD ]] && die "Directory must contain a PKGBUILD!"
}

find_pkg(){
	local result=$(find . -type d -name "$1")
	[[ -z $result ]] && die "%s is not a valid package or buildset!" "$1"
}

load_group(){
	local _multi \
		_space="s| ||g" \
		_clean=':a;N;$!ba;s/\n/ /g' \
		_com_rm="s|#.*||g" \
		devel_group='' \
		file=${DATADIR}/base-devel-udev

        info "Loading Group [%s] ..." "$file"

	if ${is_multilib}; then
		_multi="s|>multilib||g"
	else
		_multi="s|>multilib.*||g"
	fi

	devel_group=$(sed "$_com_rm" "$file" \
			| sed "$_space" \
			| sed "$_multi" \
			| sed "$_clean")

        echo ${devel_group}
}

init_base_devel(){
	if ${udev_root};then
		base_packages=( "$(load_group)" )
	else
		if ${is_multilib};then
			base_packages=('base-devel' 'multilib-devel')
		else
			base_packages=('base-devel')
		fi
	fi
}

chroot_create(){
	msg "Creating chroot for [%s] (%s)..." "${target_branch}" "${target_arch}"
	mkdir -p "${work_dir}"
	setarch "${target_arch}" \
		mkchroot ${mkchroot_args[*]} \
		"${work_dir}/root" \
		${base_packages[*]} || abort
}

chroot_clean(){
	msg "Cleaning chroot for [%s] (%s)..." "${target_branch}" "${target_arch}"
	for copy in "${work_dir}"/*; do
		[[ -d ${copy} ]] || continue
		msg2 "Deleting chroot copy %s ..." "$(basename "${copy}")"

		lock 9 "${copy}.lock" "Locking chroot copy '${copy}'"

		if [[ "$(stat -f -c %T "${copy}")" == btrfs ]]; then
			{ type -P btrfs && btrfs subvolume delete "${copy}"; } &>/dev/null
		fi
		rm -rf --one-file-system "${copy}"
	done
	exec 9>&-

	rm -rf --one-file-system "${work_dir}"
}

chroot_update(){
	msg "Updating chroot for [%s] (%s)..." "${target_branch}" "${target_arch}"
	chroot-run ${mkchroot_args[*]} \
			"${work_dir}/${OWNER}" \
			pacman -Syu --noconfirm || abort

}

clean_up(){
	msg "Cleaning up ..."
	msg2 "Cleaning [%s]" "${pkg_dir}"
	find ${pkg_dir} -maxdepth 1 -name "*.*" -delete #&> /dev/null
	if [[ -z $SRCDEST ]];then
		msg2 "Cleaning [source files]"
		find $PWD -maxdepth 1 -name '*.?z?' -delete #&> /dev/null
	fi
}

sign_pkg(){
	su ${OWNER} -c "signfile ${pkg_dir}/$1"
}

move_to_cache(){
	msg2 "Moving [%s] -> [%s]" "${1##*/}" "${pkg_dir}"
	mv $1 ${pkg_dir}/
	${sign} && sign_pkg "${1##*/}"
	chown -R "${OWNER}:users" "${pkg_dir}"
}

archive_logs(){
	local ext=log.tar.xz
	msg2 "Archiving log files %s ..." "$1.$ext"
	tar -cJf $1.$ext $2
	msg2 "Cleaning log files ..."
	find . -maxdepth 1 -name '*.log' -delete
	chown "${OWNER}:users" "$1.$ext"
}

post_build(){
	source PKGBUILD
	local ext='pkg.tar.xz' tarch
	for pkg in ${pkgname[@]};do
		case $arch in
			any) tarch='any' ;;
			*) tarch=${target_arch}
		esac
		local ver=$(get_full_version "$pkg") src
		src=$pkg-$ver-$tarch.$ext
		if [[ -n $PKGDEST ]];then
			move_to_cache "$PKGDEST/$src"
		else
			move_to_cache "$src"
		fi
	done
	if [[ -z $LOGDEST ]];then
		local name=${pkgbase:-$pkgname} ver logsrc archive
		ver=$(get_full_version "$name")
		archive=$name-$ver-${target_arch}
		logsrc=$(find . -maxdepth 1 -name "$archive*.log")
		archive_logs "$archive" "${logsrc[@]}"
	fi
}

chroot_init(){
	local timer=$(get_timer)
	if ${clean_first}; then
		chroot_clean
		chroot_create
	elif [[ ! -d "${work_dir}" ]]; then
		chroot_create
	else
		chroot_update
	fi
	show_elapsed_time "${FUNCNAME}" "${timer}"
}

build_pkg(){
	setarch "${target_arch}" \
		mkchrootpkg ${mkchrootpkg_args[*]} || return 1
		if [ $? -eq 0 ]; then
			post_build
		fi
}

make_pkg(){
	check_build "$1"
	msg "Start building [%s]" "$1"
	cd $1
		build_pkg
	cd ..
	msg "Finished building [%s]" "$1"
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}
