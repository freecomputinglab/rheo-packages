#!/usr/bin/env bash
# Asserts on this fixture's OUTPUT, not merely that the build succeeded.
#
# Greps rather than a test framework, deliberately, matching @rheo/rookery's own
# demo check: the package already has a `node --test` suite for its browser half
# and a parity harness for its ranking, and neither can see what rheo actually
# wrote to disk. THAT is what this file is for — the asset plumbing and the
# island, which only exist after a real rheo build.
#
# Run through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

# 1. The build produced the pages the spine declares, at both depths. The
#    nested vertebra is not decoration: every depth assertion below needs a page
#    that is not at the root.
for f in index.html sub/page.html; do
  [ -f "$H/$f" ] || note "no page at $f"
done

# 2. The package's assets were copied in by rheo's own package-asset detection,
#    which scans a project's `.typ` files for `@rheo/<pkg>` imports. `dist/` is
#    gitignored, so a missing file here usually means `just build` was skipped.
for a in rheo/rookery-search/lib.js rheo/rookery-search/rookery-search.css; do
  [ -f "$H/$a" ] || note "asset not copied to $a (did you run 'just build'?)"
done

# 3. Both assets are LINKED from every page, at the right depth-relative
#    prefix — `rheo/...` at the root, `../rheo/...` one level down. This is the
#    assertion a root-only fixture cannot make, and getting it wrong ships a
#    site whose search silently never loads on its inner pages.
grep -q '"rheo/rookery-search/lib.js"' "$H/index.html" ||
  note "index.html does not link lib.js at the root-relative prefix"
grep -q '"rheo/rookery-search/rookery-search.css"' "$H/index.html" ||
  note "index.html does not link rookery-search.css at the root-relative prefix"
grep -q '"../rheo/rookery-search/lib.js"' "$H/sub/page.html" ||
  note "sub/page.html does not link lib.js at the depth-relative prefix"
grep -q '"../rheo/rookery-search/rookery-search.css"' "$H/sub/page.html" ||
  note "sub/page.html does not link rookery-search.css at the depth-relative prefix"

# 4. The JSON island is present and parses, with one row per registered note.
#    `#search-index` filters to notes that have a minted page (`href != none`),
#    so this also proves the two packages agree about the registry.
python3 - "$H/index.html" <<'PY' || fail=1
import json, re, sys
h = open(sys.argv[1]).read()
m = re.search(r'<script type="application/json"[^>]*>(.*?)</script>', h, re.S)
if not m:
    print("FAIL: no JSON search island in index.html"); sys.exit(1)
try:
    rows = json.loads(m.group(1))
except json.JSONDecodeError as e:
    print(f"FAIL: search island is not valid JSON: {e}"); sys.exit(1)
if not rows:
    print("FAIL: search island is empty"); sys.exit(1)
for r in rows:
    if "id" not in r or "href" not in r:
        print(f"FAIL: row missing id or href: {r}"); sys.exit(1)
    # Tag NAMES only, never the 0.5.0 tag dictionary's values: a value can be a
    # datetime or content, and `json.encode` of content does not error — it
    # emits a structural blob and bloats every page. See @rheo/rookery's
    # `ideas()`, which publishes keys for exactly this reason.
    tags = r.get("tags", [])
    if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
        print(f"FAIL: row {r['id']} has non-string tags: {tags!r}"); sys.exit(1)
print(f"  island: {len(rows)} rows, all with id/href, tags flat strings")
PY

# 5. Every href in the island resolves to a file rheo actually wrote. A row
#    pointing at nothing is a search result that 404s on click.
python3 - "$H" <<'PY' || fail=1
import json, os, re, sys
H = sys.argv[1]
h = open(os.path.join(H, "index.html")).read()
rows = json.loads(re.search(r'<script type="application/json"[^>]*>(.*?)</script>', h, re.S).group(1))
missing = [r["href"] for r in rows if not os.path.isfile(os.path.join(H, r["href"]))]
if missing:
    print(f"FAIL: {len(missing)} island href(s) resolve to no file: {missing[:3]}"); sys.exit(1)
print(f"  hrefs: all {len(rows)} resolve to a file on disk")
PY

# 6. Both UI surfaces rendered. They are separate entry points and a project
#    may use either, so neither one standing in for the other is enough.
# `class="rookery-search"` is `#search-bar`'s own wrapper; the modal wears
# `rookery-search-modal`. Matched on the exact attribute so the bar's assertion
# cannot be satisfied by the modal's longer prefix.
grep -q 'class="rookery-search"' "$H/index.html" ||
  note "index.html does not carry the #search-bar element"
grep -q 'class="rookery-search-modal"' "$H/index.html" ||
  note "index.html does not carry the #search-modal element"

if [ "$fail" -eq 0 ]; then echo "demo/rheo OK"; else echo "demo/rheo FAILED"; exit 1; fi
