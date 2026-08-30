// The one place the package is configured, applied by both vertebrae.
//
// `#show: rookery` is per-FILE — an import cannot install it for another file —
// so a project that wants one configuration wraps it once here and every
// vertebra applies the wrapper. Same reason `rookery.ohrg.org` does it.
#import "@rheo/rookery:0.1.0": rookery
#import "@rheo/rookery:0.1.0": idea as _idea, tagged-idea as _tagged-idea

// ---- THE PROJECT-SIDE EXCLUSION PATTERN, and why it is TWO bindings --------
//
// `exclude-tags` is an argument on `#idea`, not a `rookery.with()` knob, because
// its gate has to run with no `#context` — see `_resolve-excluded` in the
// package's `src/base.typ` for the whole reasoning. A project therefore binds it
// once here, in the same file that already owns the configuration, and every
// vertebra imports the bound versions from here rather than from the package.
//
// BOTH LINES ARE REQUIRED. `tagged-idea` returns a closure calling the `idea`
// captured in PACKAGE scope, so binding `idea` alone would leave `#note` hatching
// the very notes this asks to exclude — a silently incomplete exclusion in a
// published build, which is the worst failure shape the feature has. The `as
// _idea` / `as _tagged-idea` aliasing is what lets the bound names take the
// obvious spelling without shadowing their own right-hand side.
#let EX = ("private",)
#let idea = _idea.with(exclude-tags: EX)
#let tagged-idea = _tagged-idea.with(exclude-tags: EX)
#let note = _tagged-idea("note", exclude-tags: EX)

// The template rookery hands to `.marrow.typ` for each minted note page.
//
// A NAMED TOP-LEVEL FUNCTION, deliberately: the package stores this on a
// document-wide state and `.final()` reads it, so an inline closure built inside
// `demo` below would be a different value per vertebra and whichever file
// happened to be last would win (lib.typ's own warning above
// `_idea-page-template`). The banner is what proves in the output that this
// template ran at all.
// `id` is `none` on ONE minted page: the `ideas/index.html` landing page, which
// is the rookery rather than any one note (and gets `note: (:)` for the same
// reason). A template that assumes a string here fails the build the moment a
// project sets `index-page: true`, so this one branches — which is the shape a
// real project's template wants too.
#let idea-page(id: none, note: (:), doc) = {
  let what = if id == none { [the rookery] } else { [#raw(id)] }
  html.elem("p", attrs: (class: "demo-minted-banner"), [Minted page for #what.])
  doc
}

#let demo(doc) = {
  show: rookery.with(
    idea-page-template: idea-page,
    index-page: true,
    syndicate: true,
    // Themes the `note` tag a demo note already carries, so check.sh can assert
    // that the generated `.idea-tag-<tag>` rules reach the pages `.marrow.typ`
    // mints — `rookery()`'s own emission runs per vertebra and never reaches
    // them.
    theme: (tags-color: (note: rgb("#3366ff"), secret: rgb("#ff0000"))),
    // `secret` is INVISIBLE: no pill, no `idea-tag-secret` class, and — the part
    // only a minted page can prove — no generated rule in the `@layer
    // rookery-tags` block that `.marrow.typ` puts on every page it mints. It is
    // themed just above for exactly that reason: a rule for an invisible tag
    // would be dead CSS and the one place its name still reached the output.
    //
    // `note` stays visible, on the same notes, so every assertion here is a
    // difference between two tags rather than the absence of all of them.
    invisible-tags: ("secret",),
    // `bytes(read(..))`, not a path: Typst resolves a path against the file the
    // `#bibliography` call appears in, and that call lives inside the package.
    // Reading here resolves against THIS file, where `refs.bib` sits.
    bibliography: arguments(bytes(read("refs.bib"))),
  )
  doc
}
