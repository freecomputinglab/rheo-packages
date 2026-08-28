# @rheo/rookery-timeline

A dated lifecycle log for [`@rheo/rookery`](../../rookery) notes, contributed as
tag metadata — the events, the ladders that order them, and the rail that draws
them.

```typst
#import "@rheo/rookery:0.6.0": idea
#import "@rheo/rookery-timeline:0.1.0": dates

#idea("ship", tags: entries(deadline: datetime(year: 2026, month: 9, day: 1)))[
  Cut the release.
]
```

## 0.1.0 — renamed from `@rheo/rookery-dates`

This package was `@rheo/rookery-dates` up to 0.5.0 (released) and 0.6.0
(unreleased). The rename is not cosmetic: `dates` named one field of what it now
owns, which is a note's **lifecycle** — an ordered sequence of dated entries, the
derivations over them (`stage-of`, `is-settled`, `rung`, `next-stage`), and
`#timeline-view`, the rail that draws them.

`rookery-states` was considered and declined. `deadline`, `scheduled` and `created`
are not states: a deadline is a date *attached to* a note, where `closed` is a state
the note is *in*. Those are the store's most-used reserved names, so `states` would
be misnamed for exactly them — and following that name honestly argues for moving
plans back out into their own keys, which is org-mode's split and this package's own
original design, undoing the unification 0.6.0 made deliberately. `timeline` covers
plans and events alike without claiming either is a state, and it is the word the
code had already reached for: `timeline(entry, tags)` is the reader that merges
rookery's `created` with the log.

### What moved, if you are coming from `rookery-dates`

The old package's name is written WITHOUT a colon before its version below, and
that is deliberate rather than sloppy: `just check-versions` greps for the
`@rheo/<pkg>:<x.y.z>` spec form and fails on one naming a version that is not in
this repo. `rookery-dates/` has been removed, so the spec form here — in prose
about what the package used to be called — would fail the lint. MEASURED: it did,
on this exact line.

| was | is |
| --- | --- |
| `@rheo/rookery-dates` 0.5.0 and 0.6.0 | `@rheo/rookery-timeline:0.1.0` |
| the `date-log` tag key | `timeline-log` |
| `dates(scheduled:, deadline:, timeline:)` | `entries(scheduled:, deadline:, timeline:)` |
| `log-view(..)` | `timeline-view(..)` |
| `src/rookery-dates.css`, `@layer rookery-dates` | `src/rookery-timeline.css`, `@layer rookery-timeline` |
| `.date-log`, `.date-log-event`, `--date-log-*` | `.timeline`, `.timeline-event`, `--timeline-*` |
| an entry's `on` field | `timestamp`, matching the write key |

Everything else keeps its name: `dated`, `dated-idea`, `timeline-of`, `stage-date`,
`has-stage`, `entered-of`, `deadline-of`, `scheduled-of`, `created-of`,
`updated-of`, `timeline`, `stage-of`, `stage-on`, `next-of`, `days-at-stage`,
`days-in-flight`, `is-settled`, `rung`, `next-stage`, the `as-*` extractors and the
three reserved stage constants. None of those was ever named after "dates".

### What the log is, and why there is one

`scheduled` and `deadline` used to be two independent tag keys and both were PLANS
— the org-mode pair. A log is the third thing: what happened, and when. Org-mode's
`LOGBOOK` to those two. One mechanism then carries arbitrarily complex lifecycles —
a todo's scheduled/activated/closed, a submission's
deadline/submitted/review/accepted — without this package naming any of those
states itself.

**Nothing you call has a changed signature.** `entries(deadline: d)` writes a
`deadline` entry; `deadline-of(t)` reads it back. That was the point of doing it
this way: `is-overdue`, `is-upcoming`, `@rheo/rookery-todos`' readiness check and
every existing call site kept working. What you gain is everything below.

## A skin over rookery

If you use plain rookery you import `idea`, `window` and the rest from rookery. If
you use this package you import those **same names from here** instead, and get
versions that take its date arguments:

```typst
#import "@rheo/rookery-timeline:0.1.0": idea, rookery, window
#show: rookery

#idea("ship", deadline: d, timeline: (submitted: d2))[Cut the release.]
#window("ship")   // rookery's own, unchanged
```

