#!/usr/bin/env bash
# Asserts on the rendered fixtures' OUTPUT, not merely that they compiled.
# `units.typ` covers every value; this covers the markup, which is the only thing
# the two views actually produce — `#timeline-view` in `view.typ`, `#upcoming` in
# `upcoming.typ` (a separate file because it needs `#show: rookery`; see its header).
set -euo pipefail
cd "$(dirname "$0")/.."
H=test/build/view.html
U=test/build/upcoming.html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$H" ] || { echo "FAIL: no $H — run 'just test' first"; exit 1; }
[ -f "$U" ] || { echo "FAIL: no $U — run 'just test' first"; exit 1; }

python3 - "$H" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()
rails = re.findall(r'<ol class="timeline">(.*?)</ol>', h, re.S)
if len(rails) != 8:
    print(f"FAIL: expected 8 rails, found {len(rails)}"); sys.exit(1)

def rows(rail):
    # `[a-z- ]` and not `[a-z-]`: the current row carries TWO classes
    # ("timeline-past timeline-current"), and a regex that stopped at the space
    # silently dropped that row from every count below.
    return [(c.split()[0], b)
            for c, b in re.findall(r'<li class="timeline-event ([a-z- ]+)">(.*?)</li>', rail, re.S)]

def txt(s):
    return " ".join(re.sub(r"<[^>]+>", " ", s).split())

# 1. STRADDLING: created + 3 past + a divider + 1 booked.
one = rails[0]
cls = [c for c, _ in rows(one)]
if cls != ["timeline-past"] * 4 + ["timeline-future"]:
    print(f"FAIL: rail 1 classes are {cls}"); sys.exit(1)
if one.count('class="timeline-today"') != 1:
    print("FAIL: rail 1 has no today divider, and both sides exist"); sys.exit(1)

# 2. ALL PAST: no divider at all. A line at the bottom would mark nothing.
if 'class="timeline-today"' in rails[1]:
    print("FAIL: rail 2 drew a today divider with nothing booked"); sys.exit(1)
if [c for c, _ in rows(rails[1])] != ["timeline-past"] * 3:
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
exp = [txt(b) for c, b in four if c == "timeline-expected"]
if len(exp) != 1 or "accepted" not in exp[0]:
    print(f"FAIL: with a ladder the expected rungs are {exp}, wanted just accepted")
    sys.exit(1)
if "—" not in exp[0]:
    print(f"FAIL: an expected rung should be undated: {exp}"); sys.exit(1)
# ...and WITHOUT one, none appear. Same log, two registers.
if 'timeline-expected' in rails[0]:
    print("FAIL: rail 1 drew expected rungs with no ladder passed"); sys.exit(1)

# 5. TIMED EVENTS ON THE REFERENCE DATE have happened. A date-only `today:` means
# the whole day, so comparing at full precision would call them booked — which it
# did, until the split dropped to the coarser of the two precisions.
five = rows(rails[4])
if [c for c, _ in five] != ["timeline-past"] * 2:
    print(f"FAIL: timed events on the reference date read as {[c for c, _ in five]}, not past")
    sys.exit(1)
if 'class="timeline-today"' in rails[4]:
    print("FAIL: rail 5 drew a divider with nothing booked"); sys.exit(1)

# 6. AN ENTRY'S NOTE lands inside that event's own <li>, so the rail's dot stays
# aligned to the prose it belongs to — and an event without one gets no empty
# element, which would be worse than none.
six = rows(rails[5])
if len(six) != 2:
    print(f"FAIL: rail 6 has {len(six)} rows, expected 2"); sys.exit(1)
if 'class="timeline-note"' not in six[0][1]:
    print(f"FAIL: the noted event carries no .timeline-note: {txt(six[0][1])}"); sys.exit(1)
if "500-word abstract" not in txt(six[0][1]):
    print(f"FAIL: the note's prose is missing: {txt(six[0][1])}"); sys.exit(1)
