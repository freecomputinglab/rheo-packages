// Unit fixture for the entry model, feed config, and `resolve-entries` in
// `/src/lib.typ`. No runner and no JS: `assert`/`assert.eq` fail the compile
// with a line number, and a passing compile is the green light.
//
// Run with `just test` from `rssfeed/0.1.0`.
//
// SCOPE: this bead lands data modelling only — no concrete source, no XML
// serialization, no `.marrow.typ` — so this fixture covers exactly that:
// `feed(...)`'s validation and defaults, and `resolve-entries`'s normalise
// -> sort -> dedupe -> limit pipeline, including the skip rule for entries
// with neither `published` nor `updated`.
//
// PANICS ARE NOT ASSERTABLE in Typst, so the invalid-input paths are only
// documented here, not exercised:
//   - `feed(...)` panics on: empty/missing `title`; empty/missing
//     `base-url`; a `base-url` with no scheme (e.g. "example.com"); an empty
//     `sources`; a non-function `sources` entry; a `content` other than
//     "html"/"xhtml"/none.
//   - `resolve-entries` (via `_normalize-entry`) panics on: a non-dictionary
//     entry from a source; an entry missing/empty `title`; an entry with
//     neither `url` nor `page`.
//   - `resolve-entries` panics when a source's return value is not an array.
//   - `items()` panics (via its own beacon validation, at query time) on: a
//     `<rssfeed:item>` (or custom `label-name`) beacon whose value is not a
//     dictionary; a beacon dictionary with a missing/empty `title`.
//   - `item(...)` panics on a missing/empty `title` (same rule, checked at
//     the emitting end instead of the reading end).

#import "/src/lib.typ": _clean-page, feed, item, items, resolve-entries, spine

// ---- _clean-page — no double slash whichever way a source spells `page` ---
#assert.eq(_clean-page("two.html"), "two.html")
#assert.eq(_clean-page("/two.html"), "two.html")
#assert.eq(_clean-page("./two.html"), "two.html")

// `feed(...)` requires at least one source (panics otherwise — see the top
// comment), so every config below needs one even where its entries do not
// matter to the assertion at hand.
#let _empty-source(cfg) = ()

// ---- feed — defaults, and the trailing-slash trim on `base-url` -----------
// Two configs, two different `path`s — proves `feed(...)` is not a singleton
// and each call is independent.
#let feed1 = feed(
  path: "feed1.xml",
  title: "Feed One",
  // Trailing slash: `feed(...)` must trim it so `resolve-entries` never
  // joins a page onto a double slash.
  base-url: "https://example.com/",
  sources: (_empty-source,),
)
#let feed2 = feed(
  path: "feed2.xml",
  title: "Feed Two",
  base-url: "https://example.org",
  sources: (_empty-source,),
)
#assert.eq(feed1.path, "feed1.xml")
#assert.eq(feed2.path, "feed2.xml")
#assert.eq(feed1.base-url, "https://example.com")
// Untouched when there was nothing to trim.
#assert.eq(feed2.base-url, "https://example.org")
// Defaults: `author` "Rheo", `content` "html", `subtitle`/`limit` none.
#assert.eq(feed1.author, "Rheo")
#assert.eq(feed1.content, "html")
#assert.eq(feed1.subtitle, none)
#assert.eq(feed1.limit, none)

// ---- resolve-entries — normalise, the skip rule, order, id/url fill -------
//
// Four hand-written entries from one stub source:
//   "one"   — dated (published AND updated), explicit url
//   "two"   — dated (published AND updated), url built from a leading-slash
//             `page` (exercises `_clean-page` through the real pipeline)
//   "three" — PUBLISHED ONLY — must get `updated` filled from it
//   "four"  — NO DATES AT ALL — must be DROPPED by the skip rule
#let _stub-dated(cfg) = (
  (
    title: "Entry One",
    url: "https://example.com/one",
    published: datetime(year: 2026, month: 1, day: 10),
    updated: datetime(year: 2026, month: 1, day: 12),
  ),
  (
    title: "Entry Two",
    page: "/two.html",
    published: datetime(year: 2026, month: 3, day: 5),
    updated: datetime(year: 2026, month: 3, day: 6),
  ),
  (
    title: "Entry Three",
    url: "https://example.com/three",
    published: datetime(year: 2026, month: 2, day: 1),
  ),
  (
    title: "Entry Four",
    url: "https://example.com/four",
  ),
)

#let cfg-dated = feed(
  path: "dated.xml",
  title: "Dated Feed",
  base-url: "https://example.com",
  sources: (_stub-dated,),
)
#let dated = resolve-entries(cfg-dated)

// The undated entry ("Entry Four") is gone: 3 kept, not 4.
#assert.eq(dated.len(), 3)
// Newest-first: Two (Mar 5) > Three (Feb 1) > One (Jan 10).
#assert.eq(dated.map(e => e.title), ("Entry Two", "Entry Three", "Entry One"))
// `url` built from `page`, with the leading slash stripped — no double slash.
#assert.eq(dated.at(0).url, "https://example.com/two.html")
// `id` defaults to the (possibly built) `url` when a source gives none.
#assert.eq(dated.at(0).id, "https://example.com/two.html")
#assert.eq(dated.at(2).id, "https://example.com/one")
// "Entry Three" had only `published`; `updated` must be filled from it.
#assert.eq(dated.at(1).published, datetime(year: 2026, month: 2, day: 1))
#assert.eq(dated.at(1).updated, datetime(year: 2026, month: 2, day: 1))

