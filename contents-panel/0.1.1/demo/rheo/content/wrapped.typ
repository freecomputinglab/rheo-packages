// `wrap:` — the panel handed to a container of the caller's own choosing
// instead of pinned with `position: fixed`. This page exists to hold that
// path down: the aside must land INSIDE the wrapper div, must carry
// `data-rheo-panel-wrapped`, and the contents links must still work exactly
// as they do on every other page — only where the panel sits changes, not
// what it lists.
//
// `reserve: none` goes with it: a wrapped panel is in the flow and reserves
// no room in the page's own content, so passing both is refused (see
// `src/lib.typ`'s assertion).
#set document(title: "Wrapped")
#import "@rheo/contents-panel:0.1.1": contents

#show: contents.with(
  wrap: body => html.elem("div", attrs: (class: "demo-wrap"), body),
  reserve: none,
)

= A panel in its own container

The aside is not pinned here — it is handed to `demo-wrap`, a plain div this
page built, and CSS drops it back into the flow rather than fixing it to the
viewport.

== What still works

The rows, their ids and the anchors they point at. Wrapping the panel changes
where it sits, not what it lists or how the links resolve.

== A subsection

Present so the list still carries a nested row, exactly as it would on a
page whose panel is pinned.
