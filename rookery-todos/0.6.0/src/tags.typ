// The tag mapping: how a todo's attributes become keys in rookery's tag dict.
//
// THREE SURFACES, and the split is the whole design of this package. Read this
// before adding an attribute.
//
// 1. FLAT, KEY ENCODES THE VALUE — `todo`, `todo-p0`..`todo-p4`, `todo-<type>`,
//    `todo-<status>`. Value `none`, so each renders as a pill, emits a
//    `.idea-tag-<key>` class, and is filterable by rookery's own
//    `#window(tags:)`/`#ideas(tags:)` AND by @rheo/rookery-search's tag query
//    language. That last one is the payoff and it costs this package nothing:
//    `tags:todo&!todo-closed` in a search bar lists open todos with no
//    rookery-todos code involved at all.
//
// 2. VALUED — `todo-closed`, `todo-deps`, `todo-metadata`. A valued tag renders
//    no pill but IS still presence-filterable by key, because rookery's tag
//    predicate tests keys (MEASURED: `"a" in (a: 1)` is `true`). So most
//    attributes need no duplication into surface 1; only the ones you want to
//    filter BY VALUE over a small finite domain get key-encoded.
//
// 3. NOT TAGS OF OURS AT ALL — labels are PLAIN, UNNAMESPACED rookery tags,
//    because a todo's labels ARE rookery tags and namespacing them would break
//    exactly the filtering and theming that is the point. EVERY DATE comes from
//    @rheo/rookery-dates' `date-log`, including the one this package used to
//    store itself (see `CLOSED-KEY` below). `created` comes from rookery's own
//    row field; there is no `updated` field any more — rookery-dates derives
//    last-touched from the log.
//
// DERIVED, NEVER STORED: `blocked`, `ready`, `stale`. Tagging them would let
// them go stale against the deps and dates that define them. See `graph.typ`.
//
// DELIBERATELY ABSENT: any parent/child key. Todos are networked purely through
// `todo-deps`; an epic is a tag, not a containment edge.

// The log readers and the reserved stage names this package builds on. `closed`
// is one of rookery-dates' three reserved stages, so this package names it
// through the exported constant rather than hardcoding the string.
#import "@rheo/rookery-dates:0.6.0": CLOSED-STAGE, has-stage, stage-date

// The base key every todo carries.
#let TODO-KEY = "todo"

// br's own issue types, adopted verbatim so a reader coming from beads meets
// the same vocabulary. Each becomes a flat `todo-<type>` key.
#let TYPES = ("task", "bug", "feature", "epic", "chore", "docs", "question")

// br's non-closed statuses. `closed` is NOT here: it is expressed by the
// PRESENCE of the valued `todo-closed` key, whose value is when it closed, so
// a second flat key for it would be one fact stored twice. `blocked` is not
// here either — it is derived from dependencies, never declared.
#let STATUSES = ("in-progress", "deferred", "draft")

// THIS PACKAGE'S OWN LOG STAGE, and the only one it names. rookery-dates
// reserves `scheduled`, `deadline` and `closed` and leaves every other stage
// name to its consumers — its `src/lib.typ` header says outright that status
// transitions "belong to whoever owns the status", which is this package.
//
// `activated` is the moment a todo went from ready to actually being worked on:
// the transition `status: "in-progress"` records as a STATE, given a date. The
// two are not redundant — the flat `todo-in-progress` key is what a tag query
// filters on, and the log entry is what says since when.
#let ACTIVATED-STAGE = "activated"

// The valued keys. Namespaced with a `todo-` prefix per rookery's convention:
// a key becomes a CSS class fragment, and a bare `deps` is a generic name two
// packages could both claim.
#let DEPS-KEY = "todo-deps"
#let METADATA-KEY = "todo-metadata"

