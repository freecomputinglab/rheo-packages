// The RENDERED half of the fixture, and the only file here that produces output.
//
// `units.typ` asserts values; `#timeline-view` returns content and branches on
// `target()`, so nothing about its markup can be asserted there. This compiles to
// HTML and `check.sh` greps what came out — the same division `@rheo/rookery`'s
// demo/pure and demo/rheo make between compiling and inspecting.
//
// Four cases, each the one the design turns on:
//   1. a log straddling `today` — the divider belongs, both sides exist
//   2. every event past — NO divider, because it would mark nothing
//   3. two events on ONE DAY — times shown rather than a date twice
//   4. the same log with and without `ladder:` — record vs progress
#import "/src/lib.typ": *

#let d(y, m, dd) = datetime(year: y, month: m, day: dd)
#let t(y, m, dd, h) = datetime(year: y, month: m, day: dd, hour: h, minute: 0, second: 0)
#let NOW = d(2027, 1, 5)

#let JOURNAL = (
  transit: ("submitted", "under-review", "revise-resubmit", "resubmitted", "accepted"),
  terminal: ("published", "rejected", "withdrawn"),
)

= 1. Straddling today

#let straddling = entries(timeline: (
  submitted: d(2026, 10, 28),
  "under-review": d(2026, 11, 15),
  "revise-resubmit": d(2026, 12, 20),
  resubmitted: d(2027, 3, 3),
))
#timeline-view((created: d(2026, 10, 1)), straddling, today: NOW)

= 2. Every event past

#timeline-view((created: d(2026, 1, 1)), entries(timeline: (
  submitted: d(2026, 2, 1),
  rejected: d(2026, 3, 1),
)), today: NOW)

= 3. Two events on one day

#timeline-view((:), entries(timeline: (
  activated: t(2026, 8, 27, 15),
  closed: t(2026, 8, 27, 16),
)), today: NOW)

= 4. The same log, with a ladder

#timeline-view((created: d(2026, 10, 1)), straddling, today: NOW, ladder: JOURNAL)

= 5. Timed events on the reference date itself

// The case that caught the bug: a date-only `today:` — which is what a site
// passes — against events carrying times on that very day. Both have HAPPENED, and
// a rail that called them booked would be wrong about the commonest call there is.
#timeline-view((:), entries(timeline: (
  activated: t(2027, 1, 5, 15),
  closed: t(2027, 1, 5, 16),
)), today: NOW)

= 6. Entries carrying their own notes

// The prose that is ABOUT one event, which used to end up on the note's body and
// read as a claim about the whole thing. One event has a note, one does not — a
// rail that drew an empty one for the second would be worse than drawing none.
#timeline-view((:), entries(timeline: (
  submitted: (
    timestamp: d(2026, 5, 1),
    note: [Sent the 500-word abstract, not the full paper.],
  ),
  rejected: d(2026, 7, 1),
)), today: NOW)

= 7. A ladder with a family rung

// Two reviews, written numbered because a dict cannot carry `review` twice, and a
// ladder that says "any review". The expected rungs ahead must render as `accepted`
// and `revision` — never as `revision-*` — and `review` must NOT be listed as still
// to come, since one has already happened.
#let JOURNAL2 = (
  transit: ("submitted", "review-*", "accepted", "revision-*"),
  terminal: ("published", "rejected", "withdrawn"),
)
#timeline-view((:), entries(timeline: (
  submitted: d(2026, 10, 1),
  "review-1": d(2026, 11, 1),
  "review-2": d(2026, 12, 1),
)), today: NOW, ladder: JOURNAL2)
