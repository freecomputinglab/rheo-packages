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

# Cuts `<pkg>/<new>/` from `<pkg>/<old>/` and rewrites every version this repo
# writes out by hand, so a release is one command rather than dozens of edits
# that `check-versions` can only catch AFTERWARDS. MEASURED before this existed:
# cutting rookery and rookery-search 0.3.0 -> 0.4.0 is 84 literal specs, 42 of
# them doc comments in one file.
#
# `.github/workflows/check.yml` is rewritten too, and that is the whole reason
# this recipe cannot be a one-line `sed`. `check-versions` walks `*/*/` only, so
# the CI file is invisible to it while hardcoding the version PATHS it tests
# (`cd rookery/0.3.0 && just test`, the package-cache assertion, `demo/pure`).
# A cut that misses it leaves CI exercising the PREVIOUS version and reporting
# green for code nobody ran.
#
# The OLD directory is never touched: every published version stays in the tree,
# because a release tag is cut per manifest and an edit to an already-released
# directory can never be published again.
#
# Sibling pins are PRINTED, not rewritten. `@rheo/a:1.0.0` inside package `b` is
# legal as long as `a/1.0.0/` exists, so whether a sibling should follow the bump
# is a judgement per package — the demo of an unrelated package may well want to
# stay where it is.
bump PKG OLD NEW:
    #!/usr/bin/env bash
    set -euo pipefail
    pkg='{{PKG}}'; old='{{OLD}}'; new='{{NEW}}'

    [ -f "$pkg/$old/typst.toml" ] || { echo "bump: no manifest at $pkg/$old/typst.toml"; exit 1; }
    [ -e "$pkg/$new" ] && { echo "bump: $pkg/$new already exists — refusing to overwrite"; exit 1; }

    cp -r "$pkg/$old" "$pkg/$new"
    # Build artifacts are per-package gitignored and must not be carried into a
    # new version: `dist/` is what the manifest publishes, and shipping the OLD
    # build under the NEW version is the one mistake this copy could bake in.
    find "$pkg/$new" -type d \
        \( -name dist -o -name node_modules -o -name .direnv -o -name build \) \
        -prune -exec rm -rf {} +

    # Only specs naming THIS package. A spec naming another package is that
    # package's business (printed at the end).
    grep -rl --binary-files=without-match "@rheo/$pkg:$old" "$pkg/$new" \
        | xargs -r sed -i "s|@rheo/$pkg:$old|@rheo/$pkg:$new|g"

    # Path-form self-references: `rookery/0.3.0/src/pure.typ` in a comment, `cd
    # rookery-search/0.3.0` in a readme, "run it from rookery/0.3.0" in a test
    # fixture's header. `check-versions` reads the `@rheo/pkg:ver` spec form only,
    # so these go stale silently and are found by a reader following one into the
    # PREVIOUS version's file. MEASURED on the 0.3.0 -> 0.4.0 cut: 9 such
    # references across both rookery packages, none of them caught.
    #
    # Directory form ONLY. Prose about what a version DID — "since 0.3.0",
    # "0.3.0's breaking change", a `## 0.3.0` release-notes heading — says the old
    # number on purpose and has to survive the bump.
    grep -rl --binary-files=without-match "$pkg/$old" "$pkg/$new" \
        | xargs -r sed -i "s|$pkg/$old|$pkg/$new|g"

    sed -i "s|^version = \"$old\"|version = \"$new\"|" "$pkg/$new/typst.toml"
    sed -i "s|$pkg/$old|$pkg/$new|g" .github/workflows/check.yml

    just check-versions

    # `{ grep || true; }` for the same reason `check-versions` needs it: no
    # sibling pin at all is the common case, and grep's exit 1 would trip `set -e`.
    stale=$({ grep -rn --binary-files=without-match \
        --exclude-dir=dist --exclude-dir=node_modules \
        --exclude-dir=.direnv --exclude-dir=build \
        -e "@rheo/$pkg:$old" -e "$pkg/$old/" . || true; } | grep -v "^\./$pkg/" || true)
    if [ -n "$stale" ]; then
        echo
        echo "Siblings still naming $pkg $old (legal — $pkg/$old/ is still here):"
        echo "$stale"
        echo "Decide per package whether each should follow the bump; this recipe will not."
    fi
