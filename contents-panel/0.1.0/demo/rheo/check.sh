#!/usr/bin/env bash
# Asserts on this demo's OUTPUT, not merely that the build succeeded.
#
# Every assertion below is asserted as CORRECT BEHAVIOUR, not as a description
# of whatever the current implementation happens to do — if one fails, the fix
# is in `src/`, not here. An assertion bent to match a bug would certify the
# bug, which is the one thing this file exists to avoid.
#
# What it is for: nothing this package emits is written by hand in the demo.
# The rows, their ids, their numbering and the anchors they point at are all
# derived at compile time, and every derivation here has already been wrong in
# a way that COMPILED CLEAN and shipped a broken box — a list of another page's
# sections, links to ids that existed nowhere, a flat page rendered as
# subsections of nothing. Those are the failures these assertions catch.
#
# Five pages, each carrying its own hazard: `index.typ` uses the default
# `separator: heading` with duplicate headings, `sections.typ` overrides
# `separator:` with a figure kind whose entries are flat, `nested.typ` goes
# three heading levels deep, `plain.typ` passes `breakpoint: none` and must
# carry no width-keyed rule at all, and `frame.typ` calls `frame` without
# `contents` and so must come out a frame with none of the list's classes on
# it. More than one page is itself load-bearing — a single-page demo could not
# catch the bug where `query()` returns the whole project's elements rather
# than the page's.
#
# Run through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

for f in index.html sections.html nested.html plain.html side.html frame.html; do
  [ -f "$H/$f" ] || note "no page at $f"
done

python3 - "$H" <<'PY' || fail=1
import os, re, sys, zipfile

H = sys.argv[1]
bad = 0


def fail(m):
    global bad
    print(f"FAIL: {m}")
    bad = 1


def read(page):
    path = os.path.join(H, page)
    if not os.path.isfile(path):
        fail(f"{page} missing")
        return None
    return open(path).read()


LINK = r'<a[^>]*class="([^"]*\brheo-contents-link\b[^"]*)"[^>]*href="#([^"]+)"'
LEVEL = r'<a[^>]*\brheo-contents-link\b[^>]*data-level="([0-9]+)"'
LABEL = r'<span class="rheo-contents-label">([^<]*)</span>'
NUM = r'<span class="rheo-contents-num">([^<]*)</span>'
ANCHOR = r'<div class="rheo-contents-anchor"[^>]*id="([^"]+)"'

pages = {}
for name in ("index.html", "sections.html", "nested.html", "plain.html", "side.html"):
    h = read(name)
    if h is None:
        continue
    pages[name] = dict(
        html=h,
        links=re.findall(LINK, h),
        levels=re.findall(LEVEL, h),
        labels=re.findall(LABEL, h),
        nums=re.findall(NUM, h),
        anchors=re.findall(ANCHOR, h),
        ids=set(re.findall(r'\bid="([^"]+)"', h)),
    )

