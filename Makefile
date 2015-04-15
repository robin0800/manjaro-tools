V=0.9.7.3

PREFIX = $(PREFIX)/local

BINPROGS = \
	bin/checkpkg \
	bin/lddd \
	bin/finddeps \
	bin/find-libdeps \
	bin/signpkg \
	bin/signpkgs \
	bin/mkchroot \
	bin/mkchrootpkg \
	bin/buildpkg \
	bin/basestrap \
	bin/manjaro-chroot \
	bin/fstabgen \
	bin/mkset \
	bin/chroot-run \
	bin/mkiso \
	bin/buildiso \
	bin/testiso \
	bin/buildtree

SYSCONFIGFILES = \
	conf/manjaro-tools.conf

SETS_PKG = \
	sets/pkg/default.set

SETS_ISO = \
	sets/iso/default.set \
	sets/iso/official.set \
	sets/iso/community.set \
	sets/iso/openrc.set

CONFIGFILES = \
	conf/makepkg-i686.conf \
	conf/makepkg-x86_64.conf \
	conf/pacman-default.conf \
	conf/pacman-multilib.conf \
	conf/pacman-mirrors-stable.conf \
	conf/pacman-mirrors-testing.conf \
	conf/pacman-mirrors-unstable.conf \
	conf/pacman-gfx.conf \
	conf/pacman-lng.conf

LIBS = \
	lib/util.sh \
	lib/util-mount.sh \
	lib/util-msg.sh \
	lib/util-pkg.sh \
	lib/util-fstab.sh \
	lib/util-iso.sh \
	lib/util-iso-image.sh \
	lib/util-iso-calamares.sh \
	lib/util-livecd.sh \
	lib/util-iso-boot.sh \
	lib/util-pkgtree.sh

CPIOHOOKS = \
	initcpio/hooks/miso \
	initcpio/hooks/miso_loop_mnt \
	initcpio/hooks/miso_pxe_nbd

CPIOINST = \
	initcpio/inst/miso \
	initcpio/inst/miso_loop_mnt \
	initcpio/inst/miso_pxe_nbd \
	initcpio/inst/miso_kms

SCRIPTS = \
	scripts/mhwd-live \
	scripts/livecd \
	scripts/kbd-model-map

EFISHELL = \
	efi_shell/shellx64_v1.efi \
	efi_shell/shellx64_v2.efi

MAN_XML = \
	buildiso.xml \
	manjaro-tools.conf.xml \
	profile.conf.xml

all: $(BINPROGS) doc #bin/bash_completion bin/zsh_completion

edit = sed -e "s|@pkgdatadir[@]|$(DESTDIR)$(PREFIX)/share/manjaro-tools|g" \
	-e "s|@bindir[@]|$(DESTDIR)$(PREFIX)/bin|g" \
	-e "s|@sysconfdir[@]|$(DESTDIR)$(SYSCONFDIR)/manjaro-tools|g" \
	-e "s|@libdir[@]|$(DESTDIR)$(PREFIX)/lib/manjaro-tools|g" \
	-e "s|@version@|${V}|"

%: %.in Makefile
	@echo "GEN $@"
	@$(RM) "$@"
	@m4 -P $@.in | $(edit) >$@
	@chmod a-w "$@"
	@chmod +x "$@"

doc:
	mkdir -p man
	$(foreach var,$(MAN_XML),xsltproc /usr/share/docbook2X/xslt/man/docbook.xsl docbook/$(var) | db2x_manxml --output-dir man ;)

clean:
	rm -f $(BINPROGS) #bin/bash_completion bin/zsh_completion
	rm -rf man

install:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools
	install -m0644 ${SYSCONFIGFILES} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets/pkg
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets/iso
	install -m0644 ${SETS_PKG} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets/pkg
	install -m0644 ${SETS_ISO} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets/iso
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools
	install -dm0755 $(DESTDIR)$(PREFIX)/lib/manjaro-tools
	install -m0755 ${BINPROGS} $(DESTDIR)$(PREFIX)/bin
	install -m0644 ${CONFIGFILES} $(DESTDIR)$(PREFIX)/share/manjaro-tools
	ln -sf find-libdeps $(DESTDIR)$(PREFIX)/bin/find-libprovides
	install -m0644 ${LIBS} $(DESTDIR)$(PREFIX)/lib/manjaro-tools
	install -dm0755 $(DESTDIR)$(PREFIX)/lib/initcpio/hooks
	install -m0755 ${CPIOHOOKS} $(DESTDIR)$(PREFIX)/lib/initcpio/hooks
	install -dm0755 $(DESTDIR)$(PREFIX)/lib/initcpio/install
	install -m0755 ${CPIOINST} $(DESTDIR)$(PREFIX)/lib/initcpio/install
	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools/scripts
	install -m0644 ${SCRIPTS} $(DESTDIR)$(PREFIX)/share/manjaro-tools/scripts
	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools/efi_shell
	install -m0644 ${EFISHELL} $(DESTDIR)$(PREFIX)/share/manjaro-tools/efi_shell
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man1
	gzip -c man/buildiso.1 > $(DESTDIR)$(PREFIX)/share/man/man1/buildiso.1.gz
	mkdir -p $(DESTDIR)$(PREFIX)/share/man/man5
	gzip -c man/manjaro-tools.conf.5 > $(DESTDIR)$(PREFIX)/share/man/man5/manjaro-tools.conf.5.gz
	gzip -c man/profile.conf.5 > $(DESTDIR)$(PREFIX)/share/man/man5/profile.conf.5.gz

# 	install -Dm0644 bin/bash_completion $(DESTDIR)/$(PREFIX)/share/bash-completion/completions/manjaro_tools
# 	install -Dm0644 bin/zsh_completion $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_manjaro_tools

uninstall:
	for f in ${SYSCONFIGFILES}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/$$f; done
	for f in ${SETS_PKG}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets/pkg/$$f; done
	for f in ${SETS_ISO}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/sets/iso/$$f; done
	for f in ${BINPROGS}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${CONFIGFILES}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/bin/find-libprovides
	for f in ${LIBS}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done
	for f in ${CPIOHOOKS}; do rm -f $(DESTDIR)$(PREFIX)/lib/initcpio/hooks/$$f; done
	for f in ${CPIOINST}; do rm -f $(DESTDIR)$(PREFIX)/lib/initcpio/install/$$f; done
	for f in ${SCRIPTS}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/scripts/$$f; done
	for f in ${EFISHELL}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/efi_shell/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/buildiso.1.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/manjaro-tools.conf.5.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/profiles.conf.5.gz

# 	rm $(DESTDIR)/$(PREFIX)/share/bash-completion/completions/manjaro_tools
# 	rm $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_manjaro_tools

dist:
	git archive --format=tar --prefix=manjaro-tools-$(V)/ $(V) | gzip -9 > manjaro-tools-$(V).tar.gz
	gpg --detach-sign --use-agent manjaro-tools-$(V).tar.gz

.PHONY: all clean install uninstall dist
