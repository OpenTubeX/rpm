%global __strip /bin/true
# rpm 6 writes v6 packages by default, which EL9, EL10, and openSUSE cannot unpack.
%global _rpmformat 4

Name:           opentubex
Version:        @RPM_VERSION@
# Increase when a packaging change must reach users before the next release.
Release:        3%{?dist}
Summary:        Privacy-focused YouTube desktop client
License:        AGPL-3.0-or-later
# Keep this aligned with package.json so Zypper does not require a vendor change.
Vendor:         OpenTubeX contributors <info@opentubex.org>
URL:            https://opentubex.org
Source0:        opentubex-@ASSET_VERSION@.amd64.rpm
Source1:        opentubex-@ASSET_VERSION@.arm64.rpm

ExclusiveArch:  x86_64 aarch64
AutoReqProv:    no
BuildRequires:  tar
BuildRequires:  rpm
# Each pair names the Fedora and openSUSE package, so one build serves both.
Requires:       (alsa-lib or libasound2)
Requires:       (gtk3 or libgtk-3-0)
Requires:       (libnotify or libnotify4)
Requires:       (nss or mozilla-nss)
Requires:       (libXtst or libXtst6)
Requires:       (libuuid or libuuid1)
Requires:       (mesa-libgbm or libgbm1)
Requires:       at-spi2-core
Requires:       xdg-utils

%description
OpenTubeX is a privacy-focused desktop client for YouTube.

%prep

%build

%install
mkdir -p %{buildroot}

# rpm2cpio cannot unpack the v6 packages rpm 6 builds.
%ifarch x86_64
rpm2archive - < %{SOURCE0} | tar --extract --no-same-permissions --gzip --file - --directory %{buildroot}
%endif

%ifarch aarch64
rpm2archive - < %{SOURCE1} | tar --extract --no-same-permissions --gzip --file - --directory %{buildroot}
%endif

mkdir -p %{buildroot}%{_bindir}
ln -s ../../opt/OpenTubeX/opentubex %{buildroot}%{_bindir}/opentubex
chmod 0755 %{buildroot}/opt/OpenTubeX/chrome-sandbox

%files
/opt/OpenTubeX
%{_bindir}/opentubex
%{_datadir}/applications/opentubex.desktop
%{_datadir}/icons/hicolor/scalable/apps/opentubex.svg
