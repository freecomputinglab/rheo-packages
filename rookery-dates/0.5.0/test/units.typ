// Unit fixture for @rheo/rookery-dates. Run with `just test` from
// `rookery-dates/0.5.0`. There is no runner and no JS: an `assert` that fails
// fails the compile with a line number, and a passing compile is the green
// light — the same shape `@rheo/rookery` and `@rheo/feeds` use.

#import "/src/lib.typ": *

#let d(y, m, dd) = datetime(year: y, month: m, day: dd)
#let NOW = d(2026, 8, 25)

// ---- dates() — an omitted date emits NO KEY -------------------------------
// Not a key with value `none`: under rookery 0.5.0 a `none`-valued key is a
// FLAT tag and renders as a pill, so a silent `dates()` must stay silent.
#assert.eq(dates(), (:))
#assert.eq(dates(deadline: d(2026, 9, 1)), ("date-deadline": d(2026, 9, 1)))
#assert.eq(dates(scheduled: d(2026, 9, 1)), ("date-scheduled": d(2026, 9, 1)))
#assert.eq(dates(scheduled: d(2026, 1, 2), deadline: d(2026, 3, 4)).keys().len(), 2)

// Keys are namespaced, because a key becomes a `.idea-tag-<key>` CSS class and
// a bare `deadline` is a name two packages would both reach for.
#assert.eq(SCHEDULED-KEY, "date-scheduled")
#assert.eq(DEADLINE-KEY, "date-deadline")

// Merges into an ordinary tag dictionary without disturbing it.
#assert.eq(
  (phd: none) + dates(deadline: d(2026, 9, 1)),
  (phd: none, "date-deadline": d(2026, 9, 1)),
)

// ---- readers ---------------------------------------------------------------
#assert.eq(deadline-of(dates(deadline: d(2026, 9, 1))), d(2026, 9, 1))
#assert.eq(deadline-of((:)), none)
#assert.eq(scheduled-of(dates(scheduled: d(2026, 9, 1))), d(2026, 9, 1))
#assert.eq(scheduled-of((phd: none)), none)

// created/updated come from ROOKERY CORE's own row fields, not from a second
// copy stored here.
#assert.eq(created-of((minted: d(2026, 1, 1), updated: d(2026, 2, 2))), d(2026, 1, 1))
#assert.eq(updated-of((minted: d(2026, 1, 1), updated: d(2026, 2, 2))), d(2026, 2, 2))
#assert.eq(created-of((:)), none)

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
