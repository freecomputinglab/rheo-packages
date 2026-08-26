#import "@rheo/rookery:0.5.0": rookery, idea, tagged-idea

// `#note` is a project-local two-liner as of rookery 0.5.0, not a package
// export — `tagged-idea` is the factory it is built from.
#let note = tagged-idea("note")
#show: rookery
#set document(date: datetime(year: 2026, month: 4, day: 1))

= Notes

#note("alpha", title: [Alpha])[
  A note tagged `note` (via `#note`, built from `tagged-idea`, which prepends
  that tag), syndicated
  into `notes.xml`.

  #note("alpha-inner", title: [Alpha Inner])[
    A note nested INSIDE another note's body — still minted to its own
    page, still tagged `note`, and still a candidate for `notes.xml`.
  ]
]

#note("beta", title: [Beta])[
  A second note tagged `note`.
]

#idea("gamma", title: [Gamma], tags: ("draft",))[
  A note tagged `draft`, not `note` — excluded from `notes.xml` by
  `from-ideas(tags: "note")`, and therefore never in the intersection
  `feed.xml` and `notes.xml` share.
]
