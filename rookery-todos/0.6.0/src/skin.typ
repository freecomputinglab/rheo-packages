// The SKIN over @rheo/rookery-timeline, which is itself a skin over @rheo/rookery.
//
// THE PATTERN. If you use plain rookery you import `idea`, `window` and the rest
// from rookery. If you use this package you import those SAME names from HERE, and
// get versions that know about todos.
//
//   #import "@rheo/rookery-todos:0.6.0": idea, todo, window, rookery
//   #window("some-todo")          // renders nothing if that todo is closed
//
// IT IMPORTS THE TIMELINE SKIN, NOT ROOKERY DIRECTLY, and that is load-bearing:
// the decoration has to COMPOSE. `idea` arriving here is already
// `dated(rookery.idea)`, so a note written through this package takes the log
// arguments as well as the todo ones. Importing rookery here instead would silently
// bypass the timeline skin and lose them.
//
// WHAT IS OVERRIDDEN HERE: `window` alone. `idea` and `tagged-idea` pass through
// already-decorated from the timeline skin, and everything else is rookery's,
// untouched.
#import "@rheo/rookery-timeline:0.1.0": *
#import "@rheo/rookery-timeline:0.1.0" as _tl
#import "@rheo/rookery:0.6.0": tags-of
#import "tags.typ": CLOSED-KEY

// A CLOSED TODO IS NOT TRANSCLUDED, by default.
//
// A closed todo windowed into a page is noise: the thing is done, and the reason to
// window a todo at all is to have it in front of you. `closed: true` opts one back
// in, for a page that is deliberately a record.
//
// ONLY THE NAMED CASE IS FILTERED, and this is a real limitation rather than an
// oversight. `#window` takes either a NAME or a `tags:`/`match:` selection. Given a
// name, this wrapper can read that note's tags and decide. Given a selection,
// rookery does the selecting internally and `tags:`/`match:` are any/all over a
// list with NO NEGATION — so a wrapper cannot express "todo and not closed" and a
// tag-selected window still shows closed todos. Fixing that needs a negation or a
// predicate hook in rookery's own tag predicate, not a workaround here.
//
// A CONTEXT FUNCTION, because it reads the registry to answer the question. That is
// no new constraint on a caller: `#window` already had to be called where rookery's
// state is readable.
#let window(..args, closed: false) = context {
  let pos = args.pos()
  // No positional argument means a tag-selected window, which is the case this
  // cannot filter — pass it through rather than pretending.
  if closed or pos.len() == 0 {
    return _tl.window(..args)
  }
  // `tags-of` takes the same name forms `#window` itself accepts — a bare name, a
  // full `idea:x` id, or a label — so nothing needs normalizing here.
  //
  // THE FLAT MARKER, NOT `is-closed`, and this is the marker earning its keep.
  // `tags-of` returns tag NAMES, not the tag dictionary — MEASURED, passing its
  // result to `is-closed` fails with "expected integer, found string", because that
  // reader indexes the dictionary for the log. Closedness is reachable from a name
  // list precisely because `#todo` writes `todo-closed` as a flat key beside the
  // dated entry, which is the whole argument for keeping it.
  if CLOSED-KEY in tags-of(pos.at(0)) { return }
  _tl.window(..args)
}
