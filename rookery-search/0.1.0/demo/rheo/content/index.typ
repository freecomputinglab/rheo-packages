#import "lib.typ": demo
#import "@rheo/rookery:0.1.0": footnote, idea, ideas-outline, tagged-idea, window

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
#import "@rheo/rookery-search:0.1.0": filter-panel, panel, search-bar, search-ideas, search-index, search-modal

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
#import "@rheo/rookery:0.1.0": ideas, tag-index

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

// ---- #filter-panel — the same chrome over TAGS ----------------------------
//
// THE THIRD WIDGET ON THIS PAGE, and the one that proves the OTHER shape: `#panel`
// above facets on projected fields; this scopes to the notes carrying one tag and takes
// its pills as authored TAG NAMES. `pill-match: "all"` here deliberately, because the
// DEFAULT is "any" and a union of two pills over this fixture cannot tell a working
// intersection from a broken one — `check.sh` needs the mode where a row DROPS.
//
// WHAT IT IS RENDERED WITH is the other half of the demo's job: each row is
// `#idea-row` from @rheo/rookery, so this page is where that shared row's CSS is
// proved in a real rheo build rather than in a scratch file.
//
// THE FIXTURE IS DELIBERATE. `filter-me` carries BOTH pill tags, `filter-one` carries
// one, and `filter-none` carries neither — so pressing one pill drops a row, pressing
// both drops another, and one row has no chips at all. `demo-pill` scopes the three
// away from every other note on the page, and `never-carried` is a pill nothing has:
// it must not render, which is the "a pill that can only return nothing" rule.
#idea("filter-me", title: [Carries both pills], tags: ("demo-pill": none, "demo-a": none, "demo-b": none))[
  Pressing either pill keeps this row; pressing both still keeps it.
]

#idea("filter-one", title: [Carries one pill], tags: ("demo-pill": none, "demo-a": none))[
  Pressing `demo-b` drops this row under `pill-match: "all"`, which is what makes that
  mode an INTERSECTION. Under the default "any" it would stay.
]

#idea("filter-none", title: [Carries neither pill], tags: ("demo-pill": none))[
  No chips at all, which is the row a shared-row stylesheet gets wrong first: an empty
  badge strip must take no space.
]

#filter-panel(
  tag: "demo-pill",
  pills: ("demo-a", "demo-b", "never-carried"),
  pill-match: "all",
  visible: 2,
  noun: "pill notes",
  placeholder: "Filter pill notes",
)
