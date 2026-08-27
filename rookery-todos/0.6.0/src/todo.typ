// `#todo` — the package's primitive, an `#idea` variant carrying todo tags.

#import "@rheo/rookery:0.6.0": tagged-idea, _norm
#import "@rheo/rookery-dates:0.6.0": CLOSED-STAGE, dated
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
// EVERY DATE A TODO CARRIES BELONGS TO @rheo/rookery-dates, in its entirety.
// `#todo` is built on that package's `dated(..)` decorator, so `scheduled:`,
// `deadline:` and `log:` are its named arguments passed straight through:
//
//   #todo("ship", deadline: d, log: (activated: d2, closed: d3))[..]
//
// WHAT THIS PACKAGE CONTRIBUTES IS A VOCABULARY, not storage: the stage names
// `activated` and `closed` (see `ACTIVATED-STAGE` and rookery-dates'
// `CLOSED-STAGE`), the `TODO-LADDER` that orders them, and the views. There is no
// `closed:` argument — a close is `log: (closed: d)`, one way to write one fact.
//
// The old form still works and is still supported — `dated` merges its fragment
// into whatever `tags:` the caller passed — so `#todo("ship", tags: dates(deadline: d))`
// is unchanged:
//
//   #todo("ship", tags: dates(deadline: d))[..]
//
// `created` is rookery's own row field, forwarded through `..args`. There is no
// `updated`: rookery removed it in 0.6.0 and rookery-dates derives last-touched
// from the log. Nothing in this package auto-stamps a date; there is no wall
// clock to stamp from (see rookery-dates' readme for the measured evidence).
//
// `closed:` IS A DATE, and it goes into the log rather than onto a valued tag —
// see `CLOSED-KEY` in `tags.typ` for why the flat marker stays beside it.
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
  log: none,
  ..args,
) = (dated(tagged-idea(TODO-KEY)))(
  log: log,
  tags: todo-tags(
    tags: tags,
    priority: priority,
    // Renamed on the way in: a parameter named `type` shadows Typst's built-in
    // `type()` for the whole callee body, and `todo-tags` needs that builtin.
    kind: type,
    status: status,
    // THE FLAT MARKER IS DERIVED FROM THE LOG, not from an argument. There used
    // to be a `closed:` parameter beside `log:`, and the two were not
    // equivalent: MEASURED, `#todo("a", closed: d)` carried `todo-closed` while
    // `#todo("b", log: (closed: d))` did not, so the second read as closed to
    // `is-closed` and as OPEN to `tags:todo&!todo-closed` — the query this
    // package's own header calls the payoff of the flat-tag surface. Two ways to
    // write one fact, one of them silently unfilterable.
    //
    // Deriving it here is what makes them one way. `todo-tags` cannot do it: it
    // builds this package's keys and never sees the log, which belongs to
    // @rheo/rookery-dates.
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
