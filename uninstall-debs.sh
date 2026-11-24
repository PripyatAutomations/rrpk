#!/bin/bash

set -euo pipefail
shopt -s nullglob
. .modules

# Removing librustyaxe1 will remove all of our stuff
# -- BUT! it will also remove other Pripyat Automations products!
apt remove librustyaxe1
#gmatrix
