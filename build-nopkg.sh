#!/bin/bash
set -euo pipefail
shopt -s nullglob
. .modules

cd "$(dirname "$0")"

./update-all.sh

for x in ${BUILD}; do
    dir=src/$x
    source=$(sed -n 's/^Source:[[:space:]]*//p' "$dir/debian/control")

    echo "=== Building $source ($dir) ==="
    make -C "$dir" -k $(nproc) world

    echo "******************************"
    echo "* We will continue with sudo *"
    echo "* Press ^C (ctrl-c) to abort *"
    echo "******************************"
    echo ""
    echo "=== Installing $source ==="
    sudo make -C "$dir" install
done