if 'timeline-note' in six[1][1]:
    print(f"FAIL: the note-less event drew an empty note: {txt(six[1][1])}"); sys.exit(1)
# ...and an expected rung never gets one: the ladder supplies names, not prose.
if 'timeline-note' in "".join(b for c, b in rows(rails[3]) if c == "timeline-expected"):
    print("FAIL: an expected rung drew a note"); sys.exit(1)

# THE CURRENT STAGE is marked on exactly one row per rail, and it is the last PAST
# row rather than the last row — which is the whole distinction, since a rail
# straddling today has booked rows after it.
for i, rail in enumerate(rails):
    cur = re.findall(r'<li class="timeline-event ([a-z- ]+)">', rail)
    marked = [j for j, c in enumerate(cur) if "timeline-current" in c]
    past = [j for j, c in enumerate(cur) if c.split()[0] == "timeline-past"]
    if not past:
        if marked:
            print(f"FAIL: rail {i+1} has no past rows but marked one current"); sys.exit(1)
        continue
    if marked != [past[-1]]:
        print(f"FAIL: rail {i+1} marks {marked} current, wanted just the last past row {past[-1:]}")
        sys.exit(1)

# 7. A FAMILY RUNG renders by its name, never as a pattern, and is not listed as
# still-to-come once an occurrence has happened.
seven = rows(rails[6])
if len(seven) != 5:
    print(f"FAIL: rail 7 has {len(seven)} rows, expected 3 events + 2 expected rungs")
    sys.exit(1)
exp7 = [txt(b) for c, b in seven if c == "timeline-expected"]
# The row's DATE comes first and an expected rung has none, so each reads
# "— accepted". Strip the dash rather than assuming a column order.
names7 = [e.replace("—", "").split()[0] for e in exp7]
if names7 != ["accepted", "revision"]:
    print(f"FAIL: expected rungs render as {exp7}, wanted accepted then revision")
    sys.exit(1)
if any("*" in e for e in exp7):
    print(f"FAIL: a pattern leaked into the rendering: {exp7}"); sys.exit(1)
if "review" in names7:
    print("FAIL: `review` listed as still-to-come after two reviews happened")
    sys.exit(1)

# 8. A MULTI-PARAGRAPH NOTE survives. It rendered empty inside a <p>, because
# Typst paragraphs are block content that a <p> cannot legally contain.
eight = rows(rails[7])
body8 = eight[0][1]
if "First paragraph" not in body8 or "Second paragraph" not in body8:
    print(f"FAIL: a two-paragraph note lost its prose: {txt(body8)!r}"); sys.exit(1)
if "<p class=\"timeline-note\"" in rails[7]:
    print("FAIL: the note is still a <p>, which collapses multi-paragraph content")
    sys.exit(1)

print(f"  timeline-view: 8 rails, one current row each, divider only where both sides exist, same-day times "
      f"{three[0].split()[-1]}/{three[1].split()[-1]}, 1 expected rung with a ladder and 0 without")
PY

python3 - "$U" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()

lists = re.findall(r'<ul class="upcoming-list">(.*?)</ul>', h, re.S)
if len(lists) != 3:
    print(f"FAIL: expected 3 upcoming lists (all rows, the cutoff, `name-from`), found {len(lists)}")
    sys.exit(1)

# THE CELLS ARE `#idea-row`'s NOW, from @rheo/rookery — `.idea-row-when` /
# `.idea-row-title` / `.idea-row-badges`, with this package's own `.upcoming-row`
# riding alongside `.idea-row` as its hook. The old `.upcoming-when` / `.upcoming-name`
# / `.upcoming-stage` cells were this file's own copy of that row and are gone.
def rows(lst):
    return [(c, b) for c, b in re.findall(r'<li class="([^"]*)">(.*?)</li>', lst, re.S)
            if "upcoming-row" in c]

def when(row):
    m = re.search(r'class="idea-row-when([^"]*)"[^>]*>(?:<time datetime="([^"]+)")?', row)
    return (m.group(1).strip(), m.group(2))

