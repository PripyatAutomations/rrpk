#!/bin/bash
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"
. .modules

mkdir -p deb

./update-all.sh

# Do not spend time compiling when dpkg already has unfinished operations.
audit=$(dpkg --audit)
if [[ -n "$audit" ]]; then
    printf 'Unfinished dpkg operations:\n%s\n' "$audit" >&2
    echo "Repair the package manager before building (inspect dpkg --audit)." >&2
    exit 1
fi

for x in ${BUILD}; do
    dir="src/$x"
    source=$(sed -n 's/^Source:[[:space:]]*//p' "$dir/debian/control" | head -n1)

    echo "=== Building $source ($dir) ==="
    if ! (cd "$dir" && dpkg-checkbuilddeps); then
        echo "Unmet build dependencies for $source. Run sudo ./install-deb-dep.sh and check that preceding RustyRig packages installed successfully." >&2
        exit 1
    fi
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
    if ! sudo apt-get install -y -- "${packages[@]}"; then
        echo "Installation of $source returned an APT/dpkg error; inspect the package names above." >&2
        echo "Built packages remain in deb/. Check dpkg --audit before retrying." >&2
        exit 1
    fi
    # Verify the exact packages built, not just APT exit status or an older
    # installed library. Never proceed with a partially configured SDK.
    for deb in "${packages[@]}"; do
        name=$(dpkg-deb -f "$deb" Package)
        arch=$(dpkg-deb -f "$deb" Architecture)
        version=$(dpkg-deb -f "$deb" Version)
        if [[ "$arch" == all ]]; then
            query="$name"
        else
            query="$name:$arch"
        fi
        installed=$(dpkg-query -W -f='${Status} ${Version}' "$query" 2>/dev/null || true)
        if [[ "$installed" != "install ok installed $version" ]]; then
            echo "ERROR: $name:$arch $version was not fully installed. Stopping before the next source package." >&2
            echo "Built packages remain in deb/. Inspect dpkg --audit." >&2
            exit 1
        fi
    done
    audit=$(dpkg --audit)
    if [[ -n "$audit" ]]; then
        printf 'Unfinished dpkg operations after installing %s:\n%s\n' "$source" "$audit" >&2
        exit 1
    fi
done

