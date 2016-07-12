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

# create_subtree_ssh(){
# 	local tree=${remote_target}/${remote_project}/${remote_dir}
#         ssh !${remote_user}@${shell_url} [[ ! -d $tree ]] && mkdir -pv $tree
# }

# gen_iso_fn(){
# 	local vars=() name
# 	vars+=("${iso_name}")
# 	[[ -n ${1} ]] && vars+=("${1}")
# 	[[ ${edition} == 'community' ]] && vars+=("${edition}")
# 	[[ ${initsys} == 'openrc' ]] && vars+=("${initsys}")
# 	vars+=("${dist_release}")
# 	vars+=("${target_arch}")
# 	for n in ${vars[@]};do
# 		name=${name:-}${name:+-}${n}
# 	done
# 	echo $name
# }
#
# create_torrent(){
# 	msg "Create %s.torrent" "$1"
# 	local name=$(gen_iso_fn "$1")
# 	[[ -f ${src_dir}/${name}.torrent ]] && rm ${src_dir}/${name}.torrent
# 	if [[ "${edition}" == 'official' ]];then
# 		local webseed_url="http://${remote_url}/projects/${remote_project}/${remote_dir}/${name}.iso"
# 		mktorrent_args+=(-w ${webseed_url})
# 	fi
# 	mktorrent ${mktorrent_args[*]} -o ${src_dir}/${name}.torrent ${src_dir}
# 	msg "Done %s.torrent" "$1"
# }

create_release(){
	msg2 "Create release (%s) ..." "${dist_release}"
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${dist_release}/
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}

get_edition(){
	local result=$(find ${run_dir} -maxdepth 3 -name "$1") path
	[[ -z $result ]] && die "%s is not a valid profile or build list!" "$1"
	path=${result%/*}
	path=${path%/*}
	echo ${path##*/}
}

prepare_transfer(){
	edition=$(get_edition $1)
	case ${edition} in
		'community'|'minimal') remote_project='manjaro-community' ;;
		'official') remote_project='manjaro' ;;
	esac
	sf_url=${remote_user},${remote_project}@frs.${remote_url}:${remote_target}/${remote_project}

# 	shell_url=${remote_user},${remote_project}@shell.${remote_url}

	remote_dir="${dist_release}/$1"
	src_dir="${run_dir}/${edition}/${remote_dir}"
}

sync_dir(){
	prepare_transfer "$1"
# 	${torrent_create} && create_torrent "$1"
	${release_create} && create_release "$1"
	msg "Start upload [%s] ..." "$1"
	rsync ${rsync_args[*]} ${src_dir}/ ${sf_url}/${remote_dir}/
	msg "Done upload [%s]" "$1"
	show_elapsed_time "${FUNCNAME}" "${timer_start}"
}
