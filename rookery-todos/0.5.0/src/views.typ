// The rendered views — br's derived reports, as HTML over the graph.
//
// Every view here answers a question br answers with a subcommand: `todos-list`
// is `br list`, `todos-ready` is `br ready`, `todos-blocked` is `br blocked`,
// `todos-stale` is `br stale`, `todos-stats` is `br stats`. What is NOT here is
// br's MUTATION surface — `update`, `close`, `dep add` — because a status
// change in a static build is an edit to a `.typ` file.
//
// TWO RULES EVERY VIEW FOLLOWS:
//
//  1. It runs the cycle check before rendering. A cyclic graph has no order to
//     present, and this is half of what makes a cycle impossible to ship (the
//     other half is `#todos-validate()` for a project that renders no view).
//  2. It takes `today:` where it needs a reference date, and never calls
//     `datetime.today()`. That returns 1980-01-01 under a reproducible build
//     and DOES NOT ERROR — a stale-todo report built on it would silently list
//     the whole project. @rheo/rookery-dates resolves `today:` against the
//     document date and panics when neither is available.

#import "@rheo/rookery:0.5.0": ideas
#import "@rheo/rookery-dates:0.5.0": deadline-of, is-overdue, scheduled-of
#import "tags.typ": *
#import "todo.typ": *
#import "graph.typ": *

// A row's own tag classes, so a project stylesheet can target
// `.idea-tag-todo-p0` or `.idea-tag-todo-closed` on a list row exactly as it
// targets them on a note's card. Same convention rookery's own outline rows
// use — one rule, three emission sites.
#let _row-classes(row, extra: ()) = (
  ("todo-row",) + extra + row.tags-dict.keys().map(k => "idea-tag-" + k)
).join(" ")

// One row: a link to the note, its title (or its name when untitled), and
// whatever trailing note the view wants to add.
#let _row(row, extra: (), trailing: none) = html.elem(
  "li",
  attrs: (class: _row-classes(row, extra: extra)),
  {
    let label = if row.title == none { raw(row.name) } else { row.title }
    // `href` is `none` where nothing mints pages (a plain `typst compile`, or
    // rheo with minting off), so the row degrades to unlinked text rather than
    // emitting a dead anchor.
    if row.href == none {
      html.elem("span", attrs: (class: "todo-row-title"), label)
    } else {
      html.elem(
        "a",
        attrs: (class: "todo-row-title", href: row.href),
        label,
      )
    }
    if trailing != none {
      html.elem("span", attrs: (class: "todo-row-note"), trailing)
    }
  },
)

// The shared frame: an optional title, then the rows, then an empty-state line
// rather than a bare empty list — "nothing is blocked" is a useful answer and a
// silent gap is not.
#let _list(title, rows, empty, extra: (), trailing: r => none) = html.elem(
  "div",
  attrs: (class: "todo-view"),
  {
    if title != none {
      html.elem("div", attrs: (class: "todo-view-title"), title)
    }
    if rows.len() == 0 {
      html.elem("p", attrs: (class: "todo-view-empty"), empty)
    } else {
      html.elem(
        "ul",
        attrs: (class: "todo-list"),
        rows.map(r => _row(r, extra: extra, trailing: trailing(r))).join(),
      )
    }
  },
)

// Newest-looking order first: by priority (0 is critical), then by name so the
// order is stable across builds and a diff of generated output means something.
// An unprioritised todo sorts last, not first — no priority is not urgency.
#let _by-priority(rows) = rows.sorted(key: r => (
  if r.priority == none { 9 } else { r.priority },
  r.name,
))

// ---- #todos-list — br `list` -----------------------------------------------
//
// The general, filterable view. Its parameter vocabulary deliberately mirrors
// rookery's own `#ideas-outline` — `tags:`, `match:`, `filter:`, `limit:`,
// `title:` — so an author meets ONE idiom rather than two that nearly agree.
//
// `filter:` receives the tag DICTIONARY, as it does in rookery 0.5.0, so it can
// select on a value: `filter: t => t.at("todo-metadata", default: (:)).at(
// "assignee", default: none) == "lox"`.
#let todos-list(
  title: none,
  tags: none,
  match: "any",
  filter: none,
  limit: none,
  closed: true,
) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  let rows = todos()
  if not closed { rows = rows.filter(r => not r.closed) }
  if tags != none {
    let want = if std.type(tags) == str { (tags,) } else { tags }
    rows = rows.filter(r => if match == "all" {
      want.all(t => t in r.tags-dict)
    } else {
      want.any(t => t in r.tags-dict)
    })
  }
  if filter != none { rows = rows.filter(r => filter(r.tags-dict)) }
  rows = _by-priority(rows)
  if limit != none { rows = rows.slice(0, calc.min(limit, rows.len())) }
  _list(title, rows, [No todos.])
}

