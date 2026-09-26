// @rheo/contents-panel — a sticky contents box with per-section scroll progress.
//
// Applied per vertebra as a document show rule:
//
//     #import "@rheo/contents-panel:0.1.1": contents
//     #show: contents
//
// This is NOT a view over the spine, which is why it is not a fourth view in
// `@rheo/sitemap`: every other navigation package in this repo derives from
// `rheo-context`'s spine and answers "where is this page in the site", and this
// one reads the CURRENT DOCUMENT'S OWN HEADINGS and answers "where am I in this
// page". Nothing here touches `rheo-context` at all, and the scoping below is
// plain Typst rather than anything rheo publishes, so the box also renders
// under bare `typst compile --format html`.
//
// ---- Scoping: a bare `query()` sees the WHOLE PROJECT -------------------
//
// rheo compiles an entire project in ONE `typst::compile` pass — the same fact
// `@rheo/feeds`'s beacon protocol relies on to see a `#metadata` label from any
// vertebra — so `query(..)` inside one vertebra returns matches from EVERY
// OTHER PAGE as well as its own.
//
// MEASURED, in this package's own demo: a probe vertebra owning no headings at
// all saw 13 from `query(heading)`, belonging to two other pages. Unfiltered,
// a page's contents box is a list of somebody else's sections linking to ids
// that exist nowhere in it.
//
// The fix is the `region` counter in `contents` below, which brackets the
// page. The two approaches that did NOT work are recorded there, at the point
// where someone would be tempted to reach for them again.
//
// ---- Why the anchors are ours -------------------------------------------
//
// MEASURED against rheo 0.6.4: the HTML build emits a bare `<h2>` with NO `id`
// attribute, so there is nothing in the page for a contents link to point at.
// rheo core does have heading-slugging — `HtmlDom::collect_headings` in
// `crates/core/src/html_dom.rs` derives an id per `h2`–`h6` and stamps it onto
// the element — but the only callers are in the EPUB crate
// (`crates/epub/src/lib.rs`, `crates/epub/src/xhtml.rs`). The HTML pipeline
// never calls it.
//
// So this package stamps its own anchors, and the id it links to is an id it
// wrote. That is a feature rather than a workaround: core's `text_to_id` maps
// whitespace to `-` and lowercases and otherwise keeps the text as-is, so a
// heading ending in `!` yields an id ending in `!` and two headings with the
// same text yield the SAME id. Neither is usable as a link target. `slug` below
// drops punctuation and `_ids` deduplicates.

// ---- The frame -----------------------------------------------------------
//
// Re-exported, so `frame` is importable from this package's entrypoint and a
// project can take the box's shape without its list — see `panel.typ`, which
// owns everything the two halves share.
#import "panel.typ": frame

// ---- Text extraction -----------------------------------------------------

// A markup space, as an element function. Typst gives a run of whitespace in
// markup its own element rather than folding it into the neighbouring text,
// and that element carries NO fields at all — no `text`, no `children`, no
// `body` — so every branch below misses it.
#let _SPACE = [ ].func()

// Content -> plain string, for the slug. Same shape as `@rheo/sitemap`'s
// `core.typ` `plain`, restated rather than imported: this package deliberately
// has no dependency on that one.
//
// THE SPACE CASE IS NOT AN EDGE CASE. Any heading mixing text with inline
// markup is a sequence whose word gaps are `_SPACE` elements, and without the
// branch below they vanish: `== Planning with \`beads\`` came out
// "Planning withbeads", both as the row's label and — worse, because it is a
// url — as the anchor `#planning-withbeads`. MEASURED on waterline's
// ohrg.org: 5 rows across 3 posts, every one of them a heading carrying a
// `raw` or an `emph`. A heading of plain text has no `_SPACE` children to
// lose, which is why this survived the demo.
//
// `linebreak` collapses to a space for the same reason a browser does it: a
// row is one line, and the two halves of a broken heading must not run
// together into one word.
#let plain(c) = {
  if type(c) == str {
    c
  } else if type(c) != content {
    ""
  } else if c.func() == _SPACE or c.func() == linebreak {
    " "
  } else if c.has("text") {
    c.text
  } else if c.has("children") {
    c.children.map(plain).fold("", (a, b) => a + b)
  } else if c.has("body") {
    plain(c.body)
  } else {
    ""
  }
}

