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
        ssh ${shell_url} mkdir -pv ${remote_target}/${remote_project}/${iso_edition}/${dist_release}
}

upload(){
	msg "Start upload ..."
        rsync -av --progress -e ssh ${src_dir}/ ${sf_url}/${iso_edition}/${dist_release}/${profile}
	msg "Done upload"
	msg3 "Time ${FUNCNAME}: $(elapsed_time ${timer_start}) minutes"
}
