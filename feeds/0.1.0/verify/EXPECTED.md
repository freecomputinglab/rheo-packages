# Observed output — bead rheo-packages-parity-qrd

Recorded from one real compile of each fixture (`demo/` and the three
`verify/*/` projects) under the `feat/transclusion` branch build of rheo
this package's own readme.md and rheo.toml files call out. Rows 4, 7, 11,
12 (and, incidentally, 2) live in `verify/`; the rest live in `demo/` — see
that project's own `check.sh` and this one's `run.sh` for the assertions
that pin them going forward. Both scripts run under `just check` / `just
verify` respectively.

Row numbers below match the bead's own matrix.

## Row 1 — feed author, custom

`demo/content/index.typ` configures `feed.xml` with `author: "The
Editors"` and `notes.xml` with `author: "The Rookery"` — different authors
per feed, proving it's a per-feed setting, not document-global.

OBSERVED (`demo/build/html/feed.xml`):
`<author><name>The Editors</name></author>`
OBSERVED (`demo/build/html/notes.xml`):
`<author><name>The Rookery</name></author>`

PASS — pinned by `demo/check.sh`.

## Row 2 — feed author, default

`verify/override/content/index.typ`'s one `feed(...)` call omits `author:`
entirely.

OBSERVED (`verify/override/build/html/feed.xml`):
`<author><name>Rheo</name></author>`

PASS — pinned by `verify/run.sh`.

## Row 3 — feed title doubles as the autodiscovery link's `title=`

`demo/content/index.typ` configures `title: "Feeds Demo — Posts"` /
`title: "Feeds Demo — Notes"`.

OBSERVED (`demo/build/html/feed.xml`): `<title>Feeds Demo — Posts</title>`
OBSERVED (every page's `<head>`, e.g. `demo/build/html/index.html`):
`<link rel="alternate" type="application/atom+xml"
href="https://demo.example.org/feed.xml" title="Feeds Demo — Posts">`

Both the feed-level `<title>` and the `title=` attribute carry the SAME
configured string, checked as one exact tag (href+title together, not
separately) so a mismatched pairing would be caught.

PASS — pinned by `demo/check.sh`.

## Row 4 — title is REQUIRED, no fallback chain

`verify/no-title/content/index.typ` calls `feed(...)` with no `title:`.

OBSERVED (`rheo compile verify/no-title`, stderr):
```
error: assertion failed: @rheo/feeds: feed's `title` must be a non-empty string.
```
Compile exits non-zero. Documented as a deliberate migration difference in
readme.md's "Migrating from the retired Rust feed generator" section — the
retired generator's fallback chain (HTML spine title, then project
directory name) has no equivalent.

PASS — pinned by `verify/run.sh` (`if compile succeeds -> fail`, then greps
stderr for the exact message).

## Row 5 — autodiscovery on every page, root AND nested

`demo/check.sh` checks `index.html`, `notes.html`, both top-level posts,
`posts/deep/three.html` (one directory deep), and all four minted note
pages (including the note nested inside another note's body).

OBSERVED: every one of those 9 pages' `<head>` carried both feeds'
autodiscovery `<link>` tags (same exact-tag check as row 3), root and
nested alike — the `.rheo/head.html` control asset is spliced into every
page rheo compiles, not just the one vertebra that called `configure(...)`.

PASS — pinned by `demo/check.sh`.

## Row 6 — entry URLs absolute and correct; the rookery id exception

OBSERVED (`demo/build/html/feed.xml`, the nested post):
```
<entry><id>https://demo.example.org/posts/deep/three.html</id><title>Three</title>...<link rel="alternate" href="https://demo.example.org/posts/deep/three.html"/>...</entry>
```
`<id>` equals the `<link>` href exactly — `base-url + "/" + output_path`,
depth included. Every `feed.xml` entry (all `spine()`-sourced) follows the
same rule: `id` defaults to `url` per `_normalize-entry`.

OBSERVED (`demo/build/html/notes.xml`, rookery-sourced):
```
<entry><id>idea:beta</id><title>Beta</title>...<link rel="alternate" href="https://demo.example.org/ideas/beta.html"/>...</entry>
```
Here `<id>` is `idea:beta` — rookery's OWN note id (`from-ideas` in
`demo/content/index.typ` passes `id: e.id` through explicitly) — NOT the
URL. `<link>` is still the real absolute URL, matching a real minted file
on disk. This is the entry model's documented "id defaults to url, but a
source may set its own" behaviour, not a bug: stated explicitly here rather
than papered over, as the bead asked.

