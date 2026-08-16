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
// `#show: rookery.with(prefix: "note")` must mint at the same paths lib.typ's
// `_note-file` links to, and both read the one state.
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
// coming from `_IDEA-DIR`/`_note-file`, so minting and linking cannot drift.
// The permalink comes from lib.typ's `_permalink`, with the href forced to
// this page's own fragment — a minted page must not link to itself. Building
// the <a> by hand here instead is how it came to miss the configurable hover
// property that every other permalink carries.
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
#import "@rheo/rookery:0.1.0": _registry, _note-file, _pfx, _permalink, _themed, _handle-title, _page-links, _page-href, _body-at, _footnoted, _idea-page-template, _IDEA-DIR, window

#context {
  let registry = _registry.final()
  let tpl = _idea-page-template.final()

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

  for (id, rec) in registry.pairs() {
    let slug = id.trim(_pfx(), at: start)
    // Built as a value rather than passed straight to `rheo-document`, so the
    // project's template can wrap the WHOLE page — heading, body and footer —
    // and see exactly what a vertebra's own `#show:` would.
    let page = [
      #html.elem(
        "h1",
        // The <h1> is this page's theme container — there is no `.idea-box`
        // here, so it is what the permalink inherits its colours from.
        attrs: _themed((id: id, class: "idea")),
        // Title in a span, exactly as `#idea` does it: `.idea-label:first-child`
        // is what un-indents a TITLELESS note, and CSS `:first-child` counts
        // elements only — so a bare title leaves the permalink first either way
        // and the rule strips the separator from a titled heading too.
        (if rec.title == none { [] } else {
          html.elem("span", attrs: (class: "idea-title"), rec.title)
        })
          + _permalink(id, href: "#" + id),
      )
      // `_body-at`, not `rec.body`: a document that set `window-depth` wants a
      // `#window` nested inside this note to unfurl the same way here as it
      // does wherever the note is windowed. `depth: auto` takes that
      // document-wide default, and at the default of 0 returns `rec.body`
      // unchanged.
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
      // Walks what it renders — `_body-at(rec)` rather than `rec.body` — so a
      // nested window that `window-depth` unfurls contributes its footnotes to
      // its own block rather than being missed.
      #_footnoted(_body-at(rec))
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
        let context-part = if origin == none { [] } else {
          section("idea-context", [Context],
            page-list((link(label(id), _handle-title(origin)),)))
        }

        let backlinks-part = if back.len() == 0 and back-pages.len() == 0 { [] } else {
          // FOLDED and `depth: 0`, always: a backlink list is an index of what
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
          let note-rows = if back.len() == 0 { [] } else {
            window(back.map(b => b.trim(_pfx(), at: start)), folded: true, depth: 0)
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
    ]

    // `id` is the note's full id (`idea:rookery`), which is what a template
    // wants as its "which page am I on" key — the same string `#window` and
    // `@idea:rookery` name it by. `note` is the registry record, so a template
    // can reach the title, dates, origin and outbound links without querying
    // anything.
    rheo-document(
      _note-file(id),
      handle: _IDEA-DIR + ":" + slug,
      format: "html",
      title: if rec.title == none { slug } else { rec.title },
      if tpl == none { page } else { tpl(id: id, note: rec, page) },
    )
  }
}
