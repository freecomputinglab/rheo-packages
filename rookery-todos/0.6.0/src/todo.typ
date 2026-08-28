// `#todo` — the package's primitive, an `#idea` variant carrying todo tags.

#import "@rheo/rookery:0.6.0": tagged-idea, _norm
#import "@rheo/rookery-timeline:0.1.0": CLOSED-STAGE, dated
#import "tags.typ": *

// A todo is a rookery note tagged `todo`, plus whatever `todo-tags` folds in.
//
//   #todo("build", priority: 1, type: "bug", deps: ("fetch",))[Fix the parser.]
//   #todo[A frictionless todo — takes an auto id, same as `#idea`.]
//
// Built on rookery's `tagged-idea` factory rather than on `#idea` directly, so
// the `todo` tag is PREPENDED and merged rather than replacing a caller's own
// `tags:`. `..args` is forwarded untouched, which is what keeps all three
// `#idea` call forms working — `#todo[body]`, `#todo("name")[body]` and
// `#todo(<name>)[body]` — along with every `#idea` named argument this wrapper
// does not itself consume: `title`, `level`, `created`, `show-date`,
// `show-tags`.
//
// EVERY DATE A TODO CARRIES BELONGS TO @rheo/rookery-timeline, in its entirety.
// `#todo` is built on that package's `dated(..)` decorator, so `scheduled:`,
// `deadline:` and `timeline:` are its named arguments passed straight through:
//
//   #todo("ship", deadline: d, timeline: (activated: d2, closed: d3))[..]
//
// WHAT THIS PACKAGE IS, stated plainly because the boundary moved: a LIFECYCLE
// declared over @rheo/rookery-timeline. It contributes the stage names `activated`
// and `closed` (see `ACTIVATED-STAGE` and that package's `CLOSED-STAGE`), the
// `TODO-LADDER` that orders them, its own tag family, and the views. It owns NO
// dates: the log, the readers, the derivations over a ladder and the rail that
// draws one all live there, and a todo is one vocabulary among several — a
// submission tracker declares another over the same machinery.
//
// `done:` IS THE SHORTHAND FOR ONE CLOSE, and it is sugar over that same log:
//
//   #todo("ship", done: d)               ==  #todo("ship", timeline: (closed: d))
//
// It takes whatever a log entry takes, so an entry dictionary works here too and
// is how a close carries its own prose: `done: (timestamp: d, note: [Landed as ..])`.
//
// So there is still ONE store and one write path — `done:` folds into the
// `timeline:` dictionary before anything reads it (`_closing` below), rather than
// setting a second flag beside it. That is the whole reason the old `closed:`
// argument was removed in 0.6.0: it wrote the flat marker while
// `timeline: (closed: d)` wrote the entry, and the two disagreed. Folding cannot
// disagree.
//
// IT TAKES A DATE, NOT A BOOL. `done: true` is refused with a message, because a
// log entry needs a date and there is no clock here to stamp one from — see the
// `created` note below and rookery-timeline's own header for the measured
// evidence. Giving the same stage twice — `done:` and `timeline: (closed: ..)`
// together — is refused for the same reason rookery-timeline refuses it: which
// date the author meant is unknowable.
//
// `#done(d)` (below) is the same close as a FACTORY, for a date several todos
// share — see its own comment for why the date cannot lead a positional list.
//
// The old form still works and is still supported — `dated` merges its fragment
// into whatever `tags:` the caller passed — so `#todo("ship", tags: entries(deadline: d))`
// is unchanged:
//
//   #todo("ship", tags: entries(deadline: d))[..]
//
// `created` is rookery's own row field, forwarded through `..args`. There is no
// `updated`: rookery removed it in 0.6.0 and rookery-timeline derives last-touched
// from the log. Nothing in this package auto-stamps a date; there is no wall
// clock to stamp from (see rookery-timeline's readme for the measured evidence).
//
// A CLOSE IS A DATE however it is written — `done:` or `timeline: (closed: ..)` —
// and it goes into the log rather than onto a valued tag. See `CLOSED-KEY` in
// `tags.typ` for why the flat marker stays beside it.
//
// AN AUTO-ID DEP IS FRAGILE, and this package cannot warn you about it here.
// Rookery's unnamed notes take a sequence number from a counter, so `#todo[..]`
// is `idea:1` — and that number SHIFTS when a note is inserted earlier in the
// spine, while a `deps` entry naming it does not follow. Pin any todo that
// something else depends on: `#todo("fetch")[..]`.
//
// Typst gives package code no way to emit a build warning — there is no
// `warn()`, only `panic`, and a panic here would be far too strong for what is
// a smell rather than an error. So the check lives in `#todos-validate()`
// (`graph.typ`) instead, where it can be reported alongside the cycle check
// without failing a build that has not actually broken.

