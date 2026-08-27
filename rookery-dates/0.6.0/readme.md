# @rheo/rookery-dates

A dated LOG for [`@rheo/rookery`](../../rookery) notes, contributed as tag
metadata.

```typst
#import "@rheo/rookery:0.6.0": idea
#import "@rheo/rookery-dates:0.6.0": dates

#idea("ship", tags: dates(deadline: datetime(year: 2026, month: 9, day: 1)))[
  Cut the release.
]
```

## 0.6.0 — one log instead of two slots

**Breaking.** `date-scheduled` and `date-deadline` are gone as tag KEYS. There is
one key now, `date-log`, holding an ordered array of dated events, and those two
are RESERVED STAGE NAMES inside it.

Until 0.6.0 this package owned two slots and both were PLANS — the org-mode pair.
A log is the third thing: what happened, and when. Org-mode's `LOGBOOK` to those
two. One mechanism then carries arbitrarily complex lifecycles — a todo's
scheduled/activated/closed, a submission's deadline/submitted/review/accepted —
without this package naming any of those states itself.

**Nothing you call changed its signature.** `dates(deadline: d)` writes a
`deadline` entry; `deadline-of(t)` reads it back. That was the point of doing it
this way: `is-overdue`, `is-upcoming`, `@rheo/rookery-todos`' readiness check and
every existing call site kept working with no edit at all. What you gain is
everything below.

- `dates(log: (..))` takes any vocabulary you like.
- `dated(mint)` decorates a minting function so dates become named arguments.
- `log-of` / `stage-of` / `next-of` / `entered-of` / `timeline` read it back.
- `is-settled` / `rung` / `next-stage` derive from a ladder YOU supply.
- `as-stage` / `as-date` / `as-rung` project it onto an `#ideas()` row.
- `updated-of` is derived from the log now, because rookery 0.6.0 removed its own
  `updated` field.

Migrating: if you wrote `dates(scheduled:)` or `dates(deadline:)` and read them
back with `scheduled-of`/`deadline-of`, there is nothing to do. If you hardcoded
the string `"date-deadline"` anywhere, that key no longer exists — use
`deadline-of`, or `stage-date(t, DEADLINE-STAGE)`.

## How it composes

`dates(..)` returns a TAG FRAGMENT — a plain dictionary you merge into a
rookery `tags:` argument. That is the entire write surface.

The CORE of this package does not import `@rheo/rookery`, and `@rheo/rookery`
knows nothing about this package. A tag fragment is just a dictionary, so
composition needs no import relationship in either direction: any package, and any
hand-written `#idea`, can use it. `dated(mint)` keeps that true for the decorator
too, by taking the minting function as an argument; the single `dated-idea`
binding is the one line here that imports rookery. Rookery accepts a dictionary
for `tags:` directly, so composing with ordinary tags is dictionary merge:

```typst
#idea("ship", tags: (phd: none, urgent: none) + dates(deadline: d))[...]
```

An omitted date emits **no key at all**, not a key valued `none`. A `none`-valued
key is a *flat* tag — it renders as a pill and reads as a
plain label — so `dates()` with nothing to say stays silent. `dates()` with no
arguments is `(:)`, which merges into anything and changes nothing.

## The key, and the log inside it

One key: `date-log`, holding an array of `(stage: <str>, on: <datetime>)`,
**sorted by date**.

It is namespaced with a `date-` prefix per rookery's key convention: a tag key
becomes a CSS class fragment (`.idea-tag-date-log`, which you can style or theme
like any other tag), and a bare `log` is a generic name two packages could both
reach for and silently collide over. Because it is a *valued* tag it renders no
pill, but it is still presence-filterable by key — `#window(tags: "date-log")`
finds every note carrying any dates at all.

```typst
#idea("wolf", tags: dates(
  deadline: datetime(year: 2026, month: 11, day: 1),
  log: (
    submitted:         datetime(year: 2026, month: 10, day: 28),
    longlisted:        datetime(year: 2026, month: 12, day: 15),
    "first-interview": datetime(year: 2027, month: 1, day: 20),
  ),
))[...]
```

**Sorted at write time**, once, rather than in every reader. Two consequences,
both wanted: the stored value is unambiguous, and the order you WROTE the entries
in cannot lie about the timeline. Ties keep the written order — MEASURED on typst
0.15.x, a dictionary preserves insertion order, so that is sound; and because
`array.sorted` is not documented as stable, the tie is held by decorating each
entry with its written index rather than by trusting the sort.

**Entries may be FUTURE-DATED, and that is the ordinary shape of a plan** rather
than an edge case. A deadline is by definition a date that has not arrived; an
interview is booked before it is held; a decision is promised before it comes. So
the log doubles as a calendar, and "what stage is this at" means "the last thing
that has actually happened" — which is why `stage-of` takes a `today:` and
`deadline-of` does not.