PASS — pinned by `demo/check.sh` (asserts `id == href` for every `feed.xml`
entry, and `id.startswith("idea:") and id != href` for every `notes.xml`
entry).

## Row 7 — no configuration, no output

`verify/no-configure/content/index.typ` imports `@rheo/feeds:0.1.0` (so
its `.marrow.typ` is spliced into the bundle root) but never calls
`configure(...)`.

OBSERVED: the build succeeds; `verify/no-configure/build/html/` contains
only `index.html` and `rheo-default.css` — no `*.xml` anywhere. `index.html`'s
`<head>` carries no `application/atom+xml` link at all.

PASS — pinned by `verify/run.sh`.

## Row 8 — excluding a page does not unbuild it

`demo/content/index.typ` (the root vertebra) matches NEITHER feed's source
(not under `posts/`, not a rookery idea) — excluded from every source in
the project.

OBSERVED: `demo/build/html/index.html` exists and compiles normally; its
own title ("Index") never appears as an entry `<title>` in either feed, and
no entry links to it.

PASS — pinned by `demo/check.sh`. True by construction (nothing unbuilds a
vertebra just because no feed source matched it) — asserted anyway, per the
bead's own reasoning: "'true by construction' is exactly what silently
stops being true."

## Row 9 — entry title prefers the authored document title

**Now empirically pinned — bead rheo-packages-mxqa.** The gap this row
originally flagged was real: `v.title` (`spine()`'s input, from rheo core's
own pre-compile spine-flat data) is filename-derived ONLY, on the
`feat/transclusion` line — no pre-compile AST scan of `#set document(title:
..)` feeds it, and none is coming back. But the AUTHORED title is still
reachable — post-compile, through the same per-vertebra metadata beacon
(`<rheo-meta:<handle>>`) `spine()` already reads for `date`/`keywords`. Its
`title` field is CONTENT, not a string (MEASURED, typst 0.15.1: even a title
authored as a plain string, e.g. `#set document(title: "Plain Str")`, queries
back through the beacon as content `[Plain Str]`) — the missing piece was a
flattener, landed as `_plain-text` in `src/lib.typ`. `spine()` now prefers
the beacon's flattened `title` whenever it is non-empty, falling back to
`v.title` only when `_meta` finds no beacon at all for that handle.

`demo/content/posts/one.typ` sets a PLAIN STRING title
(`#set document(title: "Custom Post Title")`); `demo/content/posts/two.typ`
sets a bracket CONTENT title containing markup
(`#set document(title: [Two, #emph[emphatically]])`) — the second exercises
`_plain-text`'s flattening itself, not merely a field read that happens to
already be a string. Both differ from their filename-derived fallbacks
("One"/"Two").

OBSERVED (`demo/build/html/feed.xml`):
```
<entry><id>https://demo.example.org/posts/one.html</id><title>Custom Post Title</title>...</entry>
<entry><id>https://demo.example.org/posts/two.html</id><title>Two, emphatically</title>...</entry>
```
Neither the plain-string nor the markup-bearing entry carries its
filename-derived fallback ("One"/"Two") — both carry the AUTHORED title.
`posts/deep/three.typ` sets no title of its own, and its entry's `<title>`
is still `Three` — the filename-derived fallback remains correct for a
vertebra that never authors one, matching `spine()`'s own documented
"beacon found no title, or no beacon at all" behaviour.

