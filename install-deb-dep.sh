#!/bin/bash
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")/src/rustyrig-fw"

# The packaging toolchain and shared library dependencies are mandatory
# regardless of the selected RustyRig firmware profile.
apt-get install build-essential git jq python3 pkg-config debhelper \
    libglib2.0-dev libncurses-dev libbsd-dev libcrypt-dev libssl-dev \
    libwslay-dev libsrtp2-dev libargon2-dev libev-dev libsqlite3-dev \
    libspatialite-dev libcurl4-openssl-dev sqlite3

./install-deps.sh deb
