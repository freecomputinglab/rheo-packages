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
// Deliberately does NOT re-declare the note's `note:<id>` Typst label on the
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
#import "@rheo/rookery:0.1.0": _registry, _note-file

#context {
  for (id, rec) in _registry.final().pairs() {
    let slug = id.trim("note:", at: start)
    rheo-document(
      _note-file(id),
      handle: "notes:" + slug,
      format: "html",
      title: if rec.title == none { slug } else { rec.title },
    )[
      #html.elem(
        "h1",
        attrs: (id: id, class: "idea"),
        (if rec.title == none { [] } else { rec.title })
          + html.elem(
            "a",
            attrs: (class: "idea-label", href: "#" + id, title: "Link to this note"),
            "[" + id + "]",
          ),
      )
      #rec.body
    ]
  }
}
