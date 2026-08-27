#import "../lib.typ": demo
#import "@rheo/rookery:0.6.0": idea, window
#show: demo

= A nested vertebra

This page's handle is `sub:page`, one level deep, so every href rookery computes
from here — to a minted note page, to another vertebra — costs one `../`. A
root-only spine cannot catch an off-by-one in that arithmetic; this page is why
the demo has a subdirectory at all.

A page-level citation, outside any note: @lamport1994. And a page-level link
back to #link(label("index"))[the root vertebra].

#idea("sub-note", title: [Sub note], created: datetime(year: 2026, month: 3, day: 14))[
  A note written on the nested vertebra, windowing back at the root one's note —
  so transclusion is exercised in BOTH directions and the pair is mutually
  windowed. At `window-depth: 0` the inner window becomes a link row,
  which is what keeps the cycle finite.

  #window(<root-note>)
]

A window emitted from INSIDE a `#context` block, which is what any package
computing its own rows must do — `@rheo/rookery-todos`'s views are the real
case. The backlink walk reads a page's content at `#show: rookery` time and
cannot enter a context block, so a window written like this used to announce
itself to nobody and the note it transcludes lost its backlink from this page.
`check.sh` asserts that `plain-note` now lists this vertebra.

#context {
  window("plain-note", folded: true)
}