// Content -> content, for the row's label, keeping the heading's own inline
// markup: a `raw` stays a `<code>`, an `emph` stays an `<em>`. The label used
// to be `plain(..)`, which threw all of it away and rendered
// "Enter:Typst" where the heading reads "Enter: _Typst_".
//
// LINKS ARE UNWRAPPED, and that is the one thing this cannot pass through: a
// row IS an `<a>`, and an `<a>` inside an `<a>` is invalid HTML that browsers
// repair by closing the outer one early — which would break the row's own
// jump-to-section behaviour. MEASURED on waterline's ohrg.org, where six
// headings across three posts are a bare `#link(..)[..]`. So a link
// contributes its body and loses its href, which a reader loses nothing by:
// the destination is one click away in the section the row points at.
//
// THE POLICY IS AN ALLOWLIST, and it has to be that way round. A row is a
// `<span>` inside an `<a>`, so only INLINE content may survive; anything
// structural is unwrapped to its body. Passing unrecognised elements through
// untouched was tried first and is wrong — `separator:` can point at
// anything, and this package's own `sections.typ` demo points it at a figure
// whose label is a `figure.caption`, which rendered a `<figcaption>` inside
// the row. Unwrapping by default cannot produce that class of bug; the cost
// is that an unlisted inline element loses its markup rather than its text.
//
// `_INLINE` is therefore the set of wrappers worth rebuilding. Extend it
// rather than adding another branch.
#let _INLINE = (emph, strong, underline, strike, highlight, super, sub)

#let rich(c) = {
  if type(c) == str {
    c
  } else if type(c) != content {
    []
  } else if c.func() == _SPACE or c.has("text") {
    // Text and `raw` both carry `text`, so a `raw` keeps its `<code>` — which
    // is the case that prompted all this: `== Planning with \`beads\``.
    c
  } else if c.func() in _INLINE {
    (c.func())(rich(c.body))
  } else if c.has("children") {
    c.children.map(rich).join()
  } else if c.has("body") {
    // Unwrapped: `link` (an `<a>` inside an `<a>` is invalid HTML that
    // browsers repair by closing the outer one early, breaking the row's own
    // jump-to-section), `figure.caption`, and every other structural
    // wrapper. MEASURED on waterline's ohrg.org: six headings across three
    // posts are a bare `#link(..)[..]`. A link contributes its body and
    // loses its href, which costs a reader nothing — the destination is one
    // click away in the section the row points at.
    rich(c.body)
  } else {
    c
  }
}

// Heading text -> url fragment. Letters and numbers of ANY script survive
// (`\p{L}`/`\p{N}`, not `a-z0-9`): a fragment id may hold non-ASCII per HTML5,
// and restricting to ASCII would collapse a whole Greek or Cyrillic heading to
// the empty string. Every other run of characters becomes a single `-`.
#let slug(s) = {
  let t = lower(s).replace(regex("[^\\p{L}\\p{N}]+"), "-").trim("-")
  // A heading of nothing but punctuation still needs a target to link to.
  if t == "" { "section" } else { t }
}

// ---- The two derived arrays ----------------------------------------------
//
// THE CENTRAL INVARIANT OF THIS PACKAGE: the `id` stamped on a heading and the
// `href` in the contents list must agree, or a link scrolls nowhere and the
// progress bar for that section never fills. They agree here by CONSTRUCTION
// rather than by coincidence — both sides call `_ids` on the same page-local
// heading array and index into the result, the show rule finding its index by
// the heading's own location. `demo/rheo/check.sh` asserts on the built output
// that every href resolves, across two pages whose headings deliberately
// collide.

// Deduplicated slugs, in document order. A repeat gets `-2`, `-3`, … — the
// first occurrence keeps the bare slug, so an existing link to it survives a
// later heading being added with the same text.
//
// An entry carrying its own `id` (an idea, see `_idea-entries`) links to that
// instead, and gets no anchor of its own.
#let _ids(all) = {
  let seen = (:)
  let out = ()
  for h in all {
    let own = h.at("id", default: none)
    if own != none {
      out.push(own)
      continue
    }
    let base = slug(plain(h.title))
    let n = seen.at(base, default: 0) + 1
    seen.insert(base, n)
    out.push(if n == 1 { base } else { base + "-" + str(n) })
  }
  out
}

