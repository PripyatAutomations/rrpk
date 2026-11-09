
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

    make -C "$dir" deb

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

