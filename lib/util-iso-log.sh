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

error_function() {
	if [[ -p $logpipe ]]; then
		rm "$logpipe"
	fi
	# first exit all subshells, then print the error
	if (( ! BASH_SUBSHELL )); then
		error "A failure occurred in %s()." "$1"
		plain "Aborting..."
	fi
	for mp in ${work_dir}/{root,${profile},live,mhwd,boot}-image;do
            umount_image "$mp"
        done
	exit 2
}

# $1: function
run_log(){
	local func="$1"
	local tmpfile=/tmp/$(gen_iso_fn).$func.log logfile=${iso_dir}/$func.log
	logpipe=$(mktemp -u "/tmp/logpipe.XXXXXXXX")
	mkfifo "$logpipe"
	tee "$tmpfile" < "$logpipe" &
	local teepid=$!
	$func &> "$logpipe"
	wait $teepid
	rm "$logpipe"
	cat $tmpfile | perl -pe 's/\e\[?.*?[\@-~]//g' > $logfile
	rm "$tmpfile"
}

run_safe() {
	local restoretrap func="$1"
	set -e
	set -E
	restoretrap=$(trap -p ERR)
	trap 'error_function $func' ERR

	if ${is_log};then
		run_log "$func"
	else
		"$func"
	fi

	eval $restoretrap
	set +E
	set +e
}
