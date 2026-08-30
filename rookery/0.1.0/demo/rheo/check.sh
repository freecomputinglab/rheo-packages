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

# A WINDOW EMITTED FROM INSIDE A `#context` BLOCK STILL PRODUCES A BACKLINK.
#
# `_page-links-beacon` walks the vertebra's content at `#show: rookery` time,
# and that walk cannot enter a context block — the body does not exist until
# layout. So the unlabelled `metadata((rookery-window: ..))` a `#window`
# announces itself with is invisible there, and every note such a window
# transcludes used to lose its backlink from the page transcluding it.
#
# NOT A HYPOTHETICAL: any package that computes its rows must emit its windows
# from inside a context block, because a registry read needs one.
# `@rheo/rookery-todos`'s `#todos-ready(windows: true)` is the real case, and
# MEASURED before the fix it produced no backlink at all while a hand-written
# window on the same page produced one.
#
# `content/sub/page.typ` holds the fixture: a `#context { window("plain-note") }`.
grep -q 'href="../sub/page.html"' "$H/ideas/plain-note.html" ||
  note "plain-note has no backlink from sub/page.html — a window inside #context announced to nobody"

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
#
#    AS A BARE BASENAME, and that is the assertion, not an incidental spelling.
#    This page IS `ideas/index.html`, so a minted note page is its SIBLING and
#    `<slug>.html` is the whole correct href. It used to be spelled
#    `ideas/<slug>.html` here, matching what rookery emitted — and what rookery
#    emitted was wrong, resolving to `ideas/ideas/<slug>.html`. Measured on an
#    82-note site: every row 404. So the old form must NOT be accepted again.
[ -f "$H/ideas/index.html" ] || note "no ideas/index.html was minted"
if [ -f "$H/ideas/index.html" ]; then
  idx="$H/ideas/index.html"
  # One row per minted note, each linking to that note's own page.
  for slug in root-note inner-note plain-note sub-note; do
    grep -q "idea-outline-row[^\"]*\"><a href=\"$slug.html\"" "$idx" ||
      note "ideas/index.html does not link $slug.html as a sibling basename"
    if grep -q "idea-outline-row[^\"]*\"><a href=\"[^\"]*ideas/$slug.html\"" "$idx"; then
      note "ideas/index.html links $slug through a directory prefix; from inside ideas/ that resolves to ideas/ideas/$slug.html"
    fi
  done
  # No row may link to an anchor on an authoring vertebra — that is the
  # `#ideas-outline` shape this page exists to avoid.
  if grep -q 'idea-outline-row"><a href="[^"]*#loc-' "$idx"; then
    note "ideas/index.html links a row at a vertebra anchor, not at a minted page"
  fi
  # SIX. `secret-note` was added for the invisible-tag assertions, `private-note`
  # for the exclusion ones (EXCLUDED, so it never registers and never gets a row —
  # which makes this count also the assertion that exclusion reaches the index
  # page), and `derived-note` for the derived-title ones.
  grep -q 'idea-index-count">6 ideas<' "$idx" ||
    note "ideas/index.html does not count its 6 ideas"
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


# 7. The `<feeds:item>` syndication beacons, opt-in via `syndicate: true` in
#    `content/lib.typ`. `.marrow.typ` emits one inside each MINTED page for every
#    note that carries a date, and `content/index.typ` queries them back on a
#    vertebra and renders their payloads — `#metadata` produces no HTML, so
#    without that rendering there is nothing here to grep.
#
#    That query is itself half the assertion: the beacons live inside documents
#    this page is not, so a passing check proves rheo's introspection carries
#    them across the bundle, which is the whole premise of the protocol. The
#    OTHER half is the payload shape, which `@rheo/feeds`'s `items()` reads by
#    key: id, title, page, categories.
#
#    This demo imports no feeds and feeds imports no rookery — neither
#    package sees the other, by design. The consuming side is covered in
#    feeds's own demo, which needs rheo >= 0.6.0 and so cannot run here.
#
#    EXACTLY the dated notes, and only them: `.marrow.typ` skips a beacon for a
#    note with no `created` date, because Atom requires `<updated>` and an
#    undated entry is one `items()` would drop anyway. root-note, inner-note and
#    derived-note are undated on purpose — this demo sets no document date, so
#    they resolve to none — and a beacon for any of them means that gate stopped
#    working.
# `{ grep || true; }` INSIDE the braces, the same guard this file's own header
# comment records for the version in `check-versions`: with `set -o pipefail`,
# grep's exit 1 for NO MATCHES kills the script before `note` can say anything —
# and no match is exactly the failure this line exists to report. MEASURED while
# writing it: with `syndicate: false` the check exited 1 silently instead of
# naming the count.
# THREE dated notes: `plain-note`, `secret-note` and `sub-note`, each carrying an
# explicit `created:`. `private-note` is excluded and so emits no beacon either — a
# second place the exclusion has to reach, since `.marrow.typ` writes one beacon
# per minted page.
beacons=$({ grep -o '<li>idea:[^<]*</li>' "$H/index.html" || true; } | wc -l)
[ "$beacons" -eq 3 ] ||
  note "index.html renders $beacons syndication beacons, expected exactly 3 (the dated notes)"
# The TITLE the note authored, not its slug, and the minted page's own path.
grep -q '<li>idea:plain-note | Plain note | ideas/plain-note.html | note</li>' "$H/index.html" ||
  note "plain-note's beacon payload is wrong (id, title, page or categories)"
grep -q '<li>idea:sub-note | Sub note | ideas/sub-note.html |' "$H/index.html" ||
  note "sub-note's beacon payload is wrong — note it is written on a NESTED vertebra"
