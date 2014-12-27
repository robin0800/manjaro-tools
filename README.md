# Manjaro-tools-0.9.5

User manual

### 1. manjaro.tools.conf

manjaro-tools.conf is the central configuration file for manjaro-tools.
By default, the config is installed in /etc/manjaro-tools/manjaro-tools.conf
A user config manjaro-tools.conf can be placed in $HOME/.config.
If the userconfig is present, manjaro-tools will load userconfig values, however, if variables have been set in the system wide /etc/manjaro-tools/manjaro-tools.conf, these values take precedence over the userconfig. Best practice is to leave system wide file untouched, by default it is commented and shows just initialization values done in code.

#### 1.1. new config files in iso profiles

Each iso profile must have these files or symlinks to shared:

* initsys 
contains the init type string, systemd or openrc, could be eg a future runit implemetation too

* displaymanager
contains the DM string
if no DM is used, set it to 'none'

* Packages-Livecd 
contains packages you only want on livecd but not installed on the target system with installer
dault files are in shared folder and can be symlinked or defined in a real file

If you need a custom livecd-overlay, create a overlay-livecd folder in your profile, and symlink from shared/overlay-livecd/<your_selection> and add your modification. 

### 2. buildpkg

buildpkg is the chroot build script oi manjaro-tools.
It it run in a abs/pkgbuilds directory which contains directories with PKGBUILD
It can be configure with manjaro-tools.conf or by args
buildpackage creates by default a pkg cache dir in /var/cache/manjaro-tools/
Subdirectories will be created when building for the branch and architecture.


A word on makepkg.conf PKGDEST
manjaro-tools.conf supports the makepkg.conf variables
If you set PKGDEST all works fine, but be careful, that your PKGDEST is clean, or else buildpkg will move all files from PKGDEST to cache dir , not only the built package.

#### 2.1 Arguments

The help(for x86_64 and manjaro-tools.conf set):

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

Example(assuming default manjaro-tools.conf):

build sysvinit package for both arches and branch testing:

first i686(build system is x86_64)

`buildpkg -p sysvinit -a i686 -b testing -cwsn`

for x86_64 and testing

`buildpkg -p sysvinit -b testing -cswn`

You can drop the branch arg if you set the branch in manjaro-tools.conf
the arch can also be set in manjaro-tools.conf, but under normal conditions, it is better to specify the non native arch by -a parameter.

**-c** 
removes the chroot dir

**-w** 
cleans pkgcache, and logfiles

**-s** 
signs the package when built

**-n** 
installs the built package in the chroot and runs a namcap check

If the -c parameter is not used, buildpkg will update the existing chroot or create a new one if none is present.

#### 2.2 Sets

buildpkg support building from a list of ppkgbuilds
Default location of sets is /etc/manjaro-tools/manjaro-tools/sets
but it can be configure in the conf file.

##### 2.2.1 mkset

mkset is a little helper tools to easily create sets.
You run it just like buildpkg in the abs/pkgbuilds dir.

    $ mkset -h
      Usage: mkset [options]
          -c <name>   Create set
          -r <name>   Remove set
          -d <name>   Display set
          -q          Show sets
          -h          This help

Example: create a set for lxqt assuming a pure lxqt abs directory

`mkset -c lxqt-0.8`

The set name should not be a name of a package, or else buildpkg won't recognize the build list and only bulds the package you specified, since the buildpkg -p arg handles set and package name.

If you create a set manually, the set must have a .set extension.

Example: 
/etc/manjaro-tools/sets/lxqt-0.8.set

## 3. buildiso

buildiso is used to build manjaro-iso-profiles. It is run insde a iso profile folder.
It now supports installing packages in a livecd chroot environment.

New packages for livecd only:

* manjaro-livecd-cli-installer 
* manjaro-livecd-openrc (openrc-run scripts for livecd)
* manjaro-livecd-systemd (systemd units for livecd)


#### 3.1 Arguments

The help:

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
        -i <file>          Config file for pacman
                           [default: /usr/share/manjaro-tools/pacman-default.conf]
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
        -h                 This help


Example: build xfce iso profile for both arches and branch testing on x86_64 build system:

`buildiso -v -a i686 -b testing `

`buildiso -v -b testing`

the branch can be defined also in manjaro-tools.conf, but a manual parameter will always override conf settings.


##### 3.1.1 Default parameters set

**-c** 
clean work dir & target dir, disabled will likely produce an error since work dir already exists

**-z** 
high compression

**-A** 
auto service configuration


##### 3.1.2 Special parameters

**-A** 
By default, buildiso auto configures services on both DE image and livecd image. This can be set in manjaro-tools.conf. Using this parameter will disable auto config. The result is, that any service configuration in iso profiles was removed. This parameter serves as custom parameter if you chose to configure services in the profile.

**-B** 
Build images only will stop after all packages have been installed. No iso sqfs compression will be executed

**-G** 
Use this if you previously used -B to sqfs compress the chroots.

**-P** 
By default, xorg package cache is cleaned on every build. Disabling the xorg cache cleaning will result in no download again for xorg drivers and the cache is used. Be careful with this option if you switch arches, it currently does not detect the pkg arch in the cache. So don't use it if you build for a different arch first time.

**-L** 
Disable lng cache, by default lng cache is cleaned on every build. Using this option will enable lng packages from cache rather than downloading them again.
