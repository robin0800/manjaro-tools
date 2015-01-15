manjaro-tools
=============

Manjaro-tools-0.9.6

User manual

1. manjaro.tools.conf

manjaro-tools.conf is the central configuration file for manjaro-tools.
By default, the config is installed in /etc/manjaro-tools/manjaro-tools.conf
A user config manjaro-tools.conf can be placed in $HOME/.config.
If the userconfig is present, manjaro-tools will load userconfig values, however, if variables have been set in the systemwise /etc/manjaro-tools/manjaro-tools.conf, these values take precedence over the userconfig. Best practise is to leave systemwide file untouched, by default it is commented and shows just initialization values done in code.

~~~
##########################################
################ common ##################
##########################################

# unset defaults to given value
# branch=stable

# unset defaults to given value
# arch=$(uname -m)

# cache dir where buildpkg or buildiso cache packages
# cache_dir=/var/cache/manjaro-tools

# custom path to sets
# sets_dir=/etc/manjaro-tools/sets

##########################################
################ buildpkg ################
##########################################

# default chroot path
# chroots_pkg=/opt/buildpkg

# default pkg buildset; name without .set extension
# buildset_pkg=default

# custom build mirror server
# build_mirror=http://mirror.netzspielplatz.de/manjaro/packages

############# eudev specific #############

# This is only useful if you compile packages against eudev

# default packages to trigger blacklist
# blacklist_trigger=('eudev' 'upower-pm-utils' 'eudev-systemdcompat')

# default blacklisted packages to remove from chroot
# blacklist=('libsystemd')

##########################################
################ buildiso ################
##########################################

# default work dir where the image chroots are located
# chroots_iso=/opt/buildiso

# default iso buildset; name without .set extension
# buildset_iso=default

############## iso settings ##############

# unset defaults to given value
# iso_label="MJRO090"

# unset defaults to given value
# iso_version=0.9.0

# unset defaults to given value, specify a date here of have it automatically set
# manjaro_version="$(date +%Y.%m)"

# unset defaults to given value
# manjaroiso="manjaroiso"

# unset defaults to value sourced from /etc/lsb-release
# code_name="Bellatrix"

# unset defaults to given value
# img_name=manjaro

# unset defaults to given value
# install_dir=manjaro

# unset defaults to given value
# compression=xz

################ install ################

# These settings are inherited in live session
# Settings will be installed

# unset defaults to given value
# manjaro_kernel="linux317"

# unset defaults to given value
# plymouth_theme=manjaro-elegant

# unset defaults to given values
# names must match systemd service names
# start_systemd=('cronie' 'org.cups.cupsd' 'tlp' 'tlp-sleep')

# unset defaults to given values, 
# names must match openrc service names
# start_openrc=('cronie' 'cupsd' 'metalog' 'dbus' 'consolekit' 'acpid')

################# livecd #################

# These settings are specific to live session
# Settings will not be installed

# unset defaults to given value
# hostname="manjaro"

# unset defaults to given value
# username="manjaro"

# unset defaults to given value
# password="manjaro"

# unset defaults to given values
# addgroups="video,audio,power,disk,storage,optical,network,lp,scanner"

# unset defaults to given values
# names must match systemd service names
# services in start_systemd array don't need to be listed here
# start_systemd_live=('bluetooth' 'NetworkManager' 'ModemManager')

# unset defaults to given values, 
# names must match openrc service names
# services in start_openrc array don't need to be listed here
# start_openrc_live=('bluetooth'  'networkmanager')
~~~

1.1. new config files in iso profiles

Each iso profile must have these files or symlinks to shared:

initsys 
contains the init type string, systemd or openrc, could be eg a future runit implemetation too

displaymanager
contains the DM string
if no DM is used, set it to 'none'

Packages-Livecd 
contains packages you only want on livecd but not installed on the target system with installer
default files are in shared folder and can be symlinked or defined in a real file

If you need a custom livecd-overlay, create a overlay-livecd folder in your profile, and symlink from shared/overlay-livecd/<your_selection> and add your modification. 

2. buildpkg

