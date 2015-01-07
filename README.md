manjaro-tools
=============

Manjaro-tools-0.9.5

User manual

1. manjaro.tools.conf

manjaro-tools.conf is the central configuration file for manjaro-tools.
By default, the config is installed in /etc/manjaro-tools/manjaro-tools.conf
A user config manjaro-tools.conf can be placed in $HOME/.config.
If the userconfig is present, manjaro-tools will load userconfig values, however, if variables have been set in the systemwise /etc/manjaro-tools/manjaro-tools.conf, these values take precedence over the userconfig. Best practise is to leave systemwide file untouched, by default it is commented and shows just initialization values done in code.

~~~
##############################################
########### manjaro-tools common #############
##############################################

# unset defaults to given value
# branch=stable

# unset defaults to given value
# arch=$(uname -m)

################################################
########### manjaro-tools buildpkg #############
################################################

# path to sets
# uncomment if you use a manjaro-tools.conf in your $HOME/.config
# profiledir=/etc/manjaro-tools/sets

# default chroot path
# chroots=/srv/manjarobuild

# pkg cache where to move built pkgs
# pkg_dir=/var/cache/manjaro-tools

# default set; name without .set extension
# profile=default

############ eudev specific ###############

# default packages to trigger blacklist
# blacklist_trigger=('eudev' 'lib32-eudev' 'upower-pm-utils' 'eudev-systemdcompat' 'lib32-eudev-systemdcompat')

# default blacklisted packages to remove from chroot
# blacklist=('libsystemd')

################################################
########### manjaro-tools buildiso #############
################################################

# default work dir
# if unset, it defaults to the iso config dir
# work_dir=/srv/manjaroiso

# default iso target dir
# if unset, it defaults to the iso config dir
# target_dir=/srv/manjaro-release-iso

# use custom cache, accessible with buildiso <args> -L
# cache_lng=/var/cache/manjaro-tools/lng

# use custom cache, accessible with buildiso <args> -P
# cache_pkgs=/var/cache/manjaro-tools/pkgs

################ iso settings ################

# unset defaults to given value
# iso_label="MJRO0811"

# unset defaults to given value
# iso_version=0.8.11

# unset defaults to given value
# manjaro_kernel="linux317"

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
# plymouth_theme=manjaro-elegant

# unset defaults to given value
# compression=xz

# unset defaults to given values
# names must match systemd service names
# start_systemd=('cronie' 'cupsd' 'tlp' 'tlp-sleep')

# unset defaults to given values, 
# names must match openrc service names
# start_openrc=('cronie' 'cupsd' 'metalog' 'dbus' 'consolekit' 'acpid')


########### livecd setup #############

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
# start_systemd_live=('bluez' 'NetworkManager' 'ModemManager')

# unset defaults to given values, 
# names must match openrc service names
# services in start_openrc array don't need to be listed here
# start_openrc_live=('bluetooth'  'networkmanager' 'connman')
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
dault files are in shared folderand can be symlinked or defined in a real file

If you need a custom livecd-overlay, create a overlay-livecd folder in your profile, and symlink from shared/overlay-livecd/<your_selection> and add your modification. 

2. buildpkg

buildpkg is the chroot build script oi manjaro-tools.
It it run in a abs/pkgbuilds directory which contains directories with PKGBUILD
It can be configure with manjaro-tools.conf or by args
buildpackage creates by default a pkg cache dir in /var/cache/manjaro-tools/
Subdirectories will be created when building for the brach and architecture.

A word on makepkg.conf PKGDEST
manjarotools.conf supports the makepkg.conf variables
If you set PKGDEST all works fine, but be careful, that your PKGDEST is clean, or else buildpkg will move all files from PKGDEST to cache dir , not only the built package.

2.1. Arguments

The help(for x86_64 and manjaro-tools.conf set):

~~~
$ buildpkg -h
Usage: buildpkg [options] [--] [makepkg args]
    -p <profile>       Set profile or pkg [default: default]
    -a <arch>          Set arch  [default: x86_64]
    -b <branch>        Set branch [default: unstable]
    -r <dir>           Chroots directory [default: /srv/manjarobuild]
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

buildpkg support building from a list of ppkgbuilds
Default location of sets is /etc/manjaro-tools/manjaro-tools/sets
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

If you create a set manually, the set must have a .set extension.

 Example: /etc/manjaro-tools/sets/lxqt-0.8.set

3. buildiso

buildiso is used to build manjaro-iso-profiles. It is run insde a iso profile folder.
It now supports installing packages in a livecd chroot environment.

New packages for livecd only:

manjaro-livecd (shared livecd skeletton)
manjaro-livecd-cli-installer 
manjaro-livecd-openrc (openrc-run scripts for livecd)
manjaro-livecd-systemd (systemd units for livecd)

3.1 Arguments

The help:

~~~
$ buildiso -h
Usage: buildiso [options]
    -a <arch>          Set arch
                       [default: x86_64]
    -b <branch>        Set branch
                       [default: unstable]
    -r <dir>           Work directory
                       [default: /srv/manjaroiso]
    -t <dir>           Target iso directory
                       [default: /srv/manjaro-release-iso]
    -v                 Verbose iso compression
    -q                 Query settings and pretend build
    -c                 Disable clean work dir and target dir iso
    -z                 Disable high compression
    -A                 Disable auto configure services
    -B                 Build images only
    -G                 Generate iso only
                       Requires pre built images
    -P                 Disable clean pkgs cache
    -L                 Disable clean lng cache
    -C                 Use custom pacman.conf in iso profile
    -h                 This help
~~~

Example: build xfce iso profile for both arches and branch testing on x86_64 build system:

buildiso -v -a i686 -b testing 

buildiso -v -b testing

the branch can be defined also in manjaro-tools.conf, but a manual parameter will always override conf settings.

3.1.1 Default parameteres set

-c
clean work dir & target dir, disabled will likely produce an error since work dir already exists

-z
high compression

-A
auto service configuration

3.1.2 Special parameters

-A
By default, buildiso auto configures services on both DE image and livecd image. This can be set in manjaro-tools.cong. Using this parmater will disable auto config. The result is, that any service configuration in iso profiles was removed. This parameter serves as custom parameter if you chose to confiogre services in the profile.

-B

Build images only will stop after all packages have been installed. No iso sqfs compression will be executed

-G
Use this if you previously used -B to sqfs compress the chroots.

-P
By default, xorg package cache is cleaned on every build. Disabling the xorg cache cleaning will result in no dowload again for xorg drivers and the cache is used. Be careful with this option if you switch arches, it currently does not detect the pkg arch in the cache. So don't use it if you build for a different arch first time.

-L
Disable lng cache, by default lng cache is cleaned on every build. Uning this option will enable lng packages from cache rather than downloading them again.

-C
Use custom pacman.conf located in profile