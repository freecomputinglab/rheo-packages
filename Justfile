build:
    #!/usr/bin/env bash
    set -euo pipefail
    find . -mindepth 2 -name Justfile -printf '%h\n' | while read -r dir; do
        echo "==> $dir"
        (cd "$dir" && just)
    done

# A Typst import spec has to be a literal, so `@rheo/<pkg>:<x.y.z>` is written
# out by hand in every readme, every doc comment, every `.marrow.typ` and every
# cross-package import — and nothing but this recipe checks any of them against
# the manifest that defines the version. CI derives the release tag from
# `typst.toml`, so a version directory cut by copying and bumping only the
# manifest publishes a package whose own marrow imports its PREDECESSOR: it
# resolves to the old code where that is installed and fails outright where it
# is not.
#
# Three rules, all of them things that have gone wrong at least once:
#   - a spec naming its OWN package must name the version its manifest declares;
#   - a spec naming ANOTHER package must name a version that exists here;
#   - `<name>/<version>/` is the layout (CLAUDE.md), so the directory must match.
#
# Hidden files are searched on purpose: `.marrow.typ` carries the import that
# mints every page, and it is the one place a stale spec silently produces no
# output at all.
check-versions:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    for manifest in */*/typst.toml; do
        dir="${manifest%/typst.toml}"
        name=$(rg -o -r '$1' '^name = "([^"]+)"' "$manifest")
        version=$(rg -o -r '$1' '^version = "([^"]+)"' "$manifest")
        if [ "$dir" != "$name/$version" ]; then
            echo "$manifest: declares $name $version but lives at $dir/"
            fail=1
        fi
        while IFS=: read -r file line rest; do
            read -r pkg ver <<<"$rest"
            if [ "$pkg" = "$name" ]; then
                if [ "$ver" != "$version" ]; then
                    echo "$file:$line: @rheo/$pkg:$ver, but $manifest declares $version"
                    fail=1
                fi
            elif [ ! -d "$pkg/$ver" ]; then
                echo "$file:$line: @rheo/$pkg:$ver, but $pkg/$ver/ is not in this repo"
                fail=1
            fi
        done < <(rg -o -n --no-heading --hidden --no-ignore-vcs \
            -g '!dist' -g '!node_modules' -g '!.direnv' -g '!build' \
            -r '$1 $2' '@rheo/([a-z-]+):([0-9]+\.[0-9]+\.[0-9]+)' "$dir" || true)
    done
    if [ "$fail" -ne 0 ]; then
        echo "check-versions: FAILED"
        exit 1
    fi
    echo "check-versions OK across $(ls -d */*/typst.toml | wc -l) manifests"
