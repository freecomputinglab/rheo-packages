// This demo overrides the default `idea:` prefix, so every id below is
// `note:<name>` — the template has to be applied in EVERY vertebra that uses
// the package (see guide/intro.typ), since imports are per-file.
// A whole theme, replacing the stylesheet's Forester blues with an amber set.
// Hover a `[note:...]` for the id colour, and a view's summary for the fold
// tint. `fold-hover` is deliberately much fainter than `id-hover`: the block
// is not a link, the id is.
#import "@rheo/rookery:0.1.0": idea, note, rookery, todo, view
#show: rookery.with(
  prefix: "note",
  theme: (
    id-hover: rgb("#ffe9a3"),
    fold-hover: "rgba(255, 190, 40, 0.07)",
    date-color: rgb("#a08a5a"),
  ),
)

// Every note inherits this date, so the views in guide/intro.typ have a muted
// date in their summaries — the only metadata a summary carries.
#set document(date: datetime(year: 2026, month: 8, day: 15))

= Ideas demo

#idea("rookery", title: [rookery])[
  Build a rookery plugin for Rheo that gives a Zettelkasten flavour.
]

#idea("tagged", labels: ("draft", "review"))[
  A note with multiple labels, to exercise the `labels` mechanism.
]

#idea[An auto-id note.]

#note("n1", title: [A note])[Sugar over `labels: ("note",)`.]

#todo("t1", labels: ("draft",))[Sugar over `labels: ("todo", "draft")`.]

#idea("multi", title: [Multi-block])[
  First paragraph of a multi-block note, for exercising `#view`'s `limit:`.

  Second paragraph, which `limit: 1` should truncate away.
]

== Views

#view("rookery", folded: true)

#view("multi", limit: 1)
#view(("rookery", "tagged", "n1"), folded: true)

#view("multi", limit: 1, folded: true)
