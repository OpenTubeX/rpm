%global __strip /bin/true

Name:           opentubex
Version:        @VERSION@
Release:        1%{?dist}
Summary:        Privacy-focused YouTube desktop client
License:        AGPL-3.0-or-later
URL:            https://opentubex.org
Source0:        opentubex-@VERSION@-beta.amd64.rpm
Source1:        opentubex-@VERSION@-beta.arm64.rpm

ExclusiveArch:  x86_64 aarch64
AutoReqProv:    no
BuildRequires:  cpio
BuildRequires:  rpm
%if 0%{?suse_version}
Requires:       libXtst6
Requires:       libuuid1
Requires:       at-spi2-core
Requires:       libgtk-3-0
Requires:       libXss1
Requires:       libnotify4
Requires:       mozilla-nss
Requires:       xdg-utils
%else
Requires:       (libXtst or libXtst6)
Requires:       (libuuid or libuuid1)
Requires:       at-spi2-core
Requires:       gtk3
Requires:       libXScrnSaver
Requires:       libnotify
Requires:       nss
Requires:       xdg-utils
%endif

%description
OpenTubeX is a privacy-focused desktop client for YouTube.

%prep

%build

%install
mkdir -p %{buildroot}

%ifarch x86_64
rpm2cpio %{SOURCE0} | (cd %{buildroot} && cpio --extract --make-directories --quiet)
%endif

%ifarch aarch64
rpm2cpio %{SOURCE1} | (cd %{buildroot} && cpio --extract --make-directories --quiet)
%endif

mkdir -p %{buildroot}%{_bindir}
ln -s ../../opt/OpenTubeX/opentubex %{buildroot}%{_bindir}/opentubex
chmod 0755 %{buildroot}/opt/OpenTubeX/chrome-sandbox

%files
/opt/OpenTubeX
%{_bindir}/opentubex
%{_datadir}/applications/opentubex.desktop
%{_datadir}/icons/hicolor/scalable/apps/opentubex.svg