for name, p in pages.items():
    h = p["html"]

    # 1. Exactly one box, in exactly one aside, wearing BOTH prefixes. The
    #    frame's classes (`rheo-panel-*`, from `src/panel.typ`) and the list's
    #    (`rheo-contents-*`) sit on the same two elements: the frame carries
    #    the shape and a project's own layout rules, the list carries the rows
    #    and every rule that restyles a frame part for a contents box. A box
    #    missing either half is styled by half the stylesheet.
    for pat, what in (
        (r'<nav class="[^"]*\brheo-panel-box\b', "rheo-panel-box"),
        (r'<nav class="[^"]*\brheo-contents-box\b', "rheo-contents-box"),
        (r'<aside class="[^"]*\brheo-panel-aside\b', "rheo-panel-aside"),
        (r'<aside class="[^"]*\brheo-contents-aside\b', "rheo-contents-aside"),
    ):
        n = len(re.findall(pat, h))
        if n != 1:
            fail(f"{name}: expected exactly one {what}, found {n}")

    # 2. THE DOCUMENT IS NOT WRAPPED. `contents` must emit the box as a SIBLING
    #    of the page's content: any element around `doc` makes Typst reject a
    #    template's `set document(..)` with "document set rules are not allowed
    #    inside of containers", which is a compile failure for most real
    #    vertebrae. A wrapper reappearing here is that bug coming back.
    for gone in ("rheo-contents-layout", "rheo-contents-main"):
        if gone in h:
            fail(f"{name}: {gone} is back — the document must not be wrapped")

    # 3. THE SLUG-AGREEMENT INVARIANT, the most important assertion here. Every
    #    link must resolve to an anchor on the SAME page. The ids and the hrefs
    #    are derived on two different code paths (a show rule and the row
    #    builder) and a divergence ships dead links with no error anywhere.
    missing = [t for _, t in p["links"] if t not in p["ids"]]
    if missing:
        fail(f"{name}: contents links with no matching id on the page: {missing}")

    # 4. One link per anchor, neither more nor fewer.
    if len(p["links"]) != len(p["anchors"]):
        fail(
            f"{name}: {len(p['links'])} links but {len(p['anchors'])} anchors — "
            f"every entry should produce exactly one of each"
        )

    # 5. Ids are unique. Dedup exists precisely so two same-named entries do
    #    not collide, and a collision is invisible except as a link that
    #    scrolls to the wrong place.
    ids = [t for _, t in p["links"]]
    if len(ids) != len(set(ids)):
        fail(f"{name}: duplicate contents ids: {ids}")

    # 6. The responsive rules were hoisted into <head>. Both are emitted per
    #    page rather than shipped in contents.css because a custom property
    #    cannot be used in an @media query.
    #
    #    `plain.html` passes `breakpoint: none` and so must carry NEITHER —
    #    that mode exists precisely so a project can own every width-keyed
    #    rule itself, and a stray one from the package would silently fight
    #    the project's own.
    #
    #    `side.html` passes `side: left` and so must reserve the room on the
    #    LEFT. The side is asserted BOTH WAYS — `padding-left` present and
    #    `padding-right` absent — because the failure worth catching is not a
    #    missing rule but a panel moved with its reservation left behind on
    #    the old side, which compiles, renders, and puts the box on top of the
    #    prose.
    head = h[: h.find("</head>")]
    has_bp = bool(re.search(r"<style>[^<]*@media\s*\(max-width:", head))
    want_pad = "padding-left" if name == "side.html" else "padding-right"
    wrong_pad = "padding-right" if name == "side.html" else "padding-left"
    has_reserve = want_pad in head
    if name == "plain.html":
        if has_bp:
            fail("plain.html: breakpoint: none still emitted an @media rule")
        # Either side counts as a stray rule here; `breakpoint: none` emits no
        # `reserve` padding at all.
        if "padding-left" in head or "padding-right" in head:
            fail("plain.html: breakpoint: none still emitted a `reserve` rule")
        if "<style>" in head:
            fail("plain.html: an empty <style> was hoisted with nothing to put in it")
    else:
        if not has_bp:
            fail(f"{name}: no breakpoint @media rule hoisted into <head>")
        if not has_reserve:
            fail(f"{name}: no `reserve` padding rule hoisted into <head>")
        if wrong_pad in head:
            fail(f"{name}: `reserve` padded {wrong_pad}, the side the panel is not on")
    # The TAG, not the bare name: the demo's prose discusses the wrapper.
    if re.search(r"</?rheo-head[\s>]", h):
        fail(f"{name}: a literal <rheo-head> tag survives — the hoist did not run")

# 6d. `side: left` IS TWO EMISSIONS THAT MUST AGREE, and they are produced on
#     different code paths — the class on the aside comes from `panel.typ`,
#     the `reserve` padding side from `lib.typ`'s hoisted `<style>` (asserted
#     above). Either alone is a bug that compiles and renders: the class
#     without the padding puts the box over the prose, the padding without the
#     class clears a column the box is not in.
#
#     The negative half matters as much: `rheo-panel-side-left` on a page that
#     did not ask for it would mirror the frame of every default panel.
for name, p in pages.items():
    has_class = "rheo-panel-side-left" in p["html"]
    if name == "side.html" and not has_class:
        fail("side.html: side: left did not put rheo-panel-side-left on the aside")
    if name != "side.html" and has_class:
        fail(f"{name}: rheo-panel-side-left on a panel that did not ask for it")

