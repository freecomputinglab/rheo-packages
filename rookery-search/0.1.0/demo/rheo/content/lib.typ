// The one place the package is configured, applied by both vertebrae.
//
// `#show: rookery` is per-FILE — an import cannot install it for another file —
// so a project that wants one configuration wraps it once here and every
// vertebra applies the wrapper. Same reason `rookery.ohrg.org` does it.
#import "@rheo/rookery:0.1.0": rookery

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
    theme: (tags-color: (note: rgb("#3366ff"))),
    // `bytes(read(..))`, not a path: Typst resolves a path against the file the
    // `#bibliography` call appears in, and that call lives inside the package.
    // Reading here resolves against THIS file, where `refs.bib` sits.
    bibliography: arguments(bytes(read("refs.bib"))),
  )
  doc
}
