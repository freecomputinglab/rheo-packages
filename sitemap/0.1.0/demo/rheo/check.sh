#!/usr/bin/env bash
# Asserts on this demo's OUTPUT, not merely that the build succeeded.
#
# `@rheo/sitemap` derives all three of its views — tree, feed, nav — from
# rheo's own spine, so a regression in the walk compiles clean and ships a
# wrong site. Run through `just check`, which builds first.
#
# Every assertion below is asserted as the CORRECT behavior: a failure means
# the code is wrong, not that the assertion should be relaxed. An assertion
# bent to match a bug would certify the bug instead of catching it, which is
# the one thing this file exists to avoid.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

# Landing pages for a directory FOLD into the directory's own node — a
# vertebra at content/posts/index.typ is written to posts.html, not
# posts/index.html. See core.typ's own `first-path` comment.
for f in index.html posts.html posts/first.html posts/second.html guide/deep.html; do
  [ -f "$H/$f" ] || note "no page at $f"
done

if [ "$fail" -ne 0 ]; then
  echo "demo/rheo FAILED"
  exit 1
fi

python3 - "$H" <<'PY' || fail=1
import os, re, sys

H = sys.argv[1]
bad = 0
def fail(m):
    global bad
    print(f"FAIL: {m}")
    bad = 1

def read(page):
    return open(os.path.join(H, page)).read()

index = read("index.html")

# ---- THE TREE --------------------------------------------------------------

if 'class="sitemap"' not in index:
    fail("index.html: no div.sitemap")

rows = re.findall(r'<div class="sitemap-row">', index)
# root + guide + guide:deep + index + posts + posts:first + posts:second
if len(rows) != 7:
    fail(f"index.html: {len(rows)} .sitemap-row, expected 7 (root + 6 nodes) — is the walk visiting every node?")

# `guide/` has no index.typ and `[spine] auto_index = false` in this demo's
# rheo.toml keeps rheo from synthesizing one, so it is a real GROUP node:
# no handle, no page, named off the first path beneath it. It must be
# CELL TEXT "guide/", not a link.
dir_cells = re.findall(r'<span class="sitemap-name sitemap-dir">([^<]*)</span>', index)
if "guide/" not in dir_cells:
    fail(f"index.html: no .sitemap-dir cell reading 'guide/' (got {dir_cells}) — is a group node's name read from the wrong path segment?")
if re.search(r'<a[^>]*>\s*<span class="sitemap-name sitemap-dir">guide/</span>', index):
    fail("index.html: guide/ dir cell is wrapped in a link — a group node has no page to link to")

if 'href="./guide/deep.html"' not in index:
    fail("index.html: no sitemap-name link to guide/deep.html")

# The site root's own landing page (content/index.typ) is the tree's first row.
# No row may be labelled with the project's content directory — that is the
# `content/` leak this assertion exists to catch.
names = re.findall(r'<span class="sitemap-name(?: sitemap-dir)?">(?:<a[^>]*>)?([^<]*)(?:</a>)?</span>', index)
if any(n == "content/" for n in names):
    fail(f"index.html: a sitemap row is labelled 'content/' (got {names}) — is an index-folded node named from its path instead of its handle?")
if "posts/" not in names:
    fail(f"index.html: no sitemap row labelled 'posts/' (got {names}) — did the index-folded directory name regress?")

# ---- THE TITLE RULE ---------------------------------------------------------

titles = re.findall(r'<span class="sitemap-title">([^<]*)</span>', index)
if "The first post" not in titles:
    fail(f"index.html: 'The first post' missing from .sitemap-title cells, got {titles}")
if "Second" in titles:
    fail("index.html: second.typ's title merely restates its stem and should print no .sitemap-title")

# ---- THE FEED ----------------------------------------------------------------

feed = read("posts.html")
if '<ul class="sitemap-post-list">' not in feed:
    fail("posts.html: no ul.sitemap-post-list")

items = re.findall(r'<li class="sitemap-post-item">.*?</li>', feed, re.S)
if len(items) != 2:
    fail(f"posts.html: {len(items)} li.sitemap-post-item, expected 2")

# posts.html sits at the site root (its own handle "posts" has no `:`
# segment), so hrefs are the full path from root — "posts/first.html", not
# "first.html".
hrefs = re.findall(r'<a href="([^"]+)" class="sitemap-post-link"', feed)
if hrefs != ["posts/second.html", "posts/first.html"]:
    fail(f"posts.html: post-link hrefs are {hrefs}, expected ['posts/second.html', 'posts/first.html'] (newest first)")

# ---- THE NAV -----------------------------------------------------------------

pages = ["index.html", "posts.html", "posts/first.html", "posts/second.html", "guide/deep.html"]

for page in pages:
    h = read(page)
    if 'class="sidebar"' not in h:
        fail(f"{page}: no nav.sidebar")

    # The wrapper `@rheo/sitemap`'s own sidebar view emits, and the scope every
    # layout rule in sitemap.css's sidebar block hangs off. `@rheo/sidebar 0.1.1`
    # emits no such wrapper, so this is what proves the demo is exercising THIS
    # package's view and not the deprecated one.
    if 'class="rheo-sidebar-layout"' not in h:
        fail(f"{page}: no div.rheo-sidebar-layout — is the demo still importing @rheo/sidebar instead of @rheo/sitemap?")

    hrefs = re.findall(r'<a href="([^"]+)"', h)
    nav_hrefs = [u for u in hrefs if u.endswith(".html")]

    base = os.path.dirname(os.path.join(H, page))
    broken = [u for u in nav_hrefs if not os.path.isfile(os.path.normpath(os.path.join(base, u)))]
    if broken:
        fail(f"{page}: nav links resolve to no file: {broken}")

    depth = page.count("/")
    if depth > 0 and not any(u.startswith("../") for u in nav_hrefs):
        fail(f"{page}: nested page but no nav url carries a ../ prefix: {nav_hrefs}")
    if depth == 0 and any(u.startswith("../") for u in nav_hrefs):
        fail(f"{page}: root page but a nav url carries a ../ prefix: {nav_hrefs}")

    if 'class="active"' not in h:
        fail(f"{page}: no active nav entry — is the current handle marking its own nav item?")

# ---- THE BUNDLE ----------------------------------------------------------------

for page in pages:
    h = read(page)
    if "lib.js" not in h:
        fail(f"{page}: no reference to the built lib.js bundle")
    css_links = re.findall(r'<link[^>]+sitemap\.css', h)
    if len(css_links) != 1:
        fail(f"{page}: sitemap.css linked {len(css_links)} times, expected 1")
    if "rheo/sidebar/" in h:
        fail(f"{page}: links an asset from the deprecated @rheo/sidebar package")

if not bad:
    print("  tree: 7 rows, guide/ named and unlinked, title rule holds")
    print("  feed: 2 posts, newest first, root-relative hrefs")
    print("  nav: links resolve, depth-relative, active marked")
    print("  bundle: lib.js + sitemap.css referenced once per page")
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "demo/rheo OK"; else echo "demo/rheo FAILED"; exit 1; fi
