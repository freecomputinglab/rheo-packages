// folded-height.typ — a folded window's summary height, titled and untitled.
//
// A REGRESSION FIXTURE for bead rheo-packages-folded-window-height-kwu1: a
// titleless folded window's closed row read as cramped beside a titled one.
//
// The summary is a wrapping flex row — the tab first, the title on a second
// line beneath it — and `_window-content` emits `.idea-window-title` only when
// the note has a title. So an untitled note's summary had ONE flex line where a
// titled one had two. MEASURED before the fix: titled 26.02px, untitled 8.02px.
//
// `.idea-window-summary:not(:has(> .idea-window-title))::after` in
// `src/rookery.css` now reserves `1lh` in exactly that case. MEASURED after:
// both 26.02px.
//
// Open windows are here too, and deliberately: the reservation is scoped to the
// absent title rather than to the closed state, so it applies in both — and an
// open titleless window must not gain a stray blank line either.

#import "../../src/lib.typ": idea, window

= Folded window heights

#idea("fh-titled", title: [A titled note])[The body of the titled note.]
#idea("fh-untitled")[The body of the untitled note, which has no title at all.]

Two FOLDED windows. Their closed rows should read as the same object at two
different lengths, not as two different shapes.

#window("fh-titled", folded: true)
#window("fh-untitled", folded: true)

The same two OPEN, where the summary is the header of a disclosed block.

#window("fh-titled")
#window("fh-untitled")
