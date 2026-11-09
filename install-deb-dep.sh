#!/bin/bash
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")/src/rustyrig-fw"
./install-deps.sh deb
