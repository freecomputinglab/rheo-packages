#!/usr/bin/env bash
# Asserts on this demo's OUTPUT: two Atom feeds built from disjoint subsets
# of one small site, the second sourced from @rheo/rookery's `ideas(tags:)`
# rather than @rheo/feeds's own `<feeds:item>` beacon protocol. Modelled on
# rookery/0.5.0/demo/rheo/check.sh — greps rather than a test framework,
# deliberately: the package ships no runner and adding one for a handful of
# assertions would be more machinery than the thing it checks. Run through
# `just check`, which builds first. The Atom-parsing helpers it uses are shared
# with ../verify/run.sh and live in ../verify/atomlib.py — add to that module
# rather than copying them into a third script.
#
# ALSO pins the parity matrix of bead rheo-packages-parity-qrd (rows 1, 3, 5,
# 6, 8, 9, 10 land here — see ../verify/ for rows 2, 4, 7, 11, 12, which
# cannot coexist with this demo's own content/config). Each block below is
# labelled with its row number. Row 9 — entry title from the AUTHORED
# `#set document(title: ..)`, not spine()'s filename-derived fallback — was
# recorded unpinnable in ../verify/EXPECTED.md until bead rheo-packages-mxqa
# gave the beacon's own flattened title precedence in `spine()`.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

# 1. Both feeds exist and are non-empty.
for f in feed.xml notes.xml; do
  [ -s "$H/$f" ] || note "$H/$f is missing or empty"
done

# 2. No `.rheo/` control-asset directory survives into the build output — it
#    is consumed while minting every page's <head> autodiscovery links, not
#    written to disk itself.
if [ -d "$H/.rheo" ]; then
  note "$H/.rheo/ survived into the build output"
fi

# 3. Neither feed carries a literal `<rheo-content` placeholder — both must
#    have been resolved to real, escaped page content by rheo's transclusion
#    pass, not left as the marker @rheo/feeds's own `atom(...)` mints. `if !`
#    rather than `grep ... && note ...`: an AND-list whose first command is
#    meant to FAIL reads as an accident, and one edit away from tripping
#    `set -e` (same reasoning the reference check.sh's own comment records).
for f in feed.xml notes.xml; do
  if grep -q '<rheo-content' "$H/$f"; then
    note "$H/$f still carries an unresolved <rheo-content> placeholder"
  fi
done

# 4. Every page's <head> — root AND nested, a vertebra AND a minted note
#    page (row 5: autodiscovery on every page, root and nested) — carries
#    BOTH feeds' autodiscovery <link> tags, each with its OWN feed's `title=`
#    attribute (row 3: the configured `title` is both the feed-level
#    `<title>` AND the autodiscovery link's `title=`). Checked as one exact
#    tag string per feed, not href and title separately, so a link with the
#    WRONG title paired to a RIGHT href would still be caught.
FEED_LINK='<link rel="alternate" type="application/atom+xml" href="https://demo.example.org/feed.xml" title="Feeds Demo — Posts">'
NOTES_LINK='<link rel="alternate" type="application/atom+xml" href="https://demo.example.org/notes.xml" title="Feeds Demo — Notes">'
for p in index.html notes.html \
  posts/one.html posts/two.html posts/deep/three.html \
  ideas/alpha.html ideas/alpha-inner.html ideas/beta.html ideas/gamma.html; do
  head="$(grep -o '<head>.*</head>' "$H/$p" || true)"
  case "$head" in
    *"$FEED_LINK"*) ;;
    *) note "$p's <head> is missing feed.xml's autodiscovery link (exact href+title pairing)" ;;
  esac
  case "$head" in
    *"$NOTES_LINK"*) ;;
    *) note "$p's <head> is missing notes.xml's autodiscovery link (exact href+title pairing)" ;;
  esac
done

# 5. Entry sets, disjointness, notes.xml's links, and the rest of the parity
#    matrix that's easier to get right in a small parser than in nested
#    greps — same tradeoff the reference check.sh already makes for its own
#    backlink assertion.
if ! python3 - "$H" ../verify <<'PY'
import re, sys, pathlib
# The four Atom-parsing helpers live in ../verify/atomlib.py, shared with
# ../verify/run.sh — they used to be copied into both scripts and had already
# drifted by one function. A stdin script has no `__file__`, so the directory
# holding them is passed in as argv[2] rather than derived here.
sys.path.insert(0, sys.argv[2])
from atomlib import Checker, entries, field, link

root = pathlib.Path(sys.argv[1])
_checker = Checker()
fail = _checker.fail

feed_text = (root / "feed.xml").read_text()
notes_text = (root / "notes.xml").read_text()
feed_entries = entries(feed_text)
notes_entries = entries(notes_text)

if len(feed_entries) == 0:
    fail("feed.xml has no entries")
