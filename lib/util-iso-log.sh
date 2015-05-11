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
	exit 2
}

run_safe() {
	local restoretrap
	set -e
	set -E
	restoretrap=$(trap -p ERR)
	trap 'error_function $1' ERR
	run_log "$1"
	eval $restoretrap
	set +E
	set +e
}

# $1: function
run_log(){
	local logfile=${work_dir}/${imgname}.log
	logpipe=$(mktemp -u "/tmp/logpipe.XXXXXXXX")
	mkfifo "$logpipe"
	tee "$logfile" < "$logpipe" &
	local teepid=$!
	$1 &> "$logpipe"
	wait $teepid
	rm "$logpipe"
}