// `done:` folded into the `timeline:` dictionary, so the log stays the one store
// and `#todo`'s two ways of writing a close have one destination.
//
// A TOP-LEVEL HELPER rather than a few lines inside `todo`, and that is forced:
// `todo`'s public signature has a parameter named `type`, which shadows Typst's
// built-in `type()` for the whole function body — so the assertions below cannot
// live there. (`tags.typ`'s `todo-tags` renames to `kind` for the same reason.)
#let _closing(done, timeline) = {
  if done == none { return timeline }
  // Checked HERE rather than left to rookery-timeline, which would report a
  // missing `timestamp` on a stage named `closed` — true, but it would not
  // mention `done:` or say why a bool cannot become a date.
  assert(
    type(done) != bool,
    message: "@rheo/rookery-todos: `done` is the DATE a todo closed, not a flag — got "
      + repr(done)
      + ". A close is a log entry and an entry needs a date; nothing here auto-stamps "
      + "one, because there is no clock to stamp from (`datetime.today()` returns "
      + "1980-01-01 under a reproducible-build SOURCE_DATE_EPOCH, and fails silently "
      + "while doing it). Write `done: datetime(year: .., month: .., day: ..)`.",
  )
  let log = if timeline == none { (:) } else { timeline }
  assert(
    type(log) == dictionary,
    message: "@rheo/rookery-todos: `timeline` takes a dictionary of stage-name -> "
      + "datetime — got " + repr(timeline),
  )
  // Both forms at once is a contradiction, not a merge — the same reading
  // rookery-timeline's `entries` takes of a stage given twice.
  assert(
    CLOSED-STAGE not in log,
    message: "@rheo/rookery-todos: this todo was closed twice — once as `done:` and "
      + "once as `" + CLOSED-STAGE + ":` inside `timeline:`. Which date it closed on "
      + "is then unknowable, so write one of them.",
  )
  log + ((CLOSED-STAGE): done)
}

// LABELS ARE NOT A PARAMETER EITHER. A todo's labels are plain rookery tags:
// `#todo("x", tags: ("phd", "urgent"))`. Unnamespaced, deliberately, so they
// keep filtering and theming like every other tag.
#let todo(
  priority: none,
  type: none,
  status: none,
  deps: (),
  metadata: (:),
  tags: none,
  done: none,
  timeline: none,
  ..args,
) = {
  // ONCE, and everything below reads this rather than the `timeline:` argument —
  // the flat marker included, so `done:` and `timeline: (closed: ..)` cannot
  // produce different tags. See the derivation note below.
  let log = _closing(done, timeline)
  (dated(tagged-idea(TODO-KEY)))(
    timeline: log,
    tags: todo-tags(
      tags: tags,
      priority: priority,
      // Renamed on the way in: a parameter named `type` shadows Typst's built-in
      // `type()` for the whole callee body, and `todo-tags` needs that builtin.
      kind: type,
      status: status,
      // THE FLAT MARKER IS DERIVED FROM THE LOG, not from an argument. There used
      // to be a `closed:` parameter beside `timeline:`, and the two were not
      // equivalent: MEASURED, `#todo("a", closed: d)` carried `todo-closed` while
      // `#todo("b", timeline: (closed: d))` did not, so the second read as closed to
      // `is-closed` and as OPEN to `tags:todo&!todo-closed` — the query this
      // package's own header calls the payoff of the flat-tag surface. Two ways to
      // write one fact, one of them silently unfilterable.
      //
      // Deriving it here is what makes them one way. `todo-tags` cannot do it: it
      // builds this package's keys and never sees the log, which belongs to
      // @rheo/rookery-timeline. `done:` gets it for free by folding into `log`
      // upstream rather than by being checked for here — which is what keeps the
      // two spellings of a close one write path.
      closed: log != none and CLOSED-STAGE in log,
      deps: deps,
      metadata: metadata,
      // Rookery's own name normalizer, so a dep written as a bare name, a full
      // `idea:x` id or a label `<x>` all resolve to the same string — the same
      // set of forms `#window` and `#hyperlink` accept.
      norm: _norm,
    ),
    ..args,
  )
}

