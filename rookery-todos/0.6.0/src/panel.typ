// `#filter-panel` — @rheo/rookery-search's panel, told about the todo graph.
//
// THE SKIN PATTERN, APPLIED SIDEWAYS. `skin.typ` re-exports @rheo/rookery's own
// surface with `window` overridden; this re-exports @rheo/rookery-search's
// `#filter-panel` with a version that knows what `ready` and `blocked` mean. Same
// rule as every other skin here: a site star-importing both packages gets THIS one
// as long as it imports rookery-todos LAST.
//
// THIS FILE IS THE EDGE TO @rheo/rookery-search, and it is new. `search.typ` used to
// say this package must never grow one. That rule is still right about
// `#todos-search`, which renders its own pill row and needs no panel — and it was
// wrong as a rule about the whole package. `ready` and `blocked` are derived HERE and
// nowhere else (`graph.typ`), so a panel that cannot press them is the one thing every
// consuming site ends up hand-rolling. The banner in `search.typ` now says which half
// still holds.
//
// IT DELEGATES TO `#panel`, NOT TO `#filter-panel`, and that is what buys the pill
// GROUPS. rookery-search's `#filter-panel` has one pill row and one `pill-match` for
// all of it, so `epic-jobs` + `todo-p0` UNION under the default "any" — press two,
// get more — and return nothing at all under "all", two epics being mutually
// exclusive. `#panel`'s facet mode already composes the way a reader expects
// (`panel.js`: "Within a facet the values OR .. and across facets they AND"), so
// state, epic and priority each become their own group for free.
//
// THE NAME IS THE POINT. A call site keeps writing `#filter-panel(..)`; what changes
// is that its pills are grouped and three of them are derived rather than authored.

#import "@rheo/rookery-search:0.6.0": panel
#import "@rheo/rookery:0.6.0": idea-row-body
#import "@rheo/rookery-timeline:0.1.0": deadline-of, scheduled-of
#import "target.typ": *
#import "tags.typ": *
#import "todo.typ": epic-of
#import "graph.typ": *

// SHORT AND NUMERIC, matching @rheo/rookery-search's own `_fmt-day` and
// @rheo/rookery-timeline's exactly — `27.8.26`, unpadded — so a site running two of
// these lists on one page does not show two spellings of the same kind of date.
#let _fmt-day(d) = d.display("[day padding:none].[month padding:none].[year repr:last_two]")

// The ISO form for the `datetime` attribute — zero-padded, machine-facing, and
// deliberately not what the cell shows.
#let _iso(d) = d.display("[year]-[month]-[day]")

// THE STATE FACET — where the declared status and the derived one meet.
//
// `status-of` (tags.typ) deliberately never answers "blocked": that is a question
// about the graph, and it says so. `is-ready`/`is-blocked` (graph.typ) never answer
// "in-progress": that is a declared fact, and no graph can derive it. One pill group
// needs one answer, so this is the order they resolve in.
//
// `in-progress` OUTRANKS `ready`, and that is the whole reason it is here rather than
// folded into `ready`: org-mode's STRT names the same distinction, and "someone is
// already on it" is the more useful thing to read off a list of what to pick up.
//
// The last rung is `scheduled` rather than `deferred`: it names the MECHANISM — a
// `scheduled` stage dated after `today` — and leaves `deferred` to mean what
// `status-of` already makes it mean, a todo declared as put off.
#let _state-of(row, graph, today) = {
  if row.closed { return "closed" }
  if is-blocked(row, graph) { return "blocked" }
  if row.status == "in-progress" { return "in-progress" }
  if is-ready(row, graph, today: today) { return "ready" }
  "scheduled"
}

