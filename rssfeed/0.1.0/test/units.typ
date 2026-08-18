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

#import "/src/lib.typ": _clean-page, feed, resolve-entries

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
