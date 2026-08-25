// Reading dates back off a tag dictionary or an `ideas()` row.
//
// Four readers, split across two sources on purpose. `scheduled-of`/
// `deadline-of` read THIS package's own keys out of a tag dictionary.
// `created-of`/`updated-of` read ROOKERY CORE's fields off an `ideas()` row,
// because rookery already resolves and stores those and a second copy could
// only disagree with the first.

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
// `none` when the key is absent, which is also what a note that never named a
// date gives — an absent plan is not an error.
#let scheduled-of(tags) = tags.at(SCHEDULED-KEY, default: none)
#let deadline-of(tags) = tags.at(DEADLINE-KEY, default: none)

// Rookery core's own dates, off an `ideas()` row.
//
// NOT STORED BY THIS PACKAGE, deliberately. `#idea(minted:, updated:)` already
// resolves each from the explicit argument, then the document's own
// `#set document(date:)`, then nothing; rookery stores both on the registry
// record and publishes them on every `ideas()` row. These two functions are
// naming, not storage: "created" is the word a reader of a todo list wants and
// `minted` is the word rookery uses, and one line here is cheaper than a second
// source of truth that can drift.
//
// `.at` with a default rather than a field access, so a row from some other
// shape — a hand-built dictionary in a test, a future rookery with a different
// row — reads as undated instead of hard-failing.
#let created-of(entry) = entry.at("minted", default: none)
#let updated-of(entry) = entry.at("updated", default: none)