if grep -q '<li>idea:root-note' "$H/index.html"; then
  note "an undated note emitted a beacon; the created gate is not holding"
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


# 9. EXCLUDED TAGS reaching everything downstream of the registry. `demo/pure`
#    proves an excluded note is absent from one page's HTML; only here can it be
#    shown to mint no page, take no index row, emit no beacon and appear nowhere
#    in the whole output tree. `content/lib.typ` binds
#    `exclude-tags: ("private",)` on both `idea` and `tagged-idea`.
[ -f "$H/ideas/private-note.html" ] &&
  note "ideas/private-note.html was minted for an EXCLUDED note"
#    The strongest form of the assertion, and the one worth keeping: the note's
#    id, its slug and its body appear NOWHERE in the built tree — not on the index,
#    not in a backlink list, not in a beacon, not in a Context footer.
if grep -rq -e 'private-note' -e PRIVATEBODY "$H"; then
  note "an excluded note leaked into the build: $(grep -rl -e 'private-note' -e PRIVATEBODY "$H" | tr '\n' ' ')"
fi
#    The control: the note added alongside it, which is NOT excluded, did mint.
[ -f "$H/ideas/secret-note.html" ] ||
  note "no minted page at ideas/secret-note.html — the non-excluded control is missing"

# 10. INVISIBLE TAGS on the surfaces only a rheo build has. A minted note page
#     renders its tags UNCONDITIONALLY (nothing writes a `show-tags:` argument for
#     a page `.marrow.typ` mints), and the index page puts `idea-tag-<tag>` on
#     every row — so these are the two places an invisible tag would most
#     obviously leak. `content/lib.typ` sets `invisible-tags: ("secret",)` AND
#     themes `secret`, so the generated `@layer rookery-tags` block is checked too.
#     TARGETED greps, not a flat `grep -r secret`, and the reason is structural
#     rather than fussy: the note's own SLUG is `secret-note`, which appears
#     legitimately in every link to its page, in its Context footer and in its
#     beacon. What must be absent is the CLASS, the PILL and the generated RULE.
if grep -rq 'idea-tag-secret' "$H"; then
  note "invisible tag leaked as a class: $(grep -rl 'idea-tag-secret' "$H" | tr '\n' ' ')"
fi
if grep -rq '>secret<' "$H"; then
  note "invisible tag leaked as a pill: $(grep -rl '>secret<' "$H" | tr '\n' ' ')"
fi
if grep -rq 'idea-tag-secret {' "$H"; then
  note "a tags-color rule was generated for an invisible tag"
fi
#     The control again, on the same note and the same pages: its VISIBLE `note`
#     tag keeps its class everywhere, so these checks are a difference between two
#     tags rather than the absence of all tag markup.
grep -q 'idea-tag-note' "$H/ideas/secret-note.html" ||
  note "ideas/secret-note.html lost the visible 'note' tag class"
grep -q 'SECRETBODY' "$H/ideas/secret-note.html" ||
  note "ideas/secret-note.html does not render its body"

# 11. NOT COVERED HERE, deliberately, and recorded so the gap is a decision
#     rather than an oversight: the `sys.inputs` half of the exclusion
#     (`--input rookery-exclude=..` / `rookery-include=..`). `rheo compile`
#     forwards no `--input` at all today — `build_inputs` in rheo core inserts
#     only `rheo-context` — so there is no way to vary it from here.
#     `demo/pure` covers that half (it compiles `excluded.typ` twice, one
#     `--input` apart), and rheo beads `rheo-cli-input-flag-q12` /
#     `rheo-toml-inputs-table-rih` are what will make it reachable from a rheo
#     build. Nothing in this package changes when they land.

# 12. A DERIVED TITLE ON A MINTED PAGE. `demo/pure` asserts the derivation on a
#     card; only here is there a minted page, whose `<title>` and `<h1>` used to
#     fall back to the note's SLUG — so an untitled note's own page was named `1`.
#     The note is called `derived-note`, so the slug and the derived title are
#     plainly different strings and the assertion cannot pass by accident.
dp="$H/ideas/derived-note.html"
[ -f "$dp" ] || note "no minted page at ideas/derived-note.html"
if [ -f "$dp" ]; then
  grep -q '<title>DERIVEDBODY' "$dp" ||
    note "ideas/derived-note.html <title> is not the derived title: $(grep -oE '<title>[^<]*' "$dp")"
  #   AND THE <h1> IS EMPTY, which is the other half of the split and the
  #   regression guard for the defect it fixed: a derived name is a LABEL for
  #   referring to the note, not a heading to print above the note's own body.
  #   MEASURED before the split — the minted page rendered `<h1>DERIVEDBODY..</h1>`
  #   and then `<p>DERIVEDBODY..</p>`, the same text twice.
  grep -q '<h1 id="idea:derived-note" class="idea"></h1>' "$dp" ||
    note "ideas/derived-note.html <h1> is not empty — a label is being printed as a heading"
  if grep -q '<span class="idea-title">DERIVEDBODY' "$dp"; then
    note "ideas/derived-note.html prints its derived label as a heading"
  fi
  #   Cut to sixty characters with an ellipsis, on the minted page as on a card.
  grep -qE '<title>DERIVEDBODY[^<]{40,50}\.\.\.</title>' "$dp" ||
    note "the minted page's derived title was not truncated with an ellipsis"
fi
#     And the index row uses it rather than the bare id.
grep -q 'derived-note.html">DERIVEDBODY' "$H/ideas/index.html" ||
  note "ideas/index.html row for derived-note does not use its derived title"

if [ "$fail" -ne 0 ]; then
  echo "demo/rheo: FAILED"
  exit 1
fi
echo "demo/rheo OK"
