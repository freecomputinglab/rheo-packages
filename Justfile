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
# output at all. `grep -r` reads dotfiles by default, so this needs no flag for
# them — unlike the `rg` this recipe used to be written with.
#
# GREP AND SED, NOT RIPGREP, and that is the whole reason this recipe reads the way
# it does. MEASURED: every run of the `check` workflow failed with
# `line 32: rg: command not found` (runs 32126839338 and 32127008271) — `rg` is not
# on GitHub's `ubuntu-latest` image, while it is in this repo's devShell, so the
# recipe passed for everyone locally and had never once run in CI. A lint that only
# works on the author's machine is not a lint. Installing ripgrep on the runner
# would have fixed the symptom and left the recipe needing a tool the check does
# not otherwise want; `grep -rEon` plus one `sed` needs nothing that is not on
# every POSIX box.
#
# THE THREE rg FEATURES THAT HAD TO BE REPLACED, so nobody reintroduces them:
#   - `-r '$1'` capture replacement -> `sed -n 's/.../\1/p'`;
#   - `--hidden` -> unnecessary, `grep -r` already reads dotfiles;
#   - `--no-ignore-vcs` + `-g '!dist'` -> `--exclude-dir`. rg skips gitignored
#     paths by default and had to be told not to; grep never skipped them and has
#     to be told to. Same list, opposite default.
check-versions:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    for manifest in */*/typst.toml; do
        dir="${manifest%/typst.toml}"
        name=$(sed -n 's/^name = "\([^"]*\)".*/\1/p' "$manifest")
        version=$(sed -n 's/^version = "\([^"]*\)".*/\1/p' "$manifest")
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
        # `grep -o` prints ONE match per output line, so each line is exactly
        # `path:line:@rheo/pkg:x.y.z` and the `sed` turns the `:@rheo/pkg:` in the
        # middle into `:pkg ` — giving `path:line:pkg x.y.z`, which is what the
        # `IFS=:` read above splits. Not `/g`: there is only ever one.
        #
        # `{ grep || true; }` INSIDE the braces, not after the pipeline: grep exits
        # 1 when a package contains no spec at all (which is legal — a pure-CSS
        # package could), and `set -o pipefail` above would take that as failure.
        done < <({ grep -rEon --binary-files=without-match \
            --exclude-dir=dist --exclude-dir=node_modules \
            --exclude-dir=.direnv --exclude-dir=build \
            '@rheo/[a-z-]+:[0-9]+\.[0-9]+\.[0-9]+' "$dir" || true; } \
            | sed 's|:@rheo/\([a-z-]*\):|:\1 |')
    done
    if [ "$fail" -ne 0 ]; then
        echo "check-versions: FAILED"
        exit 1
    fi
    echo "check-versions OK across $(ls -d */*/typst.toml | wc -l) manifests"
