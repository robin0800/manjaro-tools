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

create_release(){
    msg "Create release (%s) ..." "${dist_release}"
    rsync ${rsync_args[*]} /dev/null ${url}/${dist_release}/
    show_elapsed_time "${FUNCNAME}" "${timer_start}"
    msg "Done (%s)" "${dist_release}"
}

get_edition(){
    local result=$(find ${run_dir} -maxdepth 3 -name "$1") path
    [[ -z $result ]] && die "%s is not a valid profile or build list!" "$1"
    path=${result%/*}
    path=${path%/*}
    echo ${path##*/}
}

connect(){
    local home="/home/frs/project"
    echo "${account},$1@frs.${host}:${home}/$1"
}

# get_project(){
#     local project
#     case "$1" in
#         'community') project='manjarolinux-community' ;;
#         'manjaro') project='manjarolinux' ;;
#         'sonar') project='sonargnulinux' ;;
#         # manjarotest
#         # manjarotest-community
#     esac
#     echo ${project}
# }

gen_webseed(){
    local webseed seed="$1"
    local mirrors=('heanet' 'jaist' 'netcologne' 'iweb' 'kent')
    for m in ${mirrors[@]};do
        webseed=${webseed:-}${webseed:+,}"http://${m}.dl.${seed}"
    done
    echo ${webseed}
}

make_torrent(){
    for iso in $(ls {src_dir}/${1}/*.iso);do
        local iso_dir="${cache_dir_iso}/${edition}/${1}/${dist_release}"
        local seed=${host}/project/${project}/${1}/${dist_release}/${iso}
        local mktorrent_args=(-v -p -l ${piece_size} -a ${tracker_url} -w $(gen_webseed ${seed}))
        local fn=${iso}.torrent

        msg2 "Creating (%s) ..." "${fn}"
        [[ -f ${iso_dir}/${fn} ]] && rm ${iso_dir}/${fn}
        mktorrent ${mktorrent_args[*]} -o ${iso_dir}/${fn} ${iso_dir}/${iso}
    done
}

prepare_transfer(){
    edition=$(get_edition $1)
#     project=$(get_project "${edition}")
    url=$(connect "${project}")

    target_dir="$1/${dist_release}"
    src_dir="${run_dir}/${edition}/${target_dir}"
    ${torrent} && make_torrent "$1"
}

sync_dir(){
    prepare_transfer "$1"
    if ${release} && ! ${exists};then
        create_release
        exists=true
    fi
    msg "Start upload [%s] ..." "$1"
    rsync ${rsync_args[*]} ${src_dir}/ ${url}/${target_dir}/
    msg "Done upload [%s]" "$1"
    show_elapsed_time "${FUNCNAME}" "${timer_start}"
}
