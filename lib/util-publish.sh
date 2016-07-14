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
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${dist_release}/
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
	msg "Done (%s)" "${dist_release}"
}

get_edition(){
	local result=$(find ${run_dir} -maxdepth 3 -name "$1") path
# 	[[ -z $result ]] && die "%s is not a valid profile or build list!" "$1"
	path=${result%/*}
	path=${path%/*}
	echo ${path##*/}
}

prepare_transfer(){
	local edition=$(get_edition $1)
	set_remote_project "${edition}"
	sf_url=${remote_user},${remote_project}@frs.${remote_url}:${remote_target}/${remote_project}

	remote_dir="${dist_release}/$1"
	src_dir="${run_dir}/${edition}/${remote_dir}"
}

sync_dir(){
	prepare_transfer "$1"
	msg "Start upload [%s] ..." "$1"
	rsync ${rsync_args[*]} ${src_dir}/ ${sf_url}/${remote_dir}/
	msg "Done upload [%s]" "$1"
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}
