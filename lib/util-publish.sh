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

connect(){
    ${alt_storage} && server="storage-in" || server="storage"
    local storage="@${server}.osdn.net:/storage/groups/m/ma/"
    echo "${account}${storage}${project}"
}

make_torrent(){
    find ${src_dir} -type f -name "*.torrent" -delete

    if [[ -n $(find ${src_dir} -type f -name "*.iso") ]]; then
        for iso in $(ls ${src_dir}/*.iso);do
            local seed=https://${host}/projects/${project}/storage/${profile}/${dist_release}/${iso##*/}
            local mktorrent_args=(-c "${torrent_meta}" -p -l ${piece_size} -a ${tracker_url} -w ${seed})
            ${verbose} && mktorrent_args+=(-v)
            msg2 "Creating (%s) ..." "${iso##*/}.torrent"
            mktorrent ${mktorrent_args[*]} -o ${iso}.torrent ${iso}
        done
    fi
}

prepare_transfer(){
    profile="$1"
    hidden="$2"
    edition=$(get_edition "${profile}")
    [[ -z ${project} ]] && project="$(get_project)"
    url=$(connect)

    target_dir="${profile}/${dist_release}"
    src_dir="${run_dir}/${edition}/${target_dir}"

    ${hidden} && target_dir="${profile}/.${dist_release}"
    ${torrent} && make_torrent
}

sync_dir(){
    cont=1
    max_cont=10
    prepare_transfer "$1" "${hidden}"
    msg "Start upload [%s] to [%s] ..." "$1" "${project}"
    while [[ $cont -le $max_cont  ]]; do 
    rsync ${rsync_args[*]} ${src_dir}/ ${url}/${target_dir}/
        if [[ $? != 0 ]]; then
            cont=$(($cont + 1))
            msg "Failed to upload [%s] now try again: try $cont of $max_cont" "$1"
            sleep 2
        else
            cont=$(($max_cont + 1))
            msg "Done upload [%s]" "$1"
            show_elapsed_time "${FUNCNAME}" "${timer_start}"
        fi
    done
}
