#!/usr/bin/env bash
# Asserts on this demo's OUTPUT: two Atom feeds built from disjoint subsets
# of one small site, the second sourced from @rheo/rookery's `ideas(tags:)`
# rather than rssfeed's own `<rssfeed:item>` beacon protocol. Modelled on
# rookery/0.3.0/demo/rheo/check.sh — greps rather than a test framework,
# deliberately: the package ships no runner and adding one for a handful of
# assertions would be more machinery than the thing it checks. Run through
# `just check`, which builds first.
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
#    page — carries BOTH feeds' autodiscovery <link> tags. This comes from
#    the single `.rheo/head.html` control asset `_mint-plan` mints, spliced
#    into every page rheo compiles, not just the one vertebra that called
#    `configure(...)`.
for p in index.html notes.html \
  posts/one.html posts/two.html posts/deep/three.html \
  ideas/alpha.html ideas/alpha-inner.html ideas/beta.html ideas/gamma.html; do
  head="$(grep -o '<head>.*</head>' "$H/$p" || true)"
  n=$(printf '%s' "$head" | grep -o 'type="application/atom+xml"' | wc -l)
  [ "$n" -ge 2 ] ||
    note "$p's <head> has fewer than 2 atom autodiscovery links (found $n)"
  case "$head" in
    *'href="https://demo.example.org/feed.xml"'*) ;;
    *) note "$p's <head> is missing the feed.xml autodiscovery link" ;;
  esac
  case "$head" in
    *'href="https://demo.example.org/notes.xml"'*) ;;
    *) note "$p's <head> is missing the notes.xml autodiscovery link" ;;
  esac
done

# 5. Entry sets, disjointness, and notes.xml's links — easier to get right in
#    a small parser than in nested greps, the same tradeoff the reference
#    check.sh already makes for its own backlink assertion.
if ! python3 - "$H" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
bad = 0

def entries(path):
    return re.findall(r"<entry>(.*?)</entry>", path.read_text(), re.S)

def field(entry, tag):
    m = re.search(rf"<{tag}[^>]*>(.*?)</{tag}>", entry, re.S)
    return m.group(1) if m else None

def link(entry):
    m = re.search(r'<link rel="alternate" href="([^"]+)"/>', entry)
    return m.group(1) if m else None

feed_entries = entries(root / "feed.xml")
notes_entries = entries(root / "notes.xml")

if len(feed_entries) == 0:
    print("FAIL: feed.xml has no entries"); bad = 1
if len(notes_entries) == 0:
    print("FAIL: notes.xml has no entries"); bad = 1

feed_ids = {field(e, "id") for e in feed_entries}
notes_ids = {field(e, "id") for e in notes_entries}
overlap = feed_ids & notes_ids
if overlap:
    print(f"FAIL: feed.xml and notes.xml share entry ids: {sorted(overlap)}")
    bad = 1

# notes.xml's entries: absolute URL ending in ideas/<slug>.html, matching a
# real minted file on disk — including the note nested inside another
# note's body (alpha-inner).
seen_slugs = set()
for e in notes_entries:
    href = link(e)
    m = re.match(r"^https://[^/]+/(ideas/[\w-]+\.html)$", href or "")
    if not m:
        print(f"FAIL: notes.xml entry link is not an absolute ideas/<slug>.html URL: {href!r}")
        bad = 1
        continue
    rel = m.group(1)
    seen_slugs.add(rel)
    if not (root / rel).is_file():
        print(f"FAIL: notes.xml entry links to {href}, no such file at {root / rel}")
        bad = 1

if "ideas/alpha-inner.html" not in seen_slugs:
    print("FAIL: notes.xml is missing the nested note's entry (ideas/alpha-inner.html)")
    bad = 1

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
