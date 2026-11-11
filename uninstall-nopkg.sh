#!/bin/bash
set -euo pipefail
shopt -s nullglob
. .modules

rm -f *.deb *.buildinfo *.changes

OLD_PWD=$(pwd)
for i in ${BUILD}; do
   cd src/$i
   make uninstall
   cd "${OLD_PWD}"
done
