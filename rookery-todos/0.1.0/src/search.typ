// `#todos-search` — a filter box over the todos, with the matches listed below
// it as links to each todo's minted page.
//
// WHY THIS IS NOT `@rheo/rookery-search`. That package already offers a fuzzy,
// todos-only bar: `#search-bar(tags: "todo")`. Two things it cannot do, and
// cannot be taught to do, are what this widget is for:
//
//   1. `ready` and `blocked` pills. Both are DERIVED from the dependency graph
//      and the calendar at build time (`graph.typ`), deliberately never stored
//      as tags — so no tag query, including rookery-search's, can select them.
//      That is the load-bearing difference.
//   2. An in-page list rather than a popup. rookery-search's surfaces are a
//      combobox with a listbox and a modal overlay; this is a filter over a
//      list already on the page. The todos stay visible and typing narrows them
//      where they sit.
//
// THIS WIDGET therefore reaches for nothing in `@rheo/rookery-search`: it renders
// its own bar, its own pills and its own list, and a project wanting only
// `#todos-search` needs nothing but this package and `@rheo/rookery`.
//
// THAT USED TO BE WRITTEN AS A RULE ABOUT THE WHOLE PACKAGE — "MUST NOT depend on
// @rheo/rookery-search" — and it was too strong. `panel.typ` now skins that
// package's `#filter-panel`, for the reason point 1 above states: `ready` and
// `blocked` are derived HERE and nowhere else, so a panel that cannot press them is
// the one thing every consuming site ends up hand-rolling. The two facts sit side by
// side — this file needs no panel, and the panel needs this file's graph.
//
// LINKS, NOT TRANSCLUSIONS. Every match is the same link row the other views
// emit. (`windows: true` on those views is a separate feature and this widget
// does not use it.)
//
// NO JSON ISLAND. Every fact the filter needs rides as a `data-` attribute on
// the row carrying it, so the payload and the markup cannot disagree — and with
// no JavaScript the rendering is the full readable list rather than an empty
// container waiting to be filled.

#import "target.typ": *
#import "tags.typ": *
#import "graph.typ": *
#import "views.typ": *

// A todos() row's body as a plain string, `""` when it has none. Rookery
// publishes `body` already flattened; this only guards the missing key so a row
// from some other shape reads as empty rather than hard-failing.
#let _plain-body(row) = {
  let b = row.at("body", default: "")
  if type(b) == str { b } else { "" }
}

// One result row: `_row`'s shape plus the attributes the filter reads.
//
// A SEPARATE HELPER rather than a parameter on `_row`: this is the only caller
// that wants data attributes, and widening `_row` would put them on every view.
//
// NO ID IN THE MARKUP. A hardcoded id cannot appear twice on a page, and
// nothing stops a project putting two of these widgets on one. rookery-search
// documents the same rule and assigns ids at runtime; the JS here wires
// `aria-controls` from the input to the list element it already holds.
#let _search-row(row, status) = html.elem(
  "li",
  attrs: (
    class: _row-classes(row, extra: ("todo-search-row",)),
    "data-todo-name": row.name,
    "data-todo-status": status,
    "data-todo-type": if row.kind == none { "" } else { row.kind },
    // The haystack: title, name and body, lowercased. Searching the BODY is the
    // point — it is what makes this more than a title filter, and it costs one
    // string attribute rather than a transcluded body.
    "data-todo-text": lower(
      (row.text, row.name, _plain-body(row)).filter(s => s != "" and s != none).join(" "),
    ),
  ),
  {
    let label = _label(row)
    // `href` is `none` where nothing mints pages, so a row degrades to
    // unlinked text rather than a dead anchor — the same rule `_row` follows.
    if row.href == none {
      html.elem("span", attrs: (class: "todo-row-title"), label)
    } else {
      html.elem("a", attrs: (class: "todo-row-title", href: row.href), label)
    }
  },
)

// The status stamped into each row, computed HERE at build time and never in
// the browser — the same ladder `#todo-graph-view` uses, against the FULL
// graph. A todo whose only dependency is closed is ready, and only the full
// graph can say so.
#let _search-status(row, graph, today) = {
  if is-blocked(row, graph) {
    "blocked"
  } else if is-ready(row, graph, today: today) {
    "ready"
  } else if row.status != none { row.status } else { "open" }
}

/// A text input that fuzzy-filters the todos as you type, with the matches
/// listed below it as links, and pills that further refine the set.
///
/// `closed: false` is the DEFAULT here, unlike `#todos-list` where it is
/// `true`: a filter box is for finding live work.
#let todos-search(
  title: none,
  placeholder: "Filter todos",
  today: none,
  closed: false,
) = context {
  let graph = todo-graph()
  assert-acyclic(graph)
  let rows = todos()
  if not closed { rows = rows.filter(r => not r.closed) }
  rows = _by-priority(rows)

  // A PDF has no input to type into, so it gets the plain list it already knows
  // how to render. Same branch every view here takes, for the same reason.
  if not _is-markup() { return _list(title, rows, [No todos.]) }

  let statuses = rows.map(r => (r.name, _search-status(r, graph, today))).to-dict()

  // One pill per type ANY LISTED ROW ACTUALLY HAS, in `TYPES` order. A pill for
  // a type no row carries is a filter that can only ever return nothing.
  let present-types = TYPES.filter(t => rows.any(r => r.kind == t))

  let pill(facet, value, label) = html.elem(
    "button",
    attrs: (
      type: "button",
      class: "todo-search-pill",
      "data-todo-facet": facet,
      "data-todo-value": value,
      "aria-pressed": "false",
    ),
    label,
  )

  html.elem(
    "div",
    // `false` until the script has wired itself up. The stylesheet hides the
    // input and the pills while it says so, which is how the widget degrades:
    // with no JavaScript the chrome that would do nothing never appears, and
    // the rows below it are simply a list.
    attrs: (class: "todo-search", "data-todo-search-ready": "false"),
    {
      if title != none {
        html.elem("div", attrs: (class: "todo-view-title"), title)
      }
      html.elem(
        "input",
        attrs: (
          class: "todo-search-input",
          type: "search",
          placeholder: placeholder,
          "aria-label": placeholder,
          autocomplete: "off",
        ),
      )
      html.elem(
        "div",
        attrs: (class: "todo-search-pills", role: "group", "aria-label": "Refine"),
        {
          pill("status", "ready", "ready")
          pill("status", "blocked", "blocked")
          present-types.map(t => pill("type", t, t)).join()
        },
      )
      html.elem(
        "p",
        attrs: (class: "todo-search-count", "aria-live": "polite"),
        str(rows.len()) + " todos",
      )
      html.elem(
        "ul",
        // The package's own list class as well as this widget's, so the rows
        // inherit the styling every other view's rows have.
        attrs: (class: "todo-list todo-search-results"),
        rows.map(r => _search-row(r, statuses.at(r.name))).join(),
      )
    },
  )
}
