#!/bin/bash

set -euo pipefail
shopt -s nullglob
. .modules

# Removing librustyaxe0 will remove all of our stuff
# -- BUT! it will also remove other Pripyat Automations products!
apt remove librustyaxe0 gmatrix
