#!/bin/bash
set -euo pipefail
shopt -s nullglob
. .modules

OLD_PWD=$(pwd)
MY_SUM=$(sha256sum $0)
git pull
NEW_SUM=$(sha256sum $0)

[[ "$MY_SUM" != "$NEW_SUM" && "${RESTARTED:-0}" != 1 ]] && export RESTARTED=1 && exec bash "$0" "$@"

mkdir -p cross deb src

for i in ${BUILD}; do
   cd src/$i
   git stash || echo "Ok" 
   git pull --ff-only
   cd ${OLD_PWD}
done
