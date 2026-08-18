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

# 4. No minted page is named as a PLACE A NOTE WAS WRITTEN. `_is-vertebra`
#    filters them out, and its own comment records six wrong backlinks from the
#    build where that filter was missing: a minted page links to the notes it
#    transcludes, so without the filter every note lists every other note's page
#    as a place it was "written".
#
#    Scoped to the PAGE ROWS (`.idea-page-row`), not to every href in the Context
#    block, and that distinction is the point. Context now renders a `#window` of
#    the containing NOTE where there is one, and that window's permalink
#    legitimately points at `ideas/<container>.html` — a note link, not a claim
#    about provenance. Asserting over the whole block flagged it: a wrong answer to
#    the right question.
python3 - "$H" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
bad = 0
for page in sorted((root / "ideas").glob("*.html")):
    html = page.read_text()
    for block in re.findall(r'<li class="idea-page-row">.*?</li>', html, re.S):
        for href in re.findall(r'href="([^"]+)"', block):
            if "ideas/" in href:
                print(f"FAIL: {page.name}'s Context lists a minted page: {href}")
                bad += 1
sys.exit(1 if bad else 0)
PY

# 5. A NESTED note's Context is a WINDOW of the note containing it; a TOP-LEVEL
#    note's Context stays a page-row link naming the vertebra it was written on.
#    Both halves are asserted, because the interesting failure is the first
#    silently becoming the second — an auto-id container that fails to resolve
#    falls back to the page link and looks exactly like "has no container".
python3 - "$H" <<'PYCTX'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
def context_of(name):
    html = (root / "ideas" / name).read_text()
    m = re.search(r'<div class="idea-context">(.*?)</div></div>', html, re.S) \
        or re.search(r'<div class="idea-context">(.*?)</div>', html, re.S)
    return m.group(1) if m else ""
bad = 0
inner = context_of("inner-note.html")
if "idea-window" not in inner:
    print("FAIL: inner-note is nested in root-note, so its Context must be a window")
    bad += 1
if "idea:root-note" not in inner:
    print("FAIL: inner-note's Context window does not name root-note")
    bad += 1
for top in ("root-note.html", "sub-note.html"):
    c = context_of(top)
    if "idea-page-row" not in c:
        print("FAIL: %s is top-level, so its Context must stay a page link" % top)
        bad += 1
    if "idea-window" in c:
        print("FAIL: %s is top-level and must not window anything under Context" % top)
        bad += 1
sys.exit(1 if bad else 0)
PYCTX
[ "$?" -eq 0 ] || note "Context sections are wrong"

if [ "$fail" -ne 0 ]; then
  echo "demo/rheo: FAILED"
  exit 1
fi
echo "demo/rheo OK"
