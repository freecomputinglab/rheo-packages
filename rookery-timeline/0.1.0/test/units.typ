// Unit fixture for @rheo/rookery-timeline. Run with `just test` from
// `rookery-timeline/0.1.0`. There is no runner and no JS: an `assert` that fails
// fails the compile with a line number, and a passing compile is the green
// light — the same shape `@rheo/rookery` and `@rheo/feeds` use.

#import "/src/lib.typ": *

#let d(y, m, dd) = datetime(year: y, month: m, day: dd)
#let NOW = d(2026, 8, 25)

// ---- entries() — ONE key, and an omitted date emits none of it --------------
// Not a key with value `none`: a `none`-valued key is a FLAT tag and renders as a
// pill, so a silent `entries()` must stay silent.
#assert.eq(entries(), (:))
// As of 0.6.0 `scheduled:`/`deadline:` are STAGES in the single `timeline-log` key
// rather than two keys of their own. One destination for all three arguments.
#assert.eq(
  entries(deadline: d(2026, 9, 1)),
  ("timeline-log": ((stage: "deadline", on: d(2026, 9, 1)),)),
)
#assert.eq(
  entries(scheduled: d(2026, 9, 1)),
  ("timeline-log": ((stage: "scheduled", on: d(2026, 9, 1)),)),
)
#assert.eq(entries(scheduled: d(2026, 1, 2), deadline: d(2026, 3, 4)).keys().len(), 1)

// The key is namespaced, because a key becomes a `.idea-tag-<key>` CSS class and
// a bare `log` is a name two packages would both reach for. The three reserved
// stage names are exported for the same reason the old key constants were: a
// consumer must not hardcode them.
#assert.eq(LOG-KEY, "timeline-log")
#assert.eq(SCHEDULED-STAGE, "scheduled")
#assert.eq(DEADLINE-STAGE, "deadline")
#assert.eq(CLOSED-STAGE, "closed")

// Merges into an ordinary tag dictionary without disturbing it.
#assert.eq(
  (phd: none) + entries(deadline: d(2026, 9, 1)),
  (phd: none, "timeline-log": ((stage: "deadline", on: d(2026, 9, 1)),)),
)

// ---- the log — SORTED BY DATE, written order only breaking ties ------------
// Sorted at write time so the stored value is unambiguous and no reader has to
// sort. The order it was WRITTEN in cannot lie about the timeline.
#assert.eq(
  entries(log: (
    rejected: d(2027, 2, 3),
    submitted: d(2026, 10, 28),
    longlisted: d(2026, 12, 15),
  )).at("timeline-log").map(e => e.stage),
  ("submitted", "longlisted", "rejected"),
)
// TIES keep the written order. MEASURED on typst 0.15.x: a dictionary preserves
// insertion order, so this is sound — and the sort decorates with the written
// index rather than trusting `array.sorted`, which is not documented as stable.
#assert.eq(
  entries(log: (b: d(2026, 5, 1), a: d(2026, 5, 1))).at("timeline-log").map(e => e.stage),
  ("b", "a"),
)
// `scheduled:`/`deadline:` fold into the same log as `log:`'s own entries.
#assert.eq(
  entries(deadline: d(2026, 11, 1), log: (submitted: d(2026, 10, 28))).at("timeline-log"),
  ((stage: "submitted", on: d(2026, 10, 28)), (stage: "deadline", on: d(2026, 11, 1))),
)
// A hyphenated stage name is fine — it has to survive being a CSS class fragment.
#assert.eq(
  entries(log: ("first-interview": d(2027, 1, 20))).at("timeline-log").first().stage,
  "first-interview",
)

