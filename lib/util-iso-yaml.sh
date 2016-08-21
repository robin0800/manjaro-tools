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

import ${LIBDIR}/util-iso.sh
import ${LIBDIR}/util-iso-calamares.sh

check_yaml(){
	result=$(python -c 'import yaml,sys;yaml.safe_load(sys.stdin)' < $1)
	[[ -n ${result} ]] && error "yaml error: %s [msg: %s]"  "$1" "${result}"
}

write_netgroup_yaml(){
	echo "- name: '$1'" > "$2"
	echo "  description: '$1'" >> "$2"
	echo "  selected: false" >> "$2"
	echo "  hidden: false" >> "$2"
	echo "  packages:" >> "$2"
	for p in ${packages[@]};do
		echo "       - $p" >> "$2"
	done
	check_yaml "$2"
}

prepare_profile(){
	profile=$1
	edition=$(get_edition ${profile})
	profile_dir=${run_dir}/${edition}/${profile}
	check_profile
	load_profile_config "${profile_dir}/profile.conf"

	yaml_dir=${cache_dir_netinstall}/${profile}

	prepare_dir "${yaml_dir}"
	chown "${OWNER}:${OWNER}" "${yaml_dir}"
}

write_calamares_yaml(){
	configure_calamares "${yaml_dir}"
	for conf in "${yaml_dir}"/etc/calamares/modules/*.conf "${yaml_dir}"/etc/calamares/settings.conf; do
		check_yaml "$conf"
	done
}

make_profile_yaml(){
	prepare_profile "$1"
	load_pkgs "${profile_dir}/Packages-Root"
	yaml=${yaml_dir}/root-${target_arch}-${initsys}.yaml
	write_netgroup_yaml "$1" "${yaml}"
	if [[ -f "${packages_custom}" ]]; then
		load_pkgs "${packages_custom}"
		yaml=${yaml_dir}/desktop-${target_arch}-${initsys}.yaml
		write_netgroup_yaml "$1" "${yaml}"
	fi
	${calamares} && write_calamares_yaml "$1"
	user_own "${yaml_dir}"
	reset_profile
	unset yaml
	unset yaml_dir
}
