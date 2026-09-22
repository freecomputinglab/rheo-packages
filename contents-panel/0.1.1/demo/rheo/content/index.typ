#set document(title: "Contents demo")

#import "@rheo/contents-panel:0.1.1": contents
#show: contents

= Getting started

This demo exists to give `@rheo/contents-panel` a genuinely scrollable page to
render its sticky box and per-section progress against — a page with one
short heading and a paragraph proves nothing about scroll tracking, so
everything below is padded out with real paragraphs rather than a single
line per section.

The contents box on this page should list every heading below in document
order, track which section is currently in view as the page scrolls, and
collapse to nothing extra when the viewport is too narrow for it.

== Installing the package

Add `@rheo/contents-panel:0.1.1` to a vertebra's imports and apply it with
`#show: contents`. The template reads the current file's own heading tree —
nothing else needs to be passed in, and nothing about the surrounding spine
changes.

Under the hood this walks the document's headings, assigns each one a slug
derived from its text, and emits an anchor beside the heading and a
corresponding link in the sticky box. Two headings sharing the same text
must not collide on the same slug, which the "Notes" sections further down
this page exist to prove.

== Configuring the box

This page applies the show rule with no arguments at all, which is the
point: everything visible here is derived. `separator:` defaults to
`heading`, `levels:` to `auto`, and the numbering, the ids and the anchors
follow from the page's own heading tree.

Colour and geometry are custom properties rather than arguments, so a
project restyles the box from its own stylesheet. The breakpoint is the
exception and has to be an argument, because a custom property cannot be
used in an `@media` query.

== Notes

A first "Notes" heading, deliberately given the same text as the "Notes"
heading under the next top-level section below. The slug this one gets
should be the plain, undecorated slug — whichever of the two headings comes
first in document order.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

= Using the sticky box

The second top-level section. Its own sub-headings continue exercising the
same anchor/link pairing as the first section, at a different nesting depth
in the document, so the check script's invariant — every link's `href`
resolves to a matching `id` somewhere on the page — has more than one
section's worth of headings to fail against if the slug derivation is wrong.

== Scroll progress

As the reader scrolls past a section's anchor, the contents box is expected
to mark that section's link as active or otherwise indicate progress through
it. This paragraph, and the ones after it, exist only to give that behaviour
enough vertical space to be observable.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

== Notes

A second "Notes" heading, identical in text to the one under "Getting
started" above. This one should receive a distinct, suffixed slug — the
check script asserts that the two "Notes" headings end up with two different
`id`s rather than colliding on one, and that both anchors are still linked
to correctly from the contents box.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

== Keyboard and touch scrolling

Nothing about the contents box is expected to depend on the input method
used to scroll — mouse wheel, keyboard paging, or touch drag should all move
the same underlying scroll position that drives progress tracking.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

= Responsive behaviour

The third top-level section, covering what happens to the contents box when
the viewport narrows past the point where there is room beside the text.

== Narrow viewports

Below the breakpoint the aside hides entirely rather than squeezing itself
into an unusable sliver, and the script stops doing work — it asks the CSS
whether the box is visible rather than keeping its own copy of the width.
The rule is a `<style>` block carrying a `@media (max-width: ...)` query,
hoisted into the document `<head>` by rheo's `rheo-head` unwrapping; the
wrapper tag itself must leave no trace in the rendered output.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

== Wide viewports

Above the breakpoint the aside is fixed against the right edge of the
viewport and a matching rule pads the page to keep its text clear of it.
The box is not a column in a flex row, because wrapping the document in one
would put a template's `set document(..)` inside a container and fail the
compile — see the package readme.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.

This paragraph exists purely as scroll filler: it says nothing new, but its
presence, repeated a few times per section, is what makes the demo page tall
enough that a sticky box and scroll-driven progress indicator are actually
exercised rather than rendered against a page short enough to never scroll.
