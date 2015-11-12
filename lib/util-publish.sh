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

remote_login(){
	ssh -t ${shell_url} create
	# need a input param here for profile
	create_server_tree
	exit
}

create_server_tree(){
	# need to establish tree
	mkdir -pv ${dist_release}/$isotype
}

upload(){
	msg "Start upload ..."
	if ${is_sf};then
		#sshpass -f ${remote_pwd} remote_login
		local files=$(ls ${cache_dir_iso})
		sshpass -f ${remote_pwd} rsync -vP  --progress -e ssh $files ${sf_url}
	else
		msg3 "Do something here if not sf"
	fi
	msg "Done upload"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}
