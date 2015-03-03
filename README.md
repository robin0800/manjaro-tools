manjaro-tools
=============

Manjaro-tools-0.9.7

User manual

###1. manjaro-tools.conf

manjaro-tools.conf is the central configuration file for manjaro-tools.
By default, the config is installed in

~~~
/etc/manjaro-tools/manjaro-tools.conf
~~~

A user manjaro-tools.conf can be placed in

~~~
$HOME/.config/manjaro-tools.conf
~~~

If the userconfig is present, manjaro-tools will load the userconfig values, however, if variables have been set in the systemwide

~~~
/etc/manjaro-tools/manjaro-tools.conf
~~~

these values take precedence over the userconfig.
Best practise is to leave systemwide file untouched.
By default it is commented and shows just initialization values done in code.

Tools configuration is done in manjaro-tools.conf or by args.
Specifying args will override manjaro-tools.conf settings.

~~~
######################################################
################ manjaro-tools.conf ##################
######################################################

# unset defaults to given value
# branch=stable

# unset defaults to given value
# arch=$(uname -m)

# cache dir where buildpkg or buildiso cache packages
# cache_dir=/var/cache/manjaro-tools

################ buildtree ###############

# manjaro package tree
# repo_tree=('core' 'extra' 'community' 'multilib' 'openrc')

# host_tree=https://github.com/manjaro

# host_tree_abs=https://projects.archlinux.org/git/svntogit

################ buildpkg ################

# default chroot path
# chroots_pkg=/opt/buildpkg

# custom path to pkg sets
# sets_dir_pkg=/etc/manjaro-tools/sets/pkg

# default pkg buildset; name without .set extension
# buildset_pkg=default

# custom build mirror server
# build_mirror=http://mirror.netzspielplatz.de/manjaro/packages

# Next settings are only useful if you compile packages against eudev

# default packages to trigger blacklist
# blacklist_trigger=('eudev' 'upower-pm-utils' 'eudev-systemdcompat')

# default blacklisted packages to remove from chroot
# blacklist=('libsystemd')

################ buildiso ################

# default work dir where the image chroots are located
# chroots_iso=/opt/buildiso

# custom path to iso sets
# sets_dir_iso=/etc/manjaro-tools/sets/iso

# default iso buildset; name without .set extension
# buildset_iso=default

# unset defaults to given value
# iso_version=0.9.0

# unset defaults to given value
# branding="MJRO"

# unset defaults to given value, specify a date here of have it automatically set
# manjaro_version="$(date +%Y.%m)"

# unset defaults to given value
# install_dir=manjaro

# unset defaults to given value
# manjaroiso="manjaroiso"

# unset defaults to value sourced from /etc/lsb-release
# code_name="Bellatrix"

# unset defaults to given value
# img_name=manjaro

# unset defaults to given value
# compression=xz

# valid: md5, sha1, sha256, sha384, sha512
# checksum_mode=md5
~~~

####Config files in iso profiles

Each iso profile must have these files or symlinks to shared:


* profile.conf

~~~
##########################################
###### use this file in the profile ######
##########################################

# possible values: openrc,systemd
# initsys="systemd"

# displaymanager="lightdm"

################ install ################

# unset defaults to given value
# manjaro_kernel="linux319"

# unset defaults to given value
# efi_boot_loader="grub"

# unset defaults to given value
# plymouth_theme=manjaro-elegant

# unset defaults to given values
# names must match systemd service names
# start_systemd=('bluetooth' 'cronie' 'ModemManager' 'NetworkManager' 'org.cups.cupsd' 'tlp' 'tlp-sleep')

# unset defaults to given values,
# names must match openrc service names
# start_openrc=('acpid' 'bluetooth' 'consolekit' 'cronie' 'cupsd' 'dbus' 'syslog-ng' 'NetworkManager')

################# livecd #################

# unset defaults to given value
# hostname="manjaro"

# unset defaults to given value
# username="manjaro"

# unset defaults to given value
# password="manjaro"

# unset defaults to given values
# addgroups="video,audio,power,disk,storage,optical,network,lp,scanner,wheel"

# unset defaults to given values
# names must match systemd service names
# services in start_systemd array don't need to be listed here
# start_systemd_live=('livecd' 'mhwd-live' 'pacman-init' 'pacman-boot')

# unset defaults to given values,
# names must match openrc service names
# services in start_openrc array don't need to be listed here
# start_openrc_live=('livecd' 'mhwd-live' 'pacman-init' 'pacman-boot')
~~~

* Packages
Contains root image packages
ideally no xorg

* Packages-Custom/desktop
Contains the custom image packages
desktop environment packages go here

* Packages-Xorg
Contains the Xorg package repo

* Packages-Lng
Contains the language packages repo

* Packages-Livecd
Contains packages you only want on livecd but not installed on the target system with installer
default files are in shared folder and can be symlinked or defined in a real file

###### optional custom pacman.conf in profile

* for i686

~~~
pacman-default.conf
~~~

