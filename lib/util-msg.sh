#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

export LC_MESSAGES=C
export LANG=C

# check if messages are to be printed using color
unset ALL_OFF BOLD BLUE GREEN RED YELLOW CYAN MAGENTA WHITE
if [[ -t 2 ]]; then
	# prefer terminal safe colored and bold text when tput is supported
	if tput setaf 0 &>/dev/null; then
		ALL_OFF="$(tput sgr0)"
		BOLD="$(tput bold)"
		RED="${BOLD}$(tput setaf 1)"
		GREEN="${BOLD}$(tput setaf 2)"
		YELLOW="${BOLD}$(tput setaf 3)"
		BLUE="${BOLD}$(tput setaf 4)"
		MAGENTA="${BOLD}$(tput setaf 5)"
		CYAN="${BOLD}$(tput setaf 6)"
		WHITE="${BOLD}$(tput setaf 7)"
	else
		ALL_OFF="\e[01;00m"
		RED="\e[01;31m"
		GREEN="\e[01;32m"
		YELLOW="\e[01;33m"
		BLUE="\e[01;34m"
		MAGENTA="\e[01;35m"
		CYAN="\e[01;36m"
		WHITE="\e[01;37m"
	fi
fi
readonly ALL_OFF BOLD BLUE GREEN RED YELLOW CYAN MAGENTA WHITE

plain() {
	local mesg=$1; shift
	printf "${WHITE}    ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${WHITE} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
	local mesg=$1; shift
	printf "${BLUE}  ->${ALL_OFF}${WHITE} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg3() {
	local mesg=$1; shift
	printf "${YELLOW} -->${ALL_OFF}${WHITE} ${mesg}${ALL_OFF}\n" "$@" >&2
}

warning() {
	local mesg=$1; shift
	printf "${YELLOW}==> WARNING:${ALL_OFF}${WHITE} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
	local mesg=$1; shift
	printf "${RED}==> ERROR:${ALL_OFF}${WHITE} ${mesg}${ALL_OFF}\n" "$@" >&2
}

stat_busy() {
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${WHITE} ${mesg}...${ALL_OFF}" >&2
}

stat_done() {
	printf "${WHITE}done${ALL_OFF}\n" >&2
}

setup_workdir() {
	[[ -z $WORKDIR ]] && WORKDIR=$(mktemp -d --tmpdir "${0##*/}.XXXXXXXXXX")
}

cleanup() {
	[[ -n $WORKDIR ]] && rm -rf "$WORKDIR"
	exit ${1:-0}
}

abort() {
	error 'Aborting...'
	cleanup 255
}

die() {
	(( $# )) && error "$@"
	cleanup 255
}

lock() {
	eval "exec $1>"'"$2"'
	if ! flock -n $1; then
		stat_busy "$3"
		flock $1
		stat_done
	fi
}

slock() {
	eval "exec $1>"'"$2"'
	if ! flock -sn $1; then
		stat_busy "$3"
		flock -s $1
		stat_done
	fi
}

# trap_abort() {
# 	trap - EXIT INT QUIT TERM HUP
# 	abort
# }
#
# trap_exit() {
# 	local r=$?
# 	trap - EXIT INT QUIT TERM HUP
# 	cleanup $r
# }
#
# trap 'trap_abort' INT QUIT TERM HUP
# trap 'trap_exit' EXIT
