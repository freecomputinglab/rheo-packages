#import "@rheo/rookery:0.1.0": idea, note, todo

#set document(date: datetime(year: 2026, month: 8, day: 13))

= Notes

#idea("pinned", title: [Pinned])[
  A pinned note, referenced from the nested `guide:intro` vertebra to exercise
  cross-page `../` href prefixing. Its body links onward to
  #link(label("note:tagged"))[the tagged note], which is what exercises href
  depth on the MINTED page: `notes/pinned.html` is one level down, so this has
  to come out as `../notes.html#…` there and as a bare `#…` here.
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
