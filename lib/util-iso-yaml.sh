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

# check_yaml(){
# 	result=$(python -c 'import yaml,sys;yaml.safe_load(sys.stdin)' < $1)
# 	msg2 "Checking validity [%s] ..." "${1##*/}"
# 	[[ $? -ne 0 ]] && error "yaml error: %s [msg: %s]"  "$1" "${result}"
# }

get_preset(){
	local p=${tmp_dir}/${kernel}.preset kvmaj kvmin digit
	cp ${DATADIR}/linux.preset $p
	digit=${kernel##linux}
	kvmaj=${digit:0:1}
	kvmin=${digit:1}

	sed -e "s|@kvmaj@|$kvmaj|g" \
	    -e "s|@kvmin@|$kvmin|g" \
	    -e "s|@arch@|${target_arch}|g"\
	    -i $p

	echo $p
}

write_calamares_yaml(){
	configure_calamares "${yaml_dir}" "$(get_preset)"
# 	for conf in "${yaml_dir}"/etc/calamares/modules/*.conf "${yaml_dir}"/etc/calamares/settings.conf; do
# 		check_yaml "$conf"
# 	done
}

write_netgroup_yaml(){
	msg2 "Writing %s ..." "${2##*/}"
	echo "- name: '$1'" > "$2"
	echo "  description: '$1'" >> "$2"
	echo "  selected: false" >> "$2"
	echo "  hidden: false" >> "$2"
	echo "  packages:" >> "$2"
	for p in ${packages[@]};do
		echo "       - $p" >> "$2"
	done
# 	check_yaml "$2"
}

write_pacman_group_yaml(){
	packages=$(pacman -Sgq "$1")
	write_netgroup_yaml "$1" "${cache_dir_netinstall}/$1.yaml"
}

prepare_check(){
	profile=$1
	edition=$(get_edition ${profile})
	profile_dir=${run_dir}/${edition}/${profile}
	check_profile
	load_profile_config "${profile_dir}/profile.conf"

	yaml_dir=${cache_dir_netinstall}/${profile}/${target_arch}

	prepare_dir "${yaml_dir}"
	chown "${OWNER}:${OWNER}" "${yaml_dir}"
}

gen_fn(){
	echo ${yaml_dir}/$1-${target_arch}-${initsys}.yaml
}

make_profile_yaml(){
	prepare_check "$1"
	load_pkgs "${profile_dir}/Packages-Root"
	write_netgroup_yaml "$1" "$(gen_fn "Packages-Root")"
	if [[ -f "${packages_custom}" ]]; then
		load_pkgs "${packages_custom}"
		write_netgroup_yaml "$1" "$(gen_fn "${packages_custom##*/}")"
	fi
	${calamares} && write_calamares_yaml "$1"
	user_own "${yaml_dir}"
	reset_profile
	unset yaml_dir
}
