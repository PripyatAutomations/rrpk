#!/bin/bash
set -euo pipefail
shopt -s nullglob
. .modules

mkdir -p cross deb src

cd src
for i in ${BUILD}; do
   git clone --depth https://github.com/PripyatAutomations/$i
done
cd ..