// Section numbers (`1`, `1.1`, `1.2`, `2`, …) over the TRACKED levels only, so
// numbering stays contiguous when `levels:` skips a depth. A counter per level
// index, and descending it resets everything below it.
// The RENDERED rung of an entry: 0 for a top-level row, 1 for anything deeper.
//
// TWO RUNGS ARE DRAWN, and everything below the second is FLATTENED into it
// rather than dropped. Dropping was the first behaviour and is wrong for the
// same reason `@rheo/sidebar` gives for its own two-level nav: flattening
// loses the grouping, dropping loses the entry, and an entry missing from the
// contents is the worse failure — a reader cannot jump to what is not listed.
// MEASURED: with `separator: heading` on a page using `=`, `==` and `===`,
// taking the two shallowest depths silently omitted every `===`.
//
// A third drawn rung would need a second thread colour and a second indent to
// stay legible, which is worth designing against a real three-level vertebra
// rather than in anticipation of one. The entry's REAL depth still reaches the
// script as `data-level`, so a flattened `===` does not break the progress
// geometry: its enclosing `==` still runs until the next entry at its own
// depth or shallower.
#let _rung(levels, depth) = calc.min(levels.position(l => l == depth), 1)

#let _numbers(all, levels) = {
  let counts = (0, 0)
  let out = ()
  for h in all {
    let i = _rung(levels, h.depth)
    counts.at(i) += 1
    for j in range(i + 1, counts.len()) {
      counts.at(j) = 0
    }
    out.push(counts.slice(0, i + 1).map(str).join("."))
  }
  out
}

// ---- Reading an entry ----------------------------------------------------
//
// `separator:` lets a project point the box at something other than `heading`,
// so these two have to work for whatever it names. Both are overridable.

// An entry's label. `heading` keeps its text in `body`; a `figure` in
// `caption`; an element with an explicit `title` field uses that.
// `caption` is tried BEFORE `body`, which matters for the one case that has
// both: a `figure`'s body is the whole figure, so reading it as the label
// would put an entire section into one row of the contents list.
#let entry-title(e) = {
  if e.has("title") and e.title != none {
    e.title
  } else if e.has("caption") and e.caption != none {
    e.caption
  } else if e.has("body") {
    e.body
  } else {
    []
  }
}

// An entry's rung in the hierarchy. `heading` calls it `depth` (its ABSOLUTE
// level, which is what nesting means here, rather than the relative `level`);
// other elements that nest tend to call it `level`. Anything with neither is
// flat, and a flat set of entries is a perfectly good one-level contents list.
#let entry-depth(e) = {
  if e.has("depth") { e.depth } else if e.has("level") { e.level } else { 1 }
}

// ---- `separator: idea`, the rookery sugar --------------------------------
//
// A rookery's sections are not headings and are not reachable by a plain
// `query(selector)` either, so this is a whole ENTRY RESOLVER rather than a
// different selector. It is nonetheless only sugar: everything it does, a
// caller could do by hand, and nothing here is imported from `@rookery/core`
// — this package has no dependency on that one and must not grow one. What is
// hardcoded is rookery's published shape, restated as three constants.
//
// Mirrors `@rookery/core`'s own `core/0.1.0/src/outline.typ`, which is the
// authority for all of it:
//
//   - an idea is a `figure(kind: "rheo-idea")`;
//   - `_bracket` wraps every idea AND every window in `<rookery-edge>`
//     metadata markers, so walking the two selectors together in document
//     order gives containment depth without parsing anything;
//   - an idea's authored title is a `metadata` payload among the figure body's
//     children, NOT rendered text. MEASURED: walking the figure's body for
//     text returns the empty string for every idea on a weeknote, which is
//     what makes a generic `title-of:` useless here and this resolver
//     necessary.
#let _IDEA-KIND = "rheo-idea"
#let _idea-selector = figure.where(kind: _IDEA-KIND)

