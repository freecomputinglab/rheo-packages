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


# 6. The `ideas/index.html` landing page, on by default (`content/lib.typ`
#    also sets `index-page: true` explicitly). `/ideas/` is the parent directory
#    of every permalink this demo mints and the URL a reader will guess;
#    without this page it is a 404.
#
#    Its rows must point AT the minted pages, which is what makes it an index of
#    them rather than a second table of contents: `#ideas-outline` links each row
#    to the note's anchor on the vertebra that authored it, and this page
#    deliberately does not use it.
[ -f "$H/ideas/index.html" ] || note "no ideas/index.html was minted"
if [ -f "$H/ideas/index.html" ]; then
  idx="$H/ideas/index.html"
  # One row per minted note, each linking to that note's own page.
  for slug in root-note inner-note plain-note sub-note; do
    grep -q "href=\"[^\"]*ideas/$slug.html\"" "$idx" ||
      note "ideas/index.html does not link ideas/$slug.html"
  done
  # No row may link to an anchor on an authoring vertebra — that is the
  # `#ideas-outline` shape this page exists to avoid.
  if grep -q 'idea-outline-row"><a href="[^"]*#loc-' "$idx"; then
    note "ideas/index.html links a row at a vertebra anchor, not at a minted page"
  fi
  grep -q 'idea-index-count">4 ideas<' "$idx" ||
    note "ideas/index.html does not count its 4 ideas"
  # A dated note carries its date; sub-note is the demo's only dated one.
  grep -q 'idea-date">2026-03-14<' "$idx" ||
    note "ideas/index.html does not show the dated note's date"
  # Tag classes ride on the row, as they do in the outline, so a stylesheet can
  # reach them without this page inventing its own vocabulary.
  grep -q 'idea-outline-row idea-tag-note' "$idx" ||
    note "ideas/index.html does not carry a tagged note's idea-tag-note class"
  # The project's template wrapped it, exactly as it wraps a note page. `id` is
  # none here, and lib.typ's branch on that is what this proves runs.
  grep -q 'Minted page for the rookery' "$idx" ||
    note "ideas/index.html did not go through idea-page-template"
fi


# 7. The `<rssfeed:item>` syndication beacons, opt-in via `syndicate: true` in
#    `content/lib.typ`. `.marrow.typ` emits one inside each MINTED page for every
#    note that carries a date, and `content/index.typ` queries them back on a
#    vertebra and renders their payloads — `#metadata` produces no HTML, so
#    without that rendering there is nothing here to grep.
#
#    That query is itself half the assertion: the beacons live inside documents
#    this page is not, so a passing check proves rheo's introspection carries
#    them across the bundle, which is the whole premise of the protocol. The
#    OTHER half is the payload shape, which `@rheo/rssfeed`'s `items()` reads by
#    key: id, title, page, categories.
#
#    This demo imports no rssfeed and rssfeed imports no rookery — neither
#    package sees the other, by design. The consuming side is covered in
#    rssfeed's own demo, which needs rheo >= 0.6.0 and so cannot run here.
#
#    EXACTLY the dated notes, and only them: `.marrow.typ` skips a beacon for a
#    note with neither `minted` nor `updated`, because Atom requires `<updated>`
#    and an undated entry is one `items()` would drop anyway. root-note and
#    inner-note are undated on purpose, so a beacon for either means that gate
#    stopped working.
# `{ grep || true; }` INSIDE the braces, the same guard this file's own header
# comment records for the version in `check-versions`: with `set -o pipefail`,
# grep's exit 1 for NO MATCHES kills the script before `note` can say anything —
# and no match is exactly the failure this line exists to report. MEASURED while
# writing it: with `syndicate: false` the check exited 1 silently instead of
# naming the count.
beacons=$({ grep -o '<li>idea:[^<]*</li>' "$H/index.html" || true; } | wc -l)
[ "$beacons" -eq 2 ] ||
  note "index.html renders $beacons syndication beacons, expected exactly 2 (the dated notes)"
# The TITLE the note authored, not its slug, and the minted page's own path.
grep -q '<li>idea:plain-note | Plain note | ideas/plain-note.html | note</li>' "$H/index.html" ||
  note "plain-note's beacon payload is wrong (id, title, page or categories)"
grep -q '<li>idea:sub-note | Sub note | ideas/sub-note.html |' "$H/index.html" ||
  note "sub-note's beacon payload is wrong — note it is written on a NESTED vertebra"
if grep -q '<li>idea:root-note' "$H/index.html"; then
  note "an undated note emitted a beacon; the minted/updated gate is not holding"
fi


# 8. The per-tag theme reaches MINTED pages. `theme: (tags-color: ..)` is
#    delivered as generated `.idea-tag-<tag>` rules, and `rookery()` emits them
#    once per VERTEBRA — which cannot reach a page `.marrow.typ` mints, that
#    being a separate `#document` that never calls `rookery()` again. So
#    `.marrow.typ` carries the block itself, on every note page and on the index,
#    and this is the assertion that notices if it stops. `content/lib.typ` themes
#    the `note` tag for exactly this reason; the demo has no other use for it.
for page in ideas/index.html ideas/root-note.html; do
  grep -q '@layer rookery-tags' "$H/$page" ||
    note "$page carries no @layer rookery-tags block, so a minted page lost its tag theme"
done
#    Matched DECLARATION BY DECLARATION, not as one exact rule string: the
#    generator publishes as many properties as the entry warrants, and asserting
#    the whole rule made adding `--idea-tag-line` look like a broken minted page.
grep -q 'idea-tag-note { --idea-tag-bg: #3366ff[;}]' "$H/ideas/root-note.html" ||
  note "ideas/root-note.html's generated rule does not set --idea-tag-bg for the note tag"
grep -q 'idea-tag-line: #3366ff' "$H/ideas/root-note.html" ||
  note "ideas/root-note.html's generated rule does not set --idea-tag-line for the note tag"


if [ "$fail" -ne 0 ]; then
  echo "demo/rheo: FAILED"
  exit 1
fi
echo "demo/rheo OK"
