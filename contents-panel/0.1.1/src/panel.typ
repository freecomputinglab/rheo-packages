// @rheo/contents-panel — the frame, on its own.
//
// The box `contents` draws is two objects, not one. There is a FRAME — a left
// rule with the content padded off it, a bottom rule closing it, and a hat
// hanging over the top of that rule with a name sitting on the end of it — and
// there is a LIST inside the frame that tracks the reader. Only the second has
// anything to do with contents.
//
// Every fiddly part of this package is in the first: the hat's lift, the corner
// it makes with the left rule, the negative margin pulling it back over that
// rule, the track offset that starts at the rule's tip rather than the header's
// left edge. A project wanting that frame around something else — an
// about-the-author note beside a homepage, say — had to restate all of it. So
// it is a function here, and `contents` is one caller of it:
//
//     #import "@rheo/contents-panel:0.1.1": frame
//     #frame(cap-text: "about the author")[
//       Lachlan Kermode writes here.
//     ]
//
// The frame carries NO script and no state. `contents.js` keys off
// `.rheo-contents-link`, of which a bare frame has none, and bails before it
// touches anything — so a frame is static markup and static CSS, which is the
// whole of what a panel that does not track a scroll needs.

// Class attribute from parts, dropping the absent ones. `frame`'s callers pass
// their own classes as `none` when they have none, and `none` in a class list
// would land in the html as the word "none".
#let _classes(..names) = names.pos().filter(n => n != none and n != "").join(" ")

// `cap-text` — the name on the hat, or `none` for no hat at all. A frame with
//   no hat is the phone form: a plain bordered block, which is what the hat's
//   own media rules reduce it to anyway.
// `top` — draw the jump-to-top arrow at the right of the hat. A plain `<a
//   href="#">`, so it works with no script; `contents.js` upgrades it to a
//   smooth scroll where the panel is a contents list.
// `aria-label` — the landmark's name. An `<aside>` with a hat is already named
//   by it visually, but the accessible name has to be given.
// `element` — the tag the box itself is, inside the aside. `div` by default,
//   because a frame holds whatever a page hands it and most of that is not
//   navigation; `contents` passes `nav`, which its list of section links
//   genuinely is. A panel of prose emitted as a `nav` is a navigation landmark
//   with no links in it, which is worse than no landmark.
// `side` — which edge of the page the panel is pinned to, `right` (the
//   default) or `left`. Typst's own alignment values rather than strings, the
//   same way `contents` takes `heading` itself for `separator:`.
//
//   THIS IS NOT A TEXT DIRECTION and does not touch one. It mirrors the frame
//   — the rule, the padding off it, the hat hanging over it — because those
//   sit on the edge facing away from the prose. The list inside keeps reading
//   whichever way the script runs, so a left-hand rail on an LTR page has its
//   rule on the right and its labels still left-to-right. `contents.css`'s
//   `side: left` block is the whole of the difference, and its header explains
//   why `direction: rtl` was the wrong mechanism for it.
//
//   `contents` forwards this AND derives its `reserve:` padding side from it,
//   so a project states the side once.
// `rookery` — adopt `@rookery/core`'s `--idea-*` palette, which the panel
//   inherits when it is emitted inside an idea's box (and which `contents.js`
//   copies across where it is not). See "Adopting the rookery's theme" in
//   `contents.css`.
// `offset-selector` — CSS selector for the project's own sticky header. Given
//   one, the script pins the panel's hat beneath that element's bottom edge,
//   recomputed as the page scrolls.
// `align-selector` — CSS selector for something the panel should line up with
//   before the reader has scrolled, typically the first section's own header.
//
//   WHERE A PANEL SITS IS FRAME-LEVEL, which is why these two are here and not
//   only on `contents`. They are the one piece of script a frame with no list
//   still wants: a pinned box has to clear whatever covers the top of the
//   viewport, and neither that element's height nor the target's position is
//   knowable from CSS. MEASURED on waterline's weeknotes index, whose about
//   panel is a bare frame: without them its hat cleared the header by a hand
//   -written `calc()` that had to restate the header's height, the content's
//   leading and the hat's own overhang, and landed a pixel or two off the first
//   card's tab — the thing it is meant to read as level with.
// `aside-class` / `box-class` / `box-attrs` — what a caller hangs its own rules
//   and data attributes on. `contents` adds `.rheo-contents-aside` and
//   `.rheo-contents-box`, and every rule of its own that restyles a frame part
//   is written as a descendant of the latter, so the frame needs no hook per
//   part.
#let frame(
  cap-text: none,
  top: false,
  aria-label: none,
  element: "div",
  side: right,
  rookery: false,
  offset-selector: none,
  align-selector: none,
  aside-class: none,
  box-class: none,
  box-attrs: (:),
  body,
) = {
  // Caught here rather than left to produce a panel that silently stays on the
  // right: `side: "left"` (the string, which is the natural guess) and
  // `side: start` (the logical alignment, which is the other one) are both
  // wrong in a way nothing downstream would report.
  assert(
    side == left or side == right,
    message: "@rheo/contents-panel: `side:` must be `left` or `right`, got " + repr(side),
  )
  let box = (class: _classes("rheo-panel-box", box-class))
  if aria-label != none { box.insert("aria-label", aria-label) }
  // Read by `contents.js` off the box, not the aside: the script finds the box
  // first and everything else from it.
  if offset-selector != none { box.insert("data-offset-selector", offset-selector) }
  if align-selector != none { box.insert("data-align-selector", align-selector) }

  // PAGED AND EPUB TARGETS GET THE BODY ALONE. `html.elem` is ignored outside
  // the html target and warns per call, so a frame on a vertebra that also
  // builds to PDF would otherwise emit a warning and drop its own content on
  // the floor. The body is the part worth keeping: a hat and two rules are a
  // pinned box's furniture, and there is nothing to pin on a page.
  //
  // `contents` guards its own call for the same reason one step further out —
  // it skips the brackets and the anchors too.
  context if target() != "html" {
    body
  } else {
    html.elem(
      "aside",
      attrs: (
        class: _classes(
          "rheo-panel-aside",
          // Only the non-default side gets a class. The right-hand panel is
          // what `.rheo-panel-aside` already describes, so a
          // `rheo-panel-side-right` would be a class with no rules behind it.
          if side == left { "rheo-panel-side-left" },
          if rookery { "rheo-panel-rookery" },
          aside-class,
        ),
      ),
      html.elem(element, attrs: box + box-attrs, {
        if cap-text != none {
          html.elem("div", attrs: (class: "rheo-panel-header"), {
            html.elem("span", attrs: (class: "rheo-panel-title"), cap-text)
            if top {
              html.elem(
                "a",
                attrs: (
                  class: "rheo-panel-top",
                  href: "#",
                  title: "Top",
                  "aria-label": "Back to top",
                ),
                "\u{2191}",
              )
            }
          })
        }
        body
      }),
    )
  }
}
