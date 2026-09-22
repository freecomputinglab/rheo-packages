// `side: left` — the panel pinned to the other edge of the page. This page
// exists to hold down the two halves of that switch, which are emitted in
// different places and have gone wrong independently:
//
//   - the ASIDE carries `rheo-panel-side-left`, which is what `contents.css`
//     hangs the mirrored frame off. Without it the panel stays on the right
//     and nothing says so.
//   - the `reserve` rule pads `padding-left` and NOT `padding-right`. A panel
//     moved to the left with the room still reserved on the right is the
//     failure this catches: the box compiles, renders, and sits on top of the
//     prose.
//
// What must NOT change is the list: its rows read left-to-right here exactly
// as they do on every other page, because the side of the page is not a text
// direction. See `contents.css`'s `side: left` block.
#set document(title: "On the left")
#import "@rheo/contents-panel:0.1.1": contents

#show: contents.with(side: left)

= A panel on the left

The frame mirrors: its rule sits on the right of the box, facing the prose,
with the content padded off it from that side and the hat's own short rule
meeting it at the corner.

== What mirrors with it

The frame's rule, the padding off that rule, the hat's negative margin and the
page-progress track's inset. All four are side-axis: they describe the edge
the box presents to the page.

== What does not

The rows. Their numbers stay ranged against the label column, the subsection
thread stays on the start edge, and both progress fills still grow the way the
text runs. Those are text-axis, written as logical properties, and they follow
the script rather than the panel.

=== A subsection, to draw the thread

The thread hangs off the start edge of its group, which on this LTR page is
still the left — inside a panel whose own rule is now on the right.

== Reserving the room

The `reserve` padding is on the left here, because that is the side the box is
on. It is the one rule `side:` changes outside the stylesheet.
