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
        ssh !${remote_user}@${shell_url} mkdir -pv ${remote_target}/${remote_project}/${remote_tree}
}

create_subtree(){
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${edition_type}/
	rsync ${rsync_args[*]} /dev/null ${sf_url}/${remote_tree}/
}

sync_dir(){
	cd $1
		load_profile "$1"
		msg "Start upload [$1] ..."
		${remote_create} && create_subtree
		rsync ${rsync_args[*]} ${cache_dir_iso}/ ${sf_url}/${remote_tree}/$1

		msg "Done upload [$1]"
		msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
	cd ..
}

upload(){
	if ${is_buildset};then
		for prof in ${buildlist[@]}; do
			sync_dir "$prof"
		done
	else
		sync_dir "${buildset_iso}"
	fi
}
