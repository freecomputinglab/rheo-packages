// The tag fragment: turning a note's dates into ONE tag-dictionary key.
//
// This is the package's whole write surface, and as of 0.6.0 it writes a LOG
// rather than two independent slots. It still builds a plain dictionary for the
// caller to merge into a rookery `tags:` argument, and `dated()` at the bottom
// wraps any minting function for callers who would rather pass dates as named
// arguments.

// ---- The one key, and the stage names this package reserves ---------------
//
// NAMESPACED with a `timeline-` prefix, per the rookery key convention: a tag key
// becomes a CSS class fragment (`.idea-tag-timeline-log`), and a bare `log` would be
// a generic name two packages could both reach for and silently collide over.
#let LOG-KEY = "timeline-log"

// WHAT A LOG IS, and why it replaced the two slots this package used to own.
//
// `date-scheduled` and `date-deadline` were both PLANS — the org-mode pair, as
// this package's `src/lib.typ` header calls them. A log is the third thing: an
// ordered record of dated events, org-mode's LOGBOOK to those two. One mechanism
// then carries arbitrarily complex lifecycles — a todo's
// scheduled/activated/closed, a submission's deadline/submitted/review/accepted —
// without this package naming any of those states itself.
//
// THE LOG IS THE ONLY STORE. `date-scheduled` and `date-deadline` are gone as tag
// KEYS and are reserved STAGE NAMES inside the log instead. `entries(deadline: d)`
// writes an entry named "deadline"; `deadline-of(tags)` in `read.typ` reads that
// entry back. Every existing consumer therefore keeps working unchanged —
// @rheo/rookery-todos' readiness check, `is-overdue`, `is-upcoming`,
// `todos-stale` — because the READERS kept their signatures while the storage
// underneath them changed.
//
// THREE RESERVED NAMES, and only three. Everything else in a log is the
// consumer's own vocabulary: @rheo/rookery-todos owns `activated`, a submission
// tracker owns `submitted`/`review`/`accepted`. Exported so a consumer can name
// them without hardcoding a string, the same reason the old key constants were
// exported.
#let SCHEDULED-STAGE = "scheduled"
#let DEADLINE-STAGE = "deadline"
#let CLOSED-STAGE = "closed"

// A stage name has to survive being a CSS class fragment and an HTML attribute
// value, because that is where a consumer's view will put it. Alphanumerics and
// interior hyphens, the same shape rookery's own ids take.
#let _assert-stage(name) = {
  assert(
    type(name) == str and name.match(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$")) != none,
    message: "@rheo/rookery-timeline: a log stage name must be alphanumerics and "
      + "interior hyphens only, so it is usable as a CSS class fragment and an "
      + "HTML attribute value — got "
      + repr(name),
  )
}

// Dates compared as zero-padded STRINGS rather than as `datetime`s — the same
// device `when.typ`'s `_stamp` uses, and rookery's own `_sort-ids`. Same width
// every time, so string order is date order, and the question of how `datetime`
// orders as a sort key never arises.
//
// TIME OF DAY IS PART OF THE KEY where an entry has one, because a log that
// ignored it would order two same-day events by the sequence they were WRITTEN and
// call that a timeline. A todo activated at 15:00 and closed at 16:00 on one day
// is in the right order because the clock says so, not because of how it was
// typed.
//
// THE `none` BRANCH IS REQUIRED, not defensive, and it is why this cannot be one
// `display` call. MEASURED on typst 0.15.1: `.display("[hour]")` on a DATE-ONLY
// datetime panics with "failed to format datetime (insufficient information)", and
// `.hour()` on one is `none`. A date-only entry therefore sorts as the START of
// its day — which is also the right reading, since a `deadline` given as a bare
// date should precede a timed event that happened during it.
// The DAY alone, which is a different question and has its own callers: the
// `as-date`/`as-entered` projections in `index.typ` feed a day column in a
// consumer's table and a `tag-index` field that must stay a fixed 8 characters.
// Widening those to 14 would change what a projected date IS.
#let _day-of(d) = d.display("[year][month][day]")

#let _stamp-of(d) = {
  let day = _day-of(d)
  if d.hour() == none { day + "000000" } else { day + d.display("[hour][minute][second]") }
}

