#import "lib.typ": demo
#import "@rheo/rookery:0.6.0": footnote, idea, ideas-outline, tagged-idea, window

// `#note` is a project-local two-liner as of 0.5.0, not a package export.
#let note = tagged-idea("note")
#show: demo

= Rookery under rheo

A page-level link, written in ordinary prose OUTSIDE any note, because that is
the only thing that produces a page backlink:
#link(label("sub:page"))[the nested vertebra].

#idea("root-note", title: [Root note])[
  A note written on the ROOT vertebra, citing @knuth1984 from inside a note.

  #idea("inner-note", title: [Inner note])[
    A note nested inside another note's body — the containment `#ideas-outline`
    nests by, and the case `_flatten` has to keep out of the parent's own body.
  ]

  A window pointing ACROSS vertebrae, at a note written on the nested page:
  #window(<sub-note>)
]

#note("plain-note", title: [Plain note], updated: datetime(year: 2026, month: 5, day: 2))[
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

#ideas-outline(rookery-wide: true)
