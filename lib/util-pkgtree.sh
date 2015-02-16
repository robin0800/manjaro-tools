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

sync_tree(){
	cd ${tree_dir}
	for repo in ${repo_tree[@]};do
		if [[ -d packages-${repo} ]];then
			cd packages-${repo}
				if [ "$(git log --pretty=%H ...refs/heads/master^)" = "$(git ls-remote origin -h refs/heads/master |cut -f1)" ]; then
					msg "[${repo}]"
					msg2 "up to date"
				else
					msg "Syncing ..."
					msg2 "[${repo}]"
					git pull origin master
				fi
			cd ..
		else
			msg "Cloning ..."
			msg2 "[${repo}]"
			git clone ${host_tree}/packages-${repo}.git
		fi
	done
	cd ..
}

sync_tree_abs(){
	cd ${tree_dir}/abs
	if [[ -d packages ]];then
		cd packages
			if [ "$(git log --pretty=%H ...refs/heads/master^)" = "$(git ls-remote origin -h refs/heads/master |cut -f1)" ]; then
				msg "[abs]"
				msg2 "up to date"
			else
				msg "Syncing ..."
				msg2 "[abs]"
				git pull origin master
			fi
		cd ..
	else
		msg "Cloning ..."
		msg2 "[abs]"
		git clone ${host_tree_abs}.git
	fi
	cd ..
}