// ---- _log-entries — the normalized, sorted array --------------------------
//
//   _log-entries((submitted: d1, longlisted: d2, "first-interview": d3))
//     -> ((stage: "submitted", timestamp: d1), (stage: "longlisted", timestamp: d2), ..)
//
// SORTED BY DATE HERE, once, rather than in every reader. Two consequences, both
// wanted: the stored value is unambiguous, and the order it was WRITTEN in cannot
// lie about the timeline.
//
// TIES KEEP THE WRITTEN ORDER. MEASURED on typst 0.15.x: a dictionary preserves
// insertion order — `(zebra: 1, apple: 2, "first-interview": 3, banana: 4).keys()`
// comes back in written order, not sorted — so two entries on one date resolve to
// the sequence the author wrote them in. `array.sorted` is NOT documented as
// stable, so that tie is held by decorating each row with its written index and
// sorting on the pair, rather than by trusting the sort to preserve it.
// ---- An entry, and what it may carry --------------------------------------
//
// TWO WRITE FORMS, and the shorthand is the common one:
//
//   closed: datetime(..)                    a bare date
//   closed: (
//     timestamp: datetime(..),              reserved, required
//     note: [Landed as .. ],                reserved, rendered by #timeline-view
//     estimated: true,                      FREE — yours, stored and ignored here
//   )
//
// WHY AN ENTRY NEEDS CONTENT OF ITS OWN. Prose about an event kept ending up on
// the NOTE, where it reads as a claim about the whole thing. In the project this
// was built for, seven submission bodies carried a sentence that belonged to one
// event — "Offered and accepted, for autumn 2026", "Dropped — not a good fit",
// "Read and let go" — and one file opened with a FOURTEEN-LINE comment explaining
// per-entry date provenance at file level, invisible on the built site, because no
// entry could carry it.
//
// `timestamp` and `note` are reserved; every other key is the consumer's, stored
// verbatim and ignored by everything here. That is what lets per-entry provenance
// exist without this package needing to know what it means.
//
// A `note` CAN NEVER BE PROJECTED. rookery's `tag-index` asserts scalars, because
// `json.encode` of content silently emits a structural blob — so a note is
// Typst-side rendering only. The log already could not ride on an `ideas()` row,
// so this costs nothing new, but it is worth saying rather than discovering.
#let _norm-entry(stage, given) = {
  _assert-stage(stage)
  let e = if type(given) == datetime {
    (timestamp: given)
  } else if type(given) == dictionary {
    assert(
      "timestamp" in given,
      message: "@rheo/rookery-timeline: log stage `"
        + stage
        + "` is a dictionary with no `timestamp`. An entry without a date is not an "
        + "entry — give `timestamp: datetime(..)`, or write the bare datetime "
        + "instead of a dictionary.",
    )
    given
  } else {
    panic(
      "@rheo/rookery-timeline: log stage `"
        + stage
        + "` must be a datetime, or a dictionary carrying `timestamp:` — got "
        + repr(given)
        + ".",
    )
  }
  assert(
    type(e.timestamp) == datetime,
    message: "@rheo/rookery-timeline: log stage `"
      + stage
      + "`'s `timestamp` must be a datetime — got "
      + repr(e.timestamp)
      + ". Every date here is author-supplied; there is no clock to stamp one from.",
  )
  // Asserted because it reaches `html.elem` as a body in `#timeline-view`, where a
  // wrong type fails somewhere unrecognisable rather than here.
  if "note" in e {
    assert(
      type(e.note) in (content, str),
      message: "@rheo/rookery-timeline: log stage `"
        + stage
        + "`'s `note` must be content or a string — got "
        + repr(type(e.note))
        + ".",
    )
  }
  (..e, stage: stage)
}

// Sorted by `timestamp`, ties held by the written index — see `_stamp-of` above for
// why the key carries the time of day where an entry has one. The index is dropped
// on the way out: it exists to hold a tie, not to be read back.
#let _log-entries(entries) = {
  let rows = entries.pairs().enumerate().map(p => {
    let (i, pair) = p
    let (stage, given) = pair
    (i: i, .._norm-entry(stage, given))
  })
  rows.sorted(key: r => (_stamp-of(r.timestamp), r.i)).map(r => {
    let out = r
    let _ = out.remove("i")
    out
  })
}

