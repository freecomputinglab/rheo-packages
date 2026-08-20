// The permalink: the one navigational affordance every note carries, as a tab
// above its heading and as the id on its own page.

#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *

// ---- The permalink — the ONE navigational affordance ----------------------
//
// `[idea:etal]`, rendered beside a note's title (or alone, where there is no
// title) by BOTH `#idea` and `#window`. Shared so the two cannot drift: it is
// the same affordance meaning the same thing in both places — "this is the
// note's id, and it goes to the note's own page".
//
// Nothing else in this package is a link. A transcluded body is NOT wrapped
// in an anchor and no trailing arrow is appended (both were tried; see
// `#window`), so the reader's click budget is unambiguous: the permalink
// navigates, everything else folds.
//
// It goes to the note's standalone page when one is minted, and only falls
// back to the same-page `#id` fragment when there is not (plain `typst
// compile`, or the combined PDF). For `#idea`, that fragment points at the
// very heading the reader just clicked — a no-op — which is why the minted
// page is preferred whenever it exists.
// `href: auto` resolves the destination as described above. `.marrow.typ`
// passes an explicit one instead: on a note's OWN minted page the permalink
// must stay a same-page fragment rather than link the page to itself, and
// `_note-href` would happily compute the latter. Routing that case through
// here anyway is what keeps every permalink in the output identical — the
// hand-rolled copy this replaced had already drifted.
//
// Carries no theme properties of its own: it is always emitted inside a
// container that does (`.idea-box`, `.idea-window`, a minted page's `<h1>`), and
// custom properties inherit.
#let _permalink(id, href: auto) = {
  let dest = if href != auto { href } else {
    let page-href = _note-href(id)
    if page-href == none { "#" + id } else { page-href }
  }
  html.elem(
    "a",
    attrs: (
      class: "idea-label",
      href: dest,
      title: if dest.starts-with("#") { "Link to this note" } else { "Open this note's page" },
    ),
    "[" + id + "]",
  )
}

// The permalink as a card's TOP RULE rather than as a word in its heading:
// `.idea-tab` draws the rule (see rookery.css) and this is the id that
// straddles it. Used by every site that renders a note's HEADER — `#idea`, a
// transcluded `#idea`, a `#window` summary, a minted page's `<h1>` — and by
// nothing else: a bare permalink standing in prose (a depth-exhausted nested
// window, below) keeps `_permalink` itself, because a rule across the top of it
// would be a rule across the top of nothing.
//
// `span`, NOT `div`: this goes inside `<summary>` on the window path, whose
// content model is phrasing content, and EPUB output is XHTML, where that
// distinction is enforced rather than merely stated. `display: flex` in the
// stylesheet is what makes it behave as a block.
//
// Carries no theme properties of its own, for the same reason `_permalink`
// does not: it is always emitted inside a container that does — `.idea-box`,
// `.idea-window-summary`, or (on a minted page) the `.idea-head` wrapper — and
// custom properties inherit.
// `date` IS THE HAT'S OTHER END. Emitted LAST and pushed to the far right of the
// rule by `margin-left: auto` in the stylesheet, so the hat reads id-on-the-left,
// date-on-the-right with the frame's top edge between them. It used to render
// inside the heading (`#idea`) or as a third item in the summary row (`#window`) —
// two classes in two places for one piece of metadata. Both now pass it here.
//
// A STRING, already formatted, not a `datetime`: the two call sites resolve which
// date to show and how to display it (`#idea` from `updated`/`minted`/the
// document's own, `_window-content` from the registry record), and the paged
// branches need the same string without a hat to hang it on. Formatting here would
// put that decision in a third place.
// `tags:` renders each tag as a VISIBLE PILL, between the id and the date —
// opt-in per call site (`#idea`/`#window`'s `show-tags:`, off by default,
// same mechanism as `date:` above), and empty when the note carries none
// either way (an empty `tags` array maps to no output).
//
// TWO classes per pill, on purpose: `idea-tag` is the pill's own shape hook
// (see `.idea-tab > .idea-tag` in rookery.css); `idea-tag-<tag>` is the SAME
// class this package already puts on the card and the heading (`_flatten`'s
// IK rule, `#idea` below), and the same class `@rheo/rookery-search` puts on
// its own chips — so one project rule (`.idea-tag-draft { ... }`) now styles
// a tag everywhere it appears, including this pill. A project stylesheet
// that only meant to style the card is affected too — that is the intent of
// sharing the class, not an accident.
#let _permalink-tab(id, href: auto, tags: (), date: none) = html.elem(
  "span",
  attrs: (class: "idea-tab"),
  _permalink(id, href: href)
    + (if tags.len() == 0 { [] } else {
      tags.map(t => {
        let base = (class: "idea-tag idea-tag-" + t)
        let style = _tag-style(t)
        html.elem("span", attrs: if style == none { base } else { base + (style: style) }, t)
      }).join()
    })
    + (if date == none { [] } else { html.elem("span", attrs: (class: "idea-date"), date) }),
)

