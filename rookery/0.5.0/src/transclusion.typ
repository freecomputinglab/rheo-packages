// Transclusion: the edge markers that bracket a transcluded body, the content a
// window renders, `_flatten` and `_body-at`.
//
// This is the machinery `#window` and `#idea-body` are thin public faces over,
// and it is where the recursion budget is spent — `_flatten`'s own comments
// carry what each depth costs.

#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *
#import "hyperlink.typ": *
#import "bib.typ": *

// ---- Transclusion: edge markers, window content, _flatten, _body-at ------
//
// A link that sits DIRECTLY in a page — in its prose, or a page-level `#window`
// — is a backlink from that page. A link inside a note is a backlink from the
// note, and must not also be counted for the page or for any note enclosing
// it. So the question is only ever "how deep am I", and these two invisible
// markers answer it: `#idea` brackets its rendered body with them, `#window`
// brackets each note it transcludes, and `_page-links` walks the document in
// order keeping a depth count. Depth 0 is the page itself.
//
// Bracketing `#window` is what makes a TRANSCLUDED body behave: a note shown on
// five pages renders its links on all five, and without the brackets each of
// those pages would look like it linked directly to whatever the note links
// to. Inside the brackets they are at depth 1 and belong to the note.
//
// REFUTED ALTERNATIVE, do not retry: `show metadata: none` inside `_flatten`,
// to strip a stored body's markers instead of nesting them. MEASURED — a
// metadata element hidden by a show rule is STILL returned by `query`, so it
// strips nothing that matters and the duplicates survive.
//
// Defined BEFORE `_flatten`: its IK rule brackets a reconstructed nested
// header+box itself now, so it needs `_bracket` in scope at definition time.
//
// `container` (IK or WK) rides along on top of `edge` ("open"/"close") so a
// reader of the marker (currently just `#ideas-outline`) can tell an IDEA's
// own bracket apart from a WINDOW's — `_page-links`/`_outbound` don't care
// which, only "how deep", so this is purely additive: an extra key on the
// same dict, ignored by every existing reader.
#let _edge(edge, container) = metadata((rookery-edge: edge, rookery-container: container))
#let _bracket(body, container) = _edge("open", container) + body + _edge("close", container)

