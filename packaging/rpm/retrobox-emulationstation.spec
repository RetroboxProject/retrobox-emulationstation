# Binary-only spec: the tree is built and staged beforehand by
# scripts/build.sh + scripts/stage.sh and handed in through %%{stage}.
# Shared-library Requires are generated automatically from the ELF binary.
%global debug_package %{nil}
%global __strip /bin/true
%global _build_id_links none

Name:           retrobox-emulationstation
Version:        %{es_version}
Release:        %{pkg_revision}%{?dist}
Summary:        EmulationStation frontend, patched for Retrobox
# MIT (upstream, patches, rcheevos, httplib, miniz-cpp), BSD-2-Clause
# (id3v2lib), Zlib (nanosvg), Unlicense (miniz), RSA-MD (md5), LGPL-2.1+
# (gettext.h) and the fonts: Apache-2.0, OFL-1.1, Ubuntu-font-1.0.
# See /usr/share/doc/retrobox-emulationstation/copyright.
License:        MIT AND BSD-2-Clause AND Zlib AND Unlicense AND RSA-MD AND LGPL-2.1-or-later AND Apache-2.0 AND OFL-1.1 AND Ubuntu-font-1.0
URL:            https://github.com/manu-romero-411/retrobox-emulationstation
ExclusiveArch:  x86_64 x86_64_v3 aarch64

Requires:       retrobox-core
Recommends:     bluez
Recommends:     NetworkManager
Recommends:     NetworkManager-wifi

%description
batocera-emulationstation built for a regular Linux desktop (desktop OpenGL,
no CEC) with the Retrobox patches applied. The program lives in
/opt/retrobox/frontend and is exposed as /usr/bin/retrobox-emulationstation.

Started on its own it keeps its data in ~/.emulationstation; run `retrobox`
(package retrobox-core) to get the full environment.

libvlc comes from RPM Fusion (free), which must be enabled on the system.

%install
mkdir -p %{buildroot}
cp -a %{stage}/. %{buildroot}/

%files
/opt/retrobox/frontend
/usr/bin/retrobox-emulationstation
%license /usr/share/doc/retrobox-emulationstation/copyright
%license /usr/share/doc/retrobox-emulationstation/licenses
/usr/share/doc/retrobox-emulationstation/patches
/usr/share/doc/retrobox-emulationstation/BUILDINFO

%changelog
* Sat Oct 24 2026 Retrobox <manu-romero-411@users.noreply.github.com> - %{es_version}-%{pkg_revision}
- Automated build.