// ---- dated(mint) — the decorator ------------------------------------------
// Takes a minting FUNCTION and returns one that also accepts the date arguments,
// forwarding everything else untouched. A decorator rather than a finished
// constructor, so a consumer can put its own tag family on top.
#let _spy(tags: none, ..args) = (tags: tags, rest: args.named())
#let _dated-spy = dated(_spy)
#assert.eq(
  _dated-spy(deadline: d(2026, 9, 1), tags: (phd: none), title: "T"),
  (
    tags: (phd: none, "timeline-log": ((stage: "deadline", on: d(2026, 9, 1)),)),
    rest: (title: "T"),
  ),
)
// All four `tags:` shapes rookery accepts are normalized, so a bare string works.
#assert.eq(
  _dated-spy(deadline: d(2026, 9, 1), tags: "phd").tags.keys(),
  ("phd", "timeline-log"),
)
#assert.eq(_dated-spy(tags: ("a", "b")).tags, (a: none, b: none))
// No dates at all adds no key.
#assert.eq(_dated-spy(tags: (phd: none)).tags, (phd: none))

// ---- readers ---------------------------------------------------------------
#assert.eq(deadline-of(entries(deadline: d(2026, 9, 1))), d(2026, 9, 1))
#assert.eq(deadline-of((:)), none)
#assert.eq(scheduled-of(entries(scheduled: d(2026, 9, 1))), d(2026, 9, 1))
#assert.eq(scheduled-of((phd: none)), none)

// A stage appearing twice reads as the LATEST: a todo deferred and then
// re-deferred means the current deferral, not the first one ever set.
#assert.eq(
  scheduled-of(("timeline-log": (
    (stage: "scheduled", on: d(2026, 1, 1)),
    (stage: "scheduled", on: d(2026, 6, 1)),
  ))),
  d(2026, 6, 1),
)

// ---- is-overdue — strictly before, so "due today" is not overdue ----------
#assert.eq(is-overdue(entries(deadline: d(2026, 8, 24)), today: NOW), true)
#assert.eq(is-overdue(entries(deadline: NOW), today: NOW), false)
#assert.eq(is-overdue(entries(deadline: d(2026, 8, 26)), today: NOW), false)
// No deadline is not overdue.
#assert.eq(is-overdue((:), today: NOW), false)
// Year boundaries compare correctly, which is the whole reason dates are
// compared as zero-padded [year][month][day] strings rather than as datetimes.
#assert.eq(is-overdue(entries(deadline: d(2025, 12, 31)), today: NOW), true)
#assert.eq(is-overdue(entries(deadline: d(2027, 1, 1)), today: NOW), false)

// ---- is-upcoming — inclusive both ends, and never also overdue ------------
#assert.eq(is-upcoming(entries(deadline: NOW), today: NOW), true)
#assert.eq(is-upcoming(entries(deadline: d(2026, 9, 1)), today: NOW, within: 7), true)
#assert.eq(is-upcoming(entries(deadline: d(2026, 9, 2)), today: NOW, within: 7), false)
#assert.eq(is-upcoming(entries(deadline: NOW), today: NOW, within: 0), true)
// An overdue deadline is NOT upcoming — a row belongs to exactly one of them.
#assert.eq(is-upcoming(entries(deadline: d(2026, 8, 24)), today: NOW), false)
#assert.eq(is-upcoming((:), today: NOW), false)

// ---- is-scheduled-now — on or before, and absent means NOT scheduled ------
#assert.eq(is-scheduled-now(entries(scheduled: d(2026, 8, 24)), today: NOW), true)
#assert.eq(is-scheduled-now(entries(scheduled: NOW), today: NOW), true)
#assert.eq(is-scheduled-now(entries(scheduled: d(2026, 8, 26)), today: NOW), false)
// Absent reads as "not scheduled", NOT as "scheduled for now". A consumer
// wanting "nothing defers this" asks `scheduled-of(t) == none or is-scheduled-now(t)`.
#assert.eq(is-scheduled-now((:), today: NOW), false)

// ---- dated-idea — the one binding that imports @rheo/rookery --------------
// A plain rookery note that also takes this package's date arguments. Its
// existence is why `src/lib.typ`'s "imports rookery not at all" claim was
// rewritten rather than left standing: the CORE is still import-free, because
// `dated(mint)` takes the constructor as an argument.
#assert.eq(type(dated-idea), function)