**Two names are overridden and everything else passes through.** `idea` is
`dated(rookery.idea)`; `tagged-idea` is the same decoration applied to the factory,
so a family you build over this skin — a `#submission`, a `#todo` — takes the date
arguments without wrapping anything itself. `window`, `ideas`, `tag-data`,
`note-href`, `rookery` and the rest are rookery's, untouched.

`dated-idea` is kept as an alias of `idea`, so call sites written before the skin
keep working.

**You can still import from rookery directly**, and nothing changes if you do. The
skin is opt-in: it is where a name comes FROM, not which package provides it.

## How it composes

`entries(..)` returns a TAG FRAGMENT — a plain dictionary you merge into a
rookery `tags:` argument. That is the entire write surface.

The CORE of this package does not import `@rheo/rookery`, and `@rheo/rookery`
knows nothing about this package. A tag fragment is just a dictionary, so
composition needs no import relationship in either direction: any package, and any
hand-written `#idea`, can use it. `dated(mint)` keeps that true for the decorator
too, by taking the minting function as an argument. Two things here do import
rookery: the one-line `dated-idea` binding, and `#upcoming`, which reads the note
REGISTRY through `ideas()` because it draws one row per note across a corpus and no
argument could hand it that corpus. Rookery accepts a dictionary
for `tags:` directly, so composing with ordinary tags is dictionary merge:

```typst
#idea("ship", tags: (phd: none, urgent: none) + entries(deadline: d))[...]
```

An omitted date emits **no key at all**, not a key valued `none`. A `none`-valued
key is a *flat* tag — it renders as a pill and reads as a
plain label — so `entries()` with nothing to say stays silent. `entries()` with no
arguments is `(:)`, which merges into anything and changes nothing.

## The key, and the log inside it

One key: `timeline-log`, holding an array of `(stage: <str>, timestamp: <datetime>, ..)`,
**sorted by date**.

It is namespaced with a `date-` prefix per rookery's key convention: a tag key
becomes a CSS class fragment (`.idea-tag-timeline-log`, which you can style or theme
like any other tag), and a bare `log` is a generic name two packages could both
reach for and silently collide over. Because it is a *valued* tag it renders no
pill, but it is still presence-filterable by key — `#window(tags: "timeline-log")`
finds every note carrying any dates at all.

