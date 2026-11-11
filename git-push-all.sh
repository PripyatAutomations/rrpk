#!/usr/bin/env bash
# Commit and push first-party rrpk source repositories, never third-party deps.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"

usage() {
   cat <<'HELP'
Usage: ./git-push-all.sh [--dry-run] [--message 'Commit message']

For each first-party repo in rrpk's src/ list:
  * git add -A (including untracked files unless .gitignored)
  * commit the staged changes, if any
  * push the current branch to the same branch on origin

Never force-push or rewrite history. Stops on any error, including a diverged
remote branch or an unexpected origin. Does not push third-party submodules.
Inspect 'git status' first; be mindful of secrets in untracked files.
  --dry-run   List repositories, remotes, branch and changed files only
  --message   Override the automatic commit message for every repository
  --help      Show this message
HELP
}

dry_run=false
message="rrpk: sync source changes"
while (($#)); do
   case "$1" in
      --dry-run) dry_run=true; shift ;;
      --message)
         (($# >= 2)) || { echo '--message requires a value' >&2; exit 2; }
         message=$2; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
   esac
done

source ./.modules
allowed=(librustyaxe librrprotocol callsign-lookup rustyrig-fw)
validate() {
   local name=$1 dir="$ROOT/src/$1" origin branch expected
   [[ " $BUILD " == *" $name "* ]] || return 1
   local found=false
   for allowed_name in "${allowed[@]}"; do
      if [[ $name == "$allowed_name" ]]; then found=true; break; fi
   done
   if ! $found || [[ ! -d "$dir/.git" ]]; then
      echo "Missing or unrecognized first-party checkout: $dir" >&2
      return 1
   fi
   origin=$(git -C "$dir" remote get-url origin)
   # Only accept the actual first-party GitHub repository as origin.
   case "$origin" in
      "https://github.com/PripyatAutomations/$name"|"https://github.com/PripyatAutomations/$name.git"|\
      "git@github.com:PripyatAutomations/$name"|"git@github.com:PripyatAutomations/$name.git"|\
      "ssh://git@github.com/PripyatAutomations/$name"|"ssh://git@github.com/PripyatAutomations/$name.git") ;;
      *) echo "Refusing unknown origin for $name: $origin" >&2; return 1 ;;
   esac
   branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD) || {
      echo "Refusing to push detached HEAD in $name" >&2; return 1;
   }
   [[ -n "$branch" ]] || { echo "No branch selected in $name" >&2; return 1; }
   printf '%s (branch %s, origin %s)\n' "$name" "$branch" "$origin"
}

# Validate every module before staging any changes or pushing anything.
for name in $BUILD; do validate "$name"; done
for name in $BUILD; do
   dir="$ROOT/src/$name"
   branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD)
   printf '\n=== %s ===\n' "$name"
   git -C "$dir" status --short
   if $dry_run; then continue; fi
   git -C "$dir" add -A
   if ! git -C "$dir" diff --cached --quiet; then
      git -C "$dir" commit -m "$message"
   else
      echo 'No new changes to commit.'
   fi
   # Git rejects non-fast-forward updates; never use --force.
   git -C "$dir" push origin "HEAD:refs/heads/$branch"
done