### Three reserved stages, and no more

| stage | from | exported as |
| --- | --- | --- |
| `scheduled` | `dates(scheduled: ..)` | `SCHEDULED-STAGE` |
| `deadline` | `dates(deadline: ..)` | `DEADLINE-STAGE` |
| `closed` | your own `log:` | `CLOSED-STAGE` |

Everything else in a log is the CONSUMER's vocabulary. `@rheo/rookery-todos` owns
`activated`; a submission tracker owns `submitted`/`review`/`accepted`. The three
above are exported so a consumer names them without hardcoding a string — the
same reason the old key constants were.

A stage name must be alphanumerics and interior hyphens only, because it has to
survive being a CSS class fragment and an HTML attribute value, which is where a
consumer's view will put it.

### `dated(mint)` — dates as named arguments

```typst
#import "@rheo/rookery:0.6.0": idea, tagged-idea
#import "@rheo/rookery-dates:0.6.0": dated, dated-idea

#dated-idea("ship", deadline: d)[Cut the release.]

// or put your own tag family on top:
#let submission = dated(tagged-idea("submission"))
#submission("wolf", deadline: d, log: (submitted: d2))[...]
```

A DECORATOR rather than a finished constructor, and that is what makes the
layering work: a constructor has no seam for a consumer to add its own tag family,
and both `@rheo/rookery-todos`' `#todo` and a project's own `#submission` need
one. It also keeps this package's core import-free — the decorator receives its
constructor as an ARGUMENT, so there is nothing to import. `dated-idea` is the one
line here that imports rookery, and it exists only so the common case reads as one
name rather than two.

Your own `tags:` is kept whole and the date fragment folded in on top. All four
shapes rookery accepts for `tags:` are normalized, so `tags: "phd"` works
alongside `deadline:`.

## Reading dates back

```typst
#context {
  let t = tag-data().at("idea:ship")
  deadline-of(t)    // -> datetime or none
  scheduled-of(t)   // -> datetime or none
}
```

Both take the tag DICTIONARY rather than a note name, so they stay pure
functions and need no registry read of their own. Walking the corpus is one
`#tag-data()` and these per row.

### The log's own readers

```typst
log-of(t)                  // -> ((stage: "submitted", on: ..), ..) or ()
stage-date(t, "longlisted")// -> that entry's date; the LATEST where it repeats
has-stage(t, "offered")    // -> bool
entered-of(t)              // -> the FIRST entry's date — "in flight since"
```

`log-of` returns `()` rather than `none` when absent, so you can map over it
without a guard: an empty log and no log are the same question.

`stage-date` returns the LATEST where a stage appears more than once. A todo
deferred and then re-deferred has two `scheduled` entries, and "deferred until"
means the current deferral rather than the first one ever set.

These need no reference date. The ones that do are under "Derived predicates".

### created and updated

`created-of(entry)` takes an `#ideas()` ROW and reads rookery core's own
`created` field.

**`created` is deliberately NOT in the log.** Rookery already resolves it from
`#idea(created:)`, then the document's `#set document(date:)`, then nothing, and
publishes it on every `#ideas()` row — a second copy here could only drift from
the first. It also stays a ROW field rather than a tag value for a load-bearing
reason: rookery keeps tag values off rows, so anything in the tag dictionary — the
log included — costs a `#tag-data()` walk to reach, and a date every consumer
filters and sorts by should be free.

`updated-of(entry, tags)` is DERIVED: the log's last entry where there is one,
else `created`. Note the extra parameter — the answer now comes from two sources.
Rookery 0.6.0 removed its own `updated` field, on the grounds that a
hand-maintained "last touched" is a second date the author has to remember and one
that can contradict what actually happened to the note. For the first time this
function means something the note itself knows.

`timeline(entry, tags)` puts the two together for display:

```typst
timeline(row, t)
// -> ((stage: "created", on: ..), (stage: "deadline", on: ..), ..)
```

`created` LEADS and is not written into the log — one store per fact, one view
over both. Writing it in would give the note two copies of its creation date that
could drift apart.

## Derived predicates

```typst
#let NOW = datetime(year: 2026, month: 8, day: 25)

is-overdue(t, today: NOW)                    // deadline strictly before NOW
is-upcoming(t, today: NOW, within: 7)        // deadline in [NOW, NOW+7]
is-scheduled-now(t, today: NOW)              // scheduled on or before NOW
```