// `todo-closed` IS NO LONGER A VALUED KEY. The date a todo closed lives in
// @rheo/rookery-dates' `date-log`, under its reserved `closed` stage, alongside
// every other dated event in the todo's life — which is the whole point of
// 0.6.0: one store for a todo's timeline instead of a valued tag here, two date
// keys there, and core's `updated` somewhere else again.
//
// WHAT THIS KEY STILL IS: a FLAT presence marker, valued `none`, written
// alongside the log entry. It carries no date and is not a second copy of one.
// It exists for one reason, and the header above already calls that reason the
// payoff of the flat-tag surface: `tags:todo&!todo-closed` in a search bar lists
// the open todos with no rookery-todos code involved. Rookery's tag predicate
// and rookery-search's `tags:` query both test KEYS, so a fact living only
// inside `date-log`'s value is invisible to them. Losing that query to buy
// tidiness would have been a bad trade.
//
// So: presence here, date in the log, and `is-closed` below reads either.
#let CLOSED-KEY = "todo-closed"

// A local copy of rookery's four-form tag normalizer, so this module stays a
// pure function of its arguments and the merge below cannot depend on which
// form the caller wrote.
//
// Deliberately NOT an import of rookery's private `_norm-tags`: this is six
// lines, and a package reaching into another package's underscore names to
// save them is a dependency on an internal that can move without notice.
//
// Defined ABOVE its caller because a `#let` closure captures the scope visible
// AT DEFINITION time — a helper defined further down is invisible.
#let _norm-tags-local(v) = {
  if v == none {
    (:)
  } else if std.type(v) == str {
    ((v): none)
  } else if std.type(v) == dictionary {
    v
  } else {
    v.fold((:), (d, t) => { d.insert(t, none); d })
  }
}

// `#todo`'s arguments, folded into one tag dictionary.
//
// `kind` rather than `type`, and that is not a style choice: a parameter named
// `type` SHADOWS Typst's built-in `type()` for the whole function body, so
// every type assertion below would try to call a string. `#todo` keeps the
// friendlier `type:` in its public signature and renames on the way in.
//
// `tags` is the caller's own — labels, and anything else they want — and it is
// MERGED LAST so a caller naming one of our keys wins outright. There is no
// deep merge; a caller who writes `tags: (todo-deps: ..)` means it.
//
// `norm` is rookery's `_norm`, passed IN rather than imported here, so this
// module keeps no rookery dependency of its own and stays unit-testable with a
// stub. `todo.typ` supplies the real one.
//
// EMPTY MEANS ABSENT for the valued keys: an empty `deps` array or an empty
// `metadata` dict emits NO KEY. A key present with an empty value would read as
// "has dependencies, namely none", and would put a meaningless
// `.idea-tag-todo-deps` class on the note.
//
// `closed: false` LIKEWISE EMITS NOTHING. Presence is the status signal here,
// so a `todo-closed` key valued `false` would mark every open todo as closed to
// any consumer testing for the key — including rookery's own `tags:` filter and
// rookery-search's `tags:todo-closed`. `closed: true` emits the key with value
// `none`; `closed: <datetime>` emits it with the date it closed.
#let todo-tags(
  tags: none,
  priority: none,
  kind: none,
  status: none,
  closed: none,
  deps: (),
  metadata: (:),
  norm: it => it,
) = {
  let out = ((TODO-KEY): none)

  if priority != none {
    assert(
      type(priority) == int and priority >= 0 and priority <= 4,
      message: "@rheo/rookery-todos: `priority` must be an integer 0-4 "
        + "(0 = critical, 4 = backlog), matching br's own scale — got "
        + repr(priority),
    )
    out.insert("todo-p" + str(priority), none)
  }

  if kind != none {
    assert(
      kind in TYPES,
      message: "@rheo/rookery-todos: `type` must be one of "
        + TYPES.join(", ") + " — got " + repr(kind),
    )
    out.insert("todo-" + kind, none)
  }

  if status != none {
    assert(
      status in STATUSES,
      message: "@rheo/rookery-todos: `status` must be one of "
        + STATUSES.join(", ") + " — got " + repr(status)
        + ". A CLOSED todo is expressed by `closed:`, not by `status:`, and a "
        + "BLOCKED one is derived from its dependencies rather than declared.",
    )
    out.insert("todo-" + status, none)
  }

  // A DATE IS NOW REQUIRED, where `closed: true` used to mean "closed, when
  // unknown". Closing is a dated event in the log as of 0.6.0, and an entry
  // needs a date. This package cannot invent one — there is no wall clock to
  // stamp from, which its own header records — so an undated close is simply a
  // caller who did not say when, and the message says so rather than guessing.
  //
  // Only the FLAT marker is written here. `#todo` puts the date itself into the
  // log through rookery-dates' decorator; see `todo.typ`.
  if closed != none and closed != false {
    assert(
      type(closed) == datetime,
      message: "@rheo/rookery-todos: `closed` must be the datetime it closed — got "
        + repr(closed)
        + ". `closed: true` no longer works: a close is a dated entry in "
        + "@rheo/rookery-dates' log as of 0.6.0, and this package has no clock to "
        + "stamp one from. Give the date.",
    )
    out.insert(CLOSED-KEY, none)
  }

  if deps != none {
    assert(
      type(deps) == array,
      message: "@rheo/rookery-todos: `deps` must be an array of note names — got "
        + repr(deps),
    )
    if deps.len() > 0 { out.insert(DEPS-KEY, deps.map(norm)) }
  }

  if metadata != none {
    assert(
      type(metadata) == dictionary,
      message: "@rheo/rookery-todos: `metadata` must be a dictionary — got "
        + repr(metadata),
    )
    if metadata.len() > 0 { out.insert(METADATA-KEY, metadata) }
  }

  // The caller's own tags LAST, so their keys win on a collision. MEASURED:
  // typst dictionary `+` is right-wins, which is exactly the precedence wanted.
  out + _norm-tags-local(tags)
}

