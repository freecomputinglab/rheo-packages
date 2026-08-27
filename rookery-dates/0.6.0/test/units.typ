// Unit fixture for @rheo/rookery-dates. Run with `just test` from
// `rookery-dates/0.6.0`. There is no runner and no JS: an `assert` that fails
// fails the compile with a line number, and a passing compile is the green
// light — the same shape `@rheo/rookery` and `@rheo/feeds` use.

#import "/src/lib.typ": *

#let d(y, m, dd) = datetime(year: y, month: m, day: dd)
#let NOW = d(2026, 8, 25)

// ---- dates() — ONE key, and an omitted date emits none of it --------------
// Not a key with value `none`: a `none`-valued key is a FLAT tag and renders as a
// pill, so a silent `dates()` must stay silent.
#assert.eq(dates(), (:))
// As of 0.6.0 `scheduled:`/`deadline:` are STAGES in the single `date-log` key
// rather than two keys of their own. One destination for all three arguments.
#assert.eq(
  dates(deadline: d(2026, 9, 1)),
  ("date-log": ((stage: "deadline", on: d(2026, 9, 1)),)),
)
#assert.eq(
  dates(scheduled: d(2026, 9, 1)),
  ("date-log": ((stage: "scheduled", on: d(2026, 9, 1)),)),
)
#assert.eq(dates(scheduled: d(2026, 1, 2), deadline: d(2026, 3, 4)).keys().len(), 1)

// The key is namespaced, because a key becomes a `.idea-tag-<key>` CSS class and
// a bare `log` is a name two packages would both reach for. The three reserved
// stage names are exported for the same reason the old key constants were: a
// consumer must not hardcode them.
#assert.eq(LOG-KEY, "date-log")
#assert.eq(SCHEDULED-STAGE, "scheduled")
#assert.eq(DEADLINE-STAGE, "deadline")
#assert.eq(CLOSED-STAGE, "closed")

// Merges into an ordinary tag dictionary without disturbing it.
#assert.eq(
  (phd: none) + dates(deadline: d(2026, 9, 1)),
  (phd: none, "date-log": ((stage: "deadline", on: d(2026, 9, 1)),)),
)

// ---- the log — SORTED BY DATE, written order only breaking ties ------------
// Sorted at write time so the stored value is unambiguous and no reader has to
// sort. The order it was WRITTEN in cannot lie about the timeline.
#assert.eq(
  dates(log: (
    rejected: d(2027, 2, 3),
    submitted: d(2026, 10, 28),
    longlisted: d(2026, 12, 15),
  )).at("date-log").map(e => e.stage),
  ("submitted", "longlisted", "rejected"),
)
// TIES keep the written order. MEASURED on typst 0.15.x: a dictionary preserves
// insertion order, so this is sound — and the sort decorates with the written
// index rather than trusting `array.sorted`, which is not documented as stable.
#assert.eq(
  dates(log: (b: d(2026, 5, 1), a: d(2026, 5, 1))).at("date-log").map(e => e.stage),
  ("b", "a"),
)
// `scheduled:`/`deadline:` fold into the same log as `log:`'s own entries.
#assert.eq(
  dates(deadline: d(2026, 11, 1), log: (submitted: d(2026, 10, 28))).at("date-log"),
  ((stage: "submitted", on: d(2026, 10, 28)), (stage: "deadline", on: d(2026, 11, 1))),
)
// A hyphenated stage name is fine — it has to survive being a CSS class fragment.
#assert.eq(
  dates(log: ("first-interview": d(2027, 1, 20))).at("date-log").first().stage,
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
    tags: (phd: none, "date-log": ((stage: "deadline", on: d(2026, 9, 1)),)),
    rest: (title: "T"),
  ),
)
// All four `tags:` shapes rookery accepts are normalized, so a bare string works.
#assert.eq(
  _dated-spy(deadline: d(2026, 9, 1), tags: "phd").tags.keys(),
  ("phd", "date-log"),
)
#assert.eq(_dated-spy(tags: ("a", "b")).tags, (a: none, b: none))
// No dates at all adds no key.
#assert.eq(_dated-spy(tags: (phd: none)).tags, (phd: none))

// ---- readers ---------------------------------------------------------------
#assert.eq(deadline-of(dates(deadline: d(2026, 9, 1))), d(2026, 9, 1))
#assert.eq(deadline-of((:)), none)
#assert.eq(scheduled-of(dates(scheduled: d(2026, 9, 1))), d(2026, 9, 1))
#assert.eq(scheduled-of((phd: none)), none)

// A stage appearing twice reads as the LATEST: a todo deferred and then
// re-deferred means the current deferral, not the first one ever set.
#assert.eq(
  scheduled-of(("date-log": (
    (stage: "scheduled", on: d(2026, 1, 1)),
    (stage: "scheduled", on: d(2026, 6, 1)),
  ))),
  d(2026, 6, 1),
)

// ---- is-overdue — strictly before, so "due today" is not overdue ----------
#assert.eq(is-overdue(dates(deadline: d(2026, 8, 24)), today: NOW), true)
#assert.eq(is-overdue(dates(deadline: NOW), today: NOW), false)
#assert.eq(is-overdue(dates(deadline: d(2026, 8, 26)), today: NOW), false)
// No deadline is not overdue.
#assert.eq(is-overdue((:), today: NOW), false)
// Year boundaries compare correctly, which is the whole reason dates are
// compared as zero-padded [year][month][day] strings rather than as datetimes.
#assert.eq(is-overdue(dates(deadline: d(2025, 12, 31)), today: NOW), true)
#assert.eq(is-overdue(dates(deadline: d(2027, 1, 1)), today: NOW), false)

// ---- is-upcoming — inclusive both ends, and never also overdue ------------
#assert.eq(is-upcoming(dates(deadline: NOW), today: NOW), true)
#assert.eq(is-upcoming(dates(deadline: d(2026, 9, 1)), today: NOW, within: 7), true)
#assert.eq(is-upcoming(dates(deadline: d(2026, 9, 2)), today: NOW, within: 7), false)
#assert.eq(is-upcoming(dates(deadline: NOW), today: NOW, within: 0), true)
// An overdue deadline is NOT upcoming — a row belongs to exactly one of them.
#assert.eq(is-upcoming(dates(deadline: d(2026, 8, 24)), today: NOW), false)
#assert.eq(is-upcoming((:), today: NOW), false)

// ---- is-scheduled-now — on or before, and absent means NOT scheduled ------
#assert.eq(is-scheduled-now(dates(scheduled: d(2026, 8, 24)), today: NOW), true)
#assert.eq(is-scheduled-now(dates(scheduled: NOW), today: NOW), true)
#assert.eq(is-scheduled-now(dates(scheduled: d(2026, 8, 26)), today: NOW), false)
// Absent reads as "not scheduled", NOT as "scheduled for now". A consumer
// wanting "nothing defers this" asks `scheduled-of(t) == none or is-scheduled-now(t)`.
#assert.eq(is-scheduled-now((:), today: NOW), false)

// ---- dated-idea — the one binding that imports @rheo/rookery --------------
// A plain rookery note that also takes this package's date arguments. Its
// existence is why `src/lib.typ`'s "imports rookery not at all" claim was
// rewritten rather than left standing: the CORE is still import-free, because
// `dated(mint)` takes the constructor as an argument.
#assert.eq(type(dated-idea), function)
