// Single-document paged (PDF) build, to exercise the non-HTML heading branch
// (plain `heading()`, no permalink, title-less notes render no heading at
// all). The bundle demo (root.typ) only produces HTML pages.
//
// Build: typst compile --features html --root ../.. paged.typ build/paged.pdf
#import "../../src/lib.typ": idea

#idea("pinned", title: [Pinned])[A pinned note, paged mode.]

#idea[An auto-id note, paged mode.]
