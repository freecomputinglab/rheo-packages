#!/usr/bin/env bash
# Asserts on this demo's OUTPUT: two Atom feeds built from disjoint subsets
# of one small site, the second sourced from @rheo/rookery's `ideas(tags:)`
# rather than rssfeed's own `<rssfeed:item>` beacon protocol. Modelled on
# rookery/0.3.0/demo/rheo/check.sh — greps rather than a test framework,
# deliberately: the package ships no runner and adding one for a handful of
# assertions would be more machinery than the thing it checks. Run through
# `just check`, which builds first.
#
# ALSO pins the parity matrix of bead rheo-packages-parity-qrd (rows 1, 3, 5,
# 6, 8, 10 land here — see ../verify/ for rows 2, 4, 7, 11, 12, which cannot
# coexist with this demo's own content/config). Each block below is labelled
# with its row number.
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
#    pass, not left as the marker rssfeed's own `atom(...)` mints. `if !`
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
FEED_LINK='<link rel="alternate" type="application/atom+xml" href="https://demo.example.org/feed.xml" title="Rssfeed Demo — Posts">'
NOTES_LINK='<link rel="alternate" type="application/atom+xml" href="https://demo.example.org/notes.xml" title="Rssfeed Demo — Notes">'
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
if ! python3 - "$H" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
bad = 0

def fail(msg):
    global bad
    print(f"FAIL: {msg}")
    bad = 1

def entries(path):
    return re.findall(r"<entry>(.*?)</entry>", path.read_text(), re.S)

def field(entry, tag):
    m = re.search(rf"<{tag}[^>]*>(.*?)</{tag}>", entry, re.S)
    return m.group(1) if m else None

def link(entry):
    m = re.search(r'<link rel="alternate" href="([^"]+)"/>', entry)
    return m.group(1) if m else None

feed_text = (root / "feed.xml").read_text()
notes_text = (root / "notes.xml").read_text()
feed_entries = entries(root / "feed.xml")
notes_entries = entries(root / "notes.xml")

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
# its own content/posts/*.typ set, not e.g. a build-time value.
expected_dates = {
    "One": "2026-01-05T00:00:00Z",
    "Two": "2026-02-12T00:00:00Z",
    "Three": "2026-03-20T00:00:00Z",
}
for e in feed_entries:
    title = field(e, "title")
    want = expected_dates.get(title)
    if want is None:
        continue
    got_updated = field(e, "updated")
    got_published = field(e, "published")
    if got_updated != want:
        fail(f"{title}'s <updated> is {got_updated!r}, expected {want!r} (its own #set document(date: ..))")
    if got_published != want:
        fail(f"{title}'s <published> is {got_published!r}, expected {want!r}")

sys.exit(1 if bad else 0)
PY
then
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "demo: FAILED"
  exit 1
fi
echo "demo OK"
