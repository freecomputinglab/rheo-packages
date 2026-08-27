#!/usr/bin/env bash
# Asserts on this demo's OUTPUT, not merely that the build succeeded.
#
# Greps rather than a test framework, matching the other demos here. The `node
# --test` suite covers the pure halves (`score`, `passes`, the graph layout) and
# `just test` covers the Typst helpers; neither can see what rheo wrote to disk.
#
# Run through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$H/index.html" ] || note "no page at index.html"

# THE FILTER ACTUALLY HIDES ROWS. `#todos-search`'s script sets the `hidden`
# attribute, and that alone does NOTHING here: a search row carries `todo-row`,
# which the stylesheet makes `display: flex`, and the UA's
# `[hidden] { display: none }` loses to any author rule setting `display`.
#
# MEASURED on a live site before the rule existed: `hidden=true` and
# `display: flex` on the same element, so typing reordered the list and removed
# nothing from it. The JS was correct and the page was wrong.
#
# A computed-style assertion would need a browser and this repo's CI has none,
# so this greps for the rule instead — the cheap honest guard against the two
# halves drifting apart again.
grep -q 'todo-search-row\[hidden\]' "$H/rheo/rookery-todos/rookery-todos.css" ||
  note "the built CSS has no .todo-search-row[hidden] rule — the filter will hide nothing"

# The widget rendered, and ships closed so the no-JS state is the plain list.
grep -q 'class="todo-search"' "$H/index.html" ||
  note "index.html carries no #todos-search widget"
grep -q 'data-todo-search-ready="false"' "$H/index.html" ||
  note "the widget does not ship data-todo-search-ready=\"false\" (no-JS degradation)"

# Every row carries the attributes the filter reads. A row missing one is a row
# the filter silently never matches.
python3 - "$H/index.html" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()
rows = re.findall(r'<li class="[^"]*todo-search-row[^"]*"([^>]*)>', h)
if not rows:
    print("FAIL: no todo-search-row elements"); sys.exit(1)
bad = 0
for r in rows:
    for a in ("data-todo-name", "data-todo-status", "data-todo-text"):
        if f"{a}=" not in r:
            print(f"FAIL: a search row is missing {a}"); bad = 1
if not bad:
    print(f"  search: {len(rows)} rows, all with name/status/text")
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "demo/rheo OK"; else echo "demo/rheo FAILED"; exit 1; fi
