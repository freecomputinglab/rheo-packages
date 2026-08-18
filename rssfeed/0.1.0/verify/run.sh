#!/usr/bin/env bash
# Pins the rows of bead rheo-packages-parity-qrd's parity matrix that cannot
# coexist with ../demo's own content/config: each needs a project that
# configures something ../demo deliberately does NOT (no title, no
# `configure(...)` call at all, or entry overrides composed over `spine()`).
# Same grep/python-over-real-output style as ../demo/check.sh — see that
# script's own header for why there's no test framework here.
#
# Builds all three fixtures itself (unlike ../demo/check.sh, which `just
# check` builds first) since a couple of these are SUPPOSED to fail to
# build. Run through `just verify`.
set -euo pipefail
cd "$(dirname "$0")"
fail=0
note() { echo "FAIL: $*"; fail=1; }

for d in no-title no-configure override; do
  rm -rf "$d/build"
done

# ---- Row 4: `title` is REQUIRED — the build must FAIL, loudly, with the
# package's own message (no fallback to an HTML spine title or the project
# directory name, unlike the retired Rust generator). A Typst panic cannot be
# asserted on FROM INSIDE a fixture, so this is the shell-level
# `if compile succeeds -> fail` check the bead calls for.
echo "== row 4: no-title (must fail) =="
if out="$(rheo compile no-title 2>&1)"; then
  note "no-title: build SUCCEEDED, expected it to fail (missing \`title\`)"
elif ! printf '%s' "$out" | grep -qF "@rheo/rssfeed: feed's \`title\` must be a non-empty string."; then
  note "no-title: build failed, but not with the package's own title message — got:"
  printf '%s\n' "$out"
fi

# ---- Row 7: importing the package but never calling `configure(...)` is a
# COMPLETE no-op — no feed XML anywhere in the output, no autodiscovery
# <link> in the one page's <head>.
echo "== row 7: no-configure (must build, mint nothing) =="
if ! rheo compile no-configure >/tmp/rssfeed-verify-no-configure.log 2>&1; then
  note "no-configure: build FAILED, expected it to succeed with no-op output"
  cat /tmp/rssfeed-verify-no-configure.log
else
  H=no-configure/build/html
  if find "$H" -name '*.xml' | grep -q .; then
    note "no-configure: an *.xml file was minted despite no configure(...) call: $(find "$H" -name '*.xml')"
  fi
  if grep -q 'application/atom+xml' "$H/index.html" 2>/dev/null; then
    note "no-configure: index.html's <head> carries an atom autodiscovery link despite no configure(...) call"
  fi
fi
rm -f /tmp/rssfeed-verify-no-configure.log

# ---- Rows 2, 11, 12: default feed author, `<published>` distinct from (and
# omitted independently of) `<updated>`, and per-entry overrides composed
# over the built-in `spine()` source with no `#set document` involved.
echo "== rows 2, 11, 12: override (must build, exact XML) =="
if ! rheo compile override >/tmp/rssfeed-verify-override.log 2>&1; then
  note "override: build FAILED"
  cat /tmp/rssfeed-verify-override.log
else
  F=override/build/html/feed.xml
  if [ ! -s "$F" ]; then
    note "override: feed.xml missing or empty"
  elif ! python3 - "$F" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
bad = 0

def fail(msg):
    global bad
    print(f"FAIL: {msg}")
    bad = 1

def field(entry, tag):
    m = re.search(rf"<{tag}[^>]*>(.*?)</{tag}>", entry, re.S)
    return m.group(1) if m else None

def link(entry):
    m = re.search(r'<link rel="alternate" href="([^"]+)"/>', entry)
    return m.group(1) if m else None

entries = re.findall(r"<entry>(.*?)</entry>", text, re.S)
a = next((e for e in entries if (link(e) or "").endswith("/a.html")), None)
b = next((e for e in entries if (link(e) or "").endswith("/b.html")), None)

# Row 2: no `author:` on this project's feed(...) call -> feed-level default.
if "<author><name>Rheo</name></author>" not in text:
    fail("feed.xml is missing the default <author>Rheo</author> (row 2)")

if a is None:
    fail("could not find a.html's entry")
else:
    # Row 12: a.html's entry took the composed override's title, not its own
    # heading/filename ("A").
    if field(a, "title") != "Override":
        fail(f"a.html's entry title is {field(a, 'title')!r}, expected the composed override 'Override' (row 12)")
    # Row 11: a.html's entry carries BOTH dates, distinct, updated LATER.
    if field(a, "published") != "2026-01-01T00:00:00Z":
        fail(f"a.html's entry <published> is {field(a, 'published')!r}, expected 2026-01-01T00:00:00Z (row 11)")
    if field(a, "updated") != "2026-06-01T00:00:00Z":
        fail(f"a.html's entry <updated> is {field(a, 'updated')!r}, expected 2026-06-01T00:00:00Z (row 11)")

if b is None:
    fail("could not find b.html's entry")
else:
    # Row 11: b.html's entry has NO <published> at all (its own composed
    # override clears it), only <updated> — taken from spine()'s own reading
    # of b.typ's `#set document(date: ..)`, untouched by the override.
    if "<published>" in b:
        fail("b.html's entry has a <published> despite the override clearing it (row 11)")
    if field(b, "updated") != "2026-04-15T00:00:00Z":
        fail(f"b.html's entry <updated> is {field(b, 'updated')!r}, expected 2026-04-15T00:00:00Z")
    if field(b, "title") != "B":
        fail(f"b.html's entry title is {field(b, 'title')!r}, expected spine()'s own 'B' (untouched by the override)")

sys.exit(1 if bad else 0)
PY
  then
    note "override: XML assertions failed (see above)"
  fi
fi
rm -f /tmp/rssfeed-verify-override.log

for d in no-title no-configure override; do
  rm -rf "$d/build"
done

if [ "$fail" -ne 0 ]; then
  echo "verify: FAILED"
  exit 1
fi
echo "verify OK"
