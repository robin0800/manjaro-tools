manjaro-tools
=============

Manjaro-tools-0.15

User manual

### 1. manjaro-tools.conf

manjaro-tools.conf is the central configuration file for manjaro-tools.
By default, the config is installed in

~~~
/etc/manjaro-tools/manjaro-tools.conf
~~~

A user manjaro-tools.conf can be placed in

~~~
$HOME/.config/manjaro-tools/manjaro-tools.conf
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

User build lists(eg 'my-super-build.list') can be placed in

~~~
$HOME/.config/manjaro-tools/pkg.list.d
$HOME/.config/manjaro-tools/iso.list.d
~~~

overriding

~~~
/etc/manjaro-tools/pkg.list.d
/etc/manjaro-tools/iso.list.d
~~~


~~~
######################################################
################ manjaro-tools.conf ##################
######################################################

# default target branch
# target_branch=stable

# default target arch: auto detect
# target_arch=$(uname -m)

# cache dir where buildpkg, buildtree cache packages/pkgbuild, builiso iso files
# cache_dir=/var/cache/manjaro-tools

# build dir where buildpkg or buildiso chroots are created
# chroots_dir=/var/lib/manjaro-tools

# log dir where log files are created
# log_dir='/var/log/manjaro-tools'

# custom build mirror server
# build_mirror=https://manjaro.moson.eu

################ buildtree ###############

# manjaro package tree
# repo_tree=('core' 'extra' 'community' 'multilib')

# host_tree=https://github.com/manjaro

# default https seems slow; try this
# host_tree_abs=git://projects.archlinux.org/svntogit

################ buildpkg ################

# default pkg build list; name without .list extension
# build_list_pkg=default

################ buildiso ################

#default branch for iso-profiles repo: v17.1>current release | master>development release
# branch=v17.1

# default iso build list; name without .list extension
# build_list_iso=default

# the dist release; default: auto
# dist_release=auto

# the branding; default: auto
# dist_branding="MANJARO"

# unset defaults to given value
# kernel="linux54"

# gpg key; leave empty or commented to skip sfs signing
# gpgkey=""

########## calamares preferences ##########
#See branding.desc.d for reference

# welcome style for calamares: true="Welcome to the %1 installer." ; false="Welcome to the Calamares installer for %1." (default)
# welcomestyle=false

# welcome image scaled (productWelcome) 
# welcomelogo=true

# size and expansion policy for Calamares (possible value: normal,fullscreen,noexpand)
# windowexp=noexpand

# size of Calamares window, expressed as w,h. 
# (possible units: pixel (px) or font-units (em))
# windowsize="800px,520px"

# colors for text and background components:

# background of the sidebar
# sidebarbackground=#454948

# text color
# sidebartext=#efefef

# background of the selected step
# sidebartextselect=#4d915e

# text color of the selected step
# sidebartexthighlight=#1a1c1b

################ deployiso ################

# the server user
# account=[SetUser]

# Set to 'true' to use ssh-agent to store passphrase.
# ssh_agent=false

# use alternative storage server (one or the other might be more stable) 
# alt_storage=false

# the server project: manjaro|manjaro-community
# determined automatically based on profile if unset
# project="[SetProject]"

# set upload bandwidth limit in kB/s
# limit=

# the torrent tracker urls, comma separated
# tracker_url='udp://mirror.strits.dk:6969'

# Piece size, 2^n
# piece_size=21
~~~

### 2. buildpkg

buildpkg is the chroot build script of manjaro-tools.
It it run in a abs/pkgbuilds directory which contains directories with PKGBUILD.

###### manjaro-tools.conf supports the makepkg.conf variables

#### Arguments

~~~
$ buildpkg -h
Usage: buildpkg [options]
    -a <arch>          Arch [default: auto]
    -b <branch>        Branch [default: stable]
    -c                 Recreate chroot
    -h                 This help
    -i <pkg>           Install a package into the working copy of the chroot
    -n                 Install and run namcap check
    -p <pkg>           Buildset or pkg [default: default]
    -q                 Query settings and pretend build
    -r <dir>           Chroots directory
                       [default: /var/lib/manjaro-tools/buildpkg]
    -s                 Sign packages
    -w                 Clean up cache and sources
~~~

###### * build sysvinit package for both arches and branch testing:

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

###### * -c
* Removes the chroot dir
* If the -c parameter is not used, buildpkg will update the existing chroot or create a new one if none is present.

###### * -n
* Installs the built package in the chroot and runs a namcap check

###### * -s
* Signs the package when built

###### * -w
* Cleans pkgcache, and logfiles

### 3. buildiso

buildiso is used to build manjaro-iso-profiles. It is run insde the profiles folder.

##### Packages for livecd only:

* manjaro-livecd-systemd

#### Arguments

