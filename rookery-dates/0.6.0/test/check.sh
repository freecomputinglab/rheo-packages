#!/usr/bin/env bash
# Asserts on `test/view.typ`'s OUTPUT, not merely that it compiled. `units.typ`
# covers every value; this covers the markup, which is the only thing `#log-view`
# actually produces.
set -euo pipefail
cd "$(dirname "$0")/.."
H=test/build/view.html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$H" ] || { echo "FAIL: no $H — run 'just test' first"; exit 1; }

python3 - "$H" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()
rails = re.findall(r'<ol class="date-log">(.*?)</ol>', h, re.S)
if len(rails) != 5:
    print(f"FAIL: expected 5 rails, found {len(rails)}"); sys.exit(1)

def rows(rail):
    return re.findall(r'<li class="date-log-event ([a-z-]+)">(.*?)</li>', rail, re.S)

def txt(s):
    return " ".join(re.sub(r"<[^>]+>", " ", s).split())

# 1. STRADDLING: created + 3 past + a divider + 1 booked.
one = rails[0]
cls = [c for c, _ in rows(one)]
if cls != ["date-log-past"] * 4 + ["date-log-future"]:
    print(f"FAIL: rail 1 classes are {cls}"); sys.exit(1)
if one.count('class="date-log-today"') != 1:
    print("FAIL: rail 1 has no today divider, and both sides exist"); sys.exit(1)

# 2. ALL PAST: no divider at all. A line at the bottom would mark nothing.
if 'class="date-log-today"' in rails[1]:
    print("FAIL: rail 2 drew a today divider with nothing booked"); sys.exit(1)
if [c for c, _ in rows(rails[1])] != ["date-log-past"] * 3:
    print(f"FAIL: rail 2 classes are {[c for c, _ in rows(rails[1])]}"); sys.exit(1)

# 3. SAME DAY: both rows show a time, and the date is not simply repeated bare.
three = [txt(b) for _, b in rows(rails[2])]
if len(three) != 2:
    print(f"FAIL: rail 3 has {len(three)} rows, expected 2"); sys.exit(1)
if not ("15:00" in three[0] and "16:00" in three[1]):
    print(f"FAIL: same-day rows do not show their times: {three}"); sys.exit(1)
if "activated" not in three[0] or "closed" not in three[1]:
    print(f"FAIL: same-day rows are out of clock order: {three}"); sys.exit(1)

# 4. LADDER: the unreached rungs appear, undated and marked expected.
four = rows(rails[3])
exp = [txt(b) for c, b in four if c == "date-log-expected"]
if len(exp) != 1 or "accepted" not in exp[0]:
    print(f"FAIL: with a ladder the expected rungs are {exp}, wanted just accepted")
    sys.exit(1)
if "—" not in exp[0]:
    print(f"FAIL: an expected rung should be undated: {exp}"); sys.exit(1)
# ...and WITHOUT one, none appear. Same log, two registers.
if 'date-log-expected' in rails[0]:
    print("FAIL: rail 1 drew expected rungs with no ladder passed"); sys.exit(1)

# 5. TIMED EVENTS ON THE REFERENCE DATE have happened. A date-only `today:` means
# the whole day, so comparing at full precision would call them booked — which it
# did, until the split dropped to the coarser of the two precisions.
five = rows(rails[4])
if [c for c, _ in five] != ["date-log-past"] * 2:
    print(f"FAIL: timed events on the reference date read as {[c for c, _ in five]}, not past")
    sys.exit(1)
if 'class="date-log-today"' in rails[4]:
    print("FAIL: rail 5 drew a divider with nothing booked"); sys.exit(1)

print(f"  log-view: 5 rails, divider only where both sides exist, same-day times "
      f"{three[0].split()[-1]}/{three[1].split()[-1]}, 1 expected rung with a ladder and 0 without")
PY

if [ "$fail" -eq 0 ]; then echo "view OK"; else echo "view FAILED"; exit 1; fi
