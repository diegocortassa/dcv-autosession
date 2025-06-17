%define debug_package %{nil}

Name:           dcv-autosession
Version:        %(cat %{_sourcedir}/../../VERSION)
Release:        1%{?dist}
Summary:        Amazon DCV Autosession Configuration
License:        MIT
URL:            https://github.com/yourusername/dcv-autosession
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd

Requires:       nice-dcv-server
Requires:       gnome-shell
Requires:       jq
Requires:       zenity
Requires:       pinentry
Requires:       pinentry-gnome3
Requires:       firewalld
Requires:       systemd

%description
Configuration and scripts for Amazon DCV Server autosession setup.
It creates an "autosession" standalone configuration, with no need for session
management as it takes care of creating user sessions and managing collaboration
requests using a pam_exec script. Only one session per machine is supported.

%prep
%setup -q

%install
make install DESTDIR=%{buildroot}

%post
%systemd_post dcv_autosession_watch.service
echo "Opening DCV websocket and QUIC ports (8443 tcp and udp)"
firewall-cmd --zone public --permanent --add-port 8443/tcp || :
firewall-cmd --zone public --permanent --add-port 8443/udp || :
firewall-cmd --reload || :
# Disable Wayland
sed -i "s/#WaylandEnable=false/WaylandEnable=false/" /etc/gdm/custom.conf || :
echo "Making backup of /etc/dcv/dcv.conf to /etc/dcv/dcv.conf.bk_by_autosession"
cp -a --backup=numbered /etc/dcv/dcv.conf /etc/dcv/dcv.conf.bk_by_autosession
echo "Overwriting /etc/dcv/dcv.conf"
cp -f /usr/share/doc/dcv-autosession/dcv.conf /etc/dcv/
echo "Making backup of /etc/dcv/default.perm to /etc/dcv/default.perm.bk_by_autosession"
cp -a --backup=numbered /etc/dcv/default.perm /etc/dcv/default.perm.bk_by_autosession
echo "Overwriting /etc/dcv/default.perm"
cp -f /usr/share/doc/dcv-autosession/default.perm /etc/dcv/

%preun
%systemd_preun dcv_autosession_watch.service

%postun
%systemd_postun_with_restart dcv_autosession_watch.service

%files
%license LICENSE.md
%doc README.md
%doc src/dcv/dcv.conf
%doc src/dcv/default.perm
%config(noreplace) %{_sysconfdir}/dcv/dcv_autosession.env
%config(noreplace) %{_sysconfdir}/pam.d/dcv-autosession
%{_bindir}/dcv_autosession.sh
%{_bindir}/dcv_collab_prompt.sh
%{_bindir}/dcv_unlock_keyring.sh
%{_bindir}/dcv_reset_display.sh
%{_bindir}/dcv_autosession_watch.sh
%{_sysconfdir}/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
%{_sysconfdir}/polkit-1/localauthority/50-local.d/50-allow-reboot.pkla
%{_sysconfdir}/X11/xorg.conf.d/20-dcv-stylus.conf
%{_sysconfdir}/xdg/autostart/dcv_unlock_keyring.desktop
%{_unitdir}/dcv_autosession_watch.service

%changelog
* Sun Jun 15 2025 Diego Cortassa <diego@cortassa.net> - 0.5-1
- Initial package release
