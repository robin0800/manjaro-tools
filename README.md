manjaro-tools
=============

Manjaro-tools-0.9.9

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

# default branch
# branch=stable

# default arch: auto detect
# arch=$(uname -m)

# cache dir where buildpkg or buildiso cache packages
# cache_dir=/var/cache/manjaro-tools

# build dir where buildpkg or buildiso chroots are created
# chroots_dir=/var/lib/manjaro-tools

# default path to sets
# sets_dir=/etc/manjaro-tools/sets

# custom build mirror server
# build_mirror=http://mirror.netzspielplatz.de/manjaro/packages

################ buildtree ###############

# manjaro package tree
# repo_tree=('core' 'extra' 'community' 'multilib' 'openrc')

# host_tree=https://github.com/manjaro

# default https seems slow; try this
# host_tree_abs=git://projects.archlinux.org/svntogit

################ buildpkg ################

# default pkg buildset; name without .set extension
# buildset_pkg=default

# Next settings are only useful if you compile packages against eudev

# default packages to trigger blacklist
# blacklist_trigger=('eudev' 'upower-pm-utils' 'eudev-systemdcompat')

# default blacklisted packages to remove from chroot
# blacklist=('libsystemd')

################ buildiso ################

# default iso buildset; name without .set extension
# buildset_iso=default

# unset defaults to given value
# dist_name="Manjaro"

# unset defaults to given value
# dist_release=0.9.0

# unset defaults to value sourced from /etc/lsb-release
# dist_codename="Bellatrix"

# unset defaults to given value
# dist_branding="MJRO"

# unset defaults to given value, specify a date here of have it automatically set
# dist_version="$(date +%Y.%m)"

# unset defaults to given value
# iso_name=manjaro

# iso publisher
# iso_publisher="Manjaro Linux <http://www.manjaro.org>"

# iso app id
# iso_app_id="Manjaro Linux Live/Rescue CD"

# default compression
# iso_compression=xz

# valid: md5, sha1, sha256, sha384, sha512
# iso_checksum=md5
~~~

####Config files in iso profiles

Each iso profile must have these files or symlinks to shared:


######* profile.conf

~~~
##########################################
###### use this file in the profile ######
##########################################

# possible values: openrc,systemd
# initsys="systemd"

# use multilib packages; x86_64 only
# multilib="true"

# displaymanager="lightdm"

# Set to false to disable autologin in the livecd
# autologin="true"

# nonfree xorg drivers
# nonfree_xorg="true"

################ install ################

# unset defaults to given value
# kernel="linux319"

# unset defaults to given value
# efi_boot_loader="grub"

# set uefi partition size
# efi_part_size=32M

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

######* Packages
Contains root image packages
ideally no xorg

######* Packages-Custom/desktop
Contains the custom image packages
desktop environment packages go here

######* Packages-Xorg
Contains the Xorg package repo

######* Packages-Lng
Contains the language packages repo

######* Packages-Livecd
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

buildpkg is the chroot build script of manjaro-tools.
It it run in a abs/pkgbuilds directory which contains directories with PKGBUILD.

######manjaro-tools.conf supports the makepkg.conf variables

####Arguments

~~~
$ buildpkg -h
Usage: buildpkg [options] [--] [makepkg args]
    -p <pkg>           Buildset or pkg [default: default]
    -a <arch>          Arch [default: auto]
    -b <branch>        Branch [default: stable]
    -r <dir>           Chroots directory
                       [default: /var/lib/manjaro-tools/buildpkg]
    -i <pkg>           Install a package into the working copy of the chroot
    -c                 Recreate chroot
    -w                 Clean up cache and sources
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
The arch can also be set in manjaro-tools.conf, but under normal conditions, it is better to specify the non native arch by -a parameter.

######* -c
Removes the chroot dir
If the -c parameter is not used, buildpkg will update the existing chroot or create a new one if none is present.
######* -w
Cleans pkgcache, and logfiles
######* -s
Signs the package when built
######* -n
Installs the built package in the chroot and runs a namcap check

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
    -a <arch>          Arch [default: auto]
    -b <branch>        Branch [default: stable]
    -r <dir>           Chroots directory
                       [default: /var/lib/manjaro-tools/buildiso]
    -t <dir>           Target directory
                       [default: /var/cache/manjaro-tools/iso]
    -c                 Disable clean work dir
    -i                 Build images only
    -s                 Generate iso only
                       Requires pre built images (-i)
    -v                 Verbose output, show profies detail (-q)
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
Build images only
will stop after all packages have been installed. No iso sqfs compression will be executed
######* -s
Use this to sqfs compress the chroots if you previously used -i.

###4. buildset

buildpkg and buildiso support building from buildsets

Default location of sets is:

~~~
/etc/manjaro-tools/manjaro-tools/sets/pkg
/etc/manjaro-tools/manjaro-tools/sets/iso
~~~

but it can be configured in the manjaro-tools.conf.

buildset is a little helper tool to easily create buildsets.
It is run inside the abs/pkgbuilds or iso profiles directory.

####Arguments

~~~
$ buildset -h
Usage: buildset [options]
    -c <name>   Create set
    -r <name>   Remove set
    -s <name>   Show set
    -i          Iso mode
    -q          Query sets
    -h          This help
~~~

######* create a pkg buildset for lxqt

~~~
buildset -c lxqt-0.8
~~~

######* create a iso buildset

~~~
buildset -ic manjaro-0.9.0
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

buildtree is a little tools to sync arch abs and manjaro PKGBUILD git repos.

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
