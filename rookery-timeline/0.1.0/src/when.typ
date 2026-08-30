// Derived temporal predicates, each taking an explicit reference date.
//
// EVERY FUNCTION HERE NEEDS A "NOW", AND TYPST CANNOT SUPPLY ONE. `datetime`
// has no time of day (MEASURED: `.hour()` is `none`), and `datetime.today()`
// returns 1980-01-01 wherever `SOURCE_DATE_EPOCH` is set for reproducible
// builds — MEASURED at typst 0.15.1 with `SOURCE_DATE_EPOCH=315532800`, which
// is exactly what this repo's own devShell exports. It does not error; it just
// answers wrongly. A predicate built on it would report every deadline in the
// project as decades overdue and no build would complain.
//
// So the reference date is a PARAMETER, resolved by `_today` below, and the
// last resort is a panic rather than a guess.

#import "fragment.typ": *
#import "read.typ": *

// Dates compared as zero-padded `[year][month][day]` STRINGS rather than as
// `datetime`s. This sidesteps the question of how `datetime` orders as a sort
// key at all, and it is the same technique @rheo/rookery already uses in its
// own `_sort-ids`. Same width every time, so string order is date order.
#let _stamp(d) = d.display("[year][month][day]")

// The reference date, most specific first: the explicit `today:` argument, then
// the document's own `#set document(date:)`, then a panic.
//
// MEASURED, and the reason this is a function rather than an inline `or`: a
// document with NO date set yields `auto`, NOT `none`. Testing only for `none`
// would let `auto` through into `.display()` and fail somewhere unrecognisable.
// @rheo/rookery's `#idea` carries the same note for the same reason.
//
// Reading `document.date` requires context, so a caller resolving the fallback
// must be inside a `#context` block — which every caller of these predicates
// already is, since they are reading a rookery registry to get the tags.
//
// THE PANIC IS DELIBERATE. Defaulting to some arbitrary date would make
// "overdue" a silent lie, which is precisely the failure mode `datetime.today()`
// already offers and this package exists to refuse.
#let _today(today) = {
  if today != none {
    assert(
      type(today) == datetime,
      message: "@rheo/rookery-timeline: `today` must be a datetime — got " + repr(today),
    )
    return today
  }
  let d = document.date
  if d != auto and d != none { return d }
  panic(
    "@rheo/rookery-timeline: this view needs a reference date and there is none. "
      + "Typst has no wall clock — `datetime.today()` returns 1980-01-01 under a "
      + "reproducible build — so pass one explicitly, e.g. "
      + "`today: datetime(year: 2026, month: 8, day: 25)`, or set the document's "
      + "own date with `#set document(date: ..)`.",
  )
}

// Has a deadline, and it is STRICTLY BEFORE the reference date. A deadline
// falling on `today` is due, not overdue — the day is not over.
#let is-overdue(tags, today: none) = {
  let d = deadline-of(tags)
  if d == none { return false }
  _stamp(d) < _stamp(_today(today))
}

// Has a deadline falling from the reference date up to and including `within`
// days later. `within: 0` asks "due today". An already-overdue deadline is NOT
// upcoming — `is-overdue` answers for that one, and a row wants to appear in
// exactly one of the two.
#let is-upcoming(tags, today: none, within: 7) = {
  assert(
    type(within) == int and within >= 0,
    message: "@rheo/rookery-timeline: `within` must be a non-negative integer number "
      + "of days — got " + repr(within),
  )
  let d = deadline-of(tags)
  if d == none { return false }
  let now = _today(today)
  let s = _stamp(d)
  s >= _stamp(now) and s <= _stamp(now + duration(days: within))
}

// Scheduled, and that date has arrived — on or before the reference date. This
// is the "may I start" question, and its negation is what deferral means:
// a note scheduled for next week is not yet ready to be worked on.
//
// A note with NO `date-scheduled` is `false` here, which reads as "not
// scheduled" rather than "scheduled for now". A consumer wanting "nothing is
// deferring this" should ask `scheduled-of(tags) == none or is-scheduled-now(..)`
// — @rheo/rookery-todos does exactly that when computing readiness.
#let is-scheduled-now(tags, today: none) = {
  let d = scheduled-of(tags)
  if d == none { return false }
  _stamp(d) <= _stamp(_today(today))
}

// ---- The log's own reference-date questions -------------------------------
//
// THESE NEED A `today:` BECAUSE LOG ENTRIES MAY BE FUTURE-DATED, and that is not
// an edge case — it is the ordinary shape of a plan. A `deadline` is by definition
// a date that has not arrived; an interview is booked before it is held; a
// decision is promised before it comes. So the log doubles as a calendar, and
// "what stage is this at" means "the last thing that has actually happened",
// which is a question about a reference date and cannot be answered from the tag
// dictionary alone. The readers in `read.typ` that need no `today:` live there.

