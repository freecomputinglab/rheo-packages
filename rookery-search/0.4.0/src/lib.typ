// @rheo/rookery-search — fuzzy search over a rookery.
//
// Reads the corpus through `@rheo/rookery`'s public primitives and never
// touches its internals: `ideas()` for the notes, `note-href()` for links.
// Nothing here RENDERS a note's body — the modal's preview pane fetches the
// note's own minted page at runtime instead (see `search-modal` below), so
// this package's build cost is one pass over the registry per page rather
// than one full body render per note per page.
//
// Two layers, and the split matters:
//   - `search-ideas(query)` is pure Typst and works under plain
//     `typst compile` — build a static list of matches with no JavaScript.
//   - `search-index()` and `search-bar()` are RHEO ONLY. The bar's script is
//     injected by rheo from this manifest's `js_scripts`, and the index links
//     to minted note pages, which only rheo produces.
//
// BUILT, unlike `@rheo/rookery`: `typst.toml` points at `dist/`, and `dist/`
// comes from `just build` (vite copies this file and the CSS across and
// bundles `src/rookery-search.js` into `dist/lib.js`). Editing `src/` does
// NOT take effect until you rebuild — the one ergonomic cost of shipping JS.
#import "@rheo/rookery:0.4.0": ideas, note-href

// THE ENTRYPOINT IS A MANIFEST. Every name this package exports lives in one of
// the modules below, and `#import "x.typ": *` re-exports transitively — so
// `@rheo/rookery-search:0.4.0` stays a single import for a project and
// `.marrow.typ` keeps resolving `_compress-corpus`, `_corpus-cache` and
// `_corpus-key` by name.
//
// THE ORDER IS THE DEPENDENCY ORDER and it is load-bearing: a `#let` closure
// captures the scope visible AT DEFINITION time, and Typst has no cycles to fall
// back on. `ideas.typ` sits above `corpus.typ` because `#search-index` calls
// `#search-ideas`; with the two the other way round the package built, both test
// suites passed, and a real site failed with `unknown variable: search-ideas` —
// which is why `rheo compile` on rookery.ohrg.org is part of this package's
// checks and not only `just test`.
#import "base.typ": *
#import "tagquery.typ": *
#import "rank.typ": *
#import "lookup.typ": *
#import "corpus.typ": *
#import "ui.typ": *
