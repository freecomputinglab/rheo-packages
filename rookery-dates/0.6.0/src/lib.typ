// @rheo/rookery-dates — a dated log for rookery notes.
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
// WHAT IT OWNS: a note's DATED EVENTS, as one ordered log. Until 0.6.0 it owned
// two independent slots and both were plans — `scheduled` (when you mean to work
// on it) and `deadline` (a hard date), the org-mode pair. A log is the third
// thing, org-mode's LOGBOOK to those two: what happened, and when. Both of the
// old slots are RESERVED STAGE NAMES inside it now, so one mechanism carries
// arbitrarily complex lifecycles without this package naming any of their states.
//
// WHAT IT DOES NOT OWN, deliberately:
//
//   - `created`. Rookery core resolves and stores it and ships it on every
//     `ideas()` row. This package READS it (`created-of` below) rather than
//     keeping a second copy that could disagree — and core keeping it a ROW field
//     rather than a tag value is what makes filtering by date free, since a tag
//     value costs a `tag-data()` walk to reach.
//   - a STAGE VOCABULARY beyond the three reserved names. Whether `accepted` ends
//     a process or is the middle of it depends on words a consumer owns, so
//     `is-settled`/`rung`/`next-stage` take a ladder as a parameter. Status
//     transitions likewise: @rheo/rookery-todos owns `activated`.
//
//   `updated` is neither owned nor read — core removed that field in 0.6.0.
//   `updated-of` DERIVES it: the log's last entry, else `created`.
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
// This package reads no rheo context, no `sys.inputs`, no state and no registry.
// Every function is a function of its arguments — with ONE exception, and it is
// the reason this package now ships a stylesheet: `#log-view` (`view.typ`) draws
// the log as a vertical rail, so it emits HTML and needs CSS to be usable. There
// is still no JavaScript, and nothing here reads rheo context even now.

#import "fragment.typ": *
#import "read.typ": *
#import "when.typ": *
#import "ladder.typ": *
#import "index.typ": *
#import "view.typ": *

// THE ONE PLACE THIS PACKAGE IMPORTS @rheo/rookery, and it buys exactly one
// convenience: `#dated-idea` — a plain rookery note that also takes this
// package's `log:`/`scheduled:`/`deadline:` arguments. Everything else here is
// import-free, because `dated` (fragment.typ) receives its constructor as an
// ARGUMENT rather than reaching for one. See the header note above.
#import "@rheo/rookery:0.6.0": idea
#let dated-idea = dated(idea)