// ---- the log readers -------------------------------------------------------
// The worked case from the design: submitted, longlisted, and a first interview
// BOOKED but not yet held, read against a `today:` that falls between the last
// two. Future-dated entries are the ordinary shape of a plan, not an edge case.
#let _flight = entries(log: (
  submitted: d(2026, 10, 28),
  longlisted: d(2026, 12, 15),
  "first-interview": d(2027, 1, 20),
))
#let _JAN5 = d(2027, 1, 5)

#assert.eq(log-of(_flight).len(), 3)
#assert.eq(log-of((:)), ())
#assert.eq(entered-of(_flight), d(2026, 10, 28))
#assert.eq(entered-of((:)), none)
#assert.eq(stage-date(_flight, "longlisted"), d(2026, 12, 15))
#assert.eq(stage-date(_flight, "nope"), none)
#assert.eq(has-stage(_flight, "submitted"), true)
#assert.eq(has-stage(_flight, "offered"), false)

// The current stage is the last thing that HAS HAPPENED, not the last entry.
#assert.eq(stage-of(_flight, today: _JAN5), "longlisted")
#assert.eq(stage-on(_flight, today: _JAN5), d(2026, 12, 15))
// ...and the booked interview is the NEXT appointment.
#assert.eq(next-of(_flight, today: _JAN5), (stage: "first-interview", on: d(2027, 1, 20)))
#assert.eq(next-of(_flight, today: d(2027, 2, 1)), none)
// A log whose every entry is still future: nothing has happened yet.
#assert.eq(stage-of(_flight, today: d(2026, 1, 1)), none)
#assert.eq(stage-of((:), today: _JAN5), none)

#assert.eq(days-at-stage(_flight, today: _JAN5), 21)
#assert.eq(days-in-flight(_flight, today: _JAN5), 69)
#assert.eq(days-in-flight((:), today: _JAN5), none)
// Measured from the first entry even when that entry is future, so a not-yet-sent
// submission reports a negative number rather than none.
#assert.eq(days-in-flight(entries(deadline: d(2027, 1, 20)), today: _JAN5), -15)

// ---- deadline-of over the log — is-overdue and friends unchanged -----------
// The four-line payoff: these readers kept their signatures, so the predicates
// built on them needed no edit at all when the storage changed underneath.
#assert.eq(deadline-of(entries(deadline: d(2026, 9, 1))), d(2026, 9, 1))
#assert.eq(deadline-of(_flight), none)

// ---- updated-of — derived, no longer a core field --------------------------
// The last log entry where there is one, else `created` off the row. Core removed
// its `updated` field in 0.6.0.
#assert.eq(updated-of((created: d(2026, 1, 1)), _flight), d(2027, 1, 20))
#assert.eq(updated-of((created: d(2026, 1, 1)), (:)), d(2026, 1, 1))
#assert.eq(updated-of((:), (:)), none)
#assert.eq(created-of((created: d(2026, 1, 1))), d(2026, 1, 1))
#assert.eq(created-of((:)), none)

// ---- timeline — one view over two stores -----------------------------------
// `created` LEADS and is not written into the log: one store per fact.
#assert.eq(
  timeline((created: d(2026, 10, 1)), _flight).map(e => e.stage),
  ("created", "submitted", "longlisted", "first-interview"),
)
// A row with no `created` contributes no leading entry rather than a none-dated one.
#assert.eq(timeline((:), _flight).map(e => e.stage), ("submitted", "longlisted", "first-interview"))
#assert.eq(timeline((created: d(2026, 10, 1)), (:)).map(e => e.stage), ("created",))

