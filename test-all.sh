#!/usr/bin/env bash
# Test each rrpk component and keep stdout/stderr in one uploadable log.
set -uo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
if [[ ! -f .modules ]]; then
    printf 'Missing rrpk .modules file\n' >&2
    exit 1
fi
# shellcheck source=.modules
. ./.modules

read -r -a modules <<< "${BUILD:-}"
if (( ${#modules[@]} == 0 )); then
    printf 'No modules configured in .modules (BUILD)\n' >&2
    exit 1
fi

mkdir -p logs || exit 1
timestamp=$(date +%Y%m%d-%H%M%S)
log=${1:-"logs/test-all-${timestamp}.log"}
mkdir -p -- "$(dirname -- "$log")" || exit 1
: > "$log" || exit 1
log=$(realpath -- "$log") || exit 1

# tee shows live output while collecting the single combined log.
# The loop continues after failed tests and returns nonzero at the end.
{
    printf 'rrpk test-all\n'
    printf 'Started: %s\n' "$(date -Is)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'Working directory: %s\n' "$PWD"
    printf 'Log: %s\n' "$log"
    printf 'Modules: %s\n\n' "$BUILD"

    passed=0
    failed=0
    summary=()

    for module in "${modules[@]}"; do
        dir="src/$module"
        printf '\n========== BEGIN %s ==========\n' "$module"
        printf 'Started: %s\n' "$(date -Is)"
        if [[ -d "$dir" ]]; then
            printf 'Revision: %s\n' "$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
            make -C "$dir" test
            status=$?
        else
            printf 'ERROR: missing source directory: %s\n' "$dir" >&2
            status=1
        fi
        if (( status == 0 )); then
            ((passed+=1))
            result=PASS
        else
            ((failed+=1))
            result=FAIL
        fi
        summary+=("$result $module (exit $status)")
        printf '========== END %s: %s (exit %d) ==========\n' "$module" "$result" "$status"
    done

    printf '\n========== TEST SUMMARY ==========\n'
    printf '%s\n' "${summary[@]}"
    printf 'Passed: %d  Failed: %d  Total: %d\n' "$passed" "$failed" "${#modules[@]}"
    printf 'Finished: %s\n' "$(date -Is)"
    printf 'Full log: %s\n' "$log"
    (( failed == 0 ))
} 2>&1 | tee -a -- "$log"

exit "${PIPESTATUS[0]}"
