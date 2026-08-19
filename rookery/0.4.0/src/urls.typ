// Where a note's page lives, spelled three ways: the file rookery mints, the
// href from HERE, and the path from the SITE ROOT.
//
// `#note-href` and `#note-path` are the public pair and sit with the private
// helpers they wrap, because the whole point of both is that minting and
// linking cannot disagree — keeping them in one file is what makes that
// checkable by reading.

#import "base.typ": *
#import "state.typ": *

// ---- Note page URLs -------------------------------------------------------
//
// `.marrow.typ` mints one standalone page per note (see that file). Links
// here must agree with what it mints, so BOTH sides build the path with
// `_note-file` — never spell it out twice.
//
// The extension is literally "html" even under EPUB, where rheo-context's
// `ext` is "xhtml": `.marrow.typ` passes `document()` a literal path, so the
// minted file is `.html` whatever the format. Matching that literal is what
// keeps the href resolvable.
//
// The directory is ONE constant, because the path and the handle mirror each
// other — `ideas/<slug>.html` <-> `ideas:<slug>` — and only the path was ever
// built from `_note-file`; `.marrow.typ` spelled the handle's half out by
// hand. Two literals that must agree, in two files, is a drift waiting to
// happen, so both now read this.
#let _IDEA-DIR = "ideas"
#let _note-file(id) = _IDEA-DIR + "/" + id.trim(_pfx(), at: start) + ".html"

// The three halves of one note page, in one place: the slug, the file
// `.marrow.typ` mints it to, and the handle it mints it under. `.marrow.typ`
// used to derive all three itself — `id.trim(_pfx(), at: start)` for the slug,
// `_note-file(id)` for the path, `_IDEA-DIR + ":" + slug` for the handle — which
// is the mirroring the comment above worries about, spelled out across two
// files. Now the mirror lives here and marrow reads it.
//
// Must be called from inside `context`: `_pfx` reads the prefix state.
#let _note-page(id) = {
  let slug = id.trim(_pfx(), at: start)
  (slug: slug, file: _note-file(id), handle: _IDEA-DIR + ":" + slug)
}

// Depth-relative href from the CURRENT page to a note's standalone page, or
// `none` when no such page exists to link to:
//   - plain `typst compile` with no rheo — nothing mints per-note pages;
//   - rheo with no `ext` in its context — the combined PDF target, where
//     `.marrow.typ` is skipped outright.
// Both fall back to a `#link(label(id))` at the call site, which still lands
// on the note's anchor wherever it was written.
//
// Mirrors rheo's own cross-vertebra link rule (crates/core/src/typ/rheo.typ):
// the current page's handle comes from `state("rheo-handle")`, published per
// #document by the bundle source, and each `:` level costs one `../`. This is
// why `.marrow.typ` mints via `rheo-document` with an explicit handle — a
// bare `document()` inherits the previous page's handle and every href
// computed on a minted page comes out at the wrong depth.
#let _note-href(id) = {
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return none }
  let handle = state("rheo-handle").get()
  if type(handle) != str { return none }
  _rel-prefix(handle) + _note-file(id)
}

// Shared href resolution for a "page" vs "anchor" link-to mode: `"page"`
// prefers the note's own minted page, falling back to the in-context Typst
// label when none is minted (plain `typst compile`, the combined-PDF
// target) or when `link-to` is `"anchor"`, which forces that fallback
// unconditionally. Used by `_permalink-paged` (always `"page"`) and by
// `#hyperlink` (both its explicit-call and `show ref:` forms), so the two
// cannot drift on what either mode means.
#let _resolve-dest(id, link-to) = {
  let href = if link-to == "anchor" { none } else { _note-href(id) }
  if href == none { label(id) } else { href }
}
// ---- #note-href — where a note's minted page lives, from here -------------
//
//   #context note-href("etal")   // -> "../ideas/etal.html", or none
//
// Public because another package (`@rheo/rookery-search`) has to build links
// to minted pages, and the depth arithmetic is not something a consumer should
// reimplement. Takes a bare name, a full id or a label — whatever `_norm`
// accepts. `none` wherever no page is minted: plain `typst compile` with no
// rheo, and the combined PDF target.
//
// RELATIVE TO WHERE IT IS CALLED. `_note-href` measures depth from
// `state("rheo-handle")`, so the same note yields a different string on a
// nested vertebra than on the root one. That is the point, and it is why a
// caller must not cache the result across pages.
#let note-href(name) = _note-href(_pfx() + _norm(name))

// ---- #note-path — where a note's minted page lives, from the SITE ROOT -----
//
//   #context note-path("etal")   // -> "ideas/etal.html", or none
//
// `#note-href` above is relative to the page it is called from — right for a
// link written inline in a vertebra's own prose. `#note-path` is the SAME
// page, but from the site root, for a caller with no page of its own to
// measure depth from — a feed config or sitemap invoked once from shared
// code, not from a vertebra. It reuses `_note-file` directly, skipping
// `_note-href`'s depth arithmetic entirely, and copies its unminted guard:
// `none` under the same two conditions `#note-href` is — plain
// `typst compile` with no rheo, and the combined PDF target.
#let _note-path(id) = {
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return none }
  _note-file(id)
}
#let note-path(name) = _note-path(_pfx() + _norm(name))
