// Native Typst demo — no rheo involved. Proves @rheo/rookery needs only ONE
// compilation unit and works as a plain Typst package: import it, #include
// your note files, done.
//
// MEASURED 2026-08-13: typst 0.15.1's `typst` CLI (nixpkgs) has NO way to
// invoke the multi-document "bundle" target the epic's design notes describe
// (`#document(...)` as a constructor errors "constructing a document is only
// supported in the bundle target", and neither `--features bundle` nor
// `--format bundle` exist on this build's `compile` subcommand — verified via
// `typst compile --help`). So this demo is a single compiled document
// (#include, not #document-per-page) rather than a true multi-page bundle;
// #link/#window below resolve as in-page fragments (`#loc-N`), not cross-page
// hrefs. Cross-page href/transclusion behaviour is exercised instead by the
// documentation site in the sibling repo `rookery.ohrg.org`, which produces
// real multi-page HTML via `rheo compile`.
//
// Because there is no rheo here, the CSS is NOT auto-injected — a real HTML
// deployment would need to include ../../src/rookery.css manually (rheo does
// this for you via [tool.rheo.html]).
//
// `#show: rookery.with(bibliography: ..)` wraps the WHOLE bundle below, with
// otherwise-default settings — harmless to a.typ/b.typ (a title-less,
// nothing-cited bibliography call renders nothing, lib.typ:775-782) — so it
// can also install the document-wide footnote fallback footnotes.typ needs
// (lib.typ:2799 `show FNK:`) and the bibliography plumbing bib.typ needs
// (lib.typ:757/783/2743), without a third root. `prefix:`/`theme:` still get
// their own document (root-prefix.typ) — see that file's own header for why
// those two, unlike bibliography, cannot share this one.
//
// Build (PDF):  typst compile --features html --root ../.. root.typ build/root.pdf
// Build (HTML): typst compile --features html --format html --root ../.. root.typ build/root.html
#import "../../src/lib.typ": rookery
#show: rookery.with(bibliography: arguments(bytes(read("refs.bib")), style: "chicago-author-date"))

#include "a.typ"
#include "b.typ"
#include "footnotes.typ"
#include "bib.typ"
#include "outline.typ"
#include "tags.typ"
#include "windows.typ"
#include "cycles.typ"
#include "idea-body.typ"
