// Mints one output page per registered note, at notes/<id>.html, so a note
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
// minted page. Two elements sharing one label break every #link/#view/
// ref-rule resolution to it as soon as either is referenced (labels only
// error on ambiguous lookup, not on declaration — see the epic's "Verified
// facts"). The label stays owned by the anchor #idea creates at the note's
// original call site; #link/#view/ref-rule keep resolving there. The
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
// `notes/<slug>` is. That is a coincidence of this spine's shape, not a
// guarantee. Passing the handle makes the depth this page's own property. It
// mirrors the path — `notes/<slug>.html` <-> `notes:<slug>` — with the path
// itself coming from `_note-file`, so minting and linking cannot drift.
// The permalink comes from lib.typ's `_permalink`, with the href forced to
// this page's own fragment — a minted page must not link to itself. Building
// the <a> by hand here instead is how it came to miss the configurable hover
// property that every other permalink carries.
#import "@rheo/rookery:0.1.0": _registry, _note-file, _pfx, _permalink, _themed

#context {
  for (id, rec) in _registry.final().pairs() {
    let slug = id.trim(_pfx(), at: start)
    rheo-document(
      _note-file(id),
      handle: "notes:" + slug,
      format: "html",
      title: if rec.title == none { slug } else { rec.title },
    )[
      #html.elem(
        "h1",
        // The <h1> is this page's theme container — there is no `.idea-box`
        // here, so it is what the permalink inherits its colours from.
        attrs: _themed((id: id, class: "idea")),
        (if rec.title == none { [] } else { rec.title })
          + _permalink(id, href: "#" + id),
      )
      #rec.body
    ]
  }
}
