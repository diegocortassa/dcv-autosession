PREFIX ?= /
DESTDIR ?= 
VERSION := $(shell cat VERSION)

.PHONY: all install clean rpm

all:
	@echo "Available targets: install clean rpm"

install:
	# DCV server configuration
	install -d $(DESTDIR)/etc/dcv
	# install -m 644 src/dcv/dcv.conf $(DESTDIR)/etc/dcv/dcv.conf
	# install -m 644 src/dcv/default.perm $(DESTDIR)/etc/dcv/default.perm
	install -m 644 src/dcv/dcv_autosession.env $(DESTDIR)/etc/dcv/dcv_autosession.env

	# PAM configuration
	install -d $(DESTDIR)/etc/pam.d
	install -m 644 src/pam.d/dcv-autosession $(DESTDIR)/etc/pam.d/dcv-autosession

	# Scripts installation
	install -d $(DESTDIR)/usr/bin
	install -m 755 src/scripts/dcv_autosession.sh $(DESTDIR)/usr/bin/dcv_autosession.sh
	install -m 755 src/scripts/dcv_collab_prompt.sh $(DESTDIR)/usr/bin/dcv_collab_prompt.sh
	install -m 755 src/scripts/dcv_unlock_keyring.sh $(DESTDIR)/usr/bin/dcv_unlock_keyring.sh
	install -m 755 src/scripts/dcv_reset_display.sh $(DESTDIR)/usr/bin/dcv_reset_display.sh
	install -m 755 src/scripts/dcv_autosession_watch.sh $(DESTDIR)/usr/bin/dcv_autosession_watch.sh

	# Polkit configuration
	install -d $(DESTDIR)/etc/polkit-1/localauthority/50-local.d
	install -m 644 src/polkit_pklas/45-allow-colord.pkla $(DESTDIR)/etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
	install -m 644 src/polkit_pklas/50-allow-reboot.pkla $(DESTDIR)/etc/polkit-1/localauthority/50-local.d/50-allow-reboot.pkla

	# Xorg configuration
	install -d $(DESTDIR)/etc/X11/xorg.conf.d
	install -m 644 src/xorg.conf.d/20-dcv-stylus.conf $(DESTDIR)/etc/X11/xorg.conf.d/20-dcv-stylus.conf

	# Autostart configuration
	install -d $(DESTDIR)/etc/xdg/autostart
	install -m 644 src/dcv_unlock_keyring.desktop $(DESTDIR)/etc/xdg/autostart/dcv_unlock_keyring.desktop

	# Systemd service
	install -d $(DESTDIR)/usr/lib/systemd/system
	install -m 644 src/systemd/dcv_autosession_watch.service $(DESTDIR)/usr/lib/systemd/system/dcv_autosession_watch.service

clean:
	rm -rf rpmbuild

rpm:
	mkdir -p rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	tar --transform 's,^,dcv-autosession-$(VERSION)/,' -czf \
		rpmbuild/SOURCES/dcv-autosession-$(VERSION).tar.gz \
		src/ VERSION LICENSE.md README.md Makefile
	cp dcv-autosession.spec rpmbuild/SPECS/
	rpmbuild --define "_topdir $$(pwd)/rpmbuild" -ba rpmbuild/SPECS/dcv-autosession.spec
