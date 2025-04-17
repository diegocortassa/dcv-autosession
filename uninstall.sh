#!/bin/bash
# Autosession setup for DCV server on RHEL8/9 and clones
#
# It creates an "autosession" standalone configuration, no need for any form of session management as it
# takes care of creating user sessions and managing collaboration requests using a pam_exec script.
# Only one session per machine is supported.

echo "This script will completely unistall DCV Autosession deleting all configurations."
read -p "Do you want to proceed? [y/N] " answer
answer=${answer:-n}

if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Check prerequisites
if [ "$EUID" -ne 0 ]; then 
    echo "This script requires root privileges"
    exit 1
fi

## Enable and start dcvserver
systemctl stop dcvserver.service
systemctl disable dcvserver.service

# Close DCV websocket and QUIC ports
firewall-cmd --zone public --permanent --remove-port 8443/tcp
firewall-cmd --zone public --permanent --remove-port 8443/udp
firewall-cmd --reload

### Re enable wayland 
sed -i "s/WaylandEnable=false/#WaylandEnable=false/" /etc/gdm/custom.conf

### Remove dcv server packages 
dnf -y remove nice-dcv-server-* nice-dcv-gl-* nice-dcv-gltest-* nice-dcv-web-viewer-* nice-xdcv-*

### Remove DCV configs
rm -rf /etc/dcv
rm -f  /etc/pam.d/dcv-autosession

### Remove scripts
rm -f /usr/bin/dcv_autosession.sh
rm -f src/dcv/src/dcv_autosession.env
rm -f /usr/bin/dcv_collab_prompt.sh

# Remove sudo
rm -f  /etc/sudoers.d/90_dcv

### Remove Polkit configuration for virtual session users
rm -f /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
rm -f /etc/polkit-1/localauthority/50-local.d/50-allow-reboot.pkla

### remove DCV conf from xorg
sed -i 's/ \ \ \ \ Option "HardDPMS" "false"//' /etc/X11/xorg.conf.d/10-nvidia.conf
sed -i '/HardDPMS/d' /etc/X11/xorg.conf.d/10-nvidia.conf
rm -f /etc/X11/xorg.conf.d/20-dcv-stylus.conf

### Unlock keyring at login for virtual session users
rm -f /usr/bin/dcv_unlock_keyring.sh
rm -f /etc/xdg/autostart/unlock_keyring.desktop

