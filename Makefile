PREFIX ?= /
DESTDIR ?= 
VERSION := $(shell cat VERSION)

.PHONY: all install clean tag rpm

all:
	@echo "Available targets: install clean tag rpm"

install:
	# Autosession configuration
	install -d $(DESTDIR)/etc/dcv
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

	# Autostart unlock keyring
	install -d $(DESTDIR)/etc/xdg/autostart
	install -m 644 src/dcv_unlock_keyring.desktop $(DESTDIR)/etc/xdg/autostart/dcv_unlock_keyring.desktop

	# Systemd service
	install -d $(DESTDIR)/usr/lib/systemd/system
	install -m 644 src/systemd/dcv_autosession_watch.service $(DESTDIR)/usr/lib/systemd/system/dcv_autosession_watch.service

	# Done
	# ******************************************************
	# ******* To enable atuosession add `pam-service-name="dcv-autosession"`
	# ******* to the `[security]` section in /etc/dcv/dcv.conf
	# ******************************************************

uninstall:
	# Stop and remove Systemd service
	systemctl disable dcv_autosession_watch.service
	systemctl stop dcv_autosession_watch.service
	rm -f $(DESTDIR)/usr/lib/systemd/system/dcv_autosession_watch.service
	systemctl daemon-reload

	# Remove autostart unlock keyring
	rm -f $(DESTDIR)/etc/xdg/autostart/dcv_unlock_keyring.desktop

	# Remove Xorg configuration
	rm -f  $(DESTDIR)/etc/X11/xorg.conf.d/20-dcv-stylus.conf

	# Remove Polkit configuration
	rm -f $(DESTDIR)/etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
	rm -f $(DESTDIR)/etc/polkit-1/localauthority/50-local.d/50-allow-reboot.pkla

	# Remove scripts
	rm -f $(DESTDIR)/usr/bin/dcv_autosession.sh
	rm -f $(DESTDIR)/usr/bin/dcv_collab_prompt.sh
	rm -f $(DESTDIR)/usr/bin/dcv_unlock_keyring.sh
	rm -f $(DESTDIR)/usr/bin/dcv_reset_display.sh
	rm -f $(DESTDIR)/usr/bin/dcv_autosession_watch.sh

	# Remove PAM configuration
	rm -f $(DESTDIR)/etc/pam.d/dcv-autosession

	# Remove autosession configuration
	rm -f $(DESTDIR)/etc/dcv/dcv_autosession.env

	# Done
	# ******************************************************
	# ******* Remove `pam-service-name="dcv-autosession"`
	# ******* from the `[security]` section in /etc/dcv/dcv.conf
	# ******************************************************

clean:
	rm -rf rpmbuild

tag:
	git tag -a v$(VERSION) -m "Version $(VERSION)"
	# git push origin v$(VERSION)

rpm:
	mkdir -p rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
	tar --transform 's,^,dcv-autosession-$(VERSION)/,' -czf \
		rpmbuild/SOURCES/dcv-autosession-$(VERSION).tar.gz \
		src/ VERSION LICENSE.md README.md Makefile
	cp dcv-autosession.spec rpmbuild/SPECS/
	rpmbuild --define "_topdir $$(pwd)/rpmbuild" -ba rpmbuild/SPECS/dcv-autosession.spec
