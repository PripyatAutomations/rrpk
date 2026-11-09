#!/bin/bash
set -euo pipefail
shopt -s nullglob
. .modules

mkdir -p cross deb src

cd src
for i in ${BUILD}; do
   git --depth=1 clone https://github.com/PripyatAutomations/$i
done
cd ..