buildpkg is the chroot build script oi manjaro-tools.
It it run in a abs/pkgbuilds directory which contains directories with PKGBUILD.
It can be configured with manjaro-tools.conf or by args.
buildpkg creates by default a pkg cache dir in /var/cache/manjaro-tools/
Subdirectories will be created when building for the branch and architecture.

A word on makepkg.conf PKGDEST
manjarotools.conf supports the makepkg.conf variables
If you set PKGDEST all works fine, but be careful, that your PKGDEST is clean, or else buildpkg will move all files from PKGDEST to cache dir , not only the built package.

2.1. Arguments

The help(for x86_64 and manjaro-tools.conf set):

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

Example(assuming default manjaro-tools.conf):

build sysvinit package for both arches and branch testing:

first i686(buildsystem is x86_64)

buildpkg -p sysvinit -a i686 -b testing -cwsn

for x86_64 and testing

buildpkg -p sysvinit -b testing -cswn

You can drop the branch arg if you set the branch in manjaro-tools.conf
the arch can also be set in manjaro-tools.conf, but under normal conditions, it is better to specify the non native arch by -a parameter.

-c 
removes the chroot dir
-w 
cleans pkgcache, and logfiles
-s 
signs the package when built
-n 
installs the built package in the chroot and runs a namcap check

If the -c parameter is not used, buildpkg will update the existing chroot or create a new one if none is present.

2.2 Sets

buildpkg supports building from a list of pkgbuilds
Default location of sets is /etc/manjaro-tools/manjaro-tools/sets/pkg
but it can be configure in the conf file.

2.2.1 mkset

mkset is a little helper tools to easily create sets.
You run it just like buildpkg in the abs/pkgbuilds dir.

~~~
$ mkset -h
Usage: mkset [options]
    -c <name>   Create set
    -r <name>   Remove set
    -d <name>   Display set
    -q          Show sets
    -h          This help
~~~

Example: create a set for lxqt assuming a pure lxqt abs directory

mkset -c lxqt-0.8

The set name should not be a name of a package, or else buildpkg won't recognize the build list and only bulds the package you specified, since the buildpkg -p arg handles set and package name.
Same applies for buildiso.

If you create a set manually, the set must have a .set extension.

 Examples:
 /etc/manjaro-tools/sets/pkg/lxqt-0.8.set
 /etc/manjaro-tools/sets/iso/manjaro-0.9.0.set

3. buildiso

buildiso is used to build manjaro-iso-profiles. It is run insde the profiles folder.

Packages for livecd only:

manjaro-livecd-cli-installer 
manjaro-livecd-openrc (openrc-run scripts for livecd)
manjaro-livecd-systemd (systemd units for livecd)

3.1 Arguments

The help:

~~~
$ buildiso -h
Usage: buildiso [options]
    -p <profile>       Set or profile [default: default]
    -a <arch>          Arch [default: x86_64]
    -b <branch>        Branch [default: unstable]
    -r <dir>           Chroots directory
                       [default: /build/buildiso]
    -c                 Disable clean work dir
    -q                 Query settings and pretend build
    -i                 Build images only
    -s                 Generate iso only
                       Requires pre built images
    -x                 Disable clean xorg cache
    -l                 Disable clean lng cache
    -h                 This help
~~~

Example: build xfce iso profile for both arches and branch testing on x86_64 build system:

buildiso -p xfce -a i686 -b testing 

buildiso -p xfce -b testing

the branch can be defined also in manjaro-tools.conf, but a manual parameter will always override conf settings.


3.1.1 Special parameters


-i

Build images only will stop after all packages have been installed. No iso sqfs compression will be executed

-s

Use this if you previously used -B to sqfs compress the chroots.

-x

By default, xorg package cache is cleaned on every build. Disabling the xorg cache cleaning will result in no dowload again for xorg drivers and the cache is used. Be careful with this option if you switch arches, it currently does not detect the pkg arch in the cache. So don't use it if you build for a different arch first time.

-l

Disable lng cache, by default lng cache is cleaned on every build. Uning this option will enable lng packages from cache rather than downloading them again.

3.2 Sets

buildiso supports building from a list of iso profiles
Default location of sets is /etc/manjaro-tools/manjaro-tools/sets/iso
but it can be configured in the conf file.