// Entries for every idea inside the page brackets, with real nesting depth.
//
// `region`/`v` are the page brackets; see `contents`. Depth is an idea's
// LITERAL containment — one `#idea` written inside another's body — read off
// the edge markers, because a figure is seen before its own bracket opens and
// so counts only its enclosing ideas.
//
// Windowed ideas are skipped. A `show figure.where(kind: ..)` rule does not
// remove the original figure from `query()`, so a note windowed onto this page
// re-exposes every idea its stored body ever contained; without the
// `window-depth` guard each of those would be listed again as though it were
// a section of this page. rookery's own outline carries the same guard for the
// same reason.
#let _idea-entries(region, v) = {
  let idea-depth = 0
  let window-depth = 0
  // The window depth the PANEL ITSELF sits at, which is not always zero: a
  // `#window` replays a note's whole stored body, and in rookery mode this
  // panel is part of that body, so a weeknote windowed onto another page
  // brings its panel along inside the window.
  //
  // The guard below is therefore RELATIVE to this, not absolute. MEASURED on
  // the weeknotes index, which is one `#window(tagged: "weeknote")`: with an
  // absolute `window-depth > 0` every idea in the window was read as an echo,
  // every panel there resolved to zero entries, and the page rendered no
  // panels at all. Relative, a windowed panel lists its own window's ideas
  // and still skips anything a window NESTED inside it replays.
  //
  // Read off the first element of this panel's own region, before that
  // element's own bracket is applied — `#window`'s open edge is emitted
  // outside the body it replays, so by then the depth is already right.
  let base = none
  let out = ()
  for el in query(selector(<rookery-edge>).or(selector(_idea-selector))) {
    if base == none and region.at(el.location()) == v { base = window-depth }
    if el.func() == metadata {
      let m = el.value
      if type(m) != dictionary { continue }
      let edge = m.at("rookery-edge", default: none)
      let container = m.at("rookery-container", default: none)
      let step = if edge == "open" { 1 } else if edge == "close" { -1 } else { 0 }
      // Ideas and windows are bracketed by the same marker, told apart by
      // `rookery-container`. Anything that is not an idea is treated as a
      // window: the guard's job is to notice we are inside SOMETHING that
      // replays stored content, and erring that way skips an entry rather
      // than listing a duplicate.
      if container == _IDEA-KIND { idea-depth += step } else { window-depth += step }
      continue
    }
    if window-depth > (if base == none { 0 } else { base }) { continue }
    if region.at(el.location()) != v { continue }
    // The payload sits among the figure body's immediate children.
    let payload = el.body.children.find(x => x.func() == metadata)
    if payload == none { continue }
    let pv = payload.value
    if type(pv) != dictionary { continue }
    // `title` is the authored one; `label` is rookery's fallback for a note
    // with none, its opening words. An idea with neither has no name to list.
    let name = pv.at("title", default: none)
    if name == none { name = pv.at("label", default: none) }
    if name == none { continue }
    // The idea's own id, already on its heading wherever it renders. A
    // minted page replays the note's stored body under rookery's own inner
    // `show figure` rule, which claims each figure before the anchor rule
    // below can, so an anchor stamped there is never emitted.
    out.push((title: name, depth: idea-depth, loc: el.location(), id: pv.at("id", default: none)))
  }
  out
}

// Entries for every `separator` match inside the page brackets that is NOT
// replayed content — the plain-selector counterpart of `_idea-entries`
// above, and it exists for exactly the same reason.
//
// A `#window` replays a note's whole stored body, headings included, and
// those headings are really rendered on this page: they sit inside the page
// brackets and `query()` returns them, so a bracket test alone cannot tell
// them from the page's own sections. `_idea-entries` has always guarded
// against this; the plain path did not, and off a rookery that was harmless
// because nothing replays anything there.
//
// MEASURED on waterline's ohrg.org, a rookery whose posts keep ordinary
// headings — one idea per post, sections not hatched — and which therefore
// uses `separator: heading`. On a minted idea page rookery renders the
// Backlinks block as folded windows, so `/ideas/jensen-suther-novel-organism-
// form` listed five sections of which four belonged to the post citing it.
// 15 of that site's 30 panelled pages were wrong the same way.
//
// The walk mirrors `_idea-entries` exactly — same markers, same relative
// `base`, same treatment of a non-idea container as a window — so the two
// resolvers cannot drift apart. A project with no `<rookery-edge>` markers
// queries a label that never occurs, leaves `window-depth` at zero, and gets
// precisely the bracket-filtered list it got before this function existed.
#let _plain-entries(region, v, separator, label-of, rung-of) = {
  let window-depth = 0
  let base = none
  let out = ()
  for el in query(selector(<rookery-edge>).or(separator)) {
    if base == none and region.at(el.location()) == v { base = window-depth }
    if el.func() == metadata {
      let m = el.value
      if type(m) != dictionary { continue }
      let edge = m.at("rookery-edge", default: none)
      let container = m.at("rookery-container", default: none)
      let step = if edge == "open" { 1 } else if edge == "close" { -1 } else { 0 }
      // Anything that is not an idea is treated as a window, erring towards
      // skipping an entry rather than listing a duplicate — `_idea-entries`
      // makes the same call for the same reason.
      if container != _IDEA-KIND { window-depth += step }
      continue
    }
    if window-depth > (if base == none { 0 } else { base }) { continue }
    if region.at(el.location()) != v { continue }
    out.push((title: label-of(el), depth: rung-of(el), loc: el.location()))
  }
  out
}

// ---- The show rule -------------------------------------------------------

