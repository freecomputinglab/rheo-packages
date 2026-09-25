// A heading a consuming package hides with CSS still gets collected by
// `query(heading)` at compile time — the row is emitted the same as any
// other. What must not happen is the SCRIPT treating that row as though its
// target were on the page: `Hidden`, below, is wrapped in a `display: none`
// div, and the runtime pass in `contents.js` is what hides its row in turn.
#set document(title: "Hidden demo")
#import "@rheo/contents-panel:0.1.1": contents

#show: contents

= Visible One

Filler so the page scrolls far enough for the box to have work to do.

#html.elem("div", attrs: (style: "display: none"), heading[Hidden])

Filler after the hidden heading, so it still occupies a band of the
document even though nothing on the page shows it.

= Visible Two

More filler under the third heading.
