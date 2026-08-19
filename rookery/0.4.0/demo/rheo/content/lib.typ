// The one place the package is configured, applied by both vertebrae.
//
// `#show: rookery` is per-FILE — an import cannot install it for another file —
// so a project that wants one configuration wraps it once here and every
// vertebra applies the wrapper. Same reason `rookery.ohrg.org` does it.
#import "@rheo/rookery:0.4.0": rookery

// The template rookery hands to `.marrow.typ` for each minted note page.
//
// A NAMED TOP-LEVEL FUNCTION, deliberately: the package stores this on a
// document-wide state and `.final()` reads it, so an inline closure built inside
// `demo` below would be a different value per vertebra and whichever file
// happened to be last would win (lib.typ's own warning above
// `_idea-page-template`). The banner is what proves in the output that this
// template ran at all.
#let idea-page(id: none, note: (:), doc) = {
  html.elem("p", attrs: (class: "demo-minted-banner"), [Minted page for #raw(id).])
  doc
}

#let demo(doc) = {
  show: rookery.with(
    idea-page-template: idea-page,
    // `bytes(read(..))`, not a path: Typst resolves a path against the file the
    // `#bibliography` call appears in, and that call lives inside the package.
    // Reading here resolves against THIS file, where `refs.bib` sits.
    bibliography: arguments(bytes(read("refs.bib"))),
  )
  doc
}