def name(row):
    return re.search(r'class="idea-row-title"[^>]*>([^<]*)', row).group(1)

# 1. ORDER, and it is the whole point of the view: the notes are written
# later/sooner/booked/watched and must come out in date order.
all_rows = rows(lists[0])
names = [name(b) for _, b in all_rows]
if names != ["Sooner", "Booked", "Later", "Watched"]:
    print(f"FAIL: rows came out {names}, wanted Sooner, Booked, Later, Watched")
    sys.exit(1)

dates = [when(b)[1] for _, b in all_rows]
dated = [x for x in dates if x]
if dated != sorted(dated):
    print(f"FAIL: dates are not ascending: {dated}")
    sys.exit(1)
if dates[-1] is not None:
    print("FAIL: the undated row did not sort last")
    sys.exit(1)

# 2. SOFT is the row whose date came from a booked entry rather than from the
# stage the call queued by. Exactly one row here is like that.
soft = [name(b) for _, b in all_rows if "soft" in when(b)[0]]
if soft != ["Booked"]:
    print(f"FAIL: soft rows are {soft}, wanted just Booked")
    sys.exit(1)

# 3. THE BADGE is what has HAPPENED, not what is coming — so the booked row
# reads `submitted`, and a row nothing has happened to has no badge at all.
stages = {name(b): re.findall(r'class="idea-tag idea-tag-[^"]*">([^<]*)', b) for _, b in all_rows}
if stages["Booked"] != ["submitted"]:
    print(f"FAIL: Booked's badge is {stages['Booked']}, wanted submitted")
    sys.exit(1)
if stages["Sooner"] != []:
    print(f"FAIL: a note nothing has happened to drew a badge: {stages['Sooner']}")
    sys.exit(1)
if "idea-tag-submitted" not in lists[0]:
    print("FAIL: the badge does not wear `idea-tag-<stage>`, so no theme can reach it")
    sys.exit(1)

# 4. THE CUTOFF drops what is too old and keeps what has no date to be too old.
cut = [name(b) for _, b in rows(lists[1])]
if cut != ["Booked", "Later", "Watched"]:
    print(f"FAIL: `from:` left {cut}, wanted Booked, Later, Watched")
    sys.exit(1)

# 5. `name-from:` NAMES AND LINKS THE ROW BY THE NOTE IT POINTS AT. The dated notes
# here have no titles at all, so without it every row would read as its own body.
named = rows(lists[2])
# The third row's pointer names nothing, so it falls back to its OWN label — which
# for an untitled note is rookery's own fallback, the body's opening. That is the
# documented behaviour: a dangling pointer renders, it does not panic.
if [name(b) for _, b in named] != ["A Real Venue", "A Real Venue", "Dangling pointer."]:
    print(f"FAIL: name-from rows read {[name(b) for _, b in named]}")
    sys.exit(1)
# THE LINK CANNOT BE ASSERTED HERE, and that is a property of the fixture rather
# than of the view: under a plain `typst compile` nothing mints note pages, so every
# row's `href` is `none` and each name renders as a <span>. Same reason
# @rheo/rookery-todos' own row code documents for degrading to unlinked text. What
# IS asserted is that no row links anywhere at all, so a dangling pointer cannot
# have invented one.
if 'class="idea-row-title" href=' in lists[2]:
    print("FAIL: a link appeared where nothing mints pages — check where href came from")
    sys.exit(1)

# 6. NOTHING SELECTED renders the empty line rather than an empty list.
if h.count('class="upcoming-empty"') != 1:
    print("FAIL: the empty selection did not render exactly one .upcoming-empty")
    sys.exit(1)

print(f"  upcoming: {len(all_rows)} rows in date order, undated last, 1 soft, "
      f"badges from the log, cutoff kept {cut}")
PY

if [ "$fail" -eq 0 ]; then echo "views OK"; else echo "views FAILED"; exit 1; fi
