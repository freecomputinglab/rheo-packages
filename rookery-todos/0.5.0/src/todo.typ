// `#todo` — the package's primitive, an `#idea` variant carrying todo tags.

#import "@rheo/rookery:0.5.0": tagged-idea, _norm
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
// does not itself consume: `title`, `level`, `minted`, `updated`, `show-date`,
// `show-tags`.
//
// DATES ARE NOT PARAMETERS HERE. `scheduled`/`deadline` come from
// @rheo/rookery-dates and merge through `tags:`:
//
//   #todo("ship", tags: dates(deadline: d))[..]
//
// and created/updated are rookery's own `minted`/`updated`, forwarded through
// `..args`. Nothing in this package auto-stamps a date; there is no wall clock
// to stamp from (see rookery-dates' readme for the measured evidence).
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
  closed: none,
  deps: (),
  metadata: (:),
  tags: none,
  ..args,
) = (tagged-idea(TODO-KEY))(
  tags: todo-tags(
    tags: tags,
    priority: priority,
    // Renamed on the way in: a parameter named `type` shadows Typst's built-in
    // `type()` for the whole callee body, and `todo-tags` needs that builtin.
    kind: type,
    status: status,
    closed: closed,
    deps: deps,
    metadata: metadata,
    // Rookery's own name normalizer, so a dep written as a bare name, a full
    // `idea:x` id or a label `<x>` all resolve to the same string — the same
    // set of forms `#window` and `#hyperlink` accept.
    norm: _norm,
  ),
  ..args,
)
