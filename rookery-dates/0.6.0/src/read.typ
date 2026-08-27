// Reading dates back off a tag dictionary or an `ideas()` row.
//
// Readers split across two sources on purpose. The log readers — `log-of`,
// `stage-date`, `has-stage`, `entered-of`, and the `scheduled-of`/`deadline-of`
// pair built on them — read THIS package's own `date-log` out of a tag
// dictionary. `created-of` reads ROOKERY CORE's own row field, because rookery
// already resolves and stores it and a second copy could only disagree with the
// first. `updated-of` and `timeline` straddle the two, and say so.

#import "fragment.typ": *

// This package's own dates, off a note's tag dictionary — the thing
// `#tag-data()` hands back per note, or `#tag-value` one key of.
//
//   #context deadline-of(tag-data().at("idea:ship"))   // -> datetime or none
//
// Takes the DICTIONARY, not a note name, so it needs no registry read of its
// own and stays a pure function. A caller walking the corpus does one
// `tag-data()` and calls these per row.
//
// `none` when the stage is absent, which is also what a note that never named a
// date gives — an absent plan is not an error.
//
// RE-SOURCED OVER THE LOG in 0.6.0, signatures unchanged. `date-scheduled` and
// `date-deadline` are no longer tag keys; they are reserved STAGE NAMES inside
// the single `date-log` key (see `fragment.typ`). Keeping these two readers
// exactly as they were is what let the storage change underneath every consumer
// without one of them editing a line: @rheo/rookery-todos' readiness check,
// `is-overdue`, `is-upcoming` and `todos-stale` all still call these.
//
// THE LATEST entry wins where a stage appears more than once. A todo deferred and
// then re-deferred has two `scheduled` entries, and "deferred until" means the
// current deferral rather than the first one ever set. Entries are stored sorted
// by date, so the last match is the latest.
// ---- The log, read back ----------------------------------------------------
//
// Every reader here is a pure function of a tag DICTIONARY — the thing
// `#tag-data()` hands back per note, or a row's own `tags-dict`. A caller walking
// the corpus does one `tag-data()` and calls these per row.
//
// Anything needing a reference date lives in `when.typ` instead, not here: log
// entries may be FUTURE-DATED (a deadline is by definition a date that has not
// arrived, and an interview can be booked before it is held), so "what stage is
// this at" is a question about a `today:` and cannot be answered from the
// dictionary alone.

// The whole log, in date order. `()` rather than `none` when absent, so a caller
// can map over it without a guard: an empty log and no log are the same question.
#let log-of(tags) = tags.at(LOG-KEY, default: ())

// One named stage's date, or none.
//
// THE LATEST entry wins where a stage appears more than once. A todo deferred and
// then re-deferred has two `scheduled` entries, and "deferred until" means the
// current deferral rather than the first one ever set. Entries are stored sorted
// by date, so the last match is the latest.
#let stage-date(tags, name) = {
  let hits = log-of(tags).filter(e => e.stage == name)
  if hits.len() == 0 { none } else { hits.last().on }
}

// Does the log record this stage at all, whatever its date?
#let has-stage(tags, name) = log-of(tags).any(e => e.stage == name)

// The FIRST entry's date — "in flight since". `none` for an empty log.
#let entered-of(tags) = {
  let l = log-of(tags)
  if l.len() == 0 { none } else { l.first().on }
}

// `none` when the stage is absent, which is also what a note that never named a
// date gives — an absent plan is not an error.
//
// RE-SOURCED OVER THE LOG in 0.6.0, signatures unchanged. `date-scheduled` and
// `date-deadline` are no longer tag keys; they are reserved STAGE NAMES inside
// the single `date-log` key (see `fragment.typ`). Keeping these two readers
// exactly as they were is what let the storage change underneath every consumer
// without one of them editing a line: @rheo/rookery-todos' readiness check,
// `is-overdue`, `is-upcoming` and `todos-stale` all still call these.
#let scheduled-of(tags) = stage-date(tags, SCHEDULED-STAGE)
#let deadline-of(tags) = stage-date(tags, DEADLINE-STAGE)

// ---- created / updated — one from core, one derived -----------------------
//
// `created` IS NOT STORED BY THIS PACKAGE, deliberately. `#idea(created:)`
// resolves it from the explicit argument, then the document's own
// `#set document(date:)`, then nothing; rookery stores it on the registry record
// and publishes it on every `ideas()` row. Keeping a second copy here could only
// disagree with the first. It also stays a ROW field rather than a tag value for a
// load-bearing reason: rookery keeps tag values off `ideas()` rows, so anything
// in the tag dictionary — the log included — costs a `tag-data()` walk to reach,
// and a date every consumer filters and sorts by should be free.
//
// `.at` with a default rather than a field access, so a row from some other shape
// — a hand-built dictionary in a test, a future rookery with a different row —
// reads as undated instead of hard-failing.
#let created-of(entry) = entry.at("created", default: none)

// `updated` NO LONGER EXISTS IN CORE, and this is what replaced it. Rookery 0.6.0
// removed `#idea(updated:)` and the row field, on the grounds that a
// hand-maintained "last touched" is a second date the author has to remember and
// one that can contradict what actually happened to the note.
//
// So it is DERIVED: the last log entry where there is one, else `created`. For the
// first time this function means something the note itself knows. It takes BOTH
// the row and the tag dictionary, because the answer now comes from two sources.
#let updated-of(entry, tags) = {
  let l = log-of(tags)
  if l.len() > 0 { l.last().on } else { created-of(entry) }
}

// The display seam: core's `created` and the log's own entries as ONE sequence,
// for a view rendering a note's history.
//
//   timeline(row, tags)
//     -> ((stage: "created", on: ..), (stage: "deadline", on: ..), ..)
//
// `created` is PREPENDED here rather than written into the log, which is the whole
// point: one store per fact, one view over both. Writing it into the log would
// give the note two copies of its creation date that could drift apart.
//
// Not sorted against the log's dates. `created` leads unconditionally, because a
// note cannot have been acted on before it existed — and where a log entry
// predates it (an author back-dating a deadline they were given before writing the
// note down) the honest reading is still that the record starts at `created`.
#let timeline(entry, tags) = {
  let c = created-of(entry)
  (if c == none { () } else { ((stage: "created", on: c),) }) + log-of(tags)
}
