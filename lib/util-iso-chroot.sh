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

configure_hosts(){
    sed -e "s|localhost.localdomain|localhost.localdomain ${hostname}|" -i $1/etc/hosts
}

copy_from_cache(){
    local list="${tmp_dir}"/mhwd-cache.list
    chroot-run \
        -r "${bindmounts_ro[*]}" \
        -w "${bindmounts_rw[*]}" \
        -B "${build_mirror}/${target_branch}" \
        "$1" \
        pacman -v -Syw $2 --noconfirm || return 1
    chroot-run \
        -r "${bindmounts_ro[*]}" \
        -w "${bindmounts_rw[*]}" \
        -B "${build_mirror}/${target_branch}" \
        "$1" \
        pacman -v -Sp $2 --noconfirm > "$list"
    sed -ni '/.pkg.tar.xz/p' "$list"
    sed -i "s/.*\///" "$list"

    msg2 "Copying mhwd package cache ..."
    rsync -v --files-from="$list" /var/cache/pacman/pkg "$1${mhwd_repo}"
}

chroot_create(){
    [[ "${1##*/}" == "rootfs" ]] && local flag="-L"
    setarch "${target_arch}" \
        mkchroot ${mkchroot_args[*]} ${flag} $@
}

chroot_clean(){
    msg "Cleaning up ..."
    for image in "$1"/*fs; do
        [[ -d ${image} ]] || continue
        local name=${image##*/}
        if [[ $name != "mhwdfs" ]];then
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