PASS — pinned by `demo/check.sh` (exact-match on both authored titles, plus
an explicit check that neither stale fallback string survives anywhere in
`feed.xml`).

## Row 10 — entry timestamp falls back to the document date

Every post in `demo/content/posts/` sets `#set document(date: ..)` and no
`published`/`updated` override — `spine()` reads that date via the
`<rheo-meta:*>` beacon and fills BOTH fields from it.

OBSERVED (`demo/build/html/feed.xml`):
- `posts/one.typ` (`date: datetime(year: 2026, month: 1, day: 5)`) →
  `<published>2026-01-05T00:00:00Z</published><updated>2026-01-05T00:00:00Z</updated>`
- `posts/two.typ` (`.. month: 2, day: 12`) →
  `2026-02-12T00:00:00Z` in both fields
- `posts/deep/three.typ` (`.. month: 3, day: 20`) →
  `2026-03-20T00:00:00Z` in both fields

PASS — pinned by `demo/check.sh` (exact per-title date match).

## Row 11 — `<published>` distinct from and independent of `<updated>`

`spine()` alone always mirrors ONE date into both fields, so this needed
row 12's override composition to produce a real divergence.
`verify/override/content/index.typ`: `a.typ`'s entry is overridden with
`published: datetime(2026-01-01)` and a LATER `updated:
datetime(2026-06-01)`; `b.typ`'s entry has its `published` cleared
(`e + (published: none)`), leaving only `updated` (from its own `#set
document(date: ..)`, untouched by the override).

OBSERVED (`verify/override/build/html/feed.xml`):
```
<entry><id>https://override.example.org/b.html</id><title>B</title><updated>2026-04-15T00:00:00Z</updated>...</entry>
<entry><id>https://override.example.org/a.html</id><title>Override</title><published>2026-01-01T00:00:00Z</published><updated>2026-06-01T00:00:00Z</updated>...</entry>
```
`a`'s entry: both elements present, distinct values, `updated` later than
`published`. `b`'s entry: no `<published>` element at all, only `<updated>`.
The retired Rust generator never emitted `atom:published`; this is a real
fix, not parity.

PASS — pinned by `verify/run.sh`.

## Row 12 — per-entry overrides without `#set document`

Same fixture as row 11. `content/index.typ`'s `with-overrides` composes
over the built-in `spine()` source, `.map`-ing its output to replace
specific fields by `page`:

```typ
#let with-overrides(s) = spine()(s).map(e => if e.page == "a.html" {
  e + (
    title: "Override",
    published: datetime(year: 2026, month: 1, day: 1),
    updated: datetime(year: 2026, month: 6, day: 1),
  )
} else if e.page == "b.html" {
  e + (published: none)
} else {
  e
})
```

OBSERVED: `a.typ`'s own heading is "A" and it sets no document title at
all, yet its entry's `<title>` is `Override` — the composed function's
override, not anything scraped from the page. The exact pattern (generalised,
with the bead's own `e.page == "a.html"` shape kept) is in readme.md's
"Per-entry overrides" section — the replacement for the retired
`rheo-feed-title`/`rheo-feed-updated` variables.

PASS — pinned by `verify/run.sh`.

## Rows 13 & 14 — documented, not asserted

Both are behaviour NOTES rather than fixture rows (there's nothing to grep
for "it changed on every build" or "it's silently absent"): documented in
readme.md's "Migrating from the retired Rust feed generator" section.

- Row 13: `datetime.today()` produces a feed timestamp that changes on every
  build — warned against, with the fix (a literal `datetime(..)`).
- Row 14: an undated entry is DROPPED, not dated — Typst cannot stat a
  file, so the retired mtime fallback has no equivalent; this is also
  exercised structurally by row 8/`_stub-dated`'s "Entry Four" in
  `test/units.typ` (already existing coverage, unrelated to this bead).