```typst
#idea("wolf", tags: entries(
  deadline: datetime(year: 2026, month: 11, day: 1),
  timeline: (
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

### An entry may carry its own content

Two write forms, and the shorthand is the common one:

```typst
timeline: (
  activated: datetime(..),                  // a bare date
  closed: (
    timestamp: datetime(..),                // reserved, required
    note: [Landed as rookery's derived `label`.],  // reserved, rendered by the rail
    estimated: true,                        // FREE — yours, stored and ignored here
  ),
)
```

**Why an entry needs content of its own.** Prose about an event kept ending up on
the note, where it reads as a claim about the whole thing. In the project this was
built for, seven submission bodies carried a sentence that belonged to one event —
*"Offered and accepted, for autumn 2026"*, *"Dropped — not a good fit"*, *"Read and
let go"* — and one file opened with a **fourteen-line comment** explaining
per-entry date provenance at file level, invisible on the built site, because no
entry could carry it.

`timestamp` and `note` are reserved. **Every other key is yours**, stored verbatim
and ignored by everything here — which is what lets per-entry provenance
(`estimated: true`, a reference number, whatever) exist without this package
needing to know what it means.

Read back, an entry is `(stage:, timestamp:, ..your keys)`:

```typst
#let e = timeline-of(tags).first()
e.stage      // "closed"
e.timestamp  // datetime
e.note       // content, if it has one
```

**A `note` can never be projected.** rookery's `tag-index` asserts scalars, because
`json.encode` of content silently emits a structural blob — so a note is
Typst-side rendering only. The log already could not ride on an `#ideas()` row, so
this costs nothing new, but it is worth knowing rather than discovering.

Each refusal names the stage: a dictionary with no `timestamp`, a `timestamp` that
is not a datetime, a `note` that is neither content nor a string, and an entry that
is neither a datetime nor a dictionary.

### Three reserved stages, and no more

| stage | from | exported as |
| --- | --- | --- |
| `scheduled` | `entries(scheduled: ..)` | `SCHEDULED-STAGE` |
| `deadline` | `entries(deadline: ..)` | `DEADLINE-STAGE` |
| `closed` | your own `timeline:` | `CLOSED-STAGE` |

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
#import "@rheo/rookery-timeline:0.1.0": dated, dated-idea

#dated-idea("ship", deadline: d)[Cut the release.]

// or put your own tag family on top:
#let submission = dated(tagged-idea("submission"))
#submission("wolf", deadline: d, timeline: (submitted: d2))[...]
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
timeline-of(t)                  // -> ((stage: "submitted", on: ..), ..) or ()
stage-date(t, "longlisted")// -> that entry's date; the LATEST where it repeats
has-stage(t, "offered")    // -> bool
entered-of(t)              // -> the FIRST entry's date — "in flight since"
```

`timeline-of` returns `()` rather than `none` when absent, so you can map over it
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
`timeline-of(t).len()` if you need to.

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
what settles a note.

### A rung may name a FAMILY, so a stage can repeat

A rung ending in `-*` matches any stage sharing that prefix:

```typst
#let JOURNAL = (
  transit: ("submitted", "review-*", "accepted", "revision-*"),
  terminal: ("published", "rejected", "withdrawn"),
)
```

```typst
timeline: (
  submitted:   d1,
  "review-1":  d2,
  "review-2":  d3,   // as many as it takes
  accepted:    d4,
  "revision-1": d5,
  published:   d6,
)
```

**Why numbered names rather than a repeated key.** A Typst dict rejects a repeated
key outright — MEASURED, `(review: 1, review: 2)` fails to parse with *"duplicate
key: review"* — so a stage that can happen more than once has to be written with
distinct names, and the ladder has to be able to say "any review".

`review-*` matches `review-1` and `review-12`. It does **not** match `reviewer` —
the hyphen is part of the prefix — and does not match a bare `review` either, since
that names no occurrence and a lifecycle using the family form should say which one.

**One form, at one position.** A pattern is a prefix: no `*` in the middle, no bare
`*`, no character classes. Each addition would be another way for two rungs to
overlap, and a ladder whose rungs overlap is refused — including the non-obvious
case where a family in one array matches a name in the other.

`rung-name(pattern)` strips the `-*`, and everything that renders a rung goes
through it, so `#timeline-view` draws `review` and never `review *`. A family rung
also drops out of what is drawn as still-ahead once **any** of its occurrences has
happened: after two reviews, more are possible but no longer expected.

**No branching machinery is needed** for a lifecycle that forks. `submitted` → any
number of reviews → either `rejected`, or `accepted` → any number of revisions →
`published` is a linear ladder plus terminal membership, because a terminal stage
settles a note from any rung. The only cost is that `next-stage` after a review says
`accepted` when `rejected` is equally possible — and that reader is documented as an
expectation rather than a promise. `rung` returns `transit.len()` for anything terminal, so
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
#import "@rheo/rookery-timeline:0.1.0": (
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

## `#timeline-view` — the log as a vertical rail

One of the two functions here that draw something (`#upcoming` below is the other),
and the reason this package ships a stylesheet at all.

```typst
#import "@rheo/rookery-timeline:0.1.0": timeline-view

#context timeline-view(row, tag-data().at(row.id), today: NOW)
```

```
28.10.26  ●  submitted
          │  Sent the 500-word abstract, not the full paper.
15.11.26  ●  under-review
20.1.27   ●  revise-resubmit          <- current: bold
──────────┼──────────────────  today
 3.3.27   ○  resubmitted
```

**The line ends at the last filled dot.** A track running on past the last thing
that happened implies a record that continues where it stops. It is drawn as a
segment per past row, abutting to form one rule, with the last one cut short at its
own dot — CSS cannot ask a single element where the last past row is.

**The current stage is bold and every other is greyed.** Which matters most on a
laddered rail: with six reached rungs drawn, nothing otherwise says which one the
note is at.

The dates are a COLUMN in a left gutter, the line runs between the columns, and the
dots sit on it. Short form (`27.8.26`, with `HH:MM` appended where an entry carries
a time) because a run of them is meant to be scanned down — "27 Aug 2026" is three
words per row and reads as prose, not as a column.