// `title` — the box's own header text, or `auto` for the document's own title
//   (`set document(title: ..)`), which is what the page is called and so what
//   the panel describing it should be called too. Falls back to "contents"
//   where the document sets no title. MEASURED: `document.title` resolves per
//   vertebra under rheo, not to some bundle-wide value, despite the whole
//   project compiling as one Typst document.
// `separator` — the Typst SELECTOR whose matches become the rows.
//   `heading.where(outlined: true)` by default, so a heading Typst's own
//   `#outline` would skip gets no row either. The reason it is a parameter at
//   all is that a vertebra's sections are not always headings.
//
//   MEASURED against waterline's weeknotes: that template hands its body to
//   rookery's `#ideate` with `separator: heading.where(level: 2)`, which
//   CONSUMES those headings and re-emits each section title as a raw
//   `html.elem("h2", ..)`. rookery's own `core/0.1.0/src/outline.typ` states
//   the rule — an idea "only ever becomes [a heading] on the PAGED target ...
//   never on html/epub". So on the html target that page has eight visible
//   sections and `query(heading)` finds none of them, and no default this
//   package could pick would fix that.
//
//   Passing the selector those sections DO match — for a rookery, the figure
//   its ideas are built from — points the box at them instead:
//
//       #show: contents.with(separator: figure.where(kind: <rookery-idea>))
//
//   The selector is supplied by the CALL SITE, not imported here: this package
//   has no dependency on `@rookery/core` and must not grow one. `entry-title`
//   and `entry-depth` above read whatever it names, and `title-of:`/`depth-of:`
//   override them for an element they do not fit.
// `title-of` — entry -> label content. `auto` uses `entry-title`.
// `depth-of` — entry -> integer rung. `auto` uses `entry-depth`.
// `levels` — entry depths to include, outermost first, or `auto`.
//
//   `auto` (the default) takes the TWO SHALLOWEST DEPTHS THE PAGE ACTUALLY
//   USES. A fixed `(1, 2)` was the first design and is wrong for a large class
//   of real vertebrae: a project whose template supplies the page title
//   typically starts its sections at `==`, never using `=` at all. MEASURED
//   against waterline's weeknotes, where every section is a `==` — with a fixed
//   `(1, 2)` every row came out as an indented SUBSECTION hanging off a thread
//   with no parent, numbered `0.1`, `0.2`, because the depth-2 heading was
//   being read as the second level of a hierarchy whose first level was empty.
//   Deriving from what the page uses is right for both conventions, and for a
//   flat `separator:` whose entries all sit at one depth, with no
//   configuration in any of the three cases.
//
//   An explicit list is still honoured, and is also normalised against the
//   depths present: passing `(1, 2)` to that same weeknote yields the same
//   result `auto` does rather than reinstating the bug.
// `numbered` — draw `1`/`1.1` numbers beside each row.
// `top` — draw the jump-to-top arrow in the box header.
// `breakpoint` — a CSS length, or `none`. BELOW this viewport width the panel
//   drops out of its pinned column and into the flow above the content: a
//   rail beside the text has nowhere to sit on a phone.
//
//   `none` emits no width-keyed CSS at all and hands the whole responsive
//   decision to the project's own stylesheet — including `reserve:`, which is
//   width-keyed too. Worth doing wherever the project ALSO has its own rules
//   at the same width (a two-column layout, say), because the breakpoint
//   cannot be a custom property and would otherwise be written twice with
//   nothing keeping the two copies in step.
//   This is a Typst parameter and not a CSS variable because A CUSTOM PROPERTY
//   CANNOT BE USED IN AN `@media` QUERY — `@media (max-width: var(--x))` does
//   not work in any browser. So the breakpoint rule is the one rule this
//   package emits per page instead of shipping in `contents.css`; keeping it
//   out of the stylesheet also means an author-set breakpoint has no default
//   rule at another width left over to fight with.
// `side` — which edge the panel is pinned to, `right` (the default) or
//   `left`. Forwarded to `frame`, which is where it is documented; the only
//   thing it does HERE is pick the side `reserve:` pads, so the room made for
//   the box is on the side the box is actually on. Stated once, in other
//   words, rather than once in Typst and again in the project's stylesheet.
// `reserve` — a CSS selector to pad on the side the panel is on, so the page's
//   own content stays clear of the box. `"body"` by default, and `none` to opt
//   out for a project whose layout already leaves a wide enough margin there.
//   The box is `position: fixed` (see the long comment further down on why
//   it cannot be a column in a flex row), so it takes no space in the flow
//   and something has to make room for it.
// `offset-selector` — optional CSS selector for the project's own sticky
//   header. When given, the script measures that element, pins the box flush
//   beneath it, and scrolls a clicked section to just below it. When `none`,
//   `--rheo-panel-top` is used as-is.
// `align-selector` — optional CSS selector for something the panel should line
//   up with BEFORE the reader has scrolled, typically the first section's own
//   header. The script takes whichever of this and the sticky-header offset is
//   lower on the page, so the panel starts level with that element and then
//   rises with it until it pins under the header — which is what `position:
//   sticky` would do if the panel could be a column, and it cannot (see
//   below).
// `wrap` — a function applied to the finished panel (the aside) before it is
//   emitted, so a caller can place the panel in a container of its own
//   choosing instead of the package pinning it with `position: fixed`. When
//   given, the aside carries `data-rheo-panel-wrapped` and the CSS drops it
//   back into the flow, since its container now decides where it sits.
#let contents(
  title: auto,
  separator: heading.where(outlined: true),
  title-of: auto,
  depth-of: auto,
  levels: auto,
  numbered: true,
  top: true,
  breakpoint: "64rem",
  side: right,
  reserve: "body",
  offset-selector: none,
  align-selector: none,
  wrap: none,
  doc,
) = {
  // Same check `frame` makes, for the reason given at the `reserve:` rule
  // below: that rule uses `side` and is emitted on pages that build no frame.
  assert(
    side == left or side == right,
    message: "@rheo/contents-panel: `side:` must be `left` or `right`, got " + repr(side),
  )
  assert(
    wrap == none or type(wrap) == function,
    message: "@rheo/contents-panel: `wrap` must be none or a function — got " + repr(wrap),
  )
  assert(
    wrap == none or reserve == none,
    message: "@rheo/contents-panel: `wrap` and `reserve` cannot be combined — a wrapped "
      + "panel is in the flow and reserves nothing; pass `reserve: none`",
  )

  // ---- Which headings are on THIS output page --------------------------
  //
  // `region` brackets the page: stepped once just before the document and once
  // just after it, so every heading rendered in between reads the same value
  // and everything outside reads a different one. A counter's value AT A
  // LOCATION is monotonic in document order, which is what makes this a usable
  // "is it inside my brackets" test, and it is plain Typst — no rheo needed.
  //
  // Two earlier attempts are worth not repeating:
  //
  //   `state("rheo-handle")` at the heading's location gives the handle of the
  //   VERTEBRA THAT AUTHORED the heading, which is not the same thing as the
  //   page that renders it. MEASURED against waterline's weeknotes, whose
  //   template transcludes each section from an idea vertebra of its own: the
  //   page renders eight `==` sections and the handle filter admitted three
  //   headings, none of them those eight.
  //
  //   Walking the `doc` content tree misses any heading produced inside a
  //   `context` block, which is unresolved content until layout. Same page,
  //   same measurement: zero headings found, box absent entirely.
  //
  // Both steps and every read happen at the top level, so nothing here puts
  // `doc` inside a container — see the note further down on why that matters.
  let region = counter("rheo-contents-region")
  let label-of = if title-of == auto { entry-title } else { title-of }
  let rung-of = if depth-of == auto { entry-depth } else { depth-of }

  // `separator: idea` is sugar, recognised by NAME. `idea` is a plain function
  // rather than an element, so it cannot be queried and cannot be compared
  // against anything this package is allowed to import; `repr` of a named
  // function is its name (measured: `repr(heading)` is "heading"), which is
  // enough to spot the one case worth sugaring without a dependency.
  //
  // The call site still imports `idea` from `@rookery/core` itself — passing
  // it is what says "this is a rookery" — and a project that would rather be
  // explicit can always write the resolver's two halves out by hand.
  let rookery = type(separator) == function and repr(separator) == "idea"
  // What the anchor show rule attaches to. For a rookery that is the figure an
  // idea is built from; `separator` itself is not a selector there.
  let anchor-on = if rookery { _idea-selector } else { separator }

  // Must be called from a context INSIDE the brackets, where `region.get()` is
  // this page's own value. Returns the page's tracked headings, their ids, and
  // the depths those headings actually occupy.
  let resolve() = {
    let v = region.get()
    // Entries are `(title, depth, loc)` whichever resolver produced them, so
    // everything downstream — ids, numbering, rows, anchors — is shared.
    let mine = if rookery {
      _idea-entries(region, v)
    } else {
      _plain-entries(region, v, separator, label-of, rung-of)
    }

    // The depths the page actually uses, shallowest first. Everything is
    // indexed against THIS rather than against the `levels` argument, so a
    // level nobody wrote never occupies a rung of the hierarchy.
    let used = mine.map(h => h.depth).dedup().sorted()
    // EVERY depth the page uses, not just the two that get drawn as distinct
    // rungs — `_rung` flattens the rest into the second rather than dropping
    // them. See its comment.
    let wanted = if levels == auto { used } else { used.filter(d => d in levels) }
    let all = mine.filter(h => h.depth in wanted)
    (all: all, ids: _ids(all), levels: wanted)
  }

  // Each tracked heading gets an empty anchor div immediately BEFORE it, rather
  // than an `id` written onto the heading itself. Replacing the heading would
  // mean re-emitting it — `html.elem("h" + str(it.depth + 1), ..)` — and that
  // discards whatever the project's own `show heading` rule does to it, which
  // for a template that numbers or decorates its headings is the visible half.
  // Returning `it` unchanged after the anchor leaves every other rule intact
  // and still gives the script something to measure.
  //
  // The id is looked up in the SAME `ids` array the links are built from, by
  // the heading's own location, so the two cannot disagree. `resolve()` runs
  // again per heading rather than being computed once and captured: the value
  // it needs is only correct inside the brackets, and the show rule is the only
  // thing here that runs there.
  let body = {
    show anchor-on: it => {
      context {
        let r = resolve()
        let i = r.all.position(h => h.loc == it.location())
        if i != none and r.all.at(i).at("id", default: none) == none {
          html.elem("div", attrs: (class: "rheo-contents-anchor", id: r.ids.at(i)))
        }
      }
      it
    }
    doc
  }

  // The list, inside the frame `panel.typ` draws. Nothing about the hat, the
  // rules, the arrow or where the panel sits is decided here — this function
  // owns the rows, and hands the rest over.
  let box-of(all, ids, levels, heading-text) = {
    let nums = _numbers(all, levels)

    frame(
      cap-text: heading-text,
      top: top,
      aria-label: "Contents",
      // A list of links to the page's own sections is navigation, so the box
      // is a `nav` here where a bare frame's is a `div`.
      element: "nav",
      side: side,
      rookery: rookery,
      // In rookery mode the aside is emitted INSIDE the idea box it lists the
      // sections of, so it inherits that box's inline `--idea-*` theme;
      // `panel.typ`'s `rookery:` adds the class `contents.css` maps them
      // under. Off a rookery there is no theme to adopt and the class is
      // absent.
      offset-selector: offset-selector,
      align-selector: align-selector,
      aside-class: "rheo-contents-aside",
      box-class: "rheo-contents-box",
      // Marks the aside for `contents.css`'s wrapped rule and lets `wrap`
      // below (a plain `contents`-level closure, not a `frame` parameter)
      // decide the container the aside is emitted into.
      wrapped: wrap != none,
      html.elem("div", attrs: (class: "rheo-contents-list"), {
        for (i, h) in all.enumerate() {
          let depth-i = _rung(levels, h.depth)
          html.elem(
            "a",
            attrs: (
              class: "rheo-contents-link" + if depth-i > 0 { " rheo-contents-sub" } else { "" },
              href: "#" + ids.at(i),
              // The script needs the DEPTH, not the row's position: a section
              // runs until the next heading at the same depth or shallower,
              // which is how a top-level row keeps filling while its own
              // subsections scroll past.
              "data-level": str(h.depth),
            ),
            {
              if numbered {
                html.elem("span", attrs: (class: "rheo-contents-num"), nums.at(i))
              }
              // `rich`, not `plain`: the row keeps the heading's own inline
              // markup. `plain` is still what the SLUG is built from — an id
              // is a string and has no use for an `<em>`.
              html.elem("span", attrs: (class: "rheo-contents-label"), rich(h.title))
            },
          )
        }
      }),
    )
  }

  // Both rules are emitted here rather than living in `contents.css` because
  // both are keyed to `breakpoint:`, which cannot be a custom property — see
  // its comment above. They are exact complements, so there is no width at
  // which both apply.
  let breakpoint-css = if breakpoint == none {
    // `breakpoint: none` — THE PROJECT OWNS THE RESPONSIVE BEHAVIOUR. Nothing
    // keyed to a width is emitted: not the rule that drops the panel into the
    // flow, and not `reserve:`, which is also width-keyed and so cannot stand
    // without it.
    //
    // The reason to want this is that the breakpoint cannot be a custom
    // property — `@media (max-width: var(--x))` is illegal — so a project that
    // also has its OWN width-keyed rules for the panel's column ends up
    // stating the same number twice, once here and once in its stylesheet,
    // with nothing to keep the two in step. Handing the whole decision to the
    // stylesheet lets it live once, beside the column widths it is derived
    // from. The project then owns all four things this would have emitted:
    // making the panel `static`, hiding the hat, shortening the list, and
    // reserving the column.
    ""
  } else {
    // BELOW THE BREAKPOINT THE PANEL GOES BACK INTO THE FLOW, above the
    // content, rather than disappearing.
    //
    // Hiding it was the first behaviour and left a phone with no contents at
    // all, which is only tolerable if something else on the page supplies
    // them — and nothing generally does. A pinned rail genuinely cannot work
    // at that width, there being no room beside the prose for it; but the
    // markup is already in the right place to read as an ordinary block,
    // because `lib.typ` emits the aside BEFORE the document rather than after
    // it. So the same list becomes a short static contents above the article,
    // which is the conventional shape on a phone anyway.
    (
      "@media (max-width: " + breakpoint + ") {"
        + " .rheo-panel-aside { position: static; width: auto; max-width: none;"
        + " margin: 0 0 1.5rem; }"
        // NO HAT ON A PHONE. The hat's whole job is to label a box floating
        // beside the text; in the flow, directly under the page's own title,
        // it repeats that title and the rule reads as a stray mark. The
        // page-progress fill goes with it — it is drawn behind the title —
        // and is no loss, since a static block does not track scrolling.
        + " .rheo-panel-header { display: none; }"
        // Shorter than the pinned rail, which is sized against the viewport it
        // is fixed in; here the list is pushing the article down the page.
        + " .rheo-contents-list { max-height: 50vh; } }"
    )
    // Above it: keep the page's own content clear of the fixed box. Without
    // this a full-width article runs underneath it.
    //
    // Parenthesised, because a `+` at the START of a line inside a code block
    // is read as a unary plus opening a new statement rather than as a
    // continuation of the previous one.
    if reserve != none {
      // PADDED ON THE SIDE THE PANEL IS ON. `frame` also asserts on `side`,
      // but not usefully for this rule: the frame is only built when the page
      // has entries, and this rule is emitted either way, so the check has to
      // happen here too for it to be reached on every page.
      (
        "@media not all and (max-width: " + breakpoint + ") { " + reserve
          + " { " + (if side == left { "padding-left" } else { "padding-right" })
          + ": calc(var(--rheo-panel-width, 16rem)"
          + " + 2 * var(--rheo-panel-gap, 2.5rem)); } }"
      )
    }
  }

  // ---- Why `doc` is NOT wrapped in anything -----------------------------
  //
  // The obvious layout for this is the one the reference design uses: a flex
  // row wrapping the article in one column and the box in the other. It cannot
  // be done here, and the reason is a hard Typst rule rather than a preference.
  //
  // MEASURED against waterline's weeknotes: `#show: contents` at the top of a
  // vertebra composes OUTSIDE the project's own template, so the template's
  // content — including its `set document(title: ..)` — lands inside whatever
  // this function wraps `doc` in, and Typst fails the compile outright with
  // "document set rules are not allowed inside of containers". ANY element
  // around `doc` triggers it, so an entire class of real vertebrae — every one
  // whose template sets the document title, which is most of them — could not
  // use this package at all.
  //
  // So `doc` stays exactly where it was, at the top level, and the box is
  // emitted as its SIBLING and positioned by CSS alone. `contents.css`
  // declares its variables on `:root` for the same reason: there is no wrapper
  // element to hang them on.
  context {
    if target() != "html" {
      // PDF and EPUB get the document untouched, and no brackets either. A
      // sticky box with a scroll progress bar has no meaning on a page that
      // does not scroll, and both those targets have their own outline
      // mechanisms — EPUB's is core's `collect_headings`, cited at the top of
      // this file.
      doc
    } else {
      region.step()
      // The CSS holds no `<` or `&`, so Typst's text escaping cannot corrupt it.
      // Skipped entirely under `breakpoint: none`, rather than hoisting an
      // empty `<style>` into every page's head.
      if breakpoint-css != "" {
        html.elem("rheo-head", html.elem("style", breakpoint-css))
      }
      // Inside the brackets, so `resolve()` sees this page. An empty page gets
      // no aside at all rather than an empty one.
      context {
        let r = resolve()
        if r.all.len() > 0 {
          let heading-text = if title == auto {
            let t = document.title
            if t == none { "contents" } else { t }
          } else {
            title
          }
          let box = box-of(r.all, r.ids, r.levels, heading-text)
          if wrap != none { wrap(box) } else { box }
        }
      }
      body
      region.step()
    }
  }
}