if len(notes_entries) == 0:
    fail("notes.xml has no entries")

feed_ids = {field(e, "id") for e in feed_entries}
notes_ids = {field(e, "id") for e in notes_entries}
overlap = feed_ids & notes_ids
if overlap:
    fail(f"feed.xml and notes.xml share entry ids: {sorted(overlap)}")

# Row 1: feed-level author is per-feed, not document-global — feed.xml and
# notes.xml configure DIFFERENT custom authors in content/index.typ.
if "<author><name>The Editors</name></author>" not in feed_text:
    fail("feed.xml is missing its configured custom <author> (The Editors)")
if "<author><name>The Rookery</name></author>" not in notes_text:
    fail("notes.xml is missing its configured custom <author> (The Rookery)")

# Row 6: entry URLs are absolute and correct — base-url + "/" + output_path,
# including the nested page. For a spine()-sourced entry (feed.xml), `id`
# defaults to that same URL: <id> must equal the <link> href exactly.
for e in feed_entries:
    href = link(e)
    eid = field(e, "id")
    if eid != href:
        fail(f"feed.xml entry {field(e, 'title')!r} has id {eid!r} != link href {href!r}")
three = next((e for e in feed_entries if field(e, "title") == "Three"), None)
if three is None:
    fail("feed.xml is missing the nested post's entry (posts/deep/three.typ)")
elif link(three) != "https://demo.example.org/posts/deep/three.html":
    fail(f"nested post's link is wrong: {link(three)!r}")

# A MINTED PAGE'S FULL CONTENT REACHES THE FEED. This is the assertion that
# pins rheo 0.6.0's transclusion of minted pages: through feeds 0.1.0 the same
# config was impossible and notes.xml carried `content: none` with a comment
# calling the limitation permanent.
#
# Three things, because two of them fail SILENTLY and would otherwise ship: a
# `<content>` element per entry, no literal `<rheo-content` placeholder anywhere
# in the file (on a below-floor rheo that string reaches real readers as
# well-formed XML carrying garbage), and content that actually looks like the
# note's rendered body rather than an empty element.
for e in notes_entries:
    body = field(e, "content")
    title = field(e, "title")
    if body is None:
        fail(f"notes.xml entry {title!r} has no <content> — minted-page transclusion is not reaching the feed")
    elif not body.strip():
        fail(f"notes.xml entry {title!r} has an EMPTY <content>")
    elif "idea-" not in body:
        fail(f"notes.xml entry {title!r} has <content> that does not look like a rendered note body")
if "<rheo-content" in notes_text:
    fail("notes.xml ships a literal <rheo-content> placeholder — the transclusion did not resolve")

# Row 6 (rookery exception, stated explicitly rather than papered over): a
# notes.xml entry's <id> is rookery's OWN note id (e.g. "idea:beta"), NOT a
# URL — the entry model's documented "id defaults to url, but a source may
# set its own" behaviour. `<link href>` is still the real absolute URL.
for e in notes_entries:
    eid = field(e, "id")
    href = link(e)
    if not (eid and eid.startswith("idea:")):
        fail(f"notes.xml entry {field(e, 'title')!r} has id {eid!r}, expected an \"idea:*\" rookery id")
    if eid == href:
        fail(f"notes.xml entry {field(e, 'title')!r} has id == link href ({eid!r}); "
             f"expected the rookery id and the URL to be DIFFERENT")

# notes.xml's entries: absolute URL ending in ideas/<slug>.html, matching a
# real minted file on disk — including the note nested inside another
# note's body (alpha-inner).
seen_slugs = set()
for e in notes_entries:
    href = link(e)
    m = re.match(r"^https://[^/]+/(ideas/[\w-]+\.html)$", href or "")
    if not m:
        fail(f"notes.xml entry link is not an absolute ideas/<slug>.html URL: {href!r}")
        continue
    rel = m.group(1)
    seen_slugs.add(rel)
    if not (root / rel).is_file():
        fail(f"notes.xml entry links to {href}, no such file at {root / rel}")

if "ideas/alpha-inner.html" not in seen_slugs:
    fail("notes.xml is missing the nested note's entry (ideas/alpha-inner.html)")

# Row 8: a vertebra excluded from EVERY source (index.html: not under
# posts/, not an idea) still gets its own HTML page built. "True by
# construction" is exactly what silently stops being true, so assert it.
if not (root / "index.html").is_file():
    fail("index.html (excluded from every feed source) was not built")
all_titles = {field(e, "title") for e in feed_entries + notes_entries}
if "Index" in all_titles:
    fail("index.html leaked into a feed as an entry despite matching no source")
all_hrefs = {link(e) for e in feed_entries + notes_entries}
if any((href or "").endswith("/index.html") for href in all_hrefs):
    fail("some entry links to index.html despite matching no source")

