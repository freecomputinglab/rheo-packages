// The tag fragment: turning `scheduled:`/`deadline:` into tag-dictionary keys.
//
// This is the package's whole write surface. It builds a plain dictionary, and
// the caller merges it into a rookery `tags:` argument — no `#idea` wrapper, no
// import of @rheo/rookery, nothing for rookery to know about.

// The two keys this package owns. NAMESPACED with a `date-` prefix, per the
// rookery key convention: a tag key becomes a CSS class fragment
// (`.idea-tag-date-deadline`), and a bare `deadline` would be a generic name
// two packages could both reach for and silently collide over.
//
// Exported so a consumer can name them without hardcoding a string — and so
// @rheo/rookery-todos, which reads deferral off `date-scheduled`, cannot drift
// from what this package writes.
#let SCHEDULED-KEY = "date-scheduled"
#let DEADLINE-KEY = "date-deadline"

// A tag fragment carrying whichever dates were given:
//
//   #idea("ship", tags: dates(deadline: datetime(year: 2026, month: 9, day: 1)))[..]
//
// MERGE IT THROUGH `tags:`. Rookery 0.5.0 accepts a dictionary there directly,
// so composing with ordinary tags is dictionary merge:
//
//   tags: (phd: none) + dates(deadline: d)
//
// An OMITTED date emits NO KEY AT ALL rather than a key with value `none`.
// That distinction is load-bearing under rookery 0.5.0: a key whose value is
// `none` is a FLAT tag — it renders as a pill and reads as a plain label — so
// `dates()` with nothing to say must stay silent rather than stamp two
// meaningless pills on every note that calls it. `dates()` with no arguments
// is `(:)`, which merges into anything and changes nothing.
//
// Values are Typst `datetime` objects, asserted below. A string date would
// compare lexically by accident and sort correctly by luck; the assert exists
// so a project finds that out at build time rather than in a wrong ordering.
//
// NOTHING IS AUTO-STAMPED HERE, and no default reaches for the clock. See this
// package's `src/lib.typ` header: `datetime.today()` returns 1980-01-01 under a
// reproducible-build `SOURCE_DATE_EPOCH` and does not error while doing it, so
// a date that was not written by the author is a date that is silently wrong.
#let dates(scheduled: none, deadline: none) = {
  assert(
    scheduled == none or type(scheduled) == datetime,
    message: "@rheo/rookery-dates: `scheduled` must be none or a datetime — got "
      + repr(scheduled),
  )
  assert(
    deadline == none or type(deadline) == datetime,
    message: "@rheo/rookery-dates: `deadline` must be none or a datetime — got "
      + repr(deadline),
  )
  let out = (:)
  if scheduled != none { out.insert(SCHEDULED-KEY, scheduled) }
  if deadline != none { out.insert(DEADLINE-KEY, deadline) }
  out
}
