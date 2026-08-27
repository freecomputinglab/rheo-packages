#import "lib.typ": demo
#import "@rheo/rookery:0.6.0": footnote, idea, ideas-outline, tagged-idea, window

// `#note` is a project-local two-liner as of 0.5.0, not a package export.
#let note = tagged-idea("note")
#show: demo

= Rookery under rheo

A page-level link, written in ordinary prose OUTSIDE any note, because that is
the only thing that produces a page backlink:
#link(label("sub:page"))[the nested vertebra].

#idea("root-note", title: [Root note], tags: ("demo-kind-prose": none))[
  A note written on the ROOT vertebra, citing @knuth1984 from inside a note.

  #idea("inner-note", title: [Inner note], tags: ("demo-kind-prose": none))[
    A note nested inside another note's body — the containment `#ideas-outline`
    nests by, and the case `_flatten` has to keep out of the parent's own body.
  ]

  A window pointing ACROSS vertebrae, at a note written on the nested page:
  #window(<sub-note>)
]

#note("plain-note", title: [Plain note], tags: ("demo-kind-cited": none), created: datetime(year: 2026, month: 5, day: 2))[
  A `#note`, so the registry carries a prepended `note` tag and the heading a
  `idea-tag-note` class.

  Its only citation sits inside a footnote, which is the case that used to
  vanish: the marker rendered and no references block was emitted anywhere.
  #footnote[A second work, cited from inside the footnote @lamport1994.]
]

// The syndication beacons, read back on a VERTEBRA. `#metadata` renders no HTML,
// so a beacon is invisible to `check.sh`'s greps unless something puts its
// payload on a page — and rendering it here is also the assertion that the
// beacons `.marrow.typ` emits inside each MINTED page are reachable by a query
// from outside it. MEASURED: this count tracks the number of dated notes exactly
// (1 with one dated note, 2 with two), so cross-document introspection is what
// carries them, not a per-page accident.
//
// NOTHING HERE IMPORTS `@rheo/feeds`, which is the point of the beacon
// protocol: the emitting package and the reading package never see each other.
#context {
  let items = query(<feeds:item>).map(m => m.value).sorted(key: v => v.id)
  html.elem(
    "ul",
    attrs: (class: "demo-beacons"),
    items
      .map(v => html.elem("li", [#v.id | #v.title | #v.page | #v.categories.join(",")]))
      .join(),
  )
}

// A TITLELESS NOTE, which is what the search index used to lose. Written as the
// bare `#idea[body]` form, so it has no authored title at all and rookery derives
// its `label` from these opening words. Until 0.6.0 the island shipped an empty
// title for it and the row printed its sequence number; `check.sh` asserts both
// halves of the fix below — that the island carries the words, and that searching
// for one of them finds the note.
#idea[
  Marginalia accumulate faster than anyone reads them, which is the whole problem
  a rookery exists to have.
]

#ideas-outline(rookery-wide: true)

// ---- @rheo/rookery-search — the three public entry points -----------------
//
// This is what the fixture exists for. `#search-index` emits the JSON island
// the browser searches; `#search-bar` is the inline input with its dropdown;
// `#search-modal` is the overlay. All three read the corpus through
// `@rheo/rookery`'s own `ideas()`, so a passing build here proves the two
// packages agree about the registry as well as proving this one compiles.
#import "@rheo/rookery-search:0.6.0": panel, search-bar, search-ideas, search-index, search-modal

#search-index()
#search-bar()
#search-modal()

// THE RANKING HALF of the derived-label fix. A titleless note used to be matchable
// by its ID ALONE, so a word from its own opening line found nothing. `_rank`
// scores `label` now, so this returns the note in the NAME tier — and `check.sh`
// asserts the tier, not just the count, because a body-tier hit would mean the
// title score is still being skipped.
#context {
  let hits = search-ideas("marginalia")
  html.elem(
    "p",
    attrs: (class: "demo-label-hits"),
    hits.map(h => h.id + "|" + h.kind).join(","),
  )
}

// ---- #panel — the projection-driven filter --------------------------------
//
// A DIFFERENT widget from the three above, and the difference is the point: the
// bar and the modal rank the whole corpus against a query and pop a dropdown; a
// panel filters a list that is already on the page, by facets DECLARED as a
// `tag-index` projection.
//
// TWO PANELS ON ONE PAGE, deliberately. Each gets its own generated listbox id at
// runtime, which is what a hardcoded id in the markup could not do — and it is
// the case `check.sh` asserts on below.
#import "@rheo/rookery:0.6.0": ideas, tag-index

// ONE index for the page, passed to both panels. Panels take an index; they never
// build one, or the per-view walk of the value store comes straight back.
#let INDEX = tag-index((
  kind: (family: "demo-kind-"),
  flag: (from: t => "note" in t),
))

#context {
  let rows = ideas(index: INDEX)
  [
    #panel(
      rows: rows,
      facets: ("kind", "flag"),
      sort: "label",
      // Deliberately SMALLER than the corpus, which is what lets check.sh tell a
      // scroll cap from a data cap: four rows in the markup behind a 2-row box.
      visible: 2,
      noun: "notes",
      placeholder: "Filter notes",
      render: r => [#r.label #text(gray, [(#r.at("kind", default: "—"))])],
    )
    #panel(
      rows: rows.filter(r => r.kind != none),
      facets: ("kind",),
      visible: 2,
      noun: "kinded notes",
      render: r => [#r.label],
    )
  ]
}