# Row 10: an entry's timestamp falls back to the document date — each dated
# post's `<updated>` (and, since spine() mirrors one date into both fields,
# `<published>` too) must equal exactly the `#set document(date: ..)` value
# its own content/posts/*.typ set, not e.g. a build-time value. Keyed by the
# entry's own URL suffix, not its title — bead rheo-packages-mxqa (below)
# makes `title` the AUTHORED value now, so title can no longer double as a
# stable lookup key here.
expected_dates = {
    "posts/one.html": "2026-01-05T00:00:00Z",
    "posts/two.html": "2026-02-12T00:00:00Z",
    "posts/deep/three.html": "2026-03-20T00:00:00Z",
}
for e in feed_entries:
    href = link(e) or ""
    suffix = href.removeprefix("https://demo.example.org/")
    want = expected_dates.get(suffix)
    if want is None:
        continue
    got_updated = field(e, "updated")
    got_published = field(e, "published")
    if got_updated != want:
        fail(f"{suffix}'s <updated> is {got_updated!r}, expected {want!r} (its own #set document(date: ..))")
    if got_published != want:
        fail(f"{suffix}'s <published> is {got_published!r}, expected {want!r}")

# Row 9 (bead rheo-packages-mxqa): an entry's <title> is the AUTHORED
# `#set document(title: ..)` value, not spine()'s filename-derived fallback.
# `posts/one.typ` sets a plain STRING title; `posts/two.typ` sets a bracket
# CONTENT title containing markup (`#emph[..]`) — the second exercises
# `spine()`'s `_plain-text` flattener itself, not merely a field read that
# happens to already be a string.
expected_titles = {
    "posts/one.html": "Custom Post Title",
    "posts/two.html": "Two, emphatically",
}
for e in feed_entries:
    href = link(e) or ""
    suffix = href.removeprefix("https://demo.example.org/")
    want = expected_titles.get(suffix)
    if want is None:
        continue
    got = field(e, "title")
    if got != want:
        fail(f"{suffix}'s <title> is {got!r}, expected the AUTHORED {want!r} "
             "(spine()'s filename-derived fallback must not win when the "
             "vertebra sets its own #set document(title: ..))")
# The filename-derived fallbacks ("One"/"Two") must not survive anywhere in
# feed.xml now that both posts author their own title — a stronger,
# fallback-catching check than the exact-match one above on its own (which
# would stay silent if `title` were accidentally left blank instead).
all_titles_now = {field(e, "title") for e in feed_entries}
for stale in ("One", "Two"):
    if stale in all_titles_now:
        fail(
            f"feed.xml still carries the filename-derived fallback title "
            f"'{stale}' instead of the authored #set document(title: ..)",
        )

sys.exit(_checker.exit_code())
PY
then
  fail=1
fi

# 11. The subscribe modal (`feeds-modal`), called once from content/index.typ.
count() { grep -o "$1" "$2" 2>/dev/null | wc -l | tr -d ' '; }

[ "$(count 'id="subscribe-dialog"' $H/index.html)" = "1" ] \
  || note "index.html should carry exactly one subscribe dialog"
# Two options: the PREGIVEN Atom entry plus the one supplied via `options:`.
[ "$(count 'class="subscribe-option"' $H/index.html)" = "2" ] \
  || note "index.html should carry exactly two subscribe options (Atom + Newsletter)"
grep -q 'href="/feed.xml"' $H/index.html \
  || note "the pregiven Atom option should link this demo's own feed path"
grep -q 'href="mailto:demo@example.org?subject=subscribe"' $H/index.html \
  || note "the supplied Newsletter option should link its mailto"
[ "$(count '@layer feeds-modal' $H/index.html)" = "1" ] \
  || note "index.html should carry exactly one layered modal stylesheet"
grep -q 'getElementById("subscribe-dialog")' $H/index.html \
  || note "index.html should carry the modal script, scoped to the dialog's id"

# 12. THE LOAD-BEARING NEGATIVE. notes.html is built by the same project, from
# the same bundle, and reaches @rheo/feeds the same way — but never calls
# `feeds-modal`. Importing the package must therefore add nothing to it. If any
# of these three fire, the modal has stopped being opt-in-by-call, which is the
# entire reason it emits its CSS and JS inline instead of declaring a
# `[tool.rheo.html]` bundle.
for pattern in 'subscribe-dialog' '@layer feeds-modal' 'subscribe-btn'; do
  grep -q "$pattern" $H/notes.html \
    && note "notes.html calls no feeds-modal, so it must not carry '$pattern'"
done

if [ "$fail" -ne 0 ]; then
  echo "demo: FAILED"
  exit 1
fi
echo "demo OK"
