#import "lib.typ": demo, idea, note
#import "@rheo/rookery:0.6.0": footnote, ideas-outline, window

// `idea` AND `note` COME FROM `lib.typ`, not from the package, and that is the
// exclusion pattern rather than a style preference: both are bound there with
// `exclude-tags: ("private",)`, and importing the package's own `idea` here
// would silently opt this vertebra out of the project's exclusions.
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

// ---- EXCLUDED AND INVISIBLE TAGS, which only a rheo build can check -------
//
// `demo/pure` proves an excluded note is absent from ONE page's HTML. What needs
// rheo is everything downstream of the registry: `.marrow.typ` mints one page per
// registered note and an `ideas/index.html` listing all of them, and an excluded
// note must be missing from BOTH — no `ideas/private-note.html` at all, and no
// row for it on the index.
// ITS BODY NAMES NO TAG AND NO CLASS, deliberately: `check.sh` asserts that
// certain strings appear NOWHERE in the built tree, and prose explaining which
// strings those are would put them back — MEASURED, an earlier draft of this file
// tripped its own assertions from inside a note body. The explanation lives in
// these comments, which render nothing.
#idea("private-note", title: [Private note], tags: ("private",))[
  PRIVATEBODY — this note is dropped by the build, so it mints no page and takes
  no row on the index.
]

// A note carrying the INVISIBLE tag, plus a visible one, so every assertion is a
// difference between two tags on one note rather than the absence of all of them.
// It survives the build; only the tag's name disappears. The minted page is the
// place that matters most: it renders its note's tags UNCONDITIONALLY, with no
// `show-tags:` argument to gate them, because nothing writes an `#idea` call for
// a page `.marrow.typ` mints.
// Same rule about its body as above: no tag name, no class name, no backticked
// example — only the marker `check.sh` greps for.
#note("secret-note", title: [Secret note], tags: ("secret",), updated: datetime(year: 2026, month: 6, day: 1))[
  SECRETBODY — this note survives the build in full. What disappears is one of its
  two tags: the pill, the class and the generated rule for it are all absent, here
  and on its own minted page and on the index row, while its other tag keeps all
  three.
]

// ---- A DERIVED TITLE ON A MINTED PAGE, which no `demo/pure` root can show ---
//
// A note with no `title:` takes the first 60 characters of its body as plain text
// (`_derived-title`, src/pure.typ). `demo/pure` asserts that on a CARD; what needs
// rheo is the minted page, whose `<title>` and `<h1>` used to fall back to the
// note's SLUG — so an auto-numbered note's own page was called `1`.
//
// Named rather than auto-numbered, so `check.sh` has a stable path to grep. The
// slug is what the fallback WOULD have produced, which is exactly what makes the
// assertion meaningful: `derived-note` vs. the body's opening words.
#idea("derived-note")[
  DERIVEDBODY and this text is what the note's own page must be titled by, rather
  than by its slug, and it runs past sixty characters so the ellipsis shows too.
]

#ideas-outline(rookery-wide: true)
