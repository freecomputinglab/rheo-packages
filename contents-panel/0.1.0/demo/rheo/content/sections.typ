// The `separator:` path. This page's sections are NOT headings — they are
// figures of a custom kind, standing in for the construct a template like
// rookery's `#ideate` produces, which consumes the author's `==` headings and
// re-emits each title as raw HTML. `@rheo/contents-panel` cannot see those with
// `query(heading)`, so the box is pointed at what they ARE instead.
#set document(title: "Sections demo")
#import "@rheo/contents-panel:0.1.0": contents

#let section(name, body) = figure(kind: "demo-section", supplement: none, caption: name, body)

#show: contents.with(separator: figure.where(kind: "demo-section"))

= Sections that are not headings

This page deliberately has ONE real heading, above, and three sections that
are figures. A correct build lists the three figures and not the heading:
`separator:` replaces the default rather than adding to it.

#section("Alpha")[
  The first section. Its title lives in the figure's caption, which is why
  `entry-title` reads `caption` before `body` — a figure's body is the whole
  section, and reading that as the label would put the entire section into
  one row of the contents list.

  Filler so the page scrolls far enough for the progress fill to be worth
  looking at, and so each section occupies a distinguishable band of the
  document rather than all three landing within one viewport.
]

#section("Beta")[
  The second section. These entries carry no depth of any kind — a figure has
  neither `depth` nor `level` — so `entry-depth` reads them all as rung 1 and
  the box draws a flat list with no subsection threads. That is the correct
  rendering for a flat set of entries, not a degradation of a nested one.

  More filler, for the same reason as above.
]

#section("Alpha")[
  A third section deliberately titled the same as the first, so this page
  exercises slug deduplication on the `separator:` path as well as on the
  heading path: the ids must come out `alpha` and `alpha-2`.

  More filler, for the same reason as above.
]
