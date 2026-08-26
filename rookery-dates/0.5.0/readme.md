# @rheo/rookery-dates

Scheduled and deadline dates for [`@rheo/rookery`](../../rookery) notes,
contributed as tag metadata.

```typst
#import "@rheo/rookery:0.5.0": idea
#import "@rheo/rookery-dates:0.5.0": dates

#idea("ship", tags: dates(deadline: datetime(year: 2026, month: 9, day: 1)))[
  Cut the release.
]
```

## How it composes

`dates(..)` returns a TAG FRAGMENT — a plain dictionary you merge into a
rookery `tags:` argument. That is the entire write surface.

This package does not import `@rheo/rookery`, and `@rheo/rookery` knows nothing
about this package. A tag fragment is just a dictionary, so composition needs no
import relationship in either direction: any package, and any hand-written
`#idea`, can use it. Rookery 0.5.0 accepts a dictionary for `tags:` directly, so
composing with ordinary tags is dictionary merge:

```typst
#idea("ship", tags: (phd: none, urgent: none) + dates(deadline: d))[...]
```

An omitted date emits **no key at all**, not a key valued `none`. Under rookery
0.5.0 a `none`-valued key is a *flat* tag — it renders as a pill and reads as a
plain label — so `dates()` with nothing to say stays silent. `dates()` with no
arguments is `(:)`, which merges into anything and changes nothing.

## The keys

| key | value | from |
| --- | --- | --- |
| `date-scheduled` | `datetime` | `dates(scheduled: ..)` |
| `date-deadline` | `datetime` | `dates(deadline: ..)` |

Both are exported as `SCHEDULED-KEY` and `DEADLINE-KEY` so a consumer can name
them without hardcoding a string.

Keys are namespaced with a `date-` prefix, per rookery's key convention: a tag
key becomes a CSS class fragment (`.idea-tag-date-deadline`, which you can style
or theme like any other tag), and a bare `deadline` is a generic name two
packages could both reach for and silently collide over.

Because these are *valued* tags they render no pill, but they are still
presence-filterable by key — `#window(tags: "date-deadline")` finds every note
carrying a deadline, whatever it is.

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

`created-of(entry)` and `updated-of(entry)` take an `#ideas()` ROW instead, and
read rookery core's own `minted`/`updated` fields.

**This package deliberately does not store created/updated dates.** Rookery
already resolves each from `#idea(minted:, updated:)`, then the document's
`#set document(date:)`, then nothing, and publishes both on every `#ideas()`
row. These two functions are naming, not storage — "created" is the word a
reader wants and `minted` is the word rookery uses — because a second copy could
only drift from the first.

Status transitions are likewise not here. A closed-at timestamp belongs to
whoever owns the status; see `@rheo/rookery-todos` and its `todo-closed` tag.

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

`is-scheduled-now` is `false` for a note with no `date-scheduled`, which reads
as "not scheduled" rather than "scheduled for now". A consumer wanting "nothing
is deferring this" asks `scheduled-of(t) == none or is-scheduled-now(t)`.

Dates are compared as zero-padded `[year][month][day]` strings, which sidesteps
the question of how `datetime` orders as a sort key — the same technique rookery
uses in its own id sorting.

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

- `@rheo/rookery` 0.5.0 or later, for the tag dictionary. This package does not
  import it, but the fragment it builds is only meaningful to a rookery that
  accepts a dictionary for `tags:`.
- Pure Typst: no build step, no JavaScript, no CSS. `typst.toml`'s `entrypoint`
  points straight at `src/`, so an edit takes effect immediately.

## Development

```sh
cd rookery-dates/0.5.0
just test
```