`is-overdue` is *strictly* before, so a deadline falling on the reference date
is due rather than overdue — the day is not over. `is-upcoming` is inclusive at
both ends and excludes anything already overdue, so a row belongs to exactly one
of the two.

`is-scheduled-now` is `false` for a note with no `scheduled` entry, which reads
as "not scheduled" rather than "scheduled for now". A consumer wanting "nothing
is deferring this" asks `scheduled-of(t) == none or is-scheduled-now(t)`.

### The log's predicates

```typst
stage-of(t, today: NOW)          // last entry ON OR BEFORE NOW — what has happened
stage-on(t, today: NOW)          // that entry's date
next-of(t, today: NOW)           // first entry AFTER NOW — the next appointment
days-at-stage(t, today: NOW)     // whole days at the current stage
days-in-flight(t, today: NOW)    // whole days since the first entry
```

Each takes a `today:` because entries may be future-dated. `stage-of` is `none`
for an empty log AND for a log whose every entry is still to come — an open call
nothing has been sent to — and deliberately does not distinguish them; ask
`log-of(t).len()` if you need to.

`next-of` is what gives a view a real "next appointment" column: a booked
interview or a promised decision is an ordinary entry, and this finds it.

`days-in-flight` measures from `entered-of` rather than from the first PAST entry,
so a note whose log opens with a future deadline reports a NEGATIVE number rather
than none. That reads correctly: it is not in flight yet, and by how much.

### Ladders: `is-settled`, `rung`, `next-stage`

`accepted` ENDS a conference submission and is the MIDDLE of a journal's ladder.
`offered` ends a job application. No package can know that, so the vocabulary is
a PARAMETER and only the reasoning lives here — the same split this package
already makes for `today:`.

```typst
#let JOB = (
  transit:  ("submitted", "longlisted", "first-interview", "finalist"),
  terminal: ("offered", "rejected", "declined", "dropped", "missed"),
)

is-settled(t, ladder: JOB, today: NOW)   // current stage is terminal
rung(t, ladder: JOB, today: NOW)         // 0-based index in `transit`
next-stage(t, ladder: JOB, today: NOW)   // the next transit rung, or none
```

`transit` is ordered by progress; `terminal` is unordered and its MEMBERSHIP is
what settles a note. `rung` returns `transit.len()` for anything terminal, so
finished work sorts past everything still moving, and it is an INTEGER so it drops
straight into a sort key or a projection.

`next-stage` is an EXPECTATION, not a promise — nothing here knows a process will
advance, only what the ladder says would come next if it did. Render it as such.

An UNKNOWN stage is not an error: `rung` is `none` and `is-settled` is `false`. A
vocabulary grows, and a note written against tomorrow's ladder must degrade rather
than fail the build of an unrelated page. A name appearing in BOTH arrays IS
refused, by name, because that is the one mistake that would make `is-settled` and
`rung` disagree about the same note silently.

`ladder:` has no default. A default ladder would be a vocabulary, which is the one
thing this package must not own.

### Projecting the log onto a row: the `as-*` extractors

Rookery keeps tag values off `#ideas()` rows, so a log is reachable only through
`#tag-data()` — and `tag-index`'s `(from: ..)` form is the way back on. These are
the functions to hand it:

```typst
#import "@rheo/rookery:0.6.0": tag-index
#import "@rheo/rookery-dates:0.6.0": (
  DEADLINE-STAGE, as-date, as-days-in-flight, as-rung, as-settled, as-stage,
)

#let INDEX = tag-index((
  stage:    (from: as-stage(today: NOW)),
  deadline: (from: as-date(DEADLINE-STAGE)),
  rung:     (from: as-rung(ladder: JOB, today: NOW)),
  settled:  (from: as-settled(ladder: JOB, today: NOW)),
  waiting:  (from: as-days-in-flight(today: NOW)),
))
```

Each is a partially-applied factory rather than a function called with the tag
dictionary, which is what lets a spec read as data. A date comes back as a
zero-padded `[year][month][day]` STRING, never a `datetime`: rookery's scalar
assert would refuse the datetime, and the string sorts lexically in date order — so
a projected date is a free sort key.

Dates are compared as zero-padded `[year][month][day]` strings, which sidesteps
the question of how `datetime` orders as a sort key — the same technique rookery
uses in its own id sorting.

## `#log-view` — the log as a vertical rail

The one function here that draws something, and the reason this package ships a
stylesheet at all.

```typst
#import "@rheo/rookery-dates:0.6.0": log-view

#context log-view(row, tag-data().at(row.id), today: NOW)
```

```
●  28 Oct 2026   submitted
│
●  15 Nov 2026   under-review
│
●  20 Jan 2027   revise-resubmit
├───────────────────────────────  today
│
○  03 Mar 2027   resubmitted
```

