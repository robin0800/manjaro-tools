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

create_subtree_ssh(){
	local tree=${remote_target}/${remote_project}/${remote_dir}
        ssh !${remote_user}@${shell_url} [[ ! -d $tree ]] && mkdir -pv $tree
}

create_subtree(){
	msg2 "Create (%s) ..." "${edition}/$1/${dist_release}"
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${edition}/
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${edition}/$1/
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${edition}/$1/${dist_release}/
	msg2 "Done"
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}

prepare_transfer(){
	remote_dir="${edition}/$1/${dist_release}/${arch}"
	src_dir="${run_dir}/${remote_dir}"
}

create_torrent(){
	msg "Create %s.torrent" "$1"
	mktorrent -v -p -l ${piece_size} -a ${tracker_url} -o ${USER_HOME}/$1.torrent ${src_dir}
	msg "Done %s.torrent" "$1"
}

sync_dir(){
	eval_edition "$1"
	prepare_transfer "$1"
	${torrent_create} && create_torrent "$1"
	${remote_create} && create_subtree "$1"
	msg "Start upload [%s] (%s) ..." "$1" "${arch}"
	rsync ${rsync_args[*]} ${src_dir}/ ${sf_url}/${remote_dir}/
	msg "Done upload [%s]" "$1"
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}
