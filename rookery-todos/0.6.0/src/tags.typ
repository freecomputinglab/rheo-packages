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
//    exactly the filtering and theming that is the point. Dates come from
//    @rheo/rookery-dates. Created/updated come from rookery's own
//    `minted`/`updated`.
//
// DERIVED, NEVER STORED: `blocked`, `ready`, `stale`. Tagging them would let
// them go stale against the deps and dates that define them. See `graph.typ`.
//
// DELIBERATELY ABSENT: any parent/child key. Todos are networked purely through
// `todo-deps`; an epic is a tag, not a containment edge.

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

// The valued keys. Namespaced with a `todo-` prefix per rookery's convention:
// a key becomes a CSS class fragment, and a bare `deps` is a generic name two
// packages could both claim.
#let CLOSED-KEY = "todo-closed"
#let DEPS-KEY = "todo-deps"
#let METADATA-KEY = "todo-metadata"

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

  if closed != none and closed != false {
    assert(
      closed == true or type(closed) == datetime,
      message: "@rheo/rookery-todos: `closed` must be a boolean or a datetime "
        + "(the date it closed) — got " + repr(closed),
    )
    out.insert(CLOSED-KEY, if closed == true { none } else { closed })
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

// Closed is PRESENCE of the key. Its value, when there is one, is the date.
#let is-closed(tags) = CLOSED-KEY in tags
#let closed-on(tags) = tags.at(CLOSED-KEY, default: none)

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
