// Ladder-driven derivations: is this finished, what comes next, how far did it
// get — with the VOCABULARY taken as a parameter rather than owned here.
//
// WHY A PARAMETER, and this is the whole design of the file. No package can know
// that `accepted` ENDS a conference submission and is the MIDDLE of a journal's
// ladder, or that `offered` ends a job application and `published` ends a paper.
// The words belong to the consumer; the reasoning belongs here. It is the same
// split this package already makes for `today:` — the caller supplies what only
// the caller can know, and the package refuses to guess.
//
// A LADDER is a plain dictionary with two arrays:
//
//   #let JOB = (
//     transit:  ("submitted", "longlisted", "first-interview",
//                "second-interview", "campus-visit", "finalist"),
//     terminal: ("offered", "rejected", "declined", "dropped", "missed"),
//   )
//
// `transit` is ORDERED BY PROGRESS, and that order is what `rung` reads.
// `terminal` is unordered in meaning — its membership is what settles a note.

#import "fragment.typ": *
#import "read.typ": *
#import "when.typ": *

// Validated on every call rather than once at construction, because a ladder is a
// plain dictionary a caller writes inline and there is no constructor to hang the
// check on. The checks are cheap and each catches something that fails SILENTLY
// otherwise.
#let _assert-ladder(ladder) = {
  assert(
    ladder != none and type(ladder) == dictionary and "transit" in ladder and "terminal" in ladder,
    message: "@rheo/rookery-timeline: `ladder:` must be a dictionary with `transit:` "
      + "and `terminal:` arrays of stage names — got "
      + repr(ladder),
  )
  for k in ("transit", "terminal") {
    assert(
      type(ladder.at(k)) == array and ladder.at(k).all(n => type(n) == str),
      message: "@rheo/rookery-timeline: a ladder's `" + k + ":` must be an array of strings — got " + repr(ladder.at(k)),
    )
  }
  // A name in BOTH arrays makes `is-settled` and `rung` disagree about the same
  // note, and nothing else would report it.
  let both = ladder.transit.filter(n => n in ladder.terminal)
  assert(
    both.len() == 0,
    message: "@rheo/rookery-timeline: the stage name(s) "
      + both.join(", ")
      + " appear in BOTH a ladder's `transit:` and `terminal:`. A stage cannot be "
      + "mid-process and final at once — `is-settled` and `rung` would disagree "
      + "about the same note.",
  )
}

// Has the process finished? True when the current stage — the last one that has
// actually happened, per `stage-of` — is a member of `terminal`.
//
// An empty log, or a log entirely in the future, is NOT settled: nothing has
// happened yet, which is the opposite of finished.
#let is-settled(tags, ladder: none, today: none) = {
  _assert-ladder(ladder)
  let s = stage-of(tags, today: today)
  s != none and s in ladder.terminal
}

// HOW FAR IT GOT, as an integer, so it drops straight into a sort key or a
// `tag-index` projection:
//
//   - the index in `transit` for a mid-process stage
//   - `transit.len()` for any terminal stage, so anything finished sorts past
//     everything still moving
//   - `none` for an empty log, a log entirely in the future, or a stage the
//     ladder does not name
//
// An UNKNOWN stage is not an error, and that is deliberate: a consumer's
// vocabulary grows, and a note written against tomorrow's ladder must degrade to
// "unknown stage" rather than fail the build of an unrelated page.
#let rung(tags, ladder: none, today: none) = {
  _assert-ladder(ladder)
  let s = stage-of(tags, today: today)
  if s == none { return none }
  if s in ladder.terminal { return ladder.transit.len() }
  let i = ladder.transit.position(n => n == s)
  i
}

// The next rung of `transit` after the current stage, or none.
//
// AN EXPECTATION, NOT A PROMISE. Nothing here knows that a process will advance,
// only what the ladder says would come next if it did — so a view rendering this
// should say "expected" rather than presenting it as a fact. `none` for a terminal
// stage, for the last transit rung, for an unknown stage, and for a log where
// nothing has happened yet.
#let next-stage(tags, ladder: none, today: none) = {
  _assert-ladder(ladder)
  let s = stage-of(tags, today: today)
  if s == none or s in ladder.terminal { return none }
  let i = ladder.transit.position(n => n == s)
  if i == none or i + 1 >= ladder.transit.len() { none } else { ladder.transit.at(i + 1) }
}
