manjaro-tools
=============

Manjaro-tools-0.9.6

User manual
<ol><li>manjaro.tools.conf</li>

manjaro-tools.conf is the central configuration file for manjaro-tools.
By default, the config is installed in /etc/manjaro-tools/manjaro-tools.conf
A user config manjaro-tools.conf can be placed in $HOME/.config.
If the userconfig is present, manjaro-tools will load userconfig values, however, if variables have been set in the systemwide /etc/manjaro-tools/manjaro-tools.conf, these values take precedence over the userconfig. 
Best practise is to leave systemwide file untouched, by default it is commented and shows just initialization values done in code.

<ol><li>config files in iso profiles</li></ol>

Each iso profile must have these files or symlinks to shared:

* initsys
contains the init type string, systemd or openrc, could be eg a future runit implemetation too

* displaymanager
contains the DM string
if no DM is used, set it to 'none'

* Packages-Livecd
contains packages you only want on livecd but not installed on the target system with installer
default files are in shared folder and can be symlinked or defined in a real file

    If you need a custom livecd-overlay, create a  overlay-livecd folder in your profile, and  symlink from shared/overlay-livecd/your_selection  and add your modification

<li>buildpkg</li>

buildpkg is the chroot build script oi manjaro-tools.
It it run in a abs/pkgbuilds directory which contains directories with PKGBUILD.
It can be configured with manjaro-tools.conf or by args.
buildpkg creates by default a pkg cache dir in /var/cache/manjaro-tools/
Subdirectories will be created when building for the branch and architecture.

A word on makepkg.conf PKGDEST
manjarotools.conf supports the makepkg.conf variables
If you set PKGDEST all works fine, but be careful, that your PKGDEST is clean, or else buildpkg will move all files from PKGDEST to cache dir , not only the built package.

<ol><li>Arguments</li></ol>

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

* build sysvinit package for both arches and branch testing:

first i686(buildsystem is x86_64)
~~~
buildpkg -p sysvinit -a i686 -b testing -cwsn
~~~
for x86_64 and testing
~~~
buildpkg -p sysvinit -b testing -cswn
~~~
You can drop the branch arg if you set the branch in manjaro-tools.conf
the arch can also be set in manjaro-tools.conf, but under normal conditions, it is better to specify the non native arch by -a parameter.

* -c
removes the chroot dir
If the -c parameter is not used, buildpkg will update the existing chroot or create a new one if none is present.
* -w
cleans pkgcache, and logfiles
* -s
signs the package when built
* -n
installs the built package in the chroot and runs a namcap check

<li>buildiso</li>


buildiso is used to build manjaro-iso-profiles. It is run insde the profiles folder.

Packages for livecd only:

* manjaro-livecd-cli-installer 
* manjaro-livecd-openrc
openrc-run scripts for livecd
* manjaro-livecd-systemd
systemd units for livecd


<ol><li>Arguments</li>

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
~~~
buildiso -p xfce -a i686 -b testing 
~~~
for x86_64 and testing
~~~
buildiso -p xfce -b testing
~~~
The branch can be defined also in manjaro-tools.conf, but a manual parameter will always override conf settings.

<li>Special parameters</li>
* -i
Build images only will stop after all packages have been installed. No iso sqfs compression will be executed
* -s
Use this to sqfs compress the chroots if you previously used -i.
* -x
By default, xorg package cache is cleaned on every build. Disabling the xorg cache cleaning will result in no dowload again for xorg drivers and the cache is used. Be careful with this option if you switch arches, it currently does not detect the pkg arch in the cache. So don't use it if you build for a different arch first time.
* -l
Disable lng cache, by default lng cache is cleaned on every build. Uning this option will enable lng packages from cache rather than downloading them again.

</ol>
<li>mkset</li>

buildpkg and buildiso support building from buildsets

Default location of sets is:
~~~
/etc/manjaro-tools/manjaro-tools/sets/pkg
/etc/manjaro-tools/manjaro-tools/sets/iso
~~~
but it can be configured in the manjaro-tools.conf file.

mkset is a little helper tools to easily create sets.
It is run inside the abs/pkgbuilds or iso profiles directory.

<ol><li>Arguments</li></ol>

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

* create a pkg buildset for lxqt

~~~
mkset -c lxqt-0.8
~~~

* create a iso buildset

~~~
mkset -ic manjaro-0.9.0
~~~

The set name should not be a name of a package, or else buildpkg won't recognize the build list and only bulds the package you specified, since the buildpkg -p arg handles set and package name.
Same applies for buildiso.

If you create a set manually, the set must have a .set extension.

Examples
~~~
/etc/manjaro-tools/sets/pkg/lxqt-0.8.set
/etc/manjaro-tools/sets/iso/manjaro-0.9.0.set
~~~
</ol>