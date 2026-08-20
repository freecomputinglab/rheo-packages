// Mints one output page per registered note, at ideas/<id>.html, so a note
// gets a real URL instead of only an in-page fragment anchor on whatever page
// it happens to be written in. Reachable purely by importing this package —
// no rheo.toml entry, no project file needed — because rheo inlines a
// package's `.marrow.typ` verbatim at the bundle root (see typst_manifest.rs
// in rheo core). Skipped automatically for the combined PDF target, which
// rejects `document()`/`asset()` outright.
//
// Reach the package's own code by package spec, never a relative import: this
// text is spliced into rheo's synthesized bundle root, so a relative path
// would resolve against the PROJECT root, not this file's own directory.
//
// The `<prefix>:` stripped off each id to get a slug comes from `_pfx` (the
// document-wide prefix state), never a literal — a project running
// `#show: rookery.with(prefix: "note")` must mint at the same paths lib.typ
// links to. This file no longer strips it itself for the minting path:
// `_note-page` returns the slug, the file and the handle together, and reads
// that one state on this file's behalf.
//
// Deliberately does NOT re-declare the note's `<prefix>:<id>` Typst label on the
// minted page. Two elements sharing one label break every #link/#window/
// #hyperlink resolution to it as soon as either is referenced (labels only
// error on ambiguous lookup, not on declaration — see the epic's "Verified
// facts"). The label stays owned by the anchor #idea creates at the note's
// original call site; #link/#window/#hyperlink keep resolving there. The
// permalink on the minted page is a plain same-page HTML fragment
// (`href="#" + id` against this page's own heading `id` attribute), not a
// second declaration of the Typst label.
//
// Minted with `rheo-document`, not a bare `document()`, per rheo core's own
// guidance (crates/core/src/typ/rheo.typ): a bare `document()` skips
// `rheo-page-init`, so the page never publishes a handle of its own and
// inherits whatever `state("rheo-handle")` the spine left behind. Every
// depth-relative href computed ON this page then rides on that inherited
// value — rheo's cross-vertebra link rule, and lib.typ's `_note-href`.
// MEASURED on this package's own demo: the bare form happens to emit the same
// `../` prefix, because the inherited handle is one level deep just as
// `ideas/<slug>` is. That is a coincidence of this spine's shape, not a
// guarantee. Passing the handle makes the depth this page's own property. It
// mirrors the path — `ideas/<slug>.html` <-> `ideas:<slug>` — with both halves
// coming from lib.typ's `_note-page`, so minting and linking cannot drift.
// The permalink comes from lib.typ's `_permalink-tab` — the same top rule a
// note wears inside a card — with the href forced to this page's own fragment,
// because a minted page must not link to itself. Building the <a> by hand here
// instead is how it came to miss the configurable hover property that every
// other permalink carries.
// CONTEXT FOOTER. A minted page shows the note stripped of everything around
// it, which is the point — but a reader who lands on one has no way back to
// the argument it was written inside. The footer names that page and links to
// the note's own anchor within it, not merely to the top of it.
//
// The link is `#link(label(id))`, i.e. Typst's own cross-document label
// resolution, which exports as `<origin>.html#loc-N` — the anchor `#idea`
// declared at the call site. Two rules could have intercepted it and neither
// does: rheo's `show link:` rewrite only touches links whose target is a
// `rheo-handle` figure (this one is a `rheo-idea-anchor`), and it is exactly
// that rewrite which DROPS the fragment and lands on the top of a page. So
// `#link(<index>)` would have been the wrong tool here despite being the
// obvious one — it goes to the page, not to the note in it.
// BACKLINKS. The inverse of every note's recorded outbound links (see
// `_outbound` in lib.typ): the notes that point AT this one, in registry order.
// Built once for the whole run rather than per page — inverting the map costs
// one pass over the registry, doing it inside the loop would cost one per note.
//
// Only notes appear here. A link written in a page's ordinary prose, outside
// any `#idea`, cannot: nothing records it, because the registry is the only
// thing this package can see and it holds notes, not pages. That is also why
// the list can be rendered as `#window`s at all — every entry is by construction
// a thing there is a note to show.
// PAGE TEMPLATE. A minted page is a `#document` spliced in HERE, at the bundle
// root, so it is outside every vertebra and inherits none of the project's own
// `#show:` chrome — no site header, no nav. `#show: rookery.with(
// idea-page-template: ...)` is how a project hands one over; this file applies
// applied. `none` (the default) mints the bare page this always produced.
// Every name here is INTERNAL to `@rheo/rookery` and load-bearing for this
// file. lib.typ carries the matching "CONSUMED BY .marrow.typ" banner; renaming
// or re-signing any of them means changing both files in the same commit.
// SYNDICATION BEACON. Opt-in via `#show: rookery.with(syndicate: true)`
// (default off — a package must not emit into another package's label
// namespace unasked). When on, each minted note page also carries a
// `#metadata((..)) <rssfeed:item>` beacon shaped to the contract
// `@rheo/rssfeed`'s `items()` reads (see that package's readme and the
// `<rssfeed:item>` label — `rssfeed:item` is `items()`'s own default
// `label-name`). Emitted whether or not `@rheo/rssfeed` is installed at
// all: this file never imports it, and an unread `#metadata` beacon is
// inert — `#metadata` renders nothing on any target, so a project with no
// rssfeed in its dependency tree pays nothing for a beacon nobody queries.
// This is the SECONDARY syndication path — a project's own `.marrow.typ` (or
// any package) sourcing `ideas(tags:, match:)` straight into rssfeed's
// `items()` is the primary one; this exists for what that route cannot
// reach, e.g. a hand-authored page syndicating itself.
#import "@rheo/rookery:0.3.0": _registry, _note-page, _pfx, _head, _permalink, _permalink-tab, _themed, _handle-title, _page-links, _page-href, _body-at, _footnoted, _refs-block, _own-cited-keys, _window-depth, _idea-page-template, _syndicate, _plain, window

