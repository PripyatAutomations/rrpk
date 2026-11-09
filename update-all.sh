#!/bin/bash
set -euo pipefail
shopt -s nullglob
. .modules

OLD_PWD=$(pwd)

git pull

mkdir -p cross deb src

for i in ${BUILD}; do
   cd src/$i
   git stash || echo "Ok" 
   git pull --ff-only
   cd ${OLD_PWD}
done