**A dot per event, FILLED for what has happened and HOLLOW for what is booked**,
with a `today` divider between them. That split is the main thing a log knows and
the reason the view exists: entries may be future-dated by design — a deadline has
not arrived, an interview is booked before it is held — so a view that treats
every entry alike throws the distinction away.

The divider is emitted **only where there is something on both sides of it**. A
rail whose every event is past does not need a line saying where now is.

`created` leads the rail, from rookery's own field via `timeline` — so the record
starts when the note was written and the log is what happened to it since.

### With a ladder it becomes a progress indicator

`ladder:` defaults to `none` and the two registers are visibly different:

| call | what you get |
| --- | --- |
| `log-view(row, tags, today: NOW)` | a RECORD — the log's own events, nothing more |
| `log-view(row, tags, today: NOW, ladder: JOURNAL)` | a PROGRESS indicator — the events, then the unreached rungs, undated and greyed |

An unreached rung is an **expectation, never a promise**: nothing here knows a
process will advance, only what the ladder says would come next if it did. The
class is `date-log-expected` and the stylesheet dots its outline for that reason.

### Same-day events show their times

Two events on one day would otherwise render the same date twice with a rule
between them, saying nothing. Where an event shares its date with another, both
show `HH:MM` beside it:

```
●  27 Aug 2026 15:00   activated
●  27 Aug 2026 16:00   closed
```

Guarded on `.hour() != none`, because a date-only entry cannot be asked for its
time — MEASURED, `.display("[hour]")` on one panics with *"failed to format
datetime (insufficient information)"*.

**Has-it-happened is compared at the coarser of the two precisions.** A bare
`today:` — which is what a site passes, since a reference date is a date — means
the whole DAY, so an event timed 16:00 on that date has happened. Only when both
the event and the reference carry a time does the clock decide. Ordering is
different and uses full precision, so a date-only `deadline` still precedes a
timed event during that day.

### Styling it

Every class is a published contract: `.date-log` on the list, `.date-log-event`
per row plus exactly one of `.date-log-past` / `.date-log-future` /
`.date-log-expected`, `.date-log-stage` and `.date-log-when` inside, and
`.date-log-today` on the divider. Five custom properties theme it without
overriding a rule — `--date-log-line`, `--date-log-fg`, `--date-log-muted`,
`--date-log-dot`, `--date-log-gap`.

### What it deliberately is not

A horizontal track (crowds past four events, and gives a long stage name nowhere
to go), a definition list (says nothing about order, or about whether an event has
happened), an inline sparkline (a different component, for a table of many notes),
and **no durations of any kind** — no "126 days in flight", no per-event gaps. The
reader can subtract, and a computed interval resting on a stand-in date looks more
precise than it is.

On a paged or EPUB target there is no rail to draw, so the same events render as
an ordinary list.

## Every date is author-supplied, and here is why

**Typst has no wall clock, and this package will not pretend otherwise.**

`datetime` carries no time of day at all — MEASURED, `datetime.today().hour()`
is `none`. Worse, `datetime.today()` returns **1980-01-01** wherever
`SOURCE_DATE_EPOCH` is set for reproducible builds, which is exactly what this
repository's own devShell exports (`SOURCE_DATE_EPOCH=315532800`, MEASURED at
typst 0.15.1). It does not error. It answers wrongly and the build succeeds.

So:

- Nothing here is auto-stamped. You write the dates.
- **No function in this package calls `datetime.today()`**, and none should.
- Every predicate takes an explicit `today:`. With none given it falls back to
  the document's own `#set document(date: ..)` — and MEASURED, a document with
  no date yields `auto`, not `none`, so that case is tested for explicitly.
- With neither available it **panics**, naming the problem and both fixes.
  Defaulting to some arbitrary date would make "overdue" a silent lie, which is
  the failure mode this whole section exists to refuse.

If you generate notes programmatically, have the generator take `today()` from
its own environment and write the resulting literal into the `.typ`.

## Requirements

- `@rheo/rookery` 0.6.0, for `created` on an `#ideas()` row and for `tag-index`.
  The CORE of this package imports it not at all — a tag fragment is a plain
  dictionary, and `dated(mint)` takes its constructor as an argument — but the
  one-line `dated-idea` binding does.
- No build step and no JavaScript. `typst.toml`'s `entrypoint` points straight at
  `src/`, so an edit takes effect immediately. It DOES ship one CSS file now —
  `src/rookery-dates.css`, for `#log-view` below — inside
  `@layer rookery-dates`, so an unlayered rule in your own stylesheet beats it
  whatever the specificity.

## Development

```sh
cd rookery-dates/0.6.0
just test
```