#context {
  let registry = _registry.final()
  let tpl = _idea-page-template.final()
  let syndicate = _syndicate.final()

  // NOTE backlinks: the inverse of every note's recorded outbound links.
  let backlinks = (:)
  for (src, rec) in registry.pairs() {
    for target in rec.at("links", default: ()) {
      if target not in registry { continue }
      let seen = backlinks.at(target, default: ())
      if src not in seen { backlinks.insert(target, seen + (src,)) }
    }
  }

  // PAGE backlinks: pages that link to a note in their own right, rather than
  // through a note they contain. Each page appears ONCE per note however many
  // times it links to it, and a page whose only links are inside its notes
  // does not appear at all — those links already belong to the notes, and
  // listing both would be counting the same link twice.
  let page-backlinks = (:)
  for (handle, targets) in _page-links() {
    for target in targets {
      if target not in registry { continue }
      let seen = page-backlinks.at(target, default: ())
      if handle not in seen { page-backlinks.insert(target, seen + (handle,)) }
    }
  }

  // THE DEPTH A MINTED PAGE RENDERS ITS NOTE AT, and it is `window-depth` PLUS
  // ONE rather than `window-depth` itself.
  //
  // A minted page shows the note as the page's own top level — it is not a
  // transclusion of it. So a `#window` written directly in the note's body is
  // a TOP-LEVEL window there, exactly as it is on the page the note was
  // hatched in, and it gets a top-level window's own budget. What
  // `window-depth` governs is windows nested inside a transcluded body, and on
  // a minted page the first body that is genuinely transcluded is the one
  // inside that top-level window — one level in, which is why the budget is
  // shifted by one rather than merely floored at 1.
  //
  // Unchanged by the depth-0 rebasing of the scale (see `_window-depth`), and
  // the arithmetic is why: `+ 1` says "windows in this body get the budget a
  // TOP-LEVEL window has", which is `window-depth` itself whatever number that
  // is. At the default of 1 the body is flattened at 2 — its windows render,
  // theirs collapse — exactly as it was flattened at 1 when the default was 0.
  // At `window-depth: 0` it is flattened at 1, so a window on a minted page
  // collapses to its `[idea:x]` permalink: still a link, as that setting asks
  // for, though the permalink rather than the `.idea-page-row` shape `#window`
  // itself uses at 0.
  //
  // MEASURED DEFECT this fixes: `ideas/idea.html` on rookery.ohrg.org ended in
  // two bare `[idea:hatching-ideas]` / `[idea:referencing-ideas]` permalinks,
  // directly under prose reading "Try unfolding these windows below by
  // clicking on their title panel" — there was nothing to unfold. Passing
  // `depth: auto` here treated the note's own body as if it were being
  // windowed, so its windows spent a budget that had never been meant for
  // them and collapsed.
  //
  // Read ONCE, outside the loop: it is one document-wide state for every page
  // this file mints.
  let minted-depth = _window-depth.final() + 1

  // CONTAINMENT: `note id -> containing note id or none`, for the Context
  // section below. Built ONCE for the whole run, like the backlink maps above —

  for (id, rec) in registry.pairs() {
    // Slug, minted path and minted handle from ONE helper, so this file cannot
    // disagree with what rookery links to (`_note-page`, and the comment above
    // it in lib.typ).
    let page-at = _note-page(id)
    let slug = page-at.slug
    // The note's body as this page renders it, flattened once and reused by
    // all three of the things that need it — the rendering below, the footnote
    // wrapper around it, and the citation walk. `_flatten` is pure, so a
    // second call would only repeat the work; sharing one value also makes it
    // impossible for the walks to disagree with what is on the page.
    let flat = _body-at(rec, depth: minted-depth)
    // Built as a value rather than passed straight to `rheo-document`, so the
    // project's template can wrap the WHOLE page — heading, body and footer —
    // and see exactly what a vertebra's own `#show:` would.
    let page = [
      // The id as this page's top rule, above the <h1> rather than inside it —
      // the same treatment a note gets in a card or a window summary, so a
      // minted page reads as the same object.
      //
      // `href: "#" + id` is the whole reason this call passes one: a note's own
      // page must permalink to itself as a FRAGMENT, not to the page it is.
      //
      // `_head` for the same reason every other header uses it: two loose
      // siblings in a content block are not reliably siblings in the HTML, and
      // MEASURED here they were not — the tab came out inside a `<p>` of its
      // own, breaking the stylesheet's `.idea-tab + h*.idea` rule. See `_head`.
      //
      // The theme goes on `.idea-head` rather than on the <h1>: a minted page has
      // no `.idea-box`, so something has to be the container, and this is the
      // only element enclosing BOTH the tab and the heading. On the <h1> alone, a
      // project that themed `border-color` got the package default on every note
      // page's tab, since a sibling inherits nothing.
      // THE DATE IS ALWAYS SHOWN HERE, unlike on a card or in a window, where it
      // is opt-in behind `show-date:`. A minted page has no call site to carry
      // that argument — nobody writes `#idea` for this page, `.marrow.typ` mints
      // it from the registry — and a note's OWN page is the one place the date is
      // not clutter: it is the page's metadata, not a decoration on someone
      // else's prose. `updated` for the same reason the hat elsewhere shows it,
      // and it falls back to `minted` and then to the document date, so a note
      // that names neither still shows something rather than nothing.
      #_head(
        _permalink-tab(
          id,
          href: "#" + id,
          // ALWAYS SHOWN, for the same reason the date is always shown here
          // (see above): a minted page has no call site to carry a
          // `show-tags:` argument, and a note's OWN page is the one place
          // its tags are not clutter. An untagged note's `rec.tags` is `()`,
          // which `_permalink-tab` already renders as nothing.
          tags: rec.at("tags", default: ()),
          date: if rec.updated == none { none } else {
            rec.updated.display("[year]-[month]-[day]")
          },
        ),
        html.elem(
          "h1",
          // The <h1> keeps the `id` — it is this page's anchor, the destination
          // of `#link(label(id))` from a Context footer — and the `idea` class
          // every heading rule matches on.
          attrs: (id: id, class: "idea"),
          // Title in a span, exactly as `#idea` does it — a hook, not a
          // requirement.
          (if rec.title == none { [] } else {
            html.elem("span", attrs: (class: "idea-title"), rec.title)
          }),
        ),
        attrs: _themed((:)),
      )
      // `flat`, not `rec.body`: the note is rendered at `minted-depth` (see
      // above), so a `#window` written in its body shows in full here and a
      // window nested inside THAT one follows the document's `window-depth`.
      //
      // Wrapped in `_footnoted` — the same wrapper `#idea` and `#window` use —
      // so the note's footnote markers are claimed HERE and listed in a block
      // of this page's own. A minted page is a separate `#document` at the
      // bundle root, outside every vertebra, so `#show: rookery`'s
      // document-wide fallback never reaches it: without this the markers were
      // claimed by nothing and rendered as nothing, silently dropping the
      // note's footnotes from its own page. MEASURED before the fix.
      //
      // It also puts the block between the body and the footer, which is where
      // it belongs: the note's own apparatus stays attached to the note, and
      // Context/Backlinks remain last as the navigational layer. Typst's stock
      // endnote section would have landed BELOW the footer instead.
      //
      // Walks what it renders — `flat` rather than `rec.body` — so a window
      // this page unfurls contributes its footnotes to its own block rather
      // than being missed. A rendered window wraps its body in `_footnoted` of
      // its own, and that inner wrapper claims its markers before this outer
      // one sees them (the inner-rule-wins fact recorded at `_flatten`), so
      // the two do not fight over a window's footnotes.
      #_footnoted(flat)
      // REFERENCES. A minted page renders the note's body, so it renders the
      // note's citations — and until this existed it had no bibliography of its
      // own. A citation with no bibliography FOLLOWING it does not error; it
      // falls back to the nearest PRECEDING one. Minted pages are contributed
      // at the bundle root, after the whole spine, so every minted-page
      // citation was landing in the LAST bibliography on the last vertebra — a
      // sweep block belonging to an unrelated page, which then listed an entry
      // that no citation on that page pointed at. MEASURED.
      //
      // Walks what it renders (`flat`, not `rec.body`) so a window this page
      // unfurls contributes its citations here too.
      //
      // `id` gives the block a stable cross-page address —
      // `ideas/<slug>.html#refs-<slug>`. A plain HTML id, NOT a second
      // declaration of the note's Typst label; see the note at the top of this
      // file on why two elements must never share one label.
      //
      // Before the footer, deliberately: the note's own apparatus stays
      // attached to the note, and Context/Backlinks stay last as the
      // navigational layer.
      // `windows-claim` follows the depth budget, and asks it the same question
      // every comparison in `lib.typ` does — `> 1`, "is there a level left over
      // for a window found in this body" (see `_window-depth`). At the default
      // `minted-depth` is 2, so a window on this page renders, carries a
      // References block of its own, and therefore claims the citations written
      // after it. It was `_window-depth.final() > 0` while the body was built
      // at `depth: auto` and had to change with it: leave it false and the page
      // lists an entry for a citation that the window below it is already
      // listing. The inverse error is the one the note above records — claiming
      // for a window that collapsed, so the page emits no bibliography while
      // still citing, and the citation lands on another minted page's block.
      // MEASURED. At `window-depth: 0`, `minted-depth` is 1, the windows on
      // this page collapse and claim nothing, and this correctly goes false.
      #_refs-block(_own-cited-keys(flat, windows-claim: minted-depth > 1), id: "refs-" + slug)
      #{
        let origin = rec.at("origin", default: none)
        let back = backlinks.at(id, default: ())
        // The note's own page is named by Context and must not be named again
        // by Backlinks. It very often qualifies for both — an index page that
        // holds a note and also `#window`s it links to it directly — but the two
        // sections would then be saying the same thing about the same page,
        // and Context says it more precisely: it links to the note's own
        // anchor there, where a backlink row links to the top of the page.
        let back-pages = page-backlinks.at(id, default: ()).filter(h => h != origin)

        // Both parts are the SAME shape — a titled section, heading first —
        // so the stylesheet can treat them as one thing and lay them out
        // side by side. Neither is a special case of the other: "written
        // here" and "pointed at from here" are two answers to the same
        // question about where a note sits.
        let section(class, title, body) = html.elem(
          "div",
          attrs: (class: class),
          html.elem("h2", attrs: (class: "idea-footer-title"), title) + body,
        )

        // Each part is omitted, not left blank, when it has nothing to say —
        // no origin (a note registered where no page published a handle), no
        // backlinks (nothing points here yet) — and the whole footer with them.
        // A row naming a PAGE. A page cannot literally be a `#window` — there is
        // no note behind it to fold open — so it is a plain link, but it wears
        // the row shape `#window` gives a note (`.idea-page-row` carries the same
        // left rule and indent as `.idea-window`). Both places a page appears
        // use this, so Context and the page half of Backlinks cannot drift.
        let page-list(rows) = html.elem(
          "ul",
          attrs: (class: "idea-page-list"),
          rows.map(r => html.elem("li", attrs: (class: "idea-page-row"), r)).join(),
        )

        // Context reads as one entry under its heading, exactly as a backlink
        // does — not as a banner across the top. It links to the note's own
        // anchor on that page rather than to the top of it.
        //
        //
        // ALWAYS THE PAGE, never a window of the containing note. A note nested
        // inside another was tried here and reverted: Context answers "where was
        // this hatched", and the answer is the vertebra it was written on, whether
        // or not another note happens to enclose it. A window would answer a
        // different question and bury this one.
        let context-part = if origin == none { [] } else {
          section("idea-context", [Context],
            page-list((link(label(id), _handle-title(origin)),)))
        }

        let backlinks-part = if back.len() == 0 and back-pages.len() == 0 { [] } else {
          // FOLDED and `depth: 1`, always: a backlink list is an index of what
          // points here, and a reader following one wants to see which notes
          // those are before reading any of them in full. `depth` is pinned
          // for the same reason `folded` is, and NOT left at `auto` — a
          // document that set `window-depth` to unfurl its prose would
          // otherwise unfurl every entry of every index too, several levels
          // into notes the reader has not chosen yet. MEASURED on a
          // `window-depth: 2` project: `ideas/leaf.html`'s Backlinks showed
          // its one entry (Mid) unfurled down to a window of Leaf — the very
          // page it was on. `window` takes bare names and re-adds the prefix
          // itself, hence the trim.
          //
          // `depth: 1`, NOT `0`, since the rebasing of the scale (see
          // `_window-depth`): `1` renders each entry once and unfurls nothing
          // inside it, which is exactly what the pinned `0` meant before. `0`
          // now means "no transclusion at all", which would turn this whole
          // list into bare links — the regression to watch for here.
          let note-rows = if back.len() == 0 { [] } else {
            window(back.map(b => b.trim(_pfx(), at: start)), folded: true, depth: 1)
          }
          // Pages come after the notes: a note is the more specific answer to
          // "what points here", and a page entry means only that the link was
          // written outside any note on it.
          // Each href in its OWN `context`, deferred to where the row actually
          // renders. `_page-href` measures depth from `state("rheo-handle")`,
          // and out here — in the loop that BUILDS the pages, at the bundle
          // root — that state still holds the last spine vertebra's handle,
          // not the minted page's. MEASURED: computed eagerly it emitted
          // `index.html` from `ideas/rookery.html`, one level short. A nested
          // context resolves after `rheo-document` has published this page's
          // own handle, which is why `#window`'s permalinks were right all along.
          let page-rows = if back-pages.len() == 0 { [] } else {
            page-list(back-pages.map(handle => context {
              let href = _page-href(handle)
              let shown = _handle-title(handle)
              if href == none { shown } else { link(href, shown) }
            }))
          }
          section("idea-backlinks", [Backlinks], note-rows + page-rows)
        }

        if context-part != [] or backlinks-part != [] {
          html.elem(
            "footer",
            // Themed in its own right: the footer is a SIBLING of the <h1>
            // above, not a descendant, so it inherits nothing from it.
            attrs: _themed((class: "idea-footer")),
            context-part + backlinks-part,
          )
        }
      }
      // The beacon itself. Skipped when `syndicate` is off (the default), and
      // skipped per-note when the note has neither `minted` nor `updated`:
      // rssfeed drops an undated entry anyway (Atom's `<updated>` is
      // required, and Typst cannot stat a file to invent one), so emitting
      // one here would only produce an entry the feed silently discards.
      // Skips the BEACON only — the page above is still minted regardless.
      //
      // Field mapping, matched to what `.marrow.typ`'s own `rheo-document`
      // call below is given, so beacon and page cannot drift apart:
      //   - `id`: the note's full id, unique because it keys the registry.
      //   - `page`: `page-at.file` — the exact path/expression this loop
      //     passes `rheo-document` as its own output path (see below), not a
      //     second, independently-derived call to `_note-file`/`_note-path`.
      //   - `title`: `slug` when the note has no title, matching the
      //     `rheo-document(title: ...)` call below, so a titleless note
      //     syndicates under the name its own page shows; otherwise the
      //     title flattened to a string with `_plain` (rssfeed's `items()`
      //     requires a `str`, not content).
      //   - `categories`: `rec.at("tags", ..)` with a default, not `rec.tags`,
      //     so a stale record cannot hard-fail this.
      #if syndicate and (rec.minted != none or rec.updated != none) {
        [#metadata((
          id: id,
          title: if rec.title == none { slug } else { _plain(rec.title) },
          page: page-at.file,
          published: rec.minted,
          updated: rec.updated,
          categories: rec.at("tags", default: ()),
        ))#label("rssfeed:item")]
      }
    ]

    // `id` is the note's full id (`idea:rookery`), which is what a template
    // wants as its "which page am I on" key — the same string `#window` and
    // `@idea:rookery` name it by. `note` is the registry record, so a template
    // can reach the title, dates, origin and outbound links without querying
    // anything.
    rheo-document(
      page-at.file,
      handle: page-at.handle,
      format: "html",
      title: if rec.title == none { slug } else { rec.title },
      if tpl == none { page } else { tpl(id: id, note: rec, page) },
    )
  }
}
