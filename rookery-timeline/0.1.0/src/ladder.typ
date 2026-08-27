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
// ---- A rung may name a FAMILY of stages ----------------------------------
//
// A rung ending in `-*` matches any stage sharing that prefix:
//
//   transit: ("submitted", "review-*", "accepted", "revision-*")
//
// `review-*` matches `review-1` and `review-12`, and NOT `reviewer` — the hyphen
// is part of the prefix — and not a bare `review` either, since that carries no
// occurrence and a lifecycle using the family form should say which one.
//
// WHY IT EXISTS. A lifecycle with "a flexible number of reviews" cannot be written
// as a dict of stage names: MEASURED, a Typst dict rejects `(review: 1, review: 2)`
// outright with "duplicate key: review". So a repeated stage is written with
// numbered names, and a ladder has to be able to say "any review" rather than
// listing every occurrence anyone might reach.
//
// ONE FORM, AT ONE POSITION. A pattern is a prefix and nothing else: no `*` in the
// middle, no bare `*`, no character classes. Anything more is a glob implementation
// nobody asked for, and each addition is a new way for two rungs to overlap.
#let _is-family(pattern) = pattern.ends-with("-*")

// The prefix a family rung matches on, hyphen included, so `reviewer` cannot match
// `review-*`.
#let _family-prefix(pattern) = pattern.slice(0, pattern.len() - 1)

// What to CALL a rung — the pattern with its `-*` stripped, so a view drawing an
// expected rung shows `review` rather than `review *`. Exported because
// `#timeline-view` needs it and should not reimplement it.
#let rung-name(pattern) = {
  if _is-family(pattern) { pattern.slice(0, pattern.len() - 2) } else { pattern }
}

#let _matches(pattern, stage) = {
  if _is-family(pattern) { stage.starts-with(_family-prefix(pattern)) } else { stage == pattern }
}

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
  // A rung that is in BOTH arrays makes `is-settled` and `rung` disagree about the
  // same note, and nothing else would report it.
  //
  // OVERLAP, NOT JUST EQUALITY, now that a rung can be a family: `review-*` in
  // transit and `review-1` in terminal is the same mistake as `review` in both, and
  // reads even less obviously. So each pair is tested both ways round — a family
  // pattern against the other array's names, and its own name against the other
  // array's families.
  let both = ladder
    .transit
    .filter(a => ladder.terminal.any(b => a == b or _matches(a, rung-name(b)) or _matches(b, rung-name(a))))
  assert(
    both.len() == 0,
    message: "@rheo/rookery-timeline: the rung(s) "
      + both.join(", ")
      + " in a ladder's `transit:` also match something in its `terminal:`. A stage "
      + "cannot be mid-process and final at once — `is-settled` and `rung` would "
      + "disagree about the same note.",
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
  s != none and ladder.terminal.any(p => _matches(p, s))
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
  if ladder.terminal.any(p => _matches(p, s)) { return ladder.transit.len() }
  ladder.transit.position(p => _matches(p, s))
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
  if s == none or ladder.terminal.any(p => _matches(p, s)) { return none }
  let i = ladder.transit.position(p => _matches(p, s))
  // THROUGH `rung-name`, so this returns something renderable: the rung after
  // `submitted` reads `review`, not `review-*`.
  if i == none or i + 1 >= ladder.transit.len() { none } else { rung-name(ladder.transit.at(i + 1)) }
}
