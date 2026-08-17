# Findings: `#search-modal` build cost (bead `br-vio-core-95v`)

Handoff notes for whoever picks this up. Written 2026-08-17 against
`feat/rookery-0.2.0` (commit `0010613c`). The bead is **`in_progress`** and
deliberately not closed: half of it is fixed and committed, the other half is
blocked on a design decision that needs a human answer (see "The open
decision").

Read this whole file before touching the code. Several of the obvious moves
here are wrong, and one of them is wrong in a way that produced a confidently
incorrect diagnosis the first time round (see "False leads").

---

## TL;DR

`#search-modal` made `rheo compile` slow AND enormous. Those are **two
separate problems with two separate causes**, and only one is fixed.

| | baseline (no `#search-bodies`) | before any fix | after image fix (now) |
|---|---|---|---|
| `rheo compile . --html` | **2.65s** | 16.8s | **14.6s** |
| `build/html` | **17 MB** | **312 MB** | **33 MB** |

- **Size: FIXED** (committed, `0010613c`). Cause was base64-inlined images.
- **Time: NOT FIXED.** Cause is the *number of render calls*, which no amount
  of trimming output can address. This is what the user actually complained
  about ("takes a VERY long time"), so treat it as the live problem.

Measured on `/home/lox/code/writing/sites/weeknotes.ohrg.org` (57 notes,
69 output pages).

---

## Root cause 1 — size (FIXED)

`#search-bodies` (`rookery-search/0.2.0/src/lib.typ`, ~line 370) renders
*every note's body* into *every page*, via `#idea-body`. Typst's HTML export
inlines every `#image` as a `src="data:image/png;base64,…"` URI. So a note
carrying a 600 KB screenshot carried 600 KB of base64 in its rendered body,
and that landed on all 69 pages.

**93.2% of the entire 312 MB build was base64 image data** (301 MB of it).
The source images total ~1.6 MB on disk.

Fix, committed: a `show image: none` show rule wrapped around the
`#idea-body` call inside `#search-bodies`. Result: the per-page bodies
container is **248 KB with zero images** (largest single note body 17 KB),
and the build is 33 MB.

Two things worth knowing about that fix:

- **A show rule at the call site reaches into `#idea-body`'s content.**
  VERIFIED on typst 0.15.1 with a minimal fixture. This is why no `images:`
  parameter had to be threaded through rookery's public API — the fix lives
  entirely in `rookery-search` and rookery is untouched.
- **Nothing is substituted for a stripped image** — no placeholder, no alt
  text. A search preview is an excerpt by construction. If you decide a
  placeholder is wanted, that is a UX change, not a correctness fix.

---

## Root cause 2 — time (OPEN, the real problem)

`#search-modal` sits in the site header, so it runs on every page, and
`#search-bodies` loops over every note. That is `57 × 69 ≈ 3,900` full
`#idea-body` renders per build — each one doing `_body-at`, `_blocks`,
`_footnoted`, `_refs-block`, `_own-cited-keys` and realisation.

The cost is **per-call, not per-byte**. Proof, by measurement:

| variant | time |
|---|---|
| `#search-bodies` disabled entirely | 2.65s |
| calls `ideas()` but renders **no** bodies | 3.23s |
| renders bodies at `limit: 1` (near-empty) | 10.3s |
| renders full bodies, images stripped (current) | 14.6s |

Read that table carefully — it is the whole argument:

- The extra `ideas()` call per page costs only ~0.6s. Not worth chasing.
- Going from *no renders* to *near-empty renders* costs **~7s**. That is pure
  per-call overhead, ~1.8ms × 3,900.
- Body size accounts for the remaining ~4.3s.

**Therefore: truncation cannot fix this.** Do not "fix it" by lowering
`preview-limit`. Even a limit of 1 leaves you at 10.3s against a 2.65s
baseline, and it re-opens the `_blocks` bug (below). The only fix is to stop
rendering N×M.

---

## The open decision (needs a human answer)

Every way of reducing the render count moves preview content out of the page,
which means the modal has to `fetch` it at runtime — and `fetch` does not work
from `file://`. That trade-off is the decision. The user was asked and has not
yet answered.

Note the fallback already exists and works: when no real-content div is found
for a hit, `renderPreview` in `rookery-search/0.2.0/src/rookery-search.js`
falls back to the plain-text excerpt built from the JSON island's `body`
field. So "no rich preview" degrades to "plain-text preview", not to nothing.

**Option A — fetch the note's own minted page.** The modal fetches
`hit.href` (`ideas/<slug>.html`, already in the index and already minted by
rookery's `.marrow.typ`), extracts the body, caches per session. Build cost:
**zero** — it reuses pages rheo already emits, so the build returns to exactly
the 2.65s / 17 MB baseline. `#search-bodies` is deleted outright. Rich
previews require http. *This was going to be my recommendation.*

**Option B — ship the image fix only, stop here.** Fully static and
self-contained; rich previews work everywhere including `file://`; no runtime
fetch. Build stays 14.6s / 33 MB, i.e. 5.5× baseline, which will keep hurting
`rheo watch`.

**Option C — one generated bodies page.** Emit all bodies once into a single
extra page via `rheo-document()` (the same mechanism rookery's `.marrow.typ`
already uses to mint note pages — so a package emitting an extra page *is*
supported, despite what the `#search-bodies` comment about "no supported way
to emit a standalone asset file" implies for *asset* files). The modal fetches
that one page. N renders instead of N×M, so ~3s. Still needs fetch, so it
carries Option A's `file://` caveat *plus* an extra emitted page to own — I
judged it strictly worse than A, but it is defensible if you want the bodies
rendered by one known code path rather than scraped out of minted pages.

If Option A or C is chosen, the extraction target on a minted page is
everything between `<h1 class="idea">` and `<footer class="idea-footer">`.

---

## False leads — do not repeat these

**1. "One note is 2.3 MB" was a measurement artifact.** I originally split the
bodies container with `re.split(r'(?=<div data-rookery-search-body=")', html)`
over the *whole page*. The last note div then absorbed the entire rest of
`index.html` — including the homepage's transcluded weeks and all their
images. That produced a fake "`idea:26w33-rookery` is 2.3 MB" and a fake
"7 images survive stripping". Both are false. `26w33.typ` contains no images
at all and its minted page has zero.

**If you measure the bodies container, match `<div>` depth properly.** The
correct measurement is in the "Reproducing" section below; it reports 248 KB
and zero images.

**2. `_footnoted` / `_refs-block` are not the bottleneck.** Bypassing them in
`#idea-body` (`let inner = shown`) left the build at ~18s. Measured. The cost
is realisation volume and call count.

**3. Inline theme styles are not the bottleneck.** `_themed()` repeats a
`style="--idea-link-color: …"` attribute on every themed container, which
looks wasteful, but it is 0.5% of the bodies container. Ignore it.

**4. Do not lower `preview-limit` as the fix.** See the timing table. It also
re-opens bug (5).

---

## Related known bugs (context, not in scope)

**`_blocks` drops a space when truncating mid-paragraph.**
`rookery/0.2.0/src/lib.typ:970`. It discards every `space` child as separator
noise — correct between block-level siblings, wrong inside one paragraph's
inline sequence. So `#window(limit: n)` and `#idea-body(limit: n)` can render
"three layers, because" as "three layers,because". MEASURED on
rookery.ohrg.org. This is why `preview-limit` currently defaults to `none`.
It is a real bug in rookery's shared truncation path and deserves its own
bead; it only intersects this one if you decide to truncate previews.

**`<template>` does not survive rheo's HTML post-processing.** rheo silently
empties a `<template>`'s content, reproduced with nothing more than
`html.elem("template", .., [text])` on typst 0.15.1 / rheo 0.5.2. This is why
`#search-bodies` emits hidden `<div>`s rather than the `<template>` elements
that would otherwise be the natural choice. Do not "clean this up" back to
`<template>`.

---

## Reproducing the measurements

Baseline (comment out the `search-bodies(...)` call inside `#search-modal`,
`rookery-search/0.2.0/src/lib.typ` ~line 493):

```sh
cd /home/lox/code/_fcl/rheo-packages/rookery-search/0.2.0 && just build
cd /home/lox/code/writing/sites/weeknotes.ohrg.org && rm -rf build
time rheo compile . --html
du -sh build/html
```

Package resolution is via symlinks into the Typst cache — confirm these point
where you think they do before trusting any number:

```sh
ls -la ~/.cache/typst/packages/rheo/rookery ~/.cache/typst/packages/rheo/rookery-search
```

They currently point at `/home/lox/code/_fcl/rheo-packages/{rookery,rookery-search}/0.2.0`
(the main checkout). **If you work in a jj workspace, repoint them at the
workspace and repoint them back afterwards** — a stale symlink into a deleted
workspace is a confusing failure.

Byte breakdown of the whole build:

```sh
python3 - <<'PY'
import re, glob
tot=b64=0
for f in glob.glob('build/html/**/*.html', recursive=True):
    s=open(f,encoding='utf8',errors='replace').read(); tot+=len(s)
    b64+=sum(len(m) for m in re.findall(r'data:image/[^"]*', s))
print(f"html {tot:,}  base64 {b64:,} ({b64/tot:.1%})")
PY
```

Correct per-note measurement of the bodies container (depth-matched — this is
the one that avoids false lead 1):

```sh
python3 - <<'PY'
import re
h=open('build/html/index.html',encoding='utf8').read()
start=h.find('<div id="rookery-search-index-bodies"')
depth=0; end=None
for t in re.finditer(r'<div\b|</div>', h[start:]):
    depth += 1 if t.group(0).startswith('<div') else -1
    if depth==0: end=start+t.end(); break
seg=h[start:end]
print(f"container {len(seg):,} bytes, images {seg.count('data:image/')}")
parts=re.split(r'(?=<div data-rookery-search-body=")', seg)
rows=[]
for p in parts[1:]:
    m=re.match(r'<div data-rookery-search-body="([^"]+)"',p)
    nxt=p.find('<div data-rookery-search-body="',1)
    s=p if nxt==-1 else p[:nxt]
    rows.append((len(s), s.count('data:image/'), m.group(1)))
rows.sort(reverse=True)
for sz,im,n in rows[:6]: print(f"  {sz:>9,} imgs={im} {n}")
PY
```

---

## State when this was written

- Bead `br-vio-core-95v` is **`in_progress`**, claimed by actor `claude-slip`.
  Its description still proposes "fix `_blocks`, then restore a small
  `preview-limit`" as the direction — **that is superseded by this document**;
  the timing table shows truncation cannot fix the time problem. Update the
  bead when the decision is made.
- Commit `0010613c` ("Strips images from search preview bodies…") is on
  `feat/rookery-0.2.0` and is the size fix. `dist/` has been rebuilt.
- `@` is empty, no workspace outstanding, symlinks point at the main checkout.
- `just parity` passes (17 + 6 cases) with the image fix in place.
- Nothing has been committed in either site repo for this bead;
  weeknotes.ohrg.org and rookery.ohrg.org need only a `dist/` rebuild, which
  is done.
