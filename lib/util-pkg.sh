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

check_chroot_version(){
	[[ -f ${work_dir}/root/.manjaro-tools ]] && local chroot_version=$(cat ${work_dir}/root/.manjaro-tools)
	msg "chroot version: $chroot_version"
	if [[ ${version} != $chroot_version ]];then
		clean_first=true
	fi
}

check_requirements(){
	[[ -z $(find . -maxdepth 2 -name 'PKGBUILD' -type f) ]] && die "${0##*/} must be run inside a valid PKGBUILD directory!"
	[[ -z $(find $PWD -type d -name "${buildset_pkg}") ]] && die "${buildset_pkg} is not a valid package!"
}

chroot_create(){
	msg "Creating chroot for [${branch}] (${arch})..."
	mkdir -p "${work_dir}"
	setarch "${arch}" mkchroot \
			${mkchroot_args[*]} \
			"${work_dir}/root" \
			${base_packages[*]} || abort
}

chroot_clean(){
	for copy in "${work_dir}"/*; do
		[[ -d ${copy} ]] || continue
		msg2 "Deleting chroot copy '$(basename "${copy}")'..."

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
	msg "Updating chroot for [${branch}] (${arch})..."
	chroot-run ${mkchroot_args[*]} \
			"${work_dir}/${OWNER}" \
			pacman -Syu --noconfirm || abort

}

clean_up(){
	msg "Cleaning up ..."
	find ${cache_dir_pkg} -maxdepth 1 -name "*.*" -delete #&> /dev/null
	[[ -z $SRCDEST ]] && find $PWD -maxdepth 1 -name '*.?z?' -delete #&> /dev/null
}

blacklist_pkg(){
	msg "Removing ${blacklist[@]}..."
	for item in "${blacklist[@]}"; do
		chroot-run $1/root pacman -Rdd "$item" --noconfirm
	done
}

prepare_cachedir(){
	prepare_dir "${cache_dir_pkg}"
	chown -R "${OWNER}:users" "${cache_dir_pkg}"
}

sign_pkg(){
	su ${OWNER} -c "signpkg ${cache_dir_pkg}/$1"
}

run_post_build(){
	local _arch=${arch}
	source PKGBUILD
	local ext='pkg.tar.xz' pinfo loglist=() lname
	if [[ ${arch} == "any" ]]; then
		pinfo=${pkgver}-${pkgrel}-any
	else
		pinfo=${pkgver}-${pkgrel}-${_arch}
	fi
	if [[ -n $PKGDEST ]];then
		if [[ -n ${pkgbase} ]];then
			for p in ${pkgname[@]};do
				mv $PKGDEST/${p}-${pinfo}.${ext} ${cache_dir_pkg}/
				${sign} && sign_pkg ${p}-${pinfo}.${ext}
				loglist+=("*$p*.log")
				lname=${pkgbase}
			done
		else
			mv $PKGDEST/${pkgname}-${pinfo}.${ext} ${cache_dir_pkg}/
			${sign} && sign_pkg ${pkgname}-${pinfo}.${ext}
			loglist+=("*${pkgname}*.log")
			lname=${pkgname}
		fi
	else
		mv *.${ext} ${cache_dir_pkg}
		${sign} && sign_pkg ${pkgname}-${pinfo}.${ext}
		loglist+=("*${pkgname}*.log")
		lname=${pkgname}
	fi
	chown -R "${OWNER}:users" "${cache_dir_pkg}"
	if [[ -z $LOGDEST ]];then
		tar -cjf ${lname}-${pinfo}.log.tar.xz ${loglist[@]}
		find $PWD -maxdepth 1 -name '*.log' -delete #&> /dev/null
	fi
	arch=$_arch
}

make_pkg(){
	msg "Start building [$1]"
	cd $1
		for p in ${blacklist_trigger[@]}; do
			[[ $1 == $p ]] && blacklist_pkg "${work_dir}"
		done
		setarch "${arch}" \
			mkchrootpkg ${mkchrootpkg_args[*]} -- ${makepkg_args[*]} || eval "$2"
		run_post_build
	cd ..
	msg "Finished building [$1]"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}

chroot_build(){
	if ${is_buildset};then
		for pkg in $(cat ${sets_dir_pkg}/${buildset_pkg}.set); do
			check_sanity "$pkg/PKGBUILD" "break"
			make_pkg "$pkg" "break"
		done
	else
		check_sanity "${buildset_pkg}/PKGBUILD" 'die "Not a valid package!"'
		make_pkg "${buildset_pkg}" "abort"
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
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer}) minutes"
}
