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
// AND AS A MODULE, for `countdown`/`days-until`: the parameter below is also called
// `countdown`, and a parameter and a function of the same name cannot both be
// reachable by that name inside the panel. Same reason `#upcoming` imports its own
// `when.typ` twice.
#import "@rheo/rookery-timeline:0.1.0" as _tl
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
// THE FACETS THIS PACKAGE DERIVES, as against the ones a site authors. The split is
// what `state-label` lays out on two lines; naming it here keeps the two places that
// care — the projection below and the row split — reading off one list.
#let _DERIVED = ("state", "priority")

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
  //
  // `epic` FIRST, because the derived two are laid out on a line of their own below it
  // — see `state-label`. Within the facets list the order only decides the order of
  // the groups on their line.
  facets: ("epic", "state", "priority"),
  // THE HEADER OVER THE DERIVED PILLS, which sit on a line beneath the authored ones.
  //
  // `epic` is a tag the SITE wrote; `state` and `priority` are read back off the graph
  // and the tag keys by this package. One undifferentiated row of pills asks a reader
  // to know which is which, so the two kinds get a line each and the derived line says
  // what it is. `none` puts every group back on one line.
  state-label: [todo states:],
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
  // HOW LONG YOU HAVE, as a WASH ON THE DATE CELL — the same three bands
  // @rheo/rookery-timeline draws on `#upcoming`, off the same `countdown()`, on the
  // same family `--rookery-heat-*` ramp. What differs is where the colour lands: that
  // view draws a chip, this one paints the date. The phrase rides as a tooltip.
  //
  // ON BY DEFAULT here, where `#upcoming`'s flag is off: a panel of OUTSTANDING WORK
  // is read for what is due next, which is the question the band answers. A row
  // further off than a fortnight draws no band from the countdown — priority is the
  // fallback there, see `draw` below — and a row with no date draws nothing at all.
  //
  // IT NEEDS A `today:`. Nothing in this package may call `datetime.today()` (it
  // returns 1980-01-01 under a reproducible build and does not error), and unlike the
  // predicates in `when.typ` a countdown has no tag dictionary to resolve a
  // document-date fallback from — so with no `today:` passed, no row is measured and
  // no countdown band drawn (priority still bands where it applies).
  countdown: true,
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
      // THE COUNTDOWN IS @rheo/rookery-timeline's, not this package's: `countdown`
      // maps whole days onto the three bands and the words for them, and deriving a
      // second copy of `if days <= 7` here is exactly how two surfaces drift apart.
      let c = if countdown and d != none and today != none {
        _tl.countdown(_tl.days-until(d, today))
      } else { none }
      if not _is-markup() {
        return {
          if d != none { [#_fmt-day(d) — ] }
          r.at("label", default: r.at("name", default: ""))
          // THE SAME WORDS, NO COLOUR, which is what `#upcoming`'s paged branch does
          // too: a printed page has no chip to tint, and red ink is a decision about
          // the page rather than about the deadline.
          if c != none { [ #text(gray, "(" + c.text + ")")] }
        }
      }
      // THE BAND IS THE DATE CELL, not a fifth thing beside it. It was a chip on the
      // badge strip, which made the strip say two different kinds of thing at once —
      // what this todo IS (its facets) and how soon it is due — and spent a chip slot
      // on a reading the eye takes without words. So the colour paints the date's own
      // background and the phrase becomes a tooltip: the colour is the reading at a
      // glance, the words are there for whoever asks. `#upcoming` keeps its chips —
      // that view has a different grid and a different question.
      let band = if c == none { none } else { "todo-when-" + c.level }
      // PRIORITY, ONLY WHERE THE COUNTDOWN HAS NOTHING TO SAY. A todo three weeks out
      // earns no countdown band, so a p0 sitting far out would read exactly like the
      // p4 beside it — which is the gap this closes, on the same cell rather than a
      // second one. Where both could apply the countdown WINS: a deadline actually due
      // soon is the more pressing read regardless of how it was prioritised.
      //
      // `r.priority` HERE IS THE PROJECTED STRING (`"p0"`), not the number — the map
      // above turned it into one so it could ride as a facet attribute.
      //
      // NO p3 OR p4, deliberately: a ramp of three has three steps, and a backlog item
      // colouring itself is exactly the noise the ramp exists to cut through.
      let p = r.at("priority", default: none)
      let pri-band = if band != none or d == none or p not in ("p0", "p1", "p2") {
        none
      } else { "todo-when-" + p }
      // A ROW WITH NO DATE GETS NEITHER. A wash behind an em dash says nothing.
      let phrase = if c != none { c.text } else if pri-band != none {
        "priority " + p.slice(1)
      } else { none }
      idea-row-body(
        when: if d == none { none } else { _fmt-day(d) },
        iso: if d == none { none } else { _iso(d) },
        // `when-class:`/`when-attrs:` ARE @rheo/rookery's OWN HOLE for exactly this
        // (see `row.typ`): the caller computes the band, the row still asks nothing
        // about what a date means. With no band, neither is passed and the cell's
        // markup is what it always was.
        when-class: if band != none { (band,) } else if pri-band != none {
          (pri-band,)
        } else { () },
        // `data-countdown` carries the words for the drawn tooltip; `aria-label` says
        // them to a reader who cannot see a colour. Not `title:` — a native tooltip
        // cannot be styled and would open BESIDE the drawn one rather than instead of
        // it. `tabindex` is what makes the tooltip reachable without a pointer, which
        // is also how it opens on a touch screen.
        when-attrs: if phrase == none { (:) } else {
          (
            "data-countdown": phrase,
            "aria-label": _fmt-day(d) + ", " + phrase,
            "tabindex": "0",
          )
        },
        title: r.at("label", default: r.at("name", default: "")),
        href: r.at("href", default: none),
        // ONE CHIP PER FACET THIS ROW HAS A VALUE FOR, in the caller's facet order, so
        // the chips read in the same order as the pill groups above them. The strip is
        // about facets and nothing else — urgency is the date cell's job now.
        badges: facets
          .map(f => r.at(f, default: none))
          .filter(v => v != none and v != "")
          .map(v => (text: v.replace("-", " "), tag: v)),
      )
    }
  }

  // AUTHORED ABOVE, DERIVED BELOW — and split by membership rather than by a
  // hardcoded pair, so a site adding a facet of its own lands on the authored line
  // without touching this. An empty line is dropped, not rendered blank.
  let derived = facets.filter(f => f in _DERIVED)
  let authored = facets.filter(f => f not in _DERIVED)
  let authored-row = if authored.len() > 0 { ((facets: authored),) } else { () }
  let facet-rows = if state-label == none or derived.len() == 0 { none } else {
    authored-row + ((label: state-label, facets: derived),)
  }

  panel(
    rows: rows,
    facets: facets,
    facet-rows: facet-rows,
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