~~~
$ buildiso -h
Usage: buildiso [options]
    -i                 Initialize iso-profiles repo [default: v17.1]"
    -a <arch>          Arch [default: auto]
    -b <branch>        Branch [default: stable]
    -c                 Disable clean work dir
    -f                 Build full ISO (extra=true)
    -g <key>           The gpg key for sfs signing
                       [default: empty]
    -h                 This help
    -k <name>          Kernel to use
                       [default: linux49]
    -l                 Create permalink
    -m                 Set SquashFS image mode to persistence
    -o                 Enable office installer
    -p <profile>       Buildset or profile [default: default]
    -q                 Query settings and pretend build
    -r <dir>           Chroots directory
                       [default: /var/lib/manjaro-tools/buildiso]
    -t <dir>           Target directory
                       [default: /var/cache/manjaro-tools/iso]
    -v                 Verbose output to log file, show profile detail (-q)
    -x                 Build images only
    -z                 Generate iso only
                       Requires pre built images (-x)
~~~

###### * build xfce iso profile for both arches and branch testing on x86_64 build system

* Remember: if you run buildiso for the first time you need to do:

~~~
buildiso -i
~~~

for download in /usr/share/manjaro-tools/iso-profiles our manjaro profiles. You can override in manjaro-tools.conf what branch use with buildiso: v17.1 or master ( development profiles ). The previous command can be used to refresh the profiles as needed in your local.

* i686 (buildsystem is x86_64)

~~~
buildiso -p xfce -a i686 -b testing
~~~

* for x86_64

~~~
buildiso -p xfce -b testing
~~~

The branch can be defined also in manjaro-tools.conf, but a manual parameter will always override conf settings.

#### Special parameters

###### * -x
* Build images only
* will stop after all packages have been installed. No iso sqfs compression will be executed

###### * -z
* Use this to sqfs compress the chroots if you previously used -x.

### 4. check-yaml

check-yaml can be used to write profile package lists to yaml.
It is also possible to generate calamares conf file as buildiso would do.
yaml files are used by calamares netinstall option from a specified url(netgroups).

~~~
$ check-yaml -h
Usage: check-yaml [options]
    -a <arch>          Arch [default: auto]
    -c                 Check also calamares yaml files generated for the profile
    -g                 Enable pacman group accepted for -p
    -h                 This help
    -k <name>          Kernel to use[default: linux44]
    -p <profile>       Buildset or profile [default: default]
    -q                 Query settings
    -v                 Validate by schema
~~~
###### * build xfce iso profile for both arches and branch testing on x86_64 build system

* i686 (buildsystem is x86_64)

~~~
check-yaml -p xfce -a i686 -c
~~~

* for x86_64

~~~
check-yaml -p xfce -c
~~~

* for a kdebase pacman group with validation

~~~
check-yaml -p kdebase -gv
~~~

#### Special parameters

###### * -c
* generate calamares module and settings conf files per profile

###### * -g
* generate a netgroup for specified pacman group

### 5. buildtree

buildtree is a little tools to sync arch abs and manjaro PKGBUILD git repos.

#### Arguments

~~~
$ buildtree -h
Usage: buildtree [options]
    -a            Sync arch abs
    -c            Clean package tree
    -h            This help
    -q            Query settings
    -s            Sync manjaro tree
~~~

###### * sync arch and manjaro trees

~~~
buildtree -as
~~~

### 6. manjaro-chroot

manjaro-chroot is a little tool to quickly chroot into a second system installed on the host.
If the automount option is enabled, manjaro-chroot will detect installed systems with os-prober, and pops up a list with linux systems to select from.
If there is only 1 system installed besides the host system, no list will pop up and it will automatically mount the second system.

#### Arguments

~~~
$ manjaro-chroot -h
usage: manjaro-chroot -a [or] manjaro-chroot chroot-dir [command]
    -a             Automount detected linux system
    -h             Print this help message
    -q             Query settings and pretend

    If 'command' is unspecified, manjaro-chroot will launch /bin/sh.

    If 'automount' is true, manjaro-chroot will launch /bin/bash
    and /build/manjaro-tools/manjaro-chroot.
~~~

###### * automount

~~~
manjaro-chroot -a
~~~

###### * mount manually

~~~
manjaro-chroot /mnt /bin/bash
~~~

### 7. deployiso

deployiso is a script to upload a specific iso or a buiildset to OSDN.

#### Arguments

~~~
$ deployiso -h
Usage: deployiso [options]
    -d                 Use hidden remote directory
    -h                 This help
    -l                 Limit bandwidth in kB/s [default:]
    -p                 Source folder to upload [default:default]
    -q                 Query settings and pretend upload
    -s                 Sign ISO and create checksums
    -t                 Create ISO torrent
    -u                 Update remote directory
    -v                 Verbose output
    -z                 Upload permalinks (shell.osdn.net)
~~~

###### * upload official build list, ie all built iso defined in a build list

~~~
deployiso -p official
~~~

###### * upload sign xfce ISO file, create checksums, create torrent and upload to hidden directory

~~~
deployiso -p xfce -std
~~~


##### Fast compression
Lz4 Is very fast but not a good compression ratio, good for testing