// The name of the last entry dated ON OR BEFORE the reference date, or none.
//
// `none` covers two different situations and deliberately does not distinguish
// them, because no consumer has yet needed to: an empty log, and a log whose every
// entry is still in the future (an open call nothing has been sent to). A consumer
// that does need the difference asks `timeline-of(tags).len()`.
#let stage-of(tags, today: none) = {
  let now = _stamp(_today(today))
  let past = timeline-of(tags).filter(e => _stamp(e.timestamp) <= now)
  if past.len() == 0 { none } else { past.last().stage }
}

// That same entry's date, for "how long has it been at this stage".
#let stage-on(tags, today: none) = {
  let now = _stamp(_today(today))
  let past = timeline-of(tags).filter(e => _stamp(e.timestamp) <= now)
  if past.len() == 0 { none } else { past.last().timestamp }
}

// The first entry dated AFTER the reference date, as `(stage:, timestamp:)`, or none.
//
// This is what gives a view a real "next appointment" column: a booked interview
// or a promised decision is an ordinary log entry rather than a special slot, and
// this is the reader that finds it.
#let next-of(tags, today: none) = {
  let now = _stamp(_today(today))
  let future = timeline-of(tags).filter(e => _stamp(e.timestamp) > now)
  if future.len() == 0 { none } else { future.first() }
}

// Whole days from the current stage's date to the reference date. `none` when
// nothing has happened yet.
//
// `datetime - datetime` yields a `duration`, whose `.days()` is a float; rounded
// to an int here because every consumer wants "how many days", not 3.0.
#let days-at-stage(tags, today: none) = {
  let on = stage-on(tags, today: today)
  if on == none { return none }
  int(calc.round((_today(today) - on).days()))
}

// Whole days since the FIRST entry — "in flight for". `none` for an empty log.
//
// Measured from `entered-of` rather than from the first PAST entry, so a note
// whose log opens with a future deadline reports a negative number rather than
// none. That reads correctly: it is not in flight yet, and by how much.
#let days-in-flight(tags, today: none) = {
  let on = entered-of(tags)
  if on == none { return none }
  int(calc.round((_today(today) - on).days()))
}

// ---- How long you have, as a number and as words --------------------------
//
// THESE TWO ARE PUBLIC AND LIVE HERE rather than beside the view that draws them.
// `#upcoming` (`upcoming.typ`) held them as privates until @rheo/rookery-todos'
// `#filter-panel` needed the same chip on its own rows — and that file is the one
// place in this package that reads rookery's note registry, so a consumer importing
// from it pays for a registry walk to reach two functions over an integer.

// Whole days from the reference date to `d`, NEGATIVE where the date is already
// behind you. `datetime - datetime` yields a `duration` whose `.days()` is a
// float, so this rounds to an int — the same idiom `days-at-stage` uses above,
// rather than a second way of subtracting two dates.
//
// `today` IS POSITIONAL AND REQUIRED, unlike every predicate above: this takes two
// dates rather than a tag dictionary, so there is nothing to resolve a fallback
// from and no `#context` to resolve it in.
#let days-until(d, today) = int(calc.round((d - today).days()))

// HOW LONG YOU HAVE, AS WORDS, or `none` where the row should say nothing at all.
// Returns `(text: .., level: ..)`; the level is a presentation band, and a view
// turns it into the class a stylesheet colours.
//
// THE EDGES ARE WORDS, not arithmetic. `in 1 days` is not something anyone writes,
// and the three dates a reader acts on today are exactly the three worth naming.
//
// OVERDUE IS URGENT, AND HAS NO FLOOR. `#upcoming` sorts ASCENDING, so a date
// already behind you sits at the TOP of the list — it is the most urgent thing on
// it, not the stalest, and a row that fell out of the band after a fortnight would
// go quiet precisely as it got worse.
//
// THREE BANDS, and the split at 2 is what makes them three: today, tomorrow and
// anything overdue are `urgent`, the rest of the week is `soon`, the week after
// that is `later`. Two bands were a red and an orange; a third is what a red /
// orange / yellow ramp needs, and it is the same ramp @rheo/rookery-todos colours
// a todo's priority with.
//
// THE CUTOFFS ARE FIXED at 7 and 14 and take no arguments. What a project retunes
// is the COLOUR — the `--rookery-heat-*` ramp in this package's stylesheet —
// because a palette is a property of a page and "urgent" is a property of a
// deadline.
#let countdown(days) = {
  if days == none { return none }
  if days > 14 { return none }
  if days < -1 { return (text: str(-days) + " days ago", level: "urgent") }
  if days == -1 { return (text: "yesterday", level: "urgent") }
  if days == 0 { return (text: "today", level: "urgent") }
  if days == 1 { return (text: "tomorrow", level: "urgent") }
  if days <= 7 { return (text: "in " + str(days) + " days", level: "soon") }
  (text: "in " + str(days) + " days", level: "later")
}

// ---- Ladder-free by design ------------------------------------------------
//
// There is no `is-settled` here, and no `next-stage`. Whether `accepted` ENDS a
// process or is the middle of it depends on a vocabulary this package must not
// own: `accepted` ends a conference submission and is a transit rung for a
// journal, and `offered` ends a job application. Those functions take a ladder
// as a parameter and live alongside these — see `ladder.typ`.
