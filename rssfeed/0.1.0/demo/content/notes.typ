#import "@rheo/rookery:0.3.0": rookery, idea, note
#show: rookery
#set document(date: datetime(year: 2026, month: 4, day: 1))

= Notes

#note("alpha", title: [Alpha])[
  A note tagged `note` (via `#note`, which prepends that tag), syndicated
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