// ---- ladders — the derivations, with the vocabulary passed in --------------
// `accepted` is TRANSIT for a journal and TERMINAL for a conference. That single
// difference is why this package takes a ladder rather than owning the words.
#let JOB = (
  transit: ("submitted", "longlisted", "first-interview", "second-interview", "campus-visit", "finalist"),
  terminal: ("offered", "rejected", "declined", "dropped", "missed"),
)
#let JOURNAL = (
  transit: ("submitted", "under-review", "revise-resubmit", "resubmitted", "accepted", "in-production"),
  terminal: ("published", "rejected", "desk-rejected", "withdrawn"),
)

#let _at(stage) = entries(log: ((stage): d(2026, 6, 1)))
#let _T = d(2026, 12, 1)

#assert.eq(is-settled(_at("first-interview"), ladder: JOB, today: _T), false)
#assert.eq(rung(_at("first-interview"), ladder: JOB, today: _T), 2)
#assert.eq(next-stage(_at("first-interview"), ladder: JOB, today: _T), "second-interview")

// Terminal: settled, sorts past everything still moving, and expects nothing.
#assert.eq(is-settled(_at("offered"), ladder: JOB, today: _T), true)
#assert.eq(rung(_at("offered"), ladder: JOB, today: _T), 6)
#assert.eq(next-stage(_at("offered"), ladder: JOB, today: _T), none)

// The last transit rung expects nothing either, without being settled.
#assert.eq(next-stage(_at("finalist"), ladder: JOB, today: _T), none)
#assert.eq(is-settled(_at("finalist"), ladder: JOB, today: _T), false)

// The same stage against two ladders, which is the point of the parameter.
#assert.eq(is-settled(_at("accepted"), ladder: JOURNAL, today: _T), false)
#assert.eq(rung(_at("accepted"), ladder: JOURNAL, today: _T), 4)
#assert.eq(next-stage(_at("accepted"), ladder: JOURNAL, today: _T), "in-production")

// An UNKNOWN stage degrades rather than failing: a consumer's vocabulary grows,
// and a note written against tomorrow's ladder must not break another page.
#assert.eq(rung(_at("under-review"), ladder: JOB, today: _T), none)
#assert.eq(is-settled(_at("under-review"), ladder: JOB, today: _T), false)
#assert.eq(next-stage(_at("under-review"), ladder: JOB, today: _T), none)

// Nothing has happened yet — an empty log, and a log entirely in the future.
#assert.eq(is-settled((:), ladder: JOB, today: _T), false)
#assert.eq(rung((:), ladder: JOB, today: _T), none)
#assert.eq(is-settled(entries(deadline: d(2027, 1, 1)), ladder: JOB, today: _T), false)
#assert.eq(rung(entries(deadline: d(2027, 1, 1)), ladder: JOB, today: _T), none)

// ---- tag-index extractors — the log made projectable ----------------------
// A log can never ride on an `ideas()` row (rookery keeps tag values off rows),
// so the only way its facts become filterable or sortable is as derived scalars.
// Each of these is a factory returning the function core's `(from: ..)` calls.
#assert.eq((as-stage(today: _JAN5))(_flight), "longlisted")
#assert.eq((as-stage(today: _JAN5))((:)), none)

// A date comes back as a zero-padded STRING, never a datetime: core's scalar
// assert would refuse the datetime, and the string sorts lexically in date order.
#assert.eq((as-date(DEADLINE-STAGE))(entries(deadline: d(2026, 11, 1))), "20261101")
#assert.eq((as-date(DEADLINE-STAGE))(_flight), none)
#assert.eq((as-entered(today: _JAN5))(_flight), "20261028")

#assert.eq((as-rung(ladder: JOB, today: _JAN5))(_flight), 1)
#assert.eq((as-settled(ladder: JOB, today: _JAN5))(_flight), false)
#assert.eq(
  (as-settled(ladder: JOB, today: _JAN5))(entries(log: (offered: d(2026, 12, 1)))),
  true,
)
#assert.eq((as-days-in-flight(today: _JAN5))(_flight), 69)

