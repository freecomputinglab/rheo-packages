// Single-document paged (PDF) build, to exercise the non-HTML heading branch
// (plain `heading()`, no permalink, title-less notes render no heading at
// all). The bundle demo (root.typ) only produces HTML pages.
//
// Also the one target where bib.typ's coverage matters most: a citation
// with no bibliography anywhere is a HARD ERROR on the paged target
// (`label <key> does not exist in the document`, lib.typ:1564), so this is
// exactly where that plumbing needs to compile clean, not just under HTML.
//
// Build: typst compile --features html --root ../.. paged.typ build/paged.pdf
#import "../../src/lib.typ": idea, rookery
#show: rookery.with(bibliography: arguments(bytes(read("refs.bib")), style: "chicago-author-date"))

#idea("pinned", title: [Pinned])[A pinned note, paged mode.]

#idea[An auto-id note, paged mode.]

#include "bib.typ"
