#import "../lib.typ": demo
#import "@rheo/rookery:0.4.1": idea, window
#show: demo

= A nested vertebra

This page's handle is `sub:page`, one level deep, so every href rookery computes
from here — to a minted note page, to another vertebra — costs one `../`. A
root-only spine cannot catch an off-by-one in that arithmetic; this page is why
the demo has a subdirectory at all.

A page-level citation, outside any note: @lamport1994. And a page-level link
back to #link(label("index"))[the root vertebra].

#idea("sub-note", title: [Sub note], updated: datetime(year: 2026, month: 3, day: 14))[
  A note written on the nested vertebra, windowing back at the root one's note —
  so transclusion is exercised in BOTH directions and the pair is mutually
  windowed. At `window-depth: 0` the inner window becomes a link row,
  which is what keeps the cycle finite.

  #window(<root-note>)
]