#let filter-panel(
  // Pre-computed rows, in `todos()` shape. `none` walks the registry itself, which is
  // what a page wanting "every open todo" means.
  rows: none,
  // The reference date `is-ready` defers against. Passed through to
  // @rheo/rookery-timeline, which panics if neither this nor a document date is
  // available — NOTHING HERE CALLS `datetime.today()`, which returns 1980-01-01 under
  // a reproducible build and does not error while doing it.
  today: none,
  // The pill groups, in order. Each is a field this function projects below; a caller
  // dropping one gets a narrower panel, not a broken one.
  facets: ("state", "epic", "priority"),
  // WHICH ROWS ARE ROWS, before any pill is pressed. The default is the only one that
  // is always right — a closed todo is not outstanding work. A site with a second way
  // of finishing (a call answered before its deadline lapsed, say) passes its own.
  filter: none,
  // THE DATE IS AN ADAPTER, as it is in rookery-search's own panel. The default is the
  // todo-shaped one: a deadline where there is one, else the scheduled date, which is
  // the question a list of outstanding work is actually asking.
  when: none,
  // `"soonest"` (the default here, where rookery-search defaults to `"newest"`) puts
  // the earliest date first, because a deadline already behind you is the most urgent
  // thing on the page. Undated rows sort last either way — see `#panel`.
  order: "soonest",
  visible: 8,
  placeholder: "Filter",
  noun: "todos",
  empty: [Nothing here.],
  haystack: none,
  // Override the whole row. The default is `#idea-row-body`; this exists for the
  // caller with a genuinely different row, not as the ordinary path.
  render: none,
) = context {
  assert(
    order in ("newest", "soonest"),
    message: "@rheo/rookery-todos: #filter-panel's `order` must be \"newest\" (the most "
      + "recent date first) or \"soonest\" (the earliest first) — got "
      + repr(order),
  )

  let all = if rows != none { rows } else { todos() }
  // THE GRAPH IS BUILT FROM EVERY TODO, not from the filtered rows, and that is
  // load-bearing: a todo's blocker is very often closed, and a closed row dropped
  // before the graph is built would leave the blocker unresolvable — which
  // `is-blocked` reads as "not blocking", quietly promoting a blocked todo to ready.
  let graph = todo-graph(rows: all)

  let keep = if filter != none { filter } else { r => not r.closed }
  let when = if when != none { when } else {
    r => {
      let d = deadline-of(r.tags-dict)
      if d != none { d } else { scheduled-of(r.tags-dict) }
    }
  }

  // EVERY PROJECTED FIELD IS A SCALAR, which `#panel`'s `_attr` asserts: each one
  // becomes an HTML attribute the script reads back, and a dictionary or a datetime
  // there would stringify into nonsense. The raw datetime rides as `when-date` — not
  // a facet, so never projected into an attribute — because `render:` needs to format
  // it and the sort key is a string.
  let rows = all
    .filter(keep)
    .map(r => {
      let d = when(r)
      (
        ..r,
        state: _state-of(r, graph, today),
        epic: epic-of(r.tags-dict),
        // "p0" rather than `0`: a pill reading `p0` says what the number is, and a
        // pill reading `0` reads as a count of something.
        priority: if r.priority == none { none } else { "p" + str(r.priority) },
        // A ZERO-PADDED `[year][month][day]` STRING, because `#panel` sorts its sort
        // field as a plain string — which is date order exactly when it is padded.
        when: if d == none { none } else { d.display("[year][month][day]") },
        when-date: d,
      )
    })

  let draw = if render != none { render } else {
    r => {
      let d = r.at("when-date", default: none)
      // PAGED/EPUB: `#panel` keeps its own `target()` branch, but it still calls
      // `render:` there — and `#idea-row-body` is `html.elem` all the way down, which
      // on a paged target contributes NOTHING. So the fallback lives here rather than
      // in the panel: an empty `list(..)` item per todo is exactly the silence
      // `target.typ`'s header says this package exists to end.
      if not _is-markup() {
        return {
          if d != none { [#_fmt-day(d) — ] }
          r.at("label", default: r.at("name", default: ""))
        }
      }
      idea-row-body(
        when: if d == none { none } else { _fmt-day(d) },
        iso: if d == none { none } else { _iso(d) },
        title: r.at("label", default: r.at("name", default: "")),
        href: r.at("href", default: none),
        // ONE CHIP PER FACET THIS ROW HAS A VALUE FOR, in the caller's facet order, so
        // the chips read in the same order as the pill groups above them.
        badges: facets
          .map(f => r.at(f, default: none))
          .filter(v => v != none and v != "")
          .map(v => (text: v.replace("-", " "), tag: v)),
      )
    }
  }

  panel(
    rows: rows,
    facets: facets,
    sort: "when",
    descending: order == "newest",
    // WHAT `#idea-row` WOULD HAVE PUT ON THE `<li>` ITSELF. `#panel` owns the list
    // item here, so the row's own classes arrive this way instead: `idea-row` is the
    // GRID the body's four spans are laid out on, and `idea-tag-<tag>` is what every
    // other rookery surface already themes a note by.
    row-class: r => (
      ("idea-row",) + r.at("tags-dict", default: (:)).keys().map(t => "idea-tag-" + t)
    ),
    visible: visible,
    placeholder: placeholder,
    noun: noun,
    empty: empty,
    haystack: haystack,
    render: draw,
  )
}
