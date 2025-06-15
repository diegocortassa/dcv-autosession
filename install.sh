#!/bin/bash
# Autosession setup for DCV server on RHEL8/9 and clones
#
# It creates an "autosession" standalone configuration, no need for any form of session management as it
# takes care of creating user sessions and managing collaboration requests using a pam_exec script.
# Only one session per machine is supported.

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

# Check for --batch argument
BATCH_MODE=false
for arg in "$@"; do
    if [[ "$arg" == "--batch" ]]; then
        BATCH_MODE=true
        break
    fi
done

if [[ "$BATCH_MODE" == false ]]; then
    echo "This script will install DCV Autosession configuration and will overwrite existing DCV configurations."
    read -r -p "Do you want to proceed? [y/N] " answer
    answer=${answer:-n}
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Check prerequisites
if [[ "$EUID" -ne 0 ]]; then 
    echo "This script requires root privileges"
    exit 1
fi

if [[ -e /etc/redhat-release ]]; then
    MAJOR_VERSION=$(cat /etc/redhat-release | sed -e 's/.*release \(.\).*/\1/')
    if [ "$MAJOR_VERSION" != 9 ]; then
        echo "This script requires RHEL/Rocky/Alma 9.x"
        exit 1
    fi
fi

if ! rpm -q gnome-shell >/dev/null 2>&1; then
    echo "This script requires the gnome desktop to be installed"
    exit 1
fi

echo "### Installing required packages"
dnf -y install jq zenity pinentry pinentry-gnome3

echo "### Opening DCV websocket and QUIC ports"
firewall-cmd --zone public --permanent --add-port 8443/tcp
firewall-cmd --zone public --permanent --add-port 8443/udp
firewall-cmd --reload

echo "### Disabling wayland"
sed -i "s/#WaylandEnable=false/WaylandEnable=false/" /etc/gdm/custom.conf

echo "### Installing dcv server packages"
curl -O https://d1uj6qtbmh3dt5.cloudfront.net/2024.0/Servers/nice-dcv-2024.0-19030-el9-x86_64.tgz
tar xvzf nice-dcv-*-el9-x86_64.tgz
rm -f nice-dcv-*-el9-x86_64.tgz
dnf -y install ./nice-dcv-*-el9-x86_64/nice-dcv-server-*.rpm ./nice-dcv-*-el9-x86_64/nice-dcv-gl-*.rpm ./nice-dcv-*-el9-x86_64/nice-dcv-gltest-*.rpm ./nice-dcv-*-el9-x86_64/nice-dcv-web-viewer-*.rpm ./nice-dcv-*-el9-x86_64/nice-xdcv-*.rpm
rm -rf nice-dcv-*-el9-x86_64

echo "### Configuring DCV server with autosession"
cp -a --backup=numbered /etc/dcv/dcv.conf /etc/dcv/dcv.conf.bk_by_autosession
install --mode=644 "$SCRIPT_DIR/src/dcv/dcv.conf" /etc/dcv/dcv.conf

cp -a --backup=numbered /etc/dcv/default.perm /etc/dcv/default.perm.bk_by_autosession
install --mode=644 "$SCRIPT_DIR/src/dcv/default.perm" /etc/dcv/default.perm

install --mode=644 "$SCRIPT_DIR/src/pam.d/dcv-autosession" /etc/pam.d/dcv-autosession

echo "### Installing required scripts"
install --mode=755 "$SCRIPT_DIR/src/scripts/dcv_autosession.sh" /usr/bin/dcv_autosession.sh
install --mode=644 "$SCRIPT_DIR/src/dcv/dcv_autosession.env" /etc/dcv/dcv_autosession.env
install --mode=755 "$SCRIPT_DIR/src/scripts/dcv_collab_prompt.sh" /usr/bin/dcv_collab_prompt.sh

echo "### Adding Polkit configuration for virtual session users"
install --mode=644 "$SCRIPT_DIR/src/polkit_pklas/45-allow-colord.pkla" /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
install --mode=644 "$SCRIPT_DIR/src/polkit_pklas/50-allow-reboot.pkla" /etc/polkit-1/localauthority/50-local.d/50-allow-reboot.pkla

echo "### Configuring xorg"
grep -qF 'HardDPMS' /etc/X11/xorg.conf.d/10-nvidia.conf || sed -i '/Driver "nvidia"/a \ \ \ \ Option "HardDPMS" "false"' /etc/X11/xorg.conf.d/10-nvidia.conf
cp -f "$SCRIPT_DIR/src/xorg.conf.d/20-dcv-stylus.conf" /etc/X11/xorg.conf.d/20-dcv-stylus.conf

echo "### Configuring keyring unlock at login for virtual session users"
install --mode=755 "$SCRIPT_DIR/src/scripts/dcv_unlock_keyring.sh" /usr/bin/dcv_unlock_keyring.sh
install --mode=644 "$SCRIPT_DIR/src/dcv_unlock_keyring.desktop" /etc/xdg/autostart/dcv_unlock_keyring.desktop

echo "### Installing utility scripts"
install --mode=755 "$SCRIPT_DIR/src/scripts/dcv_reset_display.sh" /usr/bin/dcv_reset_display.sh

echo "### Configuring autosession watch service"
install --mode=755 "$SCRIPT_DIR/src/scripts/dcv_autosession_watch.sh" /usr/bin/dcv_autosession_watch.sh
install --mode=644 "$SCRIPT_DIR/src/systemd/dcv_autosession_watch.service" /lib/systemd/system/dcv_autosession_watch.service
systemctl daemon-reload
systemctl enable dcv_autosession_watch.service
systemctl start dcv_autosession_watch.service

echo "### Enabling and starting dcvserver service"
systemctl start dcvserver.service
systemctl enable dcvserver.service

