#!/bin/bash
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"
. .modules

# Remove generated Debian packages and build manifests.
rm -f -- src/*.{deb,udeb,buildinfo,changes} \
          deb/*.{deb,udeb,buildinfo,changes}

# Clean each configured project.
for x in ${BUILD}; do
    dir="src/$x"
    [[ -d $dir ]] || {
        echo "Missing source directory: $dir" >&2
        exit 1
    }

    echo "=== Cleaning $x ==="
    make -C "$dir" distclean
done