// EVERY ONE returns a scalar or none, which is the whole contract — core asserts
// it and names the field when it fails.
#let _scalar(v) = v == none or type(v) in (str, int, float, bool)
#assert(_scalar((as-stage(today: _JAN5))(_flight)))
#assert(_scalar((as-date(DEADLINE-STAGE))(_flight)))
#assert(_scalar((as-rung(ladder: JOB, today: _JAN5))(_flight)))
#assert(_scalar((as-settled(ladder: JOB, today: _JAN5))(_flight)))
#assert(_scalar((as-days-in-flight(today: _JAN5))(_flight)))

// ---- log order honours the clock, where there is one ----------------------
// Two events on ONE DAY, written closed-first. Sorted by time they come back in
// the order they happened, which is the case a date-only key could not answer: it
// tied them and fell back to the written sequence.
#let _t15 = datetime(year: 2026, month: 8, day: 27, hour: 15, minute: 0, second: 0)
#let _t16 = datetime(year: 2026, month: 8, day: 27, hour: 16, minute: 0, second: 0)
#assert.eq(
  entries(log: (closed: _t16, activated: _t15)).at("timeline-log").map(e => e.stage),
  ("activated", "closed"),
)
// A DATE-ONLY entry sorts as the start of its day, so a bare `deadline` precedes a
// timed event on the same date rather than landing after it.
#assert.eq(
  entries(deadline: d(2026, 8, 27), log: (activated: _t15)).at("timeline-log").map(e => e.stage),
  ("deadline", "activated"),
)
// Two DATE-ONLY entries on one day still tie, and still resolve by written order —
// the existing behaviour, unchanged, because neither carries a time to compare.
#assert.eq(
  entries(log: (b: d(2026, 5, 1), a: d(2026, 5, 1))).at("timeline-log").map(e => e.stage),
  ("b", "a"),
)
// The stored value keeps its time; only the sort key reads it.
#assert.eq(entries(log: (activated: _t15)).at("timeline-log").first().on.hour(), 15)

// ---- timeline-view — the past/booked/expected split -----------------------------
// The rendering is HTML and this fixture is a paged compile, so what is asserted
// here is the SPLIT the view computes, through the same readers it uses. The
// markup itself is covered by the demo.
#let _straddle = entries(log: (
  submitted: d(2026, 10, 28),
  longlisted: d(2026, 12, 15),
  "first-interview": d(2027, 1, 20),
))
#let _JAN5b = d(2027, 1, 5)
#assert.eq(stage-of(_straddle, today: _JAN5b), "longlisted")
#assert.eq(next-of(_straddle, today: _JAN5b).stage, "first-interview")
// Two past, one booked -> the divider belongs, because both sides exist.
#assert.eq(log-of(_straddle).filter(e => e.on <= _JAN5b).len(), 2)
#assert.eq(log-of(_straddle).filter(e => e.on > _JAN5b).len(), 1)
// Every event past -> nothing booked, so no divider.
#assert.eq(log-of(_straddle).filter(e => e.on > d(2027, 6, 1)).len(), 0)

// The expected rungs, which is what `ladder:` adds. `rung` is 1 at longlisted, so
// what remains ahead is everything after index 1 that the log has not reached.
#let _LAD = (
  transit: ("submitted", "longlisted", "first-interview", "finalist"),
  terminal: ("offered", "rejected"),
)
#assert.eq(rung(_straddle, ladder: _LAD, today: _JAN5b), 1)
#assert.eq(
  _LAD.transit.slice(2).filter(n => n not in log-of(_straddle).map(e => e.stage)),
  ("finalist",),
)
// Settled -> `rung` is past the transit list, so nothing is expected ahead.
#assert.eq(rung(entries(log: (offered: d(2026, 12, 1))), ladder: _LAD, today: _JAN5b), 4)

// `#timeline-view` ITSELF IS NOT ASSERTED HERE. It is a context function — it branches
// on `target()` — so it returns content rather than a value, and a context block's
// result cannot be compared. Its markup is covered by the demo instead, which is
// where a rendered rail can actually be inspected.