# 6e. THE LIST DOES NOT MIRROR WITH THE FRAME. `side:` is a side-of-the-page
#     switch, not a text direction, so the rows on `side.html` must come out
#     byte-identical in structure to a default page's: same subsection class,
#     same numbering, same order. A `direction: rtl` implementation — which is
#     what this package first reached for — passes every assertion above and
#     fails here, because it would have reversed the labels too.
if "side.html" in pages:
    p = pages["side.html"]
    if not any("rheo-contents-sub" in c for c, _ in p["links"]):
        fail("side.html: no subsection row — the list's own geometry was lost")
    if p["nums"] != ["1", "1.1", "1.2", "1.3", "1.4"]:
        fail(f"side.html: numbering differs from a default page's: {p['nums']}")

# 6c. THE FRAME WITHOUT THE LIST. `frame.typ` calls `frame` and never
#     `contents`, which is the mode the frame was pulled out of this package
#     for — the box's shape around prose a page hands it. Two ways for that to
#     regress, and both compile clean: the frame comes out carrying the list's
#     classes anyway (styled by rules meant for rows it has not got, and picked
#     up by a script with nothing to do to it), or `cap-text` does not reach the
#     hat and the panel is a bordered block with no name on it.
fh = read("frame.html")
if fh is not None:
    for pat, what in (
        (r'<aside class="[^"]*\brheo-panel-aside\b', "rheo-panel-aside"),
        (r'<div class="[^"]*\brheo-panel-box\b', "rheo-panel-box"),
        (r'<div class="rheo-panel-header"', "rheo-panel-header"),
    ):
        n = len(re.findall(pat, fh))
        if n != 1:
            fail(f"frame.html: expected exactly one {what}, found {n}")
    if not re.search(r'<span class="rheo-panel-title">about the author</span>', fh):
        fail("frame.html: `cap-text` did not reach the hat's title")
    for gone in (
        "rheo-contents-aside",
        "rheo-contents-box",
        "rheo-contents-list",
        "rheo-contents-link",
        "rheo-contents-anchor",
        "data-offset-selector",
    ):
        if gone in fh:
            fail(f"frame.html: a bare frame must not carry {gone}")

# 6b. DEEP LEVELS ARE FLATTENED, NOT DROPPED. `nested.html` uses three heading
#     depths. Keeping only the two shallowest silently omitted every `===`,
#     leaving those sections unreachable from the box with no error anywhere.
#     All eight entries must be listed; the third level must render as
#     SUBSECTION rows (two drawn rungs, not three); and `data-level` must carry
#     the entry's REAL depth, since the script's progress geometry needs to
#     know a `===` is inside its `==` even though both draw the same.
if "nested.html" in pages:
    p = pages["nested.html"]
    if len(p["links"]) != 8:
        fail(f"nested.html: expected all 8 entries, got {len(p['links'])} — a level was dropped")
    if sorted(set(p["levels"])) != ["1", "2", "3"]:
        fail(f"nested.html: data-level should carry real depths 1/2/3, got {sorted(set(p['levels']))}")
    classes = dict((t, c) for c, t in p["links"])
    third = [t for (c, t), d in zip(p["links"], p["levels"]) if d == "3"]
    if not third:
        fail("nested.html: no depth-3 entry survived")
    for t in third:
        if "rheo-contents-sub" not in classes[t]:
            fail(f"nested.html: depth-3 entry {t} is not drawn as a subsection row")
    # Flattened, so a `===` numbers as a sibling of the `==` above it: two
    # number components, never three.
    if any(n.count(".") > 1 for n in p["nums"]):
        fail(f"nested.html: numbering went three deep — only two rungs are drawn: {p['nums']}")
    if p["nums"] != ["1", "1.1", "1.2", "1.3", "1.4", "2", "2.1", "2.2"]:
        fail(f"nested.html: unexpected numbering {p['nums']}")

