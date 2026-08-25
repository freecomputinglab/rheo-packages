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
      message: "@rheo/rookery-dates: `today` must be a datetime — got " + repr(today),
    )
    return today
  }
  let d = document.date
  if d != auto and d != none { return d }
  panic(
    "@rheo/rookery-dates: this view needs a reference date and there is none. "
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
    message: "@rheo/rookery-dates: `within` must be a non-negative integer number "
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
