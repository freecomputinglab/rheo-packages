// tag-index.typ — `#tag-index` and `#ideas(index: ..)` (src/data.typ): a DECLARED
// projection of tag VALUES onto an `ideas()` row, flattened to scalars.
//
// The point of the feature, and so of this root: `ideas()` publishes tag NAMES
// only, because a value can be content and `json.encode` of content silently
// emits a structural blob. A projection makes the values narrow and asserted, so
// they can ride on a row — and a page reads three tag values per note without
// walking `tag-data()` once per view.
#import "../../src/lib.typ": idea, ideas, tag-index

#set page(width: 15cm, height: auto, margin: 1cm)

= tag-index

#let KINDS = ("postdoc", "tenuretrack")

// ONE index for the whole page, built once and passed to every reader on it.
// Building it per view is what the feature exists to stop.
#let INDEX = tag-index((
  // A flat-tag FAMILY: the prefix is stripped, and `one-of:` both restricts and
  // ORDERS the candidates, so a note carrying two members resolves to the
  // earliest listed rather than to whichever key order happens to yield.
  kind: (family: "venue-", one-of: KINDS),
  cycle: (family: "cycle-"),
  // A valued tag, stamped: a datetime is not a scalar, and a zero-padded
  // [year][month][day] string sorts lexically in date order — so this field is a
  // free sort key.
  deadline: (key: "date-deadline", stamp: true),
  // A COMPUTATION over the tag dictionary. The only way a value that cannot ride
  // on a row (an array, a log) becomes filterable or sortable at all.
  tags-count: (from: t => t.keys().len()),
))

#idea(
  "wolf",
  title: [Wolf Humanities],
  tags: (
    "venue-postdoc": none,
    "cycle-26-27": none,
    "date-deadline": datetime(year: 2026, month: 11, day: 1),
  ),
)[A postdoc, deadline 1 November 2026.]

#idea(
  "sipa",
  title: [Columbia SIPA],
  tags: (
    "venue-tenuretrack": none,
    "cycle-26-27": none,
    "date-deadline": datetime(year: 2026, month: 9, day: 30),
  ),
)[A tenure-track line, deadline 30 September 2026.]

// Carries none of the projected tags: every field comes back `none`, which is an
// ABSENT fact rather than a missing key.
#idea("undated", title: [Undated])[No tags at all.]

== Sorted by the projected deadline

// The whole reason a date is projected as a stamp: this is a plain string sort
// and it is in date order. `zzzzzzzz` puts the undated note last without a
// second comparison.
#context {
  let rows = ideas(index: INDEX).sorted(key: r => (
    if r.deadline == none { "zzzzzzzz" } else { r.deadline }
  ))
  list(
    ..rows.map(r => [
      #r.label — kind #raw(repr(r.kind)), cycle #raw(repr(r.cycle)),
      deadline #raw(repr(r.deadline)), #r.tags-count tag(s)
    ]),
  )
}

== Filtered on a projected field

#context list(
  ..ideas(index: INDEX).filter(r => r.kind == "postdoc").map(r => r.label),
)

== Without an index, no projected fields appear

// `ideas()` unchanged is the default tier, and it must stay free: no walk of the
// value store, and no projected keys on the row to read by accident.
#context [
  keys=#raw(repr("kind" in ideas().first()))
]
