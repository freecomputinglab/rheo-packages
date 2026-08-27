// Extractors for rookery core's `tag-index` — so a consuming project can project
// log-derived values onto an `ideas()` row without hardcoding this package's key
// name or reimplementing its reasoning.
//
// WHY THIS FILE EXISTS. Rookery keeps tag VALUES off `ideas()` rows: a value can
// be content, and `json.encode` of content silently emits a structural blob, so
// anything in the tag dictionary — this package's log included — is reachable only
// through `tag-data()`. `tag-index(spec)` is the way back on, and its
// `(from: <function>)` form takes a function of a note's whole tag dictionary and
// returns a SCALAR.
//
// That form exists precisely for this case. A log can never ride on a row, so the
// only way "what stage is this at" or "how far did it get" becomes filterable or
// sortable is as a derived scalar — and these are the functions that derive them.
//
// EACH IS A PARTIALLY-APPLIED FACTORY, not a function called with the tag
// dictionary directly. That shape is what lets a spec read as data:
//
//   #let INDEX = tag-index((
//     stage:    (from: as-stage(today: TODAY)),
//     deadline: (from: as-date(DEADLINE-STAGE)),
//     rung:     (from: as-rung(ladder: JOB, today: TODAY)),
//     settled:  (from: as-settled(ladder: JOB, today: TODAY)),
//     waiting:  (from: as-days-in-flight(today: TODAY)),
//   ))
//
// NO IMPORT OF @rheo/rookery HERE. These are plain functions of a tag dictionary;
// core consumes them, not the other way round. The only rookery import this
// package has is the one-line `dated-idea` binding in `lib.typ`.

#import "fragment.typ": *
#import "read.typ": *
#import "when.typ": *
#import "ladder.typ": *

// The current stage's NAME, as a string, or none.
#let as-stage(today: none) = tags => stage-of(tags, today: today)

// A NAMED stage's date as a zero-padded `[year][month][day]` STRING, not a
// datetime. Two reasons, and the second is the useful one: a projected value must
// be a scalar for core's assert to pass, and a fixed-width numeric string sorts
// lexically in date order — the device `when.typ`'s `_stamp` and rookery's own
// `_sort-ids` both already use. So `as-date(DEADLINE-STAGE)` is the ordinary
// "filter and sort by deadline" projection, and the sort is free.
#let as-date(stage) = tags => {
  let d = stage-date(tags, stage)
  if d == none { none } else { _stamp-of(d) }
}

// The FIRST entry's date, same stamp — "in flight since", as a sort key.
#let as-entered(today: none) = tags => {
  let d = entered-of(tags)
  if d == none { none } else { _stamp-of(d) }
}

// How far it got, as an integer, so a view can sort by progress rather than by
// date. `none` for a note the ladder cannot place — see `rung`.
#let as-rung(ladder: none, today: none) = tags => rung(tags, ladder: ladder, today: today)

// Whether the process has finished, as a bool — the pill a panel filters on.
#let as-settled(ladder: none, today: none) = tags => is-settled(tags, ladder: ladder, today: today)

// How long this has been sitting, as an integer — "sort by who has waited
// longest", which is the question a tracker is usually being asked.
#let as-days-in-flight(today: none) = tags => days-in-flight(tags, today: today)
