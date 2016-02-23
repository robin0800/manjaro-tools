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
		umount_image "$1"
		plain "Aborting..."
	fi
	exit 2
}

# $1: function
run_log(){
	local func="$1"
	if ${is_log};then
		local logfile=${iso_dir}/$(gen_iso_fn).$func.log shellopts=$(shopt -p)
		logpipe=$(mktemp -u "/tmp/logpipe.XXXXXXXX")
		mkfifo "$logpipe"
		tee "$logfile" < "$logpipe" &
		local teepid=$!
		$func &> "$logpipe"
		wait $teepid
		rm "$logpipe"
		eval "$shellopts"
	else
		"$func"
	fi
}

run_safe() {
	local restoretrap func="$1"
	set -e
	set -E
	restoretrap=$(trap -p ERR)
	trap 'error_function $func' ERR
	run_log "$func"
	eval $restoretrap
	set +E
	set +e
}
