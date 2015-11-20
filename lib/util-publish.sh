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
        ssh !${remote_user}@${shell_url} mkdir -pv ${remote_target}/${remote_project}/${cache_tree}
}

sync_dir(){
	msg "Start upload [$1] ..."
	local empty=/tmp/deploy
        rsync -aR -e ssh $empty/ ${sf_url}/${iso_edition}/
        rsync -aR -e ssh $empty/ ${sf_url}/${cache_tree}/
        rsync -avP --progress -e ssh ${src_dir}/ ${sf_url}/${cache_tree}/$1

	msg "Done upload"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}

set_src_dir(){
	cache_tree=iso/${iso_edition}/${dist_release}
        src_dir=${cache_dir}/${cache_tree}/$1
}

upload(){
	if ${is_buildset};then
		for prof in $(cat ${sets_dir_iso}/$1.set); do
                        eval_edition "$prof"
                        set_src_dir "$prof"
			sync_dir "$prof"
		done
	else
                eval_edition "$1"
                set_src_dir "$1"
		sync_dir "$1"
	fi
}
