#!/bin/bash
set -euo pipefail
shopt -s nullglob
. .modules

cd src
for in ${BUILD}; do
   git --depth=1 clone https://github.com/PripyatAutomations/$i
done
cd ..
