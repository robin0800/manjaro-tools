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

set_mhwd_multilib(){
	chroot-run $1/root mhwd-gpu --setgl mesa
}

prepare_cachedir(){
	prepare_dir "${cache_dir_pkg}"
	chown -R "${OWNER}:users" "${cache_dir_pkg}"
}

move_pkg(){
	local ext='pkg.tar.xz'
	if [[ -n $PKGDEST ]];then
		if [[ -n $pkgbase ]];then
			for p in ${pkgname[@]};do
				mv $PKGDEST/$p*.${ext} ${cache_dir_pkg}/
			done
		else
			mv $PKGDEST/$pkgname*.${ext} ${cache_dir_pkg}/
		fi
	else
		mv *.${ext} ${cache_dir_pkg}
	fi
	chown -R "${OWNER}:users" "${cache_dir_pkg}"
}

archive_logs(){
	local ext='log.tar.xz'
	if [[ -n $pkgbase ]];then
		tar -cJf $PWD/$pkgbase-$pkgver-$pkgrel-${CARCH}.${ext} *.log
	else
		tar -cJf $PWD/$pkgname-$pkgver-$pkgrel-${CARCH}.${ext} *.log
	fi
	find $PWD -maxdepth 1 -name '*.log' -delete #&> /dev/null
}

make_pkg(){
	msg "Start building [$1]"
	cd $1
		for p in ${blacklist_trigger[@]}; do
			[[ $1 == $p ]] && blacklist_pkg "${work_dir}"
		done
		${is_multilib} && set_mhwd_multilib
		setarch "${arch}" \
			mkchrootpkg ${mkchrootpkg_args[*]} -- ${makepkg_args[*]} || eval "$2"
		source PKGBUILD
		move_pkg
		[[ -z $LOGDEST ]] && archive_logs
	cd ..
	msg "Finished building [$1] in $(elapsed_time ${timer_start}) minutes"
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
	if ${clean_first}; then
		chroot_clean
		chroot_create
	elif [[ ! -d "${work_dir}" ]]; then
		chroot_create
	else
		chroot_update
	fi
}

sign_pkgs(){
	cd ${cache_dir_pkg}
	su "${OWNER}" <<'EOF'
signpkgs
EOF
}
