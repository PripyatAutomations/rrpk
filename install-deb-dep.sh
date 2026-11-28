#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# This wrapper builds ALL Debian packages, not a single firmware profile.
# Install the complete external Build-Depends union in one transaction.
# RustyRig libraries are built and installed in .modules order, not from APT.
packages=(build-essential git make jq python3 perl pkg-config debhelper fakeroot
    libglib2.0-dev libncurses-dev libbsd-dev libcrypt-dev libssl-dev
    libwslay-dev libsrtp2-dev libargon2-dev libev-dev libarchive-dev
    libsqlite3-dev libspatialite-dev libcurl4-openssl-dev sqlite3
    libflac-dev libogg-dev libvorbis-dev libpulse-dev libgtk-3-dev
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libhamlib-dev)

# GPIO v2 is optional; Bookworm/MX 23 may only offer the older SDK.
candidate=$(apt-cache policy libgpiod-dev | awk '/Candidate:/ {print $2; exit}')
if [[ -n "$candidate" && "$candidate" != "(none)" ]] &&
    dpkg --compare-versions "$candidate" ge 2.0; then
    packages+=(libgpiod-dev)
else
    echo "GPIO v2 SDK unavailable; Debian build will omit GPIO support."
fi

audit=$(dpkg --audit)
if [[ -n "$audit" ]]; then
    printf 'Warning: dpkg has unfinished package operations:\n%s\n' "$audit" >&2
    echo "Repair the package manager before installing build dependencies (sudo dpkg --configure -a)." >&2
    exit 1
fi

if ! apt-get install -- "${packages[@]}"; then
    echo "Dependency installation failed. Resolve the APT/dpkg errors above before building." >&2
    echo "Inspect pending packages with: dpkg --audit" >&2
    exit 1
fi

# APT can unpack packages without successfully configuring them. Check
# every requested package, including SDKs without a reliable .pc file.
missing_packages=()
for package in "${packages[@]}"; do
    status=$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)
    if [[ "$status" != "install ok installed" ]]; then
        missing_packages+=("$package")
    fi
done
if ((${#missing_packages[@]})); then
    printf 'Build dependencies not fully installed: %s\n' "${missing_packages[*]}" >&2
    exit 1
fi
audit=$(dpkg --audit)
if [[ -n "$audit" ]]; then
    printf 'Unfinished dpkg operations:\n%s\n' "$audit" >&2
    exit 1
fi

# Confirm the external SDKs really are available before a long build.
pc=(glib-2.0 gio-2.0 openssl libwslay ncursesw libsrtp2 sqlite3 spatialite
    libcurl flac ogg vorbis libpulse gtk+-3.0 gstreamer-1.0
    gstreamer-app-1.0 hamlib)
missing=()
for module in "${pc[@]}"; do
    if ! pkg-config --exists "$module"; then
        missing+=("$module")
    fi
done
if ((${#missing[@]})); then
    printf 'Missing pkg-config modules after dependency installation: %s\n' "${missing[*]}" >&2
    exit 1
fi
echo "Debian build dependencies are ready."