// ---- #done — the same close, as a factory --------------------------------
//
//   #done(datetime(year: 2026, month: 8, day: 25))("fetch", priority: 0)[Fetch it.]
//   #done(d)[A closed todo with an auto id.]
//
//   #let closed-today = done(TODAY)     // the form worth having
//   #closed-today("fetch", priority: 0, deps: ("parse",))[Fetch it.]
//
// A FACTORY, exactly like `#epic` below and for the same reason: it returns a
// `#todo` VARIANT with `done:` bound, so it keeps the whole call surface —
// content bodies, all three id forms, `priority`, `type`, `deps`, `tags`,
// `scheduled`, `deadline`, a further `timeline:` of other stages — with no
// argument list to reimplement here and none to fall out of date.
//
// THE DATE CANNOT BE A LEADING POSITIONAL ARGUMENT of a single function, which
// is what makes this a factory rather than `#done(d, "fetch")[..]`: `#todo`'s
// first positional is the note's ID, and a date sitting in front of it would
// take that slot. Currying puts the date somewhere the id is not.
//
// It is the same close as `done:` — one write path, since this is that argument
// — and `#todo(done: d)` remains the direct spelling. Reach for this one when
// several todos closed on one date, or when the date is a project constant.
#let done(on) = {
  // Validated EAGERLY, on the factory call, rather than only when the returned
  // function is used: `#let closed-q3 = done(true)` at the top of a file would
  // otherwise report at the first note, far from the mistake. `_closing`
  // carries the message; this throws its result away.
  let _ = _closing(on, none)
  (..args) => todo(done: on, ..args)
}

// ---- #epic — a factory grouping todos by a shared tag ---------------------
//
//   #let launch = epic("launch")
//   #launch("a")[Do a.]
//   #launch("b", deps: ("a",))[Do b.]
//
// `epic(name)` returns a `#todo` VARIANT with the tag `epic-<name>` bound, so
// membership in an epic is one more tag on the note and nothing else.
//
// A FACTORY, not a function taking a list of todo specifications. The factory
// is one more application of rookery's `tagged-idea` composition, so it keeps
// `#todo`'s entire call surface — content bodies, all three id forms, every
// named argument — with no argument forwarding to reimplement. The rejected
// alternative, `#epic("launch", (name: "a", body: [..]), ..)`, forces note
// bodies into dictionary values and reads worse for it.
//
// AN EPIC IS A TAG, NOT A CONTAINMENT EDGE. It creates no parent/child
// relationship and implies no dependency: todos are networked purely through
// `deps:`, and two todos in one epic are unrelated until one names the other.
// This is also why there is no `todo-parent` key anywhere in this package.
//
// The tag is namespaced `epic-<name>` per rookery's key convention, so it
// cannot collide with a free author tag and `tags:epic-launch` works in
// @rheo/rookery-search. It is FLAT (value `none`), so it renders as a pill and
// wears an `.idea-tag-epic-launch` class like any other plain tag.
#let epic(name) = {
  assert(
    std.type(name) == str and name.len() > 0,
    message: "@rheo/rookery-todos: `epic` takes a name string — got " + repr(name),
  )
  // A tag key becomes a CSS class fragment, so the name has to survive as one.
  assert(
    name.match(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$")) != none,
    message: "@rheo/rookery-todos: epic name \"" + name + "\" is not usable as a "
      + "CSS class fragment — it becomes `.idea-tag-epic-" + name + "`. Use "
      + "alphanumerics and interior hyphens only.",
  )
  let key = "epic-" + name
  (tags: none, ..args) => todo(tags: _norm-tags-local(tags) + ((key): none), ..args)
}

// The epic a todo belongs to, or `none`. Takes the tag DICTIONARY, like every
// other reader here.
#let epic-of(tags) = {
  let hit = tags.keys().find(k => k.starts-with("epic-"))
  if hit == none { none } else { hit.slice("epic-".len()) }
}