// ONE rendering of ONE window — summary row, disclosure, body — shared by
// `#window` itself and by `_flatten`'s WK rule when `depth` lets it expand a
// nested window instead of collapsing it. Shared so the two cannot drift: an
// expanded nested window must be indistinguishable from the same `#window`
// written at the top level, or `depth:` would introduce a second, lesser
// rendering of the same thing.
//
// Takes `shown` already truncated (the caller owns `limit:`) and emits NO
// `figure`/`_bracket` wrapper — the two callers wrap differently. `#window`
// needs the `figure(kind: WK)` so an enclosing `_flatten` can find and
// collapse it; the expansion deliberately emits no such figure, since it has
// already been claimed.
//
// `folded` sets only the INITIAL disclosure state — `false` (the default)
// renders `<details open>`, `true` renders it closed. It is not a second
// layout: a folded window and an unfolded one are the same block, so a reader
// who opens one sees exactly what a `#window` beside it already shows.
// `limit:` is therefore meaningful in both (it truncates the body that folding
// hides) and the two are orthogonal.
//
// CLICK BUDGET (HTML/EPUB) — the whole point of this shape, modelled on
// Forester (www.forester-notes.org, whose `tree.xsl` renders every transcluded
// tree as a `<details>` whose `<summary>` holds the title and an
// `<a class="slug">[tfmt-0006]</a>`):
//
//   - clicking ANYWHERE in the summary — title, date, the whitespace between
//     them — folds or unfolds, and does nothing else;
//   - clicking the `[idea:etal]` permalink, and only that, opens the note's
//     own page.
//
// So the transcluded body is NOT a link and there is no trailing arrow. Both
// were tried and removed. An outer <a> around the body is invalid the moment
// that body contains its own link (MEASURED: browsers and typst's HTML export
// both truncate the outer anchor where the inner one starts and never resume
// it, so only "the first bit" stays clickable), and the arrow was a second
// navigational affordance competing with the permalink for the same click.
//
// The disclosure is native `<details>`/`<summary>`: this package ships no JS,
// and a `:target`/checkbox CSS hack would need a unique control id per window.
// An `<a>` INSIDE `<summary>` does not break the toggle — only an `<a>` around
// the whole summary does, which is what the earlier folded-row design got
// wrong. The permalink navigates on its own click; the summary keeps the rest.
//
// `show-date` is OFF by default, same as `#idea`'s own — a date is always
// RESOLVED and stored on the note's registry record regardless, so passing
// `show-date: true` here can surface it even for a note whose own `#idea`
// call left it hidden; the two are independent per call site, not one shared
// setting.
//
// Must be called from inside a `context` block: `_permalink` reads the page
// handle and the prefix state. Both callers already are.
#let _window-content(id, rec, shown, folded, show-date, show-tags, windows-claim: false) = {
  // `updated`, not `minted`, matching `#idea`'s own hat. The registry record
  // carries both, and `updated` already falls back to `minted` (which falls back
  // to the document's date) when the note never named one — so a note that says
  // nothing looks exactly as it did, and a note that does shows when it was last
  // touched, which is what a reader of a rookery wants off the top of a window.
  let date = if show-date and rec.updated != none {
    rec.updated.display("[year]-[month]-[day]")
  } else { none }

  if _target() == "html" or _target() == "epub" {
    // The id leads the summary as the window's own top rule, so a titleless
    // note needs no special case: the tab is there either way, and the title
    // span is simply absent beneath it. `#idea`'s own heading does the same.
    let title-span = if rec.title == none { [] } else {
      html.elem("span", attrs: (class: "idea-window-title"), rec.title)
    }
    // The tab stays INSIDE the `<summary>`, as its first child. Moving it into
    // the `<details>` body would hide the id whenever the window is folded, and
    // it has to be visible and clickable in both states.
    //
    // THE DATE GOES IN THE TAB, not beside the title as a third item in this row.
    // `.idea-window-date` is gone with it: a date is the same object on a card and
    // on a window, so it wears the same class in the same place, and the summary
    // row is back to a tab plus a title.
    let summary = html.elem(
      "summary",
      attrs: (class: "idea-window-summary"),
      _permalink-tab(
        id,
        // Flat tags only, matching `#idea`'s own hat: a valued tag's name alone
        // says nothing useful in a pill, so `show-tags:` shows the plain ones.
        tags: if show-tags {
          rec.at("tags", default: (:)).pairs().filter(p => p.at(1) == none).map(p => p.at(0))
        } else { () },
        date: date,
      ) + title-span,
    )
    // `open` is a BOOLEAN html attribute: present means open and there is no
    // value meaning closed, so the attrs dictionary itself has to differ
    // between the two states. `open: "false"` would read as open.
    let d-attrs = if folded { (class: "idea-window-details") } else {
      (class: "idea-window-details", open: "open")
    }
    // `_footnoted(shown)`, not `shown`: a transcluded body carries the origin
    // note's footnote markers, and without a rule of its own here they would be
    // claimed by whatever idea box encloses THIS window and numbered against a
    // block that does not list them — dangling anchors, MEASURED on a
    // `#window` written inside another note's body. Installing the same wrapper
    // `#idea` uses gives the window its own block and its own numbering, and
    // being nested it wins over the enclosing rule.
    //
    // References go in the window's own body too, for the same reason its
    // footnotes do: a transcluded body carries the origin note's citations, a
    // citation link is a same-page fragment, and a window on page B therefore
    // needs its target on page B. Without a block of its own the citations
    // would be claimed by whatever bibliography follows on the host page —
    // an enclosing idea's list, or a sweep block belonging to no one.
    //
    // Cross-page citation links to the note's own minted page were considered
    // and REJECTED: redirecting a citation means de-registering it, and a
    // de-registered citation renders nothing, so the package would have to
    // format the marker itself — which means parsing the bibliography and
    // reimplementing what Typst already does. Do not reintroduce them.
    //
    // Both take `shown`, not the untruncated body — the caller already applied
    // `limit:`, and a window must not list a footnote or a citation whose
    // reference it truncated away. Both blocks sit INSIDE
    // `.idea-window-body`, so they fold away with the window.
    html.elem("div", attrs: _themed((class: "idea-window")),
      html.elem("details", attrs: d-attrs,
        summary + html.elem("div", attrs: (class: "idea-window-body"),
          _footnoted(shown) + _refs-block(_own-cited-keys(shown, windows-claim: windows-claim)))))
  } else {
    // No disclosure in a paged target — nothing to click, so a fold that
    // could not be opened would just hide the body: `folded` is ignored
    // here and the body always shows. The head still renders and the
    // permalink is still the only link, so both targets read the same.
    let head = {
      if rec.title != none { strong(rec.title); [ ] }
      _permalink-paged(id)
      if date != none { [ ]; text(gray, date) }
    }
    // `align(start)` because `#window` puts this inside a `figure`, and a
    // Typst figure CENTRES its body — see the note on `#idea`'s own paged
    // branch, which this shares the defect and the fix with.
    align(start, block[#head#parbreak()#_footnoted(shown)#_refs-block(_own-cited-keys(shown, windows-claim: windows-claim))])
  }
}

// `depth` is the nested-window budget described at `_window-depth`: how many
// further levels of `#window` the returned content may unfurl before falling
// back to the collapsed permalink. It is a CLOSURE-CAPTURED CONSTANT, not
// state, and that is the whole termination argument — each expansion below
// recurses with `depth - 1` baked into a fresh scope, so a self-window or an
// A-windows-B/B-windows-A cycle bottoms out at 0 rather than re-expanding
// forever. (The `state` depth counter this supersedes is REFUTED and must not
// come back: measured failing on typst 0.14.2 AND 0.15.1, where a self-window
// still hit the nesting cap before the state timeline converged.)
//
// MEASURED, the second half of the termination argument: when both an outer
// `_flatten(.., depth: n)` scope and an inner `_flatten(.., depth: n-1)` scope
// carry a rule for the same selector, the INNER one wins and the outer does
// NOT re-fire on content the inner already claimed. Verified on typst 0.15.1
// with a two-level `show figure.where(kind: K)` reproduction: output was
// `OUTER(INNER)`, not a "maximum show rule depth exceeded". Since every
// expansion below wraps its body in a fresh `_flatten` scope — including at
// `depth: 1`, where the rule collapses — every generated WK figure is always
// claimed by a strictly smaller budget.
//
// `depth` here is the budget of the note whose body this IS, so a window found
// in it may only unfurl when there is a level left over for it: hence `depth >
// 1` throughout, and `depth: 1` (the default, and what registration flattens a
// body at) is the collapse. See the scale at `_window-depth`.
#let _flatten(body, depth: 1) = {
  // MEASURED DEFECT this fixes: a `@idea:other` inside a note's body rendered
  // as a bare figure number ("2") on the note's minted page, while rendering
  // correctly in situ. `show ref: hyperlink` is installed by `#show:
  // rookery` on the VERTEBRA, and a minted page is a separate `#document`
  // that `.marrow.typ` contributes at the bundle root — outside every
  // vertebra's show-rule scope. So the stored body has to carry the rule
  // with it, the same way it carries the IK/WK rules below. Always the
  // page-preferring default here regardless of what the vertebra's own
  // `show ref:` was configured to — a nested reference inside a
  // transcluded/minted body has no access to that outer choice, so it gets
  // the same default an unconfigured document would.
  //
  // Attaching it here also covers a `#window` rendered anywhere else the
  // document-level rule happens not to reach, and cannot double-apply: the
  // inner rule turns the `ref` into a `link`, so an outer `show ref:` no
  // longer matches it.
  //
  // (`hyperlink` is defined ABOVE this function for exactly this reason —
  // a `#let` closure captures the scope visible at definition time.)
  show ref: hyperlink
  show figure.where(kind: IK): it => context {
    let m = it.body.children.find(c => c.func() == metadata)
    let v = m.value
    // NAMED only: the id needs `_pfx()`, safe to read here (state, no
    // stepping). An auto-numbered nested idea's id lives on a counter value
    // frozen at its ORIGINAL site — recomputing it here would read the
    // counter's value at THIS (later, transcluded) position instead, so it
    // is left without an id/permalink rather than shown wrong.
    let id = if v.named { _pfx() + v.base } else { none }
    let cls = ("idea",) + v.tags.keys().map(l => "idea-tag-" + l)
    if _target() == "html" or _target() == "epub" {
      let attrs = (class: cls.join(" "))
      if id != none { attrs = attrs + (id: id) }
      // Tab before the heading, and the `id == none` guard travels with it: an
      // auto-numbered nested note has no id to show, so it gets no tab either
      // and its card simply has no top rule.
      let header = _head(
        if id == none { [] } else { _permalink-tab(id) },
        html.elem(
          "h" + str(v.level + 1),
          attrs: attrs,
          (if v.title == none { [] } else {
            html.elem("span", attrs: (class: "idea-title"), v.title)
          }),
        ),
      )
      let box-cls = ("idea-box",) + v.tags.keys().map(l => "idea-tag-" + l)
      // Sweep first, OUTSIDE the bracket: it belongs to the page, claiming
      // prose citations written before this note. The references block goes
      // inside the bracket, so the back-references Typst puts in its entries
      // count as this note's links rather than the page's — and inside the CARD
      // as well, for the reason `#idea`'s own branch records: the card's rule and
      // indent are what make a block read as this note's apparatus, exactly as
      // its footnotes do, and a sibling of the card gets neither.
      _sweep-block()
      _bracket(
        html.elem(
          "div",
          attrs: _themed((class: box-cls.join(" "))),
          header + _footnoted(v.body) + _refs-block(_own-cited-keys(v.body, windows-claim: depth > 1)),
        ),
        IK,
      )
    } else {
      _sweep-block()
      _bracket({
        if v.title != none { heading(depth: v.level, v.title) }
        _footnoted(v.body)
      } + _refs-block(_own-cited-keys(v.body, windows-claim: depth > 1)), IK)
    }
  }
  // A `#window` nested inside a transcluded body. With no recursion budget left
  // over for it (`depth: 1`, the default — and `depth: 0`, where nothing is
  // transcluded anywhere) it bottoms out to `_window-link`, THE SAME row
  // `#window` itself emits at depth 0. One rendering for one meaning: the
  // one-link rule holds at every depth, and the row names the note by its title
  // rather than by its id.
  //
  // With budget left, it renders as a real window instead, identical to the
  // same `#window` written at the top level — same summary, same disclosure,
  // same `folded`/`limit`/`show-date`, which is why `#window` records all four
  // on the WK marker rather than the bare id it used to carry.
  //
  // Bracketed as a WINDOW, not left bare: the expanded body's links belong to
  // the note it came from, and its nested `#idea`s are echoes rather than this
  // page's own structure (`_page-links`, `_ideas-outline-data`). On a minted
  // note page there is no enclosing window bracket to inherit that from.
  //
  // Emits NO `figure(kind: WK)` of its own — nothing needs to match the
  // expansion again, and the inner `_flatten` below has already claimed
  // whatever it contains.
  //
  // Wrapped in `context` for `_permalink`/`_pfx`, which read the page handle
  // and the prefix state.
  show figure.where(kind: WK): it => context {
    let m = it.body.children.find(c => c.func() == metadata)
    let v = m.value
    let id = v.rookery-window-id
    if depth <= 1 {
      _window-link(id, _registry.final().at(id))
    } else {
      let rec = _registry.final().at(id)
      // The nested `#window` has already run in full by the time this rule
      // sees its figure — including building a body at ITS budget, which is
      // then thrown away for the one built here at the ENCLOSING budget. That
      // is the right answer (the enclosing scope owns how deep its own
      // transclusion goes) at the cost of one discarded body per level; free
      // at the default, where both sides are the cached `rec.body`. `_flatten`
      // is pure — no counter steps, no registration — so discarding it costs
      // nothing but the work.
      //
      // `depth == 2` reuses the record's already-flattened body rather than
      // re-flattening at the same budget: `rec.body` IS `_flatten(raw)` at
      // depth 1, computed once at registration.
      let inner = if depth == 2 { rec.body } else {
        _flatten(rec.raw, depth: depth - 1)
      }
      let shown = _truncate(inner, v.limit)
      // `.at(..., default: false)`, not a bare field access: a WK marker
      // minted before this bead (or by an older rookery version) carries no
      // `show-tags` key at all. NOTE: `v.show-date` just above is a bare
      // field access with no such guard — a pre-existing risk this bead does
      // not touch.
      _bracket(
        _window-content(
          id,
          rec,
          shown,
          v.folded,
          v.show-date,
          v.at("show-tags", default: false),
          windows-claim: depth - 1 > 1,
        ),
        WK,
      )
    }
  }
  body
}

// A note's body at a given nested-window budget. `auto` takes the
// document-wide default (`#show: rookery.with(window-depth: n)`), which is what
// lets a `#window` unfurl by the document's setting without naming a number.
//
// `.marrow.typ` passes an EXPLICIT depth instead, `window-depth + 1`: a minted
// page shows the note at the page's own top level rather than transcluding it,
// so a window written in that body is a top-level window and must render in
// full even at the default of 1. See the note beside `minted-depth` there.
//
// `d <= 1` short-circuits to the cached body rather than re-flattening at the
// same budget: `rec.body` IS `_flatten(rec.raw)` at depth 1 (registration's
// default), and depth 0 transcludes nothing at all, so neither has any nested
// window to unfurl. See the scale at `_window-depth`.
//
// Must be called from inside `context`: `.final()` on both states.
#let _body-at(rec, depth: auto) = {
  let d = if depth == auto { _window-depth.final() } else { depth }
  if d <= 1 { rec.body } else { _flatten(rec.raw, depth: d) }
}