// `limit: 2` keeps the 2 most recent, post-sort.
#let cfg-limited = feed(
  path: "limited.xml",
  title: "Limited Feed",
  base-url: "https://example.com",
  sources: (_stub-dated,),
  limit: 2,
)
#assert.eq(
  resolve-entries(cfg-limited).map(e => e.title),
  ("Entry Two", "Entry Three"),
)

// ---- resolve-entries — dedupe by id keeps the FIRST occurrence ------------
//
// Sorting happens BEFORE deduping, so "first occurrence" of a repeated id is
// whichever copy sorted newest — here, "Dup New".
#let _stub-dup(cfg) = (
  (
    id: "dup",
    title: "Dup Old",
    url: cfg.base-url + "/dup-old",
    updated: datetime(year: 2026, month: 1, day: 1),
  ),
  (
    id: "dup",
    title: "Dup New",
    url: cfg.base-url + "/dup-new",
    updated: datetime(year: 2026, month: 6, day: 1),
  ),
)
#let cfg-dup = feed(
  path: "dup.xml",
  title: "Dup Feed",
  base-url: "https://example.org",
  sources: (_stub-dup,),
)
#let dup = resolve-entries(cfg-dup)
#assert.eq(dup.len(), 1)
#assert.eq(dup.first().title, "Dup New")

// ---- spine — no rheo present, so spine-flat is empty and there's no error -
//
// This fixture runs under plain `typst compile` with no rheo, so
// `sys.inputs` carries no `rheo-context` and `spine()`'s internal
// `_rheo-ctx()` falls back to an empty spine — `entries` is `()`, `.map`
// never runs its body, and the `query()` inside `_meta` is therefore never
// actually reached. Still wrapped in `#context`, both because that's the
// real calling convention (`spine()`'s doc comment: call via
// `resolve-entries` from inside `#context { .. }`) and because `assert`
// failures inside a `context` block still fail the compile — the mechanism
// this whole fixture relies on.
#let cfg-spine = feed(
  path: "spine.xml",
  title: "Spine Feed",
  base-url: "https://example.com",
  sources: (spine(),),
)
#context {
  assert.eq(resolve-entries(cfg-spine), ())
}

// Same, but exercising the argument-accepting shape (`filter`/`select`
// both given) — still `()` with no rheo, since `spine-flat` is empty before
// `filter` ever runs. Proves `spine(...)` itself doesn't choke on its own
// arguments; the `filter`/`select`/date-from-beacon LOGIC can only be
// exercised under a real rheo build (no way to fake `sys.inputs` here).
#let cfg-spine-args = feed(
  path: "spine2.xml",
  title: "Spine Feed 2",
  base-url: "https://example.com",
  sources: (spine(filter: e => true, select: "main"),),
)
#context {
  assert.eq(resolve-entries(cfg-spine-args), ())
}

// ---- items — beacons emitted by THIS document, read back in one pass -----
//
// `query()` sees any beacon in the SAME compile, even under plain `typst
// compile` with no rheo: one document is one introspection pass. This is
// the single-vertebra special case of the same fact rheo's own multi-
// vertebra bundle compile relies on for `spine`'s cross-vertebra
// `<rheo-meta:*>` beacons above. `item(...)` emits the beacons; `items()`
// reads them back — this also covers bead point "assert item(...)'s
// emitted beacon is picked up by items()".
#item(
  title: "Note A",
  page: "notes/a.html",
  updated: datetime(year: 2026, month: 5, day: 1),
  categories: ("note",),
)
#item(
  title: "Note B",
  page: "notes/b.html",
  updated: datetime(year: 2026, month: 5, day: 2),
  categories: ("log",),
)

#let cfg-items = feed(
  path: "items.xml",
  title: "Items Feed",
  base-url: "https://example.com",
  sources: (items(),),
)
#context {
  let all = resolve-entries(cfg-items)
  assert.eq(all.len(), 2)
  assert.eq(all.map(e => e.title).sorted(), ("Note A", "Note B"))
  // `page`/`url`, `author`, `id` were all omitted from the `item(...)`
  // calls above — proves `item(...)`'s sparse-dict emission lets
  // `_normalize-entry`'s own fallbacks (author from the feed, id from the
  // built url) still apply, rather than baking in explicit `none`s that
  // would shadow them.
  assert.eq(all.at(0).author, "Rheo")
  assert.eq(all.at(0).url, "https://example.com/notes/b.html")
  assert.eq(all.at(0).id, "https://example.com/notes/b.html")
}

// `filter` over the parsed item VALUE keeps only the "note"-tagged beacon.
#let cfg-items-filtered = feed(
  path: "items-filtered.xml",
  title: "Items Feed Filtered",
  base-url: "https://example.com",
  sources: (items(filter: it => "note" in it.at("categories", default: ())),),
)
#context {
  let filtered = resolve-entries(cfg-items-filtered)
  assert.eq(filtered.len(), 1)
  assert.eq(filtered.first().title, "Note A")
}