// The tab and the heading as ONE element, wherever a note wears a header.
//
// NOT two loose siblings, and this is measured rather than tidiness. Typst's
// HTML export wraps a LEADING INLINE run in a `<p>` of its own depending on what
// follows it, and it is not decidable per call site: in one build of this
// package's own `demo/rheo`, one `.idea-box` came out
// `<div class="idea-box"><p><span class="idea-tab">..</span></p><h2>` and the
// next `<div class="idea-box"><span class="idea-tab">..</span><h2>` — same
// construct, same run, different grouping, because their bodies differ. Every
// stylesheet rule that positions the tab against its heading
// (`.idea-tab + h*.idea`) silently stops matching in the first form.
//
// Inside one `html.elem` the two are always real siblings. `.idea-head` is also
// the theme container on a minted note page, where there is no `.idea-box` to be
// one — see `.marrow.typ`, which passes `_themed((:))` here.
//
// `#window`'s summary needs none of this: its tab is a direct child of
// `<summary>`, whose content is inline throughout, and no `<p>` ever appears
// there (checked in the same build).
#let _head(tab, heading, attrs: (:)) = html.elem(
  "div",
  attrs: attrs + (class: "idea-head"),
  tab + heading,
)

// Paged counterpart: no `html.elem`, and the fallback is the Typst label
// rather than an HTML fragment.
#let _permalink-paged(id) = {
  link(_resolve-dest(id, "page"), text(gray, raw("[" + id + "]")))
}

// THE ONE BOTTOM-OUT RENDERING. A `#window` that has no recursion budget left emits
// this, wherever it ran out: `#window` itself at depth 0, and `_flatten`'s WK arm for
// a window nested past the budget. It used to be TWO renderings — a bare `[idea:x]`
// permalink from the WK arm, and this row from the depth-0 branch — so a bottomed-out
// window looked like a different KIND of object depending on WHY it bottomed out.
// Factored here so the two cannot drift again; that drift is what the shared
// `_permalink`/`_note-file`/`_truncate` helpers all exist to prevent.
//
// The note's TITLE, linked to its own page, in the row shape a page backlink uses
// (`.idea-page-row` gives it the frame's bar and indent at body size). A TITLELESS
// note falls back to its permalink — there is nothing else to name it by, and that
// is the one case the old rendering survives in.
//
// Defined HERE, above `_flatten`, for the reason `_blocks` and `_truncate` are: a
// `#let` closure captures the scope visible AT DEFINITION time, and `_flatten` is one
// of the two callers.
#let _window-link(id, rec) = {
  let row = if rec.title == none { _permalink(id) } else {
    link(_resolve-dest(id, "page"), rec.title)
  }
  if _target() == "html" or _target() == "epub" {
    html.elem(
      "ul",
      attrs: _themed((class: "idea-page-list")),
      html.elem("li", attrs: (class: "idea-page-row"), row),
    )
  } else {
    // `align(start)` for the reason `_window-content`'s paged branch uses it: a
    // Typst figure centres its body.
    align(start, block(row))
  }
}
