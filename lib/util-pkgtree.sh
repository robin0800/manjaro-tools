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
	if [ "$(git log --pretty=%H ...refs/heads/master^)" = "$(git ls-remote origin -h refs/heads/master |cut -f1)" ]; then
		msg "[$1]" && msg2 "up to date"
	else
		msg "[$1]" && msg2 "sync"
		git pull origin master
	fi
}

clone_tree(){
	msg "[$1]" && msg2 "clone"
	git clone $2.git
}

sync_tree_manjaro(){
	cd ${tree_dir}
	for repo in ${repo_tree[@]};do
		if [[ -d packages-${repo} ]];then
			cd packages-${repo}
				sync_tree "${repo}"
			cd ..
		else
			clone_tree "${host_tree}/packages-${repo}"
		fi
	done
	cd ..
}

sync_tree_abs(){
	local repo=abs
	cd ${tree_dir}/${repo}
		if [[ -d packages ]];then
			cd packages
				sync_tree "${repo}"
			cd ..

		else
			clone_tree "${host_tree_abs}"
		fi
	cd ..
}
