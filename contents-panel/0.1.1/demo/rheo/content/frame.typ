// THE FRAME WITHOUT THE LIST, which is the whole of what `frame` is for: a
// project that wants the box's shape around something that is not a contents
// list — an about-the-author note beside a homepage is the case it was pulled
// out for.
//
// This page holds that path down. `contents` is never called here, so nothing
// on it is derived from the spine: no rows, no anchors, no script. What it
// asserts is that the frame alone still comes out a frame — the aside, the box,
// the hat with `cap-text` on it — and that none of the list's classes or
// attributes appear, since a panel carrying half of them would be styled by
// half the stylesheet and picked up by a script with nothing to do to it.
#set document(title: "Frame only")
#import "@rheo/contents-panel:0.1.1": frame

= A frame around anything

#frame(cap-text: "about the author")[
  Written by nobody in particular, which is the point: this panel's content is
  prose the page hands it, not a list the package derived.
]

== What it shares with a contents box

The shape. The left rule, the bottom rule closing it off, the hat pulled back
over the outer edge of that rule with its name resting on it — all of it is
`src/panel.typ` and `.rheo-panel-*`, and a contents box is one caller of it.

== What it does not have

Rows, anchors, ids, a page-progress track, and any behaviour at all.
