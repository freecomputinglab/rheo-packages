# Beads

Plain markdown backlog, not `br` — this machine isn't the main dev box for this
repo, so these are written up here for triage into real beads later rather than
filed directly.

## 1. Empty-bodied `#idea`/`#window` overlaps the next tab

**Where noticed:** weeknotes.ohrg.org, `build/html/26w34.html`. A week's content
had `#idea(<26w34-rheo>, title: [Rheo])[]` — a genuinely empty body — immediately
followed by another `#idea`. The next idea's `[idea:...]` tab visually overlapped
the box above it.

**Root cause:** `rookery/0.4.0/src/rookery.css` lifts each idea's tab above its
box with a negative `margin-top` (`.idea-box > .idea-head > .idea-tab`, around
line 236-258), and compensates with `padding-top` on the wrapping `<figure>`
(`figure:has(> .idea-box)`, around line 555-566). That compensation assumes
there is normal body content beneath the head, providing clearance before the
next idea's lifted tab arrives. When an idea's body is completely empty (not
just untitled — no content block at all), the box collapses to just its head
line, the assumed clearance isn't there, and the next tab's lift no longer
clears it.

Gets worse the larger `--idea-label-size` is set (e.g. weeknotes.ohrg.org uses
0.85rem against rookery's own 0.57rem default), since both the lift and the
resulting overlap scale with that variable.

**Suggested direction:** give an idea/window box some minimum height or bottom
clearance when its body is empty — similar in spirit to the existing untitled-
note handling at `.idea-head:has(> :empty) + *` (around line 335), but keyed to
an empty *body* rather than an empty *heading*.

## 2. Folded `#window` with no title reads too short

A folded (closed) `#window`'s summary height comes from the tab row plus
`.idea-window-title`'s line box. When the transcluded note has no title, that
line box contributes ~nothing, so the closed row reads visually cramped next to
a titled folded window beside it.

**Relevant CSS** (`rookery/0.4.0/src/rookery.css`): `.idea-window-summary`
(around line 793), `.idea-window-title` (around line 950), and the folded-
window floor/background rules (around line 871-898). There's already a fix for
the analogous case on `#idea` — `.idea-head:has(> :empty) + *` (around line
335) normalizes spacing for a titleless idea — but nothing equivalent exists
for a folded `#window`'s summary height.

**Suggested direction:** give the summary (or its title slot) a minimum block
size / line-height reservation so a titleless folded window matches a titled
one's height.
