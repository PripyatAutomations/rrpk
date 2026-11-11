#!/usr/bin/env bash
# Bump every RustyRig-owned checkout in the rrpk source bundle.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"

usage() {
   cat <<'HELP'
Usage: ./bump-version.sh [--patch|--minor|--major] [--dry-run]

Bump each source project's own .version and its packaging metadata:
  (default)   Patch: 1.2.3 -> 1.2.4
  --minor     Minor: 1.2.3 -> 1.3.0
  --major     Major: 1.2.3 -> 2.0.0
  --dry-run   Preview each proposed bump without modifying files
  --help      Show this message

All source checkouts must exist below src/ (run ./fetch-all.sh first).
The script does not commit or push; use ./git-push-all.sh when ready.
HELP
}

args=()
mode_seen=false
dry_run=false
while (($#)); do
   case "$1" in
      --patch|--minor|--major)
         if $mode_seen; then echo 'Only one bump mode may be used' >&2; exit 2; fi
         args+=("$1"); mode_seen=true; shift ;;
      --dry-run) dry_run=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
   esac
done

source ./.modules
# Restrict operations to the exact first-party rrpk build modules. Never
# traverse third-party git submodules or arbitrary sibling repositories.
allowed=(librustyaxe librrprotocol callsign-lookup rustyrig-fw)
for module in $BUILD; do
   valid=false
   for name in "${allowed[@]}"; do [[ $module != "$name" ]] || valid=true; done
   if ! $valid || [[ ! -f "src/$module/tools/bump-version.sh" ]]; then
      echo "Missing/unrecognized project or bump script: src/$module" >&2
      exit 1
   fi
done

# Check every repository before changing any files.
for module in $BUILD; do
   echo "=== Preflight: $module ==="
   (cd "src/$module" && bash tools/bump-version.sh "${args[@]}" --dry-run)
done
if $dry_run; then exit 0; fi
for module in $BUILD; do
   echo "=== Bump: $module ==="
   (cd "src/$module" && bash tools/bump-version.sh "${args[@]}")
done
printf 'Version bumps complete. Review diffs, then run ./git-push-all.sh.\n'