* for x86_64

~~~
pacman-multilib.conf
~~~

If you need a custom livecd-overlay, create overlay-livecd folder in  profile, and  symlink from shared/overlay-livecd/your_selection to the overlay-livecd folder.

###2. buildpkg

buildpkg is the chroot build script oi manjaro-tools.
It it run in a abs/pkgbuilds directory which contains directories with PKGBUILD.

######manjaro-tools.conf supports the makepkg.conf variables

####Arguments

~~~
$ buildpkg -h
Usage: buildpkg [options] [--] [makepkg args]
    -p <pkg>           Set or pkg [default: default]
    -a <arch>          Arch [default: x86_64]
    -b <branch>        Branch [default: unstable]
    -r <dir>           Chroots directory
                       [default: /build/buildpkg]
    -c                 Recreate chroot
    -w                 Clean up
    -n                 Install and run namcap check
    -s                 Sign packages
    -q                 Query settings and pretend build
    -h                 This help
~~~

######* build sysvinit package for both arches and branch testing:

* i686(buildsystem is x86_64)

~~~
buildpkg -p sysvinit -a i686 -b testing -cwsn
~~~

* for x86_64

~~~
buildpkg -p sysvinit -b testing -cswn
~~~

You can drop the branch arg if you set the branch in manjaro-tools.conf
the arch can also be set in manjaro-tools.conf, but under normal conditions, it is better to specify the non native arch by -a parameter.

######* -c
removes the chroot dir
If the -c parameter is not used, buildpkg will update the existing chroot or create a new one if none is present.
######* -w
cleans pkgcache, and logfiles
######* -s
signs the package when built
######* -n
installs the built package in the chroot and runs a namcap check

###3. buildiso

buildiso is used to build manjaro-iso-profiles. It is run insde the profiles folder.

#####Packages for livecd only:

* manjaro-livecd-cli-installer
* manjaro-livecd-openrc
* manjaro-livecd-systemd

####Arguments

~~~
$ buildiso -h
Usage: buildiso [options]
    -p <profile>       Buildset or profile [default: default]
    -a <arch>          Arch [default: x86_64]
    -b <branch>        Branch [default: unstable]
    -r <dir>           Chroots directory
                       [default: /build/buildiso]
    -w                 Disable clean iso cache
    -c                 Disable clean work dir
    -x                 Disable clean xorg cache
    -l                 Disable clean lng cache
    -i                 Build images only
    -s                 Generate iso only
                       Requires pre built images (-i)
    -q                 Query settings and pretend build
    -h                 This help
~~~

######* build xfce iso profile for both arches and branch testing on x86_64 build system

* i686 (buildsystem is x86_64)

~~~
buildiso -p xfce -a i686 -b testing
~~~

* for x86_64

~~~
buildiso -p xfce -b testing
~~~

The branch can be defined also in manjaro-tools.conf, but a manual parameter will always override conf settings.

####Special parameters

######* -i
Build images only will stop after all packages have been installed. No iso sqfs compression will be executed
######* -s
Use this to sqfs compress the chroots if you previously used -i.
######* -x
By default, xorg package cache is cleaned on every build. Disabling the xorg cache cleaning will result in no dowload again for xorg drivers and the cache is used.
######* -l
Disable lng cache, by default lng cache is cleaned on every build. Uning this option will enable lng packages from cache rather than downloading them again.

###4. mkset

buildpkg and buildiso support building from buildsets

Default location of sets is:

~~~
/etc/manjaro-tools/manjaro-tools/sets/pkg
/etc/manjaro-tools/manjaro-tools/sets/iso
~~~

but it can be configured in the manjaro-tools.conf file.

mkset is a little helper tool to easily create buildsets.
It is run inside the abs/pkgbuilds or iso profiles directory.

####Arguments

~~~
$ mkset -h
Usage: mkset [options]
    -c <name>   Create set
    -r <name>   Remove set
    -s <name>   Show set
    -i          Iso mode
    -q          Query sets
    -h          This help
~~~

######* create a pkg buildset for lxqt

~~~
mkset -c lxqt-0.8
~~~

######* create a iso buildset

~~~
mkset -ic manjaro-0.9.0
~~~

The buildset name should not be a name of a package or profile!
Else buildpkg/buildiso won't recognize the build list and will only build the package/profile specified. The -p arg handles set and package/profile name.

If you create a buildset manually, the buildset must have a .set extension.

* Examples:

~~~
/etc/manjaro-tools/sets/pkg/lxqt-0.8.set
/etc/manjaro-tools/sets/iso/manjaro-0.9.0.set
~~~

###5. buildtree

buildtree is a little tools to sync arch abs and manjaro packages git repos.

####Arguments

~~~
$ buildtree -h
Usage: buildtree [options]
    -s            Sync manjaro tree
    -a            Sync arch abs
    -c            Clean package tree
    -q            Query settings
    -h            This help
~~~

######* sync arch and manjaro trees

~~~
buildtree -as
~~~