// ---- Readers over a todo's tag dictionary ---------------------------------
//
// Each takes the DICT — what `#tag-data()` hands back per note — rather than a
// note name, so they stay pure and a caller walking the corpus pays one
// registry read for everything rather than one per note per question.

// Is this note a todo at all?
#let is-todo(tags) = TODO-KEY in tags

// Closed is PRESENCE — of the flat marker `#todo` writes, or of a `closed` entry
// in the log. EITHER, so a note whose log was written directly through
// `dates(log: (closed: d))` without going through `#todo` still reads as closed
// rather than silently open.
#let is-closed(tags) = CLOSED-KEY in tags or has-stage(tags, CLOSED-STAGE)

// The date it closed, from the log. `none` where the marker is present but no
// dated entry is — which `#todo` cannot produce, but a hand-written note can.
#let closed-on(tags) = stage-date(tags, CLOSED-STAGE)

// The names this todo depends on, already normalized at write time.
#let deps-of(tags) = tags.at(DEPS-KEY, default: ())

// The catch-all bag: estimate, assignee, close-reason, external-ref, whatever
// a project put there.
#let metadata-of(tags) = tags.at(METADATA-KEY, default: (:))

// Priority back out of the key that encodes it, or `none` when unset. Decoded
// rather than stored separately, so the filterable surface and the sortable
// value cannot disagree.
#let priority-of(tags) = {
  let hit = range(5).find(n => ("todo-p" + str(n)) in tags)
  hit
}

// The declared type, or `none`. Same decode-don't-duplicate rule as priority.
#let type-of(tags) = TYPES.find(t => ("todo-" + t) in tags)

// The declared status. `closed` wins over any declared status, because the
// closed key is the stronger statement; otherwise the first declared status,
// else "open". `blocked` never appears here — ask the graph.
#let status-of(tags) = {
  if is-closed(tags) { return "closed" }
  let hit = STATUSES.find(s => ("todo-" + s) in tags)
  if hit == none { "open" } else { hit }
}