// ---- entries(..) — the tag fragment ----------------------------------------
//
//   #idea("ship", tags: entries(deadline: datetime(year: 2026, month: 9, day: 1)))[..]
//   #idea("wolf", tags: entries(deadline: d, log: (submitted: d2, rejected: d3)))[..]
//
// MERGE IT THROUGH `tags:`. Rookery accepts a dictionary there directly, so
// composing with ordinary tags is dictionary merge:
//
//   tags: (phd: none) + entries(deadline: d)
//
// `scheduled:` and `deadline:` stay named arguments even though they are now log
// stages, because they are the two a note most often has and because every
// existing call site writes them that way. They fold into the same log the `log:`
// argument builds, so all three arguments have ONE destination.
//
// AN OMITTED DATE EMITS NO KEY AT ALL rather than a key with value `none`. That
// distinction is load-bearing: a key whose value is `none` is a FLAT tag — it
// renders as a pill and reads as a plain label — so `entries()` with nothing to say
// must stay silent rather than stamp a meaningless pill on every note that calls
// it. `entries()` with no arguments is `(:)`, which merges into anything and
// changes nothing.
//
// NOTHING IS AUTO-STAMPED HERE, and no default reaches for the clock. See this
// package's `src/lib.typ` header: `datetime.today()` returns 1980-01-01 under a
// reproducible-build `SOURCE_DATE_EPOCH` and does not error while doing it, so a
// date that was not written by the author is a date that is silently wrong.
//
// `created` IS NOT IN THE LOG. Rookery core resolves and stores it (from
// `#idea(created:)`, else the document's own date), and `read.typ` reads it off an
// `ideas()` row rather than keeping a second copy that could only disagree.
#let entries(scheduled: none, deadline: none, log: none) = {
  assert(
    scheduled == none or type(scheduled) == datetime,
    message: "@rheo/rookery-timeline: `scheduled` must be none or a datetime — got " + repr(scheduled),
  )
  assert(
    deadline == none or type(deadline) == datetime,
    message: "@rheo/rookery-timeline: `deadline` must be none or a datetime — got " + repr(deadline),
  )
  let entries = (:)
  if scheduled != none { entries.insert(SCHEDULED-STAGE, scheduled) }
  if deadline != none { entries.insert(DEADLINE-STAGE, deadline) }
  if log != none {
    assert(
      type(log) == dictionary,
      message: "@rheo/rookery-timeline: `log` takes a dictionary of stage-name -> datetime — got " + repr(log),
    )
    for (stage, on) in log.pairs() {
      // A stage given twice is a contradiction, not a merge: which of the two
      // dates the author meant is unknowable, and picking one silently would put
      // a wrong date in a timeline that reads as authoritative.
      assert(
        stage not in entries,
        message: "@rheo/rookery-timeline: stage `"
          + stage
          + "` was given twice — once as the `"
          + stage
          + ":` argument and once inside `log:`. Give it once.",
      )
      entries.insert(stage, on)
    }
  }
  if entries.len() == 0 { return (:) }
  ((LOG-KEY): _log-entries(entries))
}

// ---- dated(mint) — the decorator -----------------------------------------
//
//   #let dated-note = dated(tagged-idea("note"))
//   #dated-note("ship", deadline: d, log: (submitted: d2))[..]
//
// TAKES A MINTING FUNCTION and returns one that also accepts this package's date
// arguments. A DECORATOR rather than a finished constructor, and that is the whole
// reason the layering works: a constructor has no seam for a consumer to add its
// own tag family, and both @rheo/rookery-todos' `#todo` and a project's own
// `#submission` need to put a family of their own on top.
//
// It also keeps this package's core free of any import of @rheo/rookery — the
// decorator receives its constructor as an argument, so there is nothing to
// import. Only the one-line `dated-idea` convenience in `lib.typ` needs it.
//
// The caller's own `tags:` is kept whole and the date fragment folded in on top.
// All four shapes rookery accepts for `tags:` are normalized here (none, a bare
// string, an array, a dictionary), because a decorator that handled only a
// dictionary would break `#dated-note("x", tags: "phd", deadline: d)`.
#let _norm-tags(tags) = {
  if tags == none {
    (:)
  } else if type(tags) == str {
    ((tags): none)
  } else if type(tags) == dictionary {
    tags
  } else if type(tags) == array {
    tags.fold((:), (acc, t) => { acc.insert(t, none); acc })
  } else {
    panic(
      "@rheo/rookery-timeline: `tags` must be none, a string, an array of strings or a dictionary — got " + repr(tags),
    )
  }
}

#let dated(mint) = {
  assert(
    type(mint) == function,
    message: "@rheo/rookery-timeline: `dated` takes a minting FUNCTION — rookery's "
      + "`idea`, a `tagged-idea(..)` factory, or another decorated one. Got "
      + repr(mint),
  )
  (scheduled: none, deadline: none, log: none, tags: none, ..args) => mint(
    // Caller's own tags on the LEFT, this package's fragment on the right. The
    // two cannot collide by accident, since `timeline-log` is namespaced, and a
    // caller who wrote that key by hand meant to.
    tags: _norm-tags(tags) + entries(scheduled: scheduled, deadline: deadline, log: log),
    ..args,
  )
}
