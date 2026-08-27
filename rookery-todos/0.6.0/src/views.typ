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

#import "@rheo/rookery:0.6.0": ideas, window
#import "@rheo/rookery-dates:0.6.0": dates, deadline-of, is-overdue, scheduled-of, updated-of
#import "target.typ": *
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

// A row's label: its title, or its name when untitled.
#let _label(row) = if row.title == none { raw(row.name) } else { row.title }

// One row: a link to the note, its label, and whatever trailing note the view
// wants to add.
//
// `href` is `none` where nothing mints pages (a plain `typst compile`, or rheo
// with minting off), so a row degrades to unlinked text rather than emitting a
// dead anchor. A PAGED target has no minted pages to link to at all, which is
// why its branch never builds one.
#let _row(row, extra: (), trailing: none) = html.elem(
  "li",
  attrs: (class: _row-classes(row, extra: extra)),
  {
    let label = _label(row)
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

// The same row on a paged target, as plain Typst content.
#let _row-paged(row, trailing: none) = {
  let label = _label(row)
  if row.closed { strike(label) } else { label }
  if trailing != none { [ #text(gray, trailing)] }
}

// The shared frame: an optional title, then the rows, then an empty-state line
// rather than a bare empty list — "nothing is blocked" is a useful answer and a
// silent gap is not.
#let _list(title, rows, empty, extra: (), trailing: r => none) = {
  if _is-markup() {
    return html.elem(
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
  }
  // PAGED. `align(start)` is load-bearing, and it is the same trap rookery
  // documents at `idea.typ`'s paged branch: this content can sit inside a
  // Typst `figure`, and a figure CENTRES its body — which on a paged target
  // centred every row rather than leaving it at the text margin.
  align(start, {
    if title != none { strong(title); linebreak() }
    if rows.len() == 0 {
      text(gray, emph(empty))
    } else {
      list(..rows.map(r => _row-paged(r, trailing: trailing(r))))
    }
  })
}

// ---- _windows — the same rows, as folded transclusions --------------------
//
// `#todos-*(windows: true)` renders each row as a folded `#window` instead of a
// link, so a reader unfolds a todo's body in place rather than clicking through
// to its minted page.
//
// WHY THIS LIVES IN THE PACKAGE and not in a caller: `ready` and `blocked` are
// DERIVED from the dependency graph and the calendar (`is-ready`, `is-blocked`
// in `graph.typ`), never stored as tags — so no `#window(tags: ..)` selection
// can express them. Only code that has already computed the rows can hand
// `#window` the names, and that code is here.
//
// ONE `#window` CALL PER ROW, not one array call. `#window` does accept an
// array of names, and that form would cost one registry read instead of N —
// but it cannot interleave the per-row `trailing` note, and that note is the
// entire value of `#todos-blocked` ("blocked by X, Y"). The per-row cost is
// what `#window` already costs everywhere else it is used.
// THESE WINDOWS DO PRODUCE BACKLINKS, and that took a rookery fix. The backlink
// walk reads a page's content at `#show: rookery` time, which cannot enter a
// `context` block — and these views must run inside one, since the graph and
// the reference date resolve nowhere else. A window emitted from here therefore
// announced itself to nobody, and every note the view unfolded lost its
// backlink from the page unfolding it. MEASURED, then fixed in rookery by
// labelling `#window`'s announce marker and collecting those by `query()`,
// which sees them wherever the window was written.
//
// So a `windows: true` view is a real reference and shows up as one. Documented
// in the readme, because a busy index becomes a backlink on everything it
// lists.
#let _windows(title, rows, empty, trailing: r => none) = {
  // PAGED FIRST. A PDF or EPUB page has no fold to click, so those targets keep
  // the link list they already render. Deliberate, not a stub — see `_list`.
  if not _is-markup() { return _list(title, rows, empty, trailing: trailing) }

  html.elem(
    "div",
    attrs: (class: "todo-view todo-windows"),
    {
      if title != none {
        html.elem("div", attrs: (class: "todo-view-title"), title)
      }
      if rows.len() == 0 {
        html.elem("p", attrs: (class: "todo-view-empty"), empty)
      } else {
        rows
          .map(r => html.elem(
            "div",
            // NOT `_row-classes`, and this is the reason: that prepends
            // `todo-row`, which the stylesheet makes a baseline-aligned flex
            // row — and a `<details>` inside one lays out wrongly. A window row
            // is a block; it only wants the note's own tag classes.
            attrs: (
              class: (("todo-window-row",) + r.tags-dict.keys().map(k => "idea-tag-" + k)).join(" "),
            ),
            {
              window(r.name, folded: true)
              let note = trailing(r)
              if note != none {
                html.elem("span", attrs: (class: "todo-row-note"), note)
              }
            },
          ))
          .join()
      }
    },
  )
}

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
  windows: false,
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
  if windows { _windows(title, rows, [No todos.]) } else { _list(title, rows, [No todos.]) }
}

