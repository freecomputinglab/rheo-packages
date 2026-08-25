#!/usr/bin/env bash
# Asserts on this demo's OUTPUT, not merely that the build succeeded.
#
# What it exists for: as of 0.1.1 the sidebar derives BOTH its nav and its
# active page from rheo, and neither derivation is visible in the source — the
# demo's template passes no `nav:` and no `current:`. A regression would
# therefore compile clean and ship a site with an empty or wrongly-linked nav.
#
# Greps and a small python pass, matching the other demos here. Run through
# `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

for f in index.html guide/intro.html guide/deeper.html; do
  [ -f "$H/$f" ] || note "no page at $f"
done

python3 - "$H" <<'PY' || fail=1
import os, re, sys

H = sys.argv[1]
bad = 0
def fail(m):
    global bad
    print(f"FAIL: {m}")
    bad = 1

pages = {
    "index.html": "Index",
    "guide/intro.html": "Intro",
    "guide/deeper.html": "Deeper",
}

for page, heading in pages.items():
    h = open(os.path.join(H, page)).read()

    # 1. The nav was BUILT FROM THE SPINE. The template passes no `nav:`, so
    #    every one of these links exists only because `nav-from-context()` read
    #    rheo's injected tree.
    urls = sorted(set(re.findall(r'<a href="([^"]+)"', h)))
    nav_urls = [u for u in urls if u.endswith(".html")]
    if len(nav_urls) < 3:
        fail(f"{page}: nav has {len(nav_urls)} page links, expected all 3 vertebrae — is nav-from-context reading the spine?")

    # 2. EVERY LINK RESOLVES FROM THIS PAGE'S OWN DIRECTORY. The same nav is
    #    rendered on every page, so a site-root-relative url works at the root
    #    and 404s one directory down. This is the assertion a root-only fixture
    #    cannot make, and the reason `guide/` exists in this demo.
    base = os.path.dirname(os.path.join(H, page))
    broken = [u for u in nav_urls if not os.path.isfile(os.path.normpath(os.path.join(base, u)))]
    if broken:
        fail(f"{page}: nav links resolve to no file: {broken}")

    # 3. A handle's `:` segments are DIRECTORIES in the output. A naive
    #    `"./" + handle + ".html"` would emit `guide:intro.html`, which exists
    #    nowhere — it compiles, it renders, and every link is dead.
    if any(":" in u for u in nav_urls):
        fail(f"{page}: a nav url uses a colon rather than a directory: {[u for u in nav_urls if ':' in u]}")

    # 4. The ACTIVE page is marked, derived from `state('rheo-handle')` rather
    #    than from a `current:` the author passes.
    if 'class="active"' not in h:
        fail(f"{page}: no active nav entry — is the current handle being read?")

    # 5. The document title names the active page, which is the same derivation
    #    seen from the other end.
    t = re.search(r"<title>([^<]*)</title>", h)
    if not t:
        fail(f"{page}: no <title>")
    elif not t.group(1).startswith(heading):
        fail(f"{page}: title is {t.group(1)!r}, expected it to start with {heading!r}")

# 6. Depth is actually exercised: the nested pages must carry `../` and the
#    root must not. Without this, 2 above would pass on a site that emitted
#    root-relative urls everywhere and happened to be checked only at the root.
root_urls = re.findall(r'<a href="([^"]+\.html)"', open(os.path.join(H, "index.html")).read())
if any(u.startswith("../") for u in root_urls):
    fail(f"index.html has a ../ nav url, but it is at the site root: {root_urls}")
deep_urls = re.findall(r'<a href="([^"]+\.html)"', open(os.path.join(H, "guide/intro.html")).read())
if not all(u.startswith("../") for u in deep_urls):
    fail(f"guide/intro.html has a nav url without the ../ its depth needs: {deep_urls}")

if not bad:
    print(f"  nav: {len(pages)} pages, all links resolve, depth-relative, active marked")
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "demo/rheo OK"; else echo "demo/rheo FAILED"; exit 1; fi