// ---- #todos-ready — br `ready` ---------------------------------------------
//
// Open, unblocked, and not deferred past `today`. The deferral clause is what
// makes this br's `ready` rather than merely "not blocked" — see `is-ready`.
#let todos-ready(title: none, today: none, limit: none) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  let rows = _by-priority(todos().filter(r => is-ready(r, graph, today: today)))
  if limit != none { rows = rows.slice(0, calc.min(limit, rows.len())) }
  _list(title, rows, [Nothing is ready.], extra: ("todo-row-ready",))
}

// ---- #todos-blocked — br `blocked` -----------------------------------------
//
// Open todos with at least one unclosed dependency, EACH NAMING WHAT BLOCKS IT.
// The naming is the whole value of the view: a list of blocked things without
// their blockers tells you nothing you could act on.
#let todos-blocked(title: none) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  let rows = _by-priority(
    todos().filter(r => not r.closed and is-blocked(r, graph)),
  )
  _list(
    title,
    rows,
    [Nothing is blocked.],
    extra: ("todo-row-blocked",),
    trailing: r => [blocked by #blockers-of(r, graph).join(", ")],
  )
}

// ---- #todos-stale — br `stale` ---------------------------------------------
//
// Open todos untouched for more than `older-than` days. `updated` is ROOKERY
// CORE's field, not a tag of ours — rookery already resolves it from
// `#idea(updated:)`, then `minted`, then the document date.
//
// A todo with NO date at all is not stale: nothing is known about when it was
// touched, and reporting silence as staleness would flag every undated project
// wholesale.
#let todos-stale(title: none, today: none, older-than: 30) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  assert(
    std.type(older-than) == int and older-than >= 0,
    message: "@rheo/rookery-todos: `older-than` must be a non-negative integer "
      + "number of days — got " + repr(older-than),
  )
  // "Untouched since `updated` + N days" is the same question as "is that date
  // in the past", so it goes through rookery-dates' `is-overdue` rather than a
  // second date comparison written here. That keeps ONE answer to "what is
  // now" in the whole stack — including its panic when there is none, and its
  // MEASURED handling of an unset document date, which is `auto` and not
  // `none`.
  let stale(u) = is-overdue(("date-deadline": u + duration(days: older-than)), today: today)
  let rows = todos().filter(r => {
    if r.closed { return false }
    if r.updated == none { return false }
    stale(r.updated)
  })
  _list(
    title,
    _by-priority(rows),
    [Nothing is stale.],
    extra: ("todo-row-stale",),
    trailing: r => [last touched #r.updated.display("[year]-[month]-[day]")],
  )
}

// ---- #todos-stats — br `stats` / `count` -----------------------------------
//
// Totals by status, priority and type, over every todo in the rookery.
#let todos-stats(title: none, today: none) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  let rows = todos()
  let count(pred) = rows.filter(pred).len()

  let cell(k, v) = html.elem(
    "li",
    attrs: (class: "todo-stat"),
    html.elem("span", attrs: (class: "todo-stat-key"), k)
      + html.elem("span", attrs: (class: "todo-stat-value"), str(v)),
  )

  html.elem(
    "div",
    attrs: (class: "todo-view todo-stats"),
    {
      if title != none {
        html.elem("div", attrs: (class: "todo-view-title"), title)
      }
      html.elem(
        "ul",
        attrs: (class: "todo-stat-list"),
        {
          cell("total", rows.len())
          cell("open", count(r => not r.closed))
          cell("closed", count(r => r.closed))
          cell("blocked", count(r => not r.closed and is-blocked(r, graph)))
          cell("ready", count(r => is-ready(r, graph, today: today)))
          for n in range(5) {
            let c = count(r => r.priority == n)
            if c > 0 { cell("p" + str(n), c) }
          }
          for t in TYPES {
            let c = count(r => r.kind == t)
            if c > 0 { cell(t, c) }
          }
        },
      )
    },
  )
}
