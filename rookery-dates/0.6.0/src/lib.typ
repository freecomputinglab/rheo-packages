// @rheo/rookery-dates — scheduled and deadline dates for rookery notes.
//
// A note's temporal planning, contributed through @rheo/rookery 0.6.0's TAG
// DICTIONARY rather than through a wrapper around `#idea`. The whole interface
// is a fragment builder you merge into a `tags:` argument:
//
//   #import "@rheo/rookery-dates:0.6.0": dates
//   #idea("ship", tags: dates(deadline: datetime(year: 2026, month: 9, day: 1)))[..]
//
// THAT SHAPE IS THE POINT, and it survives 0.6.0's `#dated-idea` intact. The
// CORE of this package imports @rheo/rookery not at all, and @rheo/rookery knows
// nothing of it — a tag fragment is a plain dictionary, so composition needs no
// import relationship in either direction. Any package, and any hand-written
// `#idea`, can use it. `dated(mint)` keeps that true for the decorator too, by
// taking the minting function as an ARGUMENT; the single `dated-idea` binding at
// the foot of this file is the one line that imports rookery, and it exists only
// so the common case reads as one name rather than two.
//
// WHAT IT OWNS: dates that are PLANS — `scheduled` (when you mean to work on
// it) and `deadline` (a hard date), the org-mode pair.
//
// WHAT IT DOES NOT OWN, deliberately:
//
//   - `created`/`updated`. Rookery core already resolves and stores these as
//     `minted`/`updated` and ships them on every `ideas()` row. This package
//     READS them (`created-of`/`updated-of` below) rather than storing a
//     second copy that could disagree.
//   - status transitions. A closed-at timestamp belongs to whoever owns the
//     status — @rheo/rookery-todos and its `todo-closed` tag.
//
// THERE IS NO WALL CLOCK, and this constrains the whole package. Typst has no
// time of day at all (MEASURED: `datetime.today().hour()` is `none`), and in a
// reproducible-build environment `SOURCE_DATE_EPOCH` makes `datetime.today()`
// return 1980-01-01 rather than the real date (MEASURED at typst 0.15.1 with
// `SOURCE_DATE_EPOCH=315532800`, which is what this repo's own devShell sets).
// IT FAILS SILENTLY — a wrong date, not an error. So:
//
//   - every date is author-supplied; nothing here is auto-stamped
//   - NO FUNCTION IN THIS PACKAGE MAY CALL `datetime.today()`
//   - a predicate needing a "now" takes an explicit `today:`, falling back to
//     the document's own `#set document(date:)`, and panics rather than guess
//
// This package reads no rheo context, no `sys.inputs`, no state and no
// registry. Every function is a function of its arguments.

#import "fragment.typ": *
#import "read.typ": *
#import "when.typ": *
#import "ladder.typ": *
#import "index.typ": *

// THE ONE PLACE THIS PACKAGE IMPORTS @rheo/rookery, and it buys exactly one
// convenience: `#dated-idea` — a plain rookery note that also takes this
// package's `log:`/`scheduled:`/`deadline:` arguments. Everything else here is
// import-free, because `dated` (fragment.typ) receives its constructor as an
// ARGUMENT rather than reaching for one. See the header note above.
#import "@rheo/rookery:0.6.0": idea
#let dated-idea = dated(idea)