# 6c. THE ROOKERY THEME CLASS IS MODE-SPECIFIC. `.rheo-contents-rookery` maps
#     `--idea-*` onto this package's variables, and those only exist inside a
#     rookery's idea box. None of these demo pages is a rookery, so none may
#     carry the class — if one did, every mapped variable would fall through
#     to its fallback and the mapping would be silently untested.
for name, p in pages.items():
    if "rheo-contents-rookery" in p["html"]:
        fail(f"{name}: carries .rheo-contents-rookery outside rookery mode")

# 7. PAGE SCOPING. rheo compiles the whole project in ONE Typst pass, so an
#    unfiltered `query()` returns every page's elements. This is the assertion
#    that catches that: neither page may list any of the other's entries.
names = sorted(pages)
for i, na in enumerate(names):
    if not pages[na]["labels"]:
        fail(f"{na} listed nothing at all")
    for nb in names[i + 1 :]:
        leak = set(pages[na]["labels"]) & set(pages[nb]["labels"])
        if leak:
            fail(f"{na} and {nb} list each other's entries — query is not page-scoped: {sorted(leak)}")

# 8. The default `separator: heading` path, on index.html: nested numbering,
#    a subsection row, and dedup of the two identical "Notes" headings.
if "index.html" in pages:
    p = pages["index.html"]
    if "1.1" not in p["nums"]:
        fail(f"index.html: no nested numbering, so no subsection was drawn: {p['nums']}")
    if not re.search(r'class="[^"]*rheo-contents-sub', p["html"]):
        fail("index.html: no rheo-contents-sub row — the second level is not being indented")
    notes = [t for _, t in p["links"] if re.fullmatch(r"notes(-\d+)?", t)]
    if sorted(notes) != ["notes", "notes-2"]:
        fail(f"index.html: the two identical 'Notes' headings did not dedup to notes/notes-2: {notes}")

# 9. The `separator:` path, on sections.html. Its sections are figures, not
#    headings — the case waterline's weeknotes are an instance of, where a
#    template consumes the author's headings and re-emits the titles as raw
#    HTML that `query(heading)` cannot see.
if "sections.html" in pages:
    p = pages["sections.html"]
    if p["labels"] != ["Alpha", "Beta", "Alpha"]:
        fail(f"sections.html: expected the three figure captions as labels, got {p['labels']}")
    if [t for _, t in p["links"]] != ["alpha", "beta", "alpha-2"]:
        fail(f"sections.html: wrong ids on the separator path: {[t for _, t in p['links']]}")
    # `separator:` REPLACES the default; it does not add to it. The page's one
    # real heading must not appear.
    if any("not headings" in l for l in p["labels"]):
        fail("sections.html: a real heading was listed even though separator: was set")
    # Figures carry neither `depth` nor `level`, so the list is flat. A
    # subsection row here means entry-depth invented a hierarchy.
    if "rheo-contents-sub" in p["html"]:
        fail("sections.html: flat entries were rendered as subsections")
    if p["nums"] != ["1", "2", "3"]:
        fail(f"sections.html: flat entries should number 1,2,3 — got {p['nums']}")

# 10. NON-HTML TARGETS GET THE DOCUMENT UNTOUCHED. `contents` returns `doc`
#     unwrapped when `target() != "html"`, so none of its markup may reach the
#     EPUB: a fixed progress rail is meaningless in a reflowable book, and EPUB
#     builds its own outline from the headings. Asserted because the show rule
#     is applied unconditionally by the vertebra, so a regression in the target
#     guard is invisible in the HTML the assertions above read.
epub = os.path.join(os.path.dirname(H), "epub", "rheo.epub")
if not os.path.isfile(epub):
    fail(f"no EPUB at {epub}")
else:
    with zipfile.ZipFile(epub) as z:
        leaked = sorted(
            n
            for n in z.namelist()
            if n.endswith((".xhtml", ".html")) and b"rheo-contents-panel" in z.read(n)
        )
    if leaked:
        fail(f"contents-box markup leaked into the EPUB: {leaked}")

if not bad:
    total = sum(len(p["links"]) for p in pages.values())
    print(
        f"  contents: {len(pages)} pages, {total} rows, every id resolves, "
        f"pages scoped apart, both separator paths correct, EPUB clean"
    )
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "demo/rheo OK"; else echo "demo/rheo FAILED"; exit 1; fi
