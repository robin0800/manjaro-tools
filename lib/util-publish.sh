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
        ssh !${remote_user}@${shell_url} mkdir -pv ${remote_target}/${remote_project}/${edition_type}/${dist_release}
}

sync_dir(){
	msg "Start upload [$1] ..."
	if ${remote_create}; then
		local empty=/tmp/deploy
		rsync -aR -e ssh $empty/ ${sf_url}/${edition_type}/
		rsync -aR -e ssh $empty/ ${sf_url}/${edition_type}/${dist_release}/
        fi
        rsync -avP --progress -e ssh ${cache_dir_iso}/ ${sf_url}/${edition_type}/${dist_release}/$1

	msg "Done upload [$1]"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}

upload(){
	if ${is_buildset};then
		for prof in $(cat ${sets_dir_iso}/$1.set); do
			cd $prof
				load_profile "$prof"
				sync_dir "$prof"
			cd ..
		done
	else
		cd $1
			load_profile "$1"
			sync_dir "$1"
		cd ..
	fi
}
