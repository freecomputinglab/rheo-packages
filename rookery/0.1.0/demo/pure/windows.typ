// windows.typ — #window's `limit:`, `folded:`, `show-date:`, `sort:` and
// `depth:` (lib.typ:1680), including a real nested-window unfurl (`depth:
// 2`) so the collapse-vs-expand branch in `_flatten`'s WK rule actually
// runs, not just `#window`'s own top-level rendering.
#import "../../src/lib.typ": idea, window

#idea("w-inner", title: [Inner], created: datetime(year: 2024, month: 1, day: 5))[
  The innermost note, unfurled only when a window's depth budget reaches it.
]

#idea("w-outer", title: [Outer], created: datetime(year: 2024, month: 6, day: 1))[
  First block of Outer's body.

  Second block, with #window("w-inner") transcluded one level down.

  Third block — at depth 1 (the document default) the nested window above
  collapses to a bare permalink instead of re-expanding; at depth 2 it
  unfurls as a real window.

  Fourth block, so `limit:` below has something to truncate.
]

#idea("w-early", title: [Early], created: datetime(year: 2023, month: 3, day: 1))[
  An early note, for `sort: "date"` to place ahead of Outer/Inner.
]

// depth: 0 — a LINK to the note's page, no body at all (lib.typ:1840).
#window("w-outer", depth: 0)

// depth: 1 (auto/default) — renders Outer once, collapsing its own nested
// #window("w-inner") to a bare permalink.
#window("w-outer", depth: 1)

// depth: 2 — unfurls the nested #window("w-inner") as a real window too.
#window("w-outer", depth: 2)

// limit: 2 — only Outer's first two blocks, then a grey ellipsis
// (pure.typ:474 `_truncate`).
#window("w-outer", limit: 2)

// folded: true — same block, `<details>` starts closed instead of open
// (inert on the paged target — nothing to click there).
#window("w-outer", folded: true)

// show-date: true — the resolved `created` date
// appears at the right-hand end of the hat, inside the window's summary,
// regardless of whether `#idea` itself was told to show one.
#window("w-outer", show-date: true)

// sort: "date" — naming a sort orders the WHOLE selection (oldest first),
// unlike the default `auto`, which keeps call-site order.
#window(("w-outer", "w-early", "w-inner"), sort: "date")

// sort: "lexicographic" — orders by id text instead.
#window(("w-outer", "w-early", "w-inner"), sort: "lexicographic")
