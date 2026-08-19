#!/usr/bin/env bash
# Asserts on this demo's OUTPUT. Everything checked here exists only under rheo
# and none of it is covered by `demo/pure`, which is a single native `typst
# compile` with no minted pages and no cross-page hrefs at all.
#
# Greps rather than a test framework, deliberately: the package ships no runner
# and adding one for four assertions would be more machinery than the thing it
# checks. Run it through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

# 1. One minted page per registered note, including the note nested inside
#    another note's body and the one written on the nested vertebra.
for slug in root-note inner-note plain-note sub-note; do
  [ -f "$H/ideas/$slug.html" ] || note "no minted page at ideas/$slug.html"
done

# 2. Depth arithmetic. The root vertebra links to a minted page with no `../`;
#    the nested one, handle `sub:page`, pays exactly one. This is the assertion a
#    root-only spine cannot make, and an off-by-one here breaks every link on
#    every page of a real site.
grep -q 'href="ideas/root-note.html"' "$H/index.html" ||
  note "index.html does not link ideas/root-note.html at depth 0"
grep -q 'href="\.\./ideas/root-note.html"' "$H/sub/page.html" ||
  note "sub/page.html does not link ../ideas/root-note.html at depth 1"
# `if !` rather than `grep ... && note ...`: an AND-list whose first command is
# meant to FAIL reads as an accident, and one edit away from tripping `set -e`.
if grep -q 'href="\.\./\.\./' "$H/sub/page.html"; then
  note "sub/page.html has a ../../ href — one level deep should never need two"
fi

# 3. `idea-page-template` ran, and the minted page carries both footer sections.
#    The banner comes from `content/lib.typ`'s named `idea-page` function, so its
#    absence means the state channel from vertebra to bundle root is broken.
for slug in root-note sub-note; do
  grep -q 'demo-minted-banner' "$H/ideas/$slug.html" ||
    note "ideas/$slug.html is missing the idea-page-template banner"
  grep -q '>Context</h2>' "$H/ideas/$slug.html" ||
    note "ideas/$slug.html has no Context section"
done
grep -q '>Backlinks</h2>' "$H/ideas/root-note.html" ||
  note "ideas/root-note.html has no Backlinks section — sub-note windows it"

# 4. No minted page appears in another note's PAGE backlinks. `_is-vertebra`
#    filters them out, and its own comment records six wrong backlinks from the
#    build where that filter was missing: a minted page links to the notes it
#    transcludes, so without the filter every note lists every other note's page
#    as a place it was "written".
python3 - "$H" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
bad = 0
for page in sorted((root / "ideas").glob("*.html")):
    html = page.read_text()
    for block in re.findall(r'<div class="idea-context">.*?</div>', html, re.S):
        for href in re.findall(r'href="([^"]+)"', block):
            if "ideas/" in href:
                print(f"FAIL: {page.name}'s Context lists a minted page: {href}")
                bad += 1
sys.exit(1 if bad else 0)
PY

# 5. A citation written inside a `#footnote` belongs to the idea the footnote was
#    written in. `plain-note`'s ONLY citation sits in one, so the whole
#    references block on both its pages depends on the walk descending into the
#    footnote's metadata payload. MEASURED before that descent existed: the
#    author-date marker rendered, `.idea-references` was emitted nowhere, and an
#    empty `.idea-page-refs` appeared in its place — a reader saw a citation with
#    nothing on the site saying what it cited.
#
#    Counted, not merely found: the BIBLIOGRAPHY ENTRY must appear exactly once
#    per page. The footnote body is rendered as well as scanned, and a walk
#    claiming the citation from both places would list the work twice. The
#    author-date MARKER is a separate string ("Lamport 1994", inside the
#    footnote's own text) and is asserted separately, so neither check can pass
#    by finding the other.
for p in index.html ideas/plain-note.html; do
  grep -q 'idea-references' "$H/$p" ||
    note "$p has no references block for plain-note's footnote citation"
  grep -q 'doc-biblioref">Lamport 1994<' "$H/$p" ||
    note "$p is missing the footnote's own author-date citation marker"
  n=$(grep -o 'Lamport, Leslie' "$H/$p" | wc -l)
  [ "$n" -eq 1 ] ||
    note "$p lists the footnote's cited work $n times in its bibliography, expected exactly 1"
done


if [ "$fail" -ne 0 ]; then
  echo "demo/rheo: FAILED"
  exit 1
fi
echo "demo/rheo OK"