// ---- #todos-ready — br `ready` ---------------------------------------------
//
// Open, unblocked, and not deferred past `today`. The deferral clause is what
// makes this br's `ready` rather than merely "not blocked" — see `is-ready`.
#let todos-ready(title: none, today: none, limit: none, windows: false) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  let rows = _by-priority(todos().filter(r => is-ready(r, graph, today: today)))
  if limit != none { rows = rows.slice(0, calc.min(limit, rows.len())) }
  // `extra:` is dropped on the windows path: `todo-row-ready` styles the
  // border-left of a flex row, and a window row is neither.
  if windows {
    _windows(title, rows, [Nothing is ready.])
  } else {
    _list(title, rows, [Nothing is ready.], extra: ("todo-row-ready",))
  }
}

// ---- #todos-blocked — br `blocked` -----------------------------------------
//
// Open todos with at least one unclosed dependency, EACH NAMING WHAT BLOCKS IT.
// The naming is the whole value of the view: a list of blocked things without
// their blockers tells you nothing you could act on.
#let todos-blocked(title: none, windows: false) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  let rows = _by-priority(
    todos().filter(r => not r.closed and is-blocked(r, graph)),
  )
  let why = r => [blocked by #blockers-of(r, graph).join(", ")]
  if windows {
    _windows(title, rows, [Nothing is blocked.], trailing: why)
  } else {
    _list(
      title,
      rows,
      [Nothing is blocked.],
      extra: ("todo-row-blocked",),
      trailing: why,
    )
  }
}

// ---- #todos-stale — br `stale` ---------------------------------------------
//
// Open todos untouched for more than `older-than` days.
//
// RE-SOURCED IN 0.6.0, AND IT NOW MEASURES WHAT IT CLAIMS TO. It used to read
// rookery core's `updated` field, which resolved from `#idea(updated:)`, then
// `minted`, then the DOCUMENT's date — so on any project that did not hand-write
// an `updated:` per todo, "stale" measured how old the document was and not
// whether anything had happened. It now reads @rheo/rookery-dates'
// `updated-of(row, tags)`: the last entry in the todo's own dated log, falling
// back to `created`. A todo that was deferred, activated or otherwise touched
// says so, because touching it puts an entry in the log.
//
// A todo with NO date at all is still not stale: nothing is known about when it
// was touched, and reporting silence as staleness would flag every undated
// project wholesale.
#let todos-stale(title: none, today: none, older-than: 30, windows: false) = context {
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
  // Built through `dates(deadline: ..)` rather than by hand-writing a tag key:
  // the deadline is a STAGE in the log now, not a key of its own, and naming the
  // storage shape here would be this view knowing something only rookery-dates
  // should.
  let stale(u) = is-overdue(dates(deadline: u + duration(days: older-than)), today: today)
  let touched = r => updated-of(r, r.tags-dict)
  let rows = todos().filter(r => {
    if r.closed { return false }
    let u = touched(r)
    if u == none { return false }
    stale(u)
  })
  let when = r => [last touched #touched(r).display("[year]-[month]-[day]")]
  if windows {
    _windows(title, _by-priority(rows), [Nothing is stale.], trailing: when)
  } else {
    _list(
      title,
      _by-priority(rows),
      [Nothing is stale.],
      extra: ("todo-row-stale",),
      trailing: when,
    )
  }
}

// ---- #todos-stats — br `stats` / `count` -----------------------------------
//
// Totals by status, priority and type, over every todo in the rookery.
#let todos-stats(title: none, today: none) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  let rows = todos()
  let count(pred) = rows.filter(pred).len()

  // Built once as (key, value) pairs, rendered twice — so the two targets
  // cannot report different numbers.
  let pairs = (
    ("total", rows.len()),
    ("open", count(r => not r.closed)),
    ("closed", count(r => r.closed)),
    ("blocked", count(r => not r.closed and is-blocked(r, graph))),
    ("ready", count(r => is-ready(r, graph, today: today))),
  )
  for n in range(5) {
    let c = count(r => r.priority == n)
    if c > 0 { pairs.push(("p" + str(n), c)) }
  }
  for t in TYPES {
    let c = count(r => r.kind == t)
    if c > 0 { pairs.push((t, c)) }
  }

  if not _is-markup() {
    // `align(start)` for the same figure-centring reason as `_list` above.
    return align(start, {
      if title != none { strong(title); linebreak() }
      pairs.map(pr => text(gray, pr.at(0)) + " " + str(pr.at(1))).join(", ")
    })
  }

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
        pairs.map(pr => cell(pr.at(0), pr.at(1))).join(),
      )
    },
  )
}
