#!/bin/bash
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"
. .modules

mkdir -p deb

./update-all.sh

for x in ${BUILD}; do
    dir="src/$x"
    source=$(sed -n 's/^Source:[[:space:]]*//p' "$dir/debian/control" | head -n1)

    echo "=== Building $source ($dir) ==="
    rm -f -- "src/${source}_"*.changes

    # Only the binary package version changes. Restore the tracked release
    # changelog even on a failed build; never invoke bump-version.
    (
        cd "$dir"
        exec 9>"$(git rev-parse --git-path rrpk-deb-build.lock)"
        flock 9
        changelog=debian/changelog
        backup=$(mktemp)
        cp -p "$changelog" "$backup"
        trap 'cp -p "$backup" "$changelog"; rm -f "$backup"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        base=$(dpkg-parsechangelog -S Version)
        # Separate counter for each release, local to this checkout.
        counter="$(git rev-parse --git-path "rrpk-deb-revision-$base")"
        last=0
        if [[ -f "$counter" ]]; then read -r last < "$counter"; fi
        [[ "$last" =~ ^(0|[1-9][0-9]{0,8})$ ]] || { echo "Invalid Debian build counter" >&2; exit 1; }
        revision=$((last + 1))
        printf '%s\n' "$revision" > "$counter"
        # +r sorts after the previous +build timestamp suffix in dpkg.
        version="${base}+r${revision}"
        dpkg --validate-version "$version"
        # Change only the version on the top entry, retaining release notes.
        sed -i "1s/([^)]*)/($version)/" "$changelog"
        [[ $(dpkg-parsechangelog -S Version) == "$version" ]]
        echo "Debian build version: $version (release: $base)"
        make deb
    )

    changes=( "src/${source}_"*.changes )
    ((${#changes[@]})) || {
        echo "No .changes manifest for $source" >&2
        exit 1
    }

    mapfile -t debs < <(
        awk '/^Files:/{f=1;next}
             f && /^[^ ]/{f=0}
             f && /\.deb$/ {print $5}' "${changes[@]}" |
        sort -u
    )

    ((${#debs[@]})) || {
        echo "No binary packages listed for $source" >&2
        exit 1
    }

    packages=()
    for deb in "${debs[@]}"; do
        [[ -f "src/$deb" ]] || {
            echo "Missing package: src/$deb" >&2
            exit 1
        }

        mv -f -- "src/$deb" "deb/$deb"
        packages+=( "./deb/$deb" )
    done

    # Keep build manifests alongside the binaries.
    for changes_file in "${changes[@]}"; do
        buildinfo="${changes_file%.changes}.buildinfo"
        [[ ! -f $buildinfo ]] || mv -f -- "$buildinfo" deb/
        mv -f -- "$changes_file" deb/
    done

    printf '  %s\n' "${packages[@]}"

    echo "=== Installing $source ==="
    sudo apt install -y -- "${packages[@]}"
done