**A dot per event, FILLED for what has happened and HOLLOW for what is booked**,
with a `today` divider between them. That split is the main thing a log knows and
the reason the view exists: entries may be future-dated by design — a deadline has
not arrived, an interview is booked before it is held — so a view that treats
every entry alike throws the distinction away.

The divider is emitted **only where there is something on both sides of it**. A
rail whose every event is past does not need a line saying where now is.

`created` leads the rail, from rookery's own field via `timeline` — so the record
starts when the note was written and the log is what happened to it since.

### An event's own prose

Where an entry carries a `note`, the rail renders it under that event's stage and
date — inside the same list item, so the dot stays aligned to the prose it belongs
to. That is the whole reason an entry can carry content: a sentence about one event
on the note's body reads as a claim about the whole thing.

A note may span more than one paragraph. Its container is a `<div>` and not a `<p>`
for exactly that reason — MEASURED, a two-paragraph note inside a `<p>` renders
EMPTY, because Typst's paragraphs are block content a `<p>` cannot legally contain
and the whole element collapses.

An event without a note gets no element at all rather than an empty one, and an
**expected rung never gets one** — a rung that has not happened cannot have prose
about it, and the ladder supplies names only.

### With a ladder it becomes a progress indicator

`ladder:` defaults to `none` and the two registers are visibly different:

| call | what you get |
| --- | --- |
| `timeline-view(row, tags, today: NOW)` | a RECORD — the log's own events, nothing more |
| `timeline-view(row, tags, today: NOW, ladder: JOURNAL)` | a PROGRESS indicator — the events, then the unreached rungs, undated and greyed |

An unreached rung is an **expectation, never a promise**: nothing here knows a
process will advance, only what the ladder says would come next if it did. The
class is `timeline-expected` and the stylesheet dots its outline for that reason.

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

