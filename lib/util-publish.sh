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

connect_shell(){
    local shell="@shell.osdn.net:/home/groups/m/ma/"
    echo "${account}${shell}${project}"
}

make_torrent(){
    find ${src_dir} -type f -name "*.torrent" -delete

    if [[ -n $(find ${src_dir} -type f -name "*.iso") ]]; then
        isos=$(ls ${src_dir}/*.iso)
        for iso in ${isos}; do
            local seed=https://${host}/dl/${project}/${iso##*/}
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
    server=$(connect)

    webshell=$(connect_shell)
    htdocs="htdocs/${profile}"

    target_dir="${profile}/${dist_release}"
    src_dir="${run_dir}/${edition}/${target_dir}"

    ${hidden} && target_dir="${profile}/.${dist_release}"
}

start_agent(){
    msg2 "Initializing SSH agent..."
    ssh-agent | sed 's/^echo/#echo/' > "$1"
    chmod 600 "$1"
    . "$1" > /dev/null
    ssh-add
}

ssh_add(){
    local ssh_env="$USER_HOME/.ssh/environment"

    if [ -f "${ssh_env}" ]; then
         . "${ssh_env}" > /dev/null
         ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
            start_agent ${ssh_env};
        }
    else
        start_agent ${ssh_env};
    fi
}

sync_dir(){
    count=1
    max_count=10
    prepare_transfer "$1" "${hidden}"

    ${torrent} && make_torrent
    ${sign} && signiso "${src_dir}"
    ${ssh_agent} && ssh_add

    msg "Start upload [%s] to [%s] ..." "$1" "${project}"

    while [[ $count -le $max_count ]]; do
    rsync ${rsync_args[*]} --exclude '.latest*' --exclude 'index.html' --exclude 'links.txt' ${src_dir}/ ${server}/${target_dir}/
        if [[ $? != 0 ]]; then
            count=$(($count + 1))
            msg "Upload failed. retrying (%s/%s) ..." "$count" "$max_count"
            sleep 2
        else
            count=$(($max_count + 1))

            # sync latest files
            #   manjaro.osdn.io
            #   manjaro-community.osdn.io
            sync_web_shell

            msg "Done upload [%s]" "$1"
            show_elapsed_time "${FUNCNAME}" "${timer_start}"
        fi
    done

}

sync_web_shell(){
    if [[ -f "${src_dir}/.latest" ]]; then
        LINKS="links.txt"
        LATEST_ISO=$(sed -e 's/\"/\n/g' < "${src_dir}/.latest" | grep -Eo 'http.*iso$' -m1 | awk '{split($0,x,"/"); print x[6]}')
        PKGLIST="${LATEST_ISO/.iso/-pkgs.txt}"

        [[ -f "${src_dir}/.latest" ]] && sync_latest_html
        [[ -f "${src_dir}/.latest.php" ]] && sync_latest_php

        [[ -f "${src_dir}/${LATEST_ISO}.torrent" ]] && sync_latest_torrent
        [[ -f "${src_dir}/${LATEST_ISO}.sig" ]] && sync_latest_signature
        [[ -f "${src_dir}/${LATEST_ISO}.sha1" ]] && sync_latest_checksum_sha1
        [[ -f "${src_dir}/${LATEST_ISO}.sha256" ]] && sync_latest_checksum_sha256
        [[ -f "${src_dir}/${PKGLIST}" ]] && sync_latest_pkg_list

        #sync_latest_index

        rm -f "${src_dir}/latest"
        rm -f "${src_dir}/latest.php"
        rm -f "${src_dir}/*.iso.torrent"
        rm -f "${src_dir}/*.iso.sig"
        rm -f "${src_dir}/*.iso.sha1"
        rm -f "${src_dir}/*.iso.sha256"
    fi
}

sync_latest_pkg_list(){
    msg2 "Uploading package list ..."
    local pkglist="latest-pkgs.txt"
    scp "${src_dir}/${PKGLIST}" "${webshell}/${htdocs}/${pkglist}"
}

sync_latest_checksum_sha256(){
    msg2 "Uploading sha256 checksum file ..."
    local filename="${LATEST_ISO}.sha256"
    local checksum_file="latest.sha256"
    scp "${src_dir}/${filename}" "${webshell}/${htdocs}/${checksum_file}"
}

sync_latest_checksum_sha1(){
    msg2 "Uploading sha1 checksum file ..."
    local filename="${LATEST_ISO}.sha1"
    local checksum_file="latest.sha1"
    scp "${src_dir}/${filename}" "${webshell}/${htdocs}/${checksum_file}"
}

sync_latest_signature(){
    msg2 "Uploading signature file ..."
    local filename="${LATEST_ISO}.sig"
    local signature="latest.sig"
    scp "${src_dir}/${filename}" "${webshell}/${htdocs}/${signature}"
}

sync_latest_torrent(){
    msg2 "Uploading torrent file ..."
    local filename="${LATEST_ISO}.torrent"
    local torrent="latest.torrent"
    scp "${src_dir}/${filename}" "${webshell}/${htdocs}/${torrent}"
}

sync_latest_php(){
    msg2 "Uploading php redirector ..."
    local php="latest.php"
    scp "${src_dir}/.${php}" "${webshell}/${htdocs}/${php}"
}

sync_latest_html(){
    msg2 "Uploading url redirector ..."
    local html="latest"
    scp "${src_dir}/.latest" "${webshell}/${htdocs}/${html}"
}