Every class is a published contract: `.timeline` on the list, `.timeline-event`
per row plus exactly one of `.timeline-past` / `.timeline-future` /
`.timeline-expected`, `.timeline-stage`, `.timeline-when` and `.timeline-note` inside, `.timeline-current`
alongside `.timeline-past` on the one row that is the current stage, and
`.timeline-today` on the divider. Six custom properties theme it without
overriding a rule — `--timeline-line`, `--timeline-fg`, `--timeline-muted`,
`--timeline-dot`, `--timeline-gap`, `--timeline-note`, `--timeline-gutter` (the
width of the date column, and what the line's position is measured from).

### What it deliberately is not

A horizontal track (crowds past four events, and gives a long stage name nowhere
to go), a definition list (says nothing about order, or about whether an event has
happened), an inline sparkline (a different component, for a table of many notes — which
`#upcoming` below now is),
and **no durations of any kind** — no "126 days in flight", no per-event gaps. The
reader can subtract, and a computed interval resting on a stand-in date looks more
precise than it is.

On a paged or EPUB target there is no rail to draw, so the same events render as
an ordinary list.

## `#upcoming` — the log as a dated list across many notes

The rail's sibling: `#timeline-view` draws ONE note's log down a line, this draws
ONE ROW PER NOTE across a whole corpus, ordered by what is coming next.

```typst
#import "@rheo/rookery-timeline:0.1.0": upcoming, DEADLINE-STAGE, SCHEDULED-STAGE

#upcoming(
  tags: "submission",
  stage: (DEADLINE-STAGE, SCHEDULED-STAGE),
  today: NOW,
  from: datetime(year: 2026, month: 1, day: 1),
)
```

```
 1.9.26   Cornell Society for the Humanities            POSTDOC
 7.9.26   Lecturer in Artificial Intelligence           SUBMITTED
20.9.26   Media Theory Conference 2027                  UNDER REVIEW
   —      Temporalities of AI, Bibliotheca Hertziana
```

Three columns: when, the note's name, and the stage it is CURRENTLY at. Every row
links to the note.

### The arguments

| | |
|---|---|
| `tags:` / `match:` | rookery's own selection vocabulary, passed straight to `ideas()` |
| `filter:` | a predicate over the note's tag dictionary, ANDed with the above |
| `stage:` | which log entry dates the row — see below |
| `today:` | the reference date, as everywhere else here |
| `from:` | a `datetime`; drops a row dated before it |
| `within:` | days; drops a row dated later than `today + within` |
| `limit:` | truncate after sorting |
| `title:` | optional label above the list |
| `empty:` | what to show when nothing survives |

### `stage:` — which entry dates the row

**The log is a dictionary of named dates, and only the caller knows which name it is
waiting on.** A job application is queued by its `deadline`; a call whose dates are
not published yet is queued by the `scheduled` date it is expected to post on; a
conference is queued by whichever of the two it has. So `stage:` takes one name, or
an array of names in **priority order**:

```typst
#upcoming(stage: (DEADLINE-STAGE, SCHEDULED-STAGE))   // deadline, else the watch date
#upcoming(stage: "campus-visit")                      // queued by one booked event
```

The date resolves in three steps:

1. the first of `stage:` the log carries — that date, rendered firm;
2. otherwise the next entry dated **after** `today:` (`next-of`) — that date,
   rendered **soft**;
3. otherwise nothing: the row renders `—` and sorts after every dated row.

Step 2 is the row with no deadline that nonetheless has something booked, and it
belongs in the queue — an interview next month is exactly what is imminent about it.
The soft styling says only that the date came from a different entry than the one you
asked to be queued by; it is not a claim about the date's reliability.

Rows sort **ascending, oldest first**, which puts a date already behind you at the
TOP. An overdue row is the most urgent thing on the list, not the stalest.

### What it deliberately is not

**It takes no ladder and cannot tell you a note is finished.** Whether `accepted`
ends a process is vocabulary this package refuses to own, for the reason
`is-settled` lives in `ladder.typ` and takes one as a parameter. A caller that wants
settled rows gone passes `filter:`:

```typst
#upcoming(tags: "submission", filter: t => not is-settled(t, ladder: JOB, today: NOW))
```

**Three fixed columns, and no render hook.** A fourth column — a submission's host
school, a path to a manuscript — is a question about the caller's own data model,
which this package cannot see; a project needing one keeps its own view. Fixed
columns are what make one call over two unrelated corpora read as one table.

On a paged or EPUB target there is no grid to align and no anchor to click, so the
same rows render as an ordinary list.

### Styling it

Every class is a published contract: `.upcoming` on the wrapper, `.upcoming-title`
on the label, `.upcoming-list` on the list, `.upcoming-row` per row — plus one
`idea-tag-<tag>` class per tag the note carries, so a project theming a tag on a
card has already themed it here — and inside a row `.upcoming-when` (with `.soft`
where the date came from a booked entry), `.upcoming-name`, and `.upcoming-stage`.
An empty result is `.upcoming-empty`.

The stage chip also wears rookery's own `idea-tag` and `idea-tag-<stage>`, which is
how a project's `theme: (tags-color: ..)` colours a stage here without this package
naming a single hue: those generated rules publish `--idea-tag-bg`,
`--idea-tag-color` and `--idea-tag-line`, and the chip reads all three. Its SHAPE is
copied from rookery's own pill rather than inherited from it — wearing `.idea-tab`
to pick that rule up would also draw that element's `::before` stub of rule, which
inside a table row reads as a stray dash.

Colours come from the rail's own properties (`--timeline-fg`, `--timeline-muted`,
`--timeline-line`), and there is one knob of its own: `--upcoming-gutter`, the width
of the date column, defaulting to `--timeline-gutter`'s 7.5em.

The list **flows down the page**: no `max-height`, no `overflow`, no scroll box. A
caller wanting fewer rows passes `limit:`, which is a claim about the data rather
than a lie about the height.

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

- `@rheo/rookery` 0.6.0, for `created` on an `#ideas()` row, for `tag-index`, and
  for the `ideas()` registry read `#upcoming` does. The CORE of this package imports
  it not at all — a tag fragment is a plain dictionary, and `dated(mint)` takes its
  constructor as an argument — but the `dated-idea` binding and `#upcoming` both do.
- No build step and no JavaScript. `typst.toml`'s `entrypoint` points straight at
  `src/`, so an edit takes effect immediately. It DOES ship one CSS file —
  `src/rookery-timeline.css`, for the two views that draw something
  (`#timeline-view` and `#upcoming`) — inside `@layer rookery-timeline`, so an
  unlayered rule in your own stylesheet beats it whatever the specificity.

## Development

```sh
cd rookery-timeline/0.1.0
just test
```
