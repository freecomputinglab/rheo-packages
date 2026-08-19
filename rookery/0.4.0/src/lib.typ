// rookery — atomic, interlinked, transcludable notes ("ideas") for Typst (Zettelkasten-style).
//
// A note exists only where the author writes `#idea("name")[...]` — there is
// no document show rule and no "every heading is a note" behaviour. Notes are
// flat: there is no kind/type taxonomy, only a free-form set of tags an
// author attaches to a note. `#note`/`#todo` are pure sugar over that same
// tags array (see below), not a taxonomy of their own. Note ids are flat
// Typst labels (`<idea:name>`), not handle-prefixed, so a note can move
// between files without breaking inbound links.
//
// This package takes no `ctx` argument and installs no template: under plain
// `typst compile` one root file `#include`s the notes and everything works.
// Under rheo (https://rheo.ohrg.org) it feature-detects `sys.inputs` and the
// `rheo-handle` page state to upgrade cross-page links automatically.
//
// NO `#preview`/tooltip integration: rheo's package asset auto-detection only
// scans a project's own `.typ` files for package imports, not the packages
// those files' packages import in turn — so a `#preview` composing
// `@rheo/tooltip` from inside THIS package would need every consuming project
// to import `@rheo/tooltip` directly too, just to get its JS auto-injected.
// That leaky requirement (REJECTED 2026-08-14) is worse than not having the
// feature; `#hyperlink`/`#window` cover referencing a note without it.

// ---- Target detection — the only rheo-specific read ------------------------
//
// `std.target()` reports EPUB as "html"; rheo's own context distinguishes
// them. Use `std.target()` rather than a bare `target()`: rheo injects its
// `target()` polyfill into each vertebra's scope, not into package scope.
//
// REQUIRES `--features html`: `std.target` is gated by that compiler feature,
// not by output format — it is absent from `dictionary(std)` under a plain
// `typst compile` with no `--features html`, even when compiling to PDF. This
// package accepts that constraint rather than working around it: every
// invocation, including a plain paged build with no rheo, needs the flag.
// Document this as a hard requirement (readme bead).
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: none)

#let _target() = {
  let c = _rheo-ctx()
  if c != none and "target" in c { c.target } else { std.target() }
}

// ---- pure.typ — the ordering-free half ------------------------------------
//
// `pure.typ` holds the helpers that are pure functions of their arguments: no
// `state`, no `context`, no `query`, no target detection, nothing that reads
// document state. They therefore carry none of the definition-time scope
// capture the rest of THIS file's ordering is load-bearing for.
//
// The wildcard form is deliberate, because it RE-EXPORTS — VERIFIED: a name
// imported into `lib.typ` with `#import "pure.typ": *` is visible to anything
// importing `lib.typ`. `test/units.typ` relies on it directly (twelve of its
// fifteen imported internals now live in `pure.typ`), and `.marrow.typ`
// imports eighteen of this file's own internals by name on the same footing —
// an underscore is a convention here, not a barrier.
//
// A RELATIVE import is safe here: it resolves against the package's own
// directory. UNLIKE `.marrow.typ`, whose text is spliced into rheo's bundle
// root (its own header explains it), so that file must keep importing from
// `"@rheo/rookery:0.4.0"` by name.
#import "pure.typ": *

// ---- CONSUMED BY .marrow.typ — a real API, with no other marker ------------
//
// `.marrow.typ` (this package's own, at the package root) imports SEVENTEEN
// names from `"@rheo/rookery:0.4.0"`, seventeen of them underscore-private. They
// are as load-bearing as anything public here, and nothing else in this file
// says so. RENAMING OR RE-SIGNING ANY OF THEM MEANS CHANGING `.marrow.typ` IN
// THE SAME COMMIT.
//
// The failure mode is why this banner exists rather than a convention. rheo's
// `package_marrow_source` returns None for a marrow it cannot read instead of
// erroring, so a broken marrow does not fail a build: the package installs,
// compiles, and simply mints none of the pages it exists to mint. Nothing goes
// red. The site just quietly loses every note page.
//
//   _registry            the note store; marrow walks `.final()` to mint one
//                        page per note, and inverts its `links` for backlinks
//   _note-page           slug + minted path + minted handle for one note, the
//                        one place that mirror lives (see "Note page URLs")
//   _pfx                 the `<prefix>:` to strip off a BACKLINK id, for the
//                        `#window` call that renders the backlinks list
//   _head                per-page <head> contributions
//   _permalink           a note's `[idea:x]` permalink
//   _permalink-tab       the top-rule permalink tab a note wears in a card,
//                        reused on the minted page with a self-fragment href
//   _themed              carries the document's theme as inline custom props
//   _handle-title        the human title of the vertebra a handle names, for
//                        the Context section's links back into the spine
//   _page-links          which notes a given PAGE links to directly
//   _page-href           depth-relative href from this page to another page
//   _body-at             a note's body at a given nested-window budget
//   _footnoted           wraps a body with its own Footnotes block
//   _refs-block          the References block for a set of citation keys
//   _own-cited-keys      which keys a body cites, minus the windowed ones
//   _window-depth        the document-wide nested-window budget state
//   _idea-page-template  the project's own minted-page template, if any
//   window               public, but listed for completeness: marrow renders
//                        the backlinks list as folded windows
//
// Their DEFINITIONS are deliberately not gathered here. Several (`_footnoted`,
// `_body-at`) sit where they do because a `#let` closure captures the scope
// visible at definition time, and moving them to satisfy a banner would break
// the thing the banner is protecting.
//
// NOT COVERED BY CI, and this is the gap: `demo/rheo` is the only thing that
// proves marrow still mints, and it needs the `rheo` binary, which no published
// release can supply yet — package-`.marrow.typ` support landed after v0.5.1.
// Until a release carries it (the same release bead rheo-packages-2ps waits on),
// this banner and a local `demo/rheo` run are the whole guard.

// The human title of the vertebra a handle names — "Rookery under Rheo" for
// `index`. Read from `rheo-context`'s `spine-flat`, which every vertebra and
// every marrow contribution sees identically (it is spine-wide, not per-file),
// so this works from package scope with no `ctx:` parameter and no `query()`.
//
// Falls back to the handle itself: a handle is always something a reader can
// place, and this must never be the reason a build fails.
#let _handle-title(handle) = {
  let c = _rheo-ctx()
  if c == none { return handle }
  for v in c.at("spine-flat", default: ()) {
    if v.at("handle", default: none) == handle {
      return v.at("title", default: handle)
    }
  }
  handle
}

// Is this handle one of the project's OWN pages?
//
// `spine-flat` lists the vertebrae the author wrote. It does NOT list the
// per-note pages `.marrow.typ` mints, whose handles are `ideas:<slug>` — and
// that distinction is load-bearing for backlinks. A minted page carries links
// of its own (its permalink, its context link, the windows in its own backlinks
// list), all of which would otherwise be harvested as "this page links to that
// note" and every note would list every other note's page. MEASURED: without
// this filter, `ideas/rookery.html` claimed six page backlinks, four of them
// other minted pages.
#let _is-vertebra(handle) = {
  let c = _rheo-ctx()
  if c == none { return false }
  c.at("spine-flat", default: ()).any(v => v.at("handle", default: none) == handle)
}

// ---- Label prefix — configurable, document-wide ---------------------------
//
// A note's id is `<prefix>:<name>`, `idea:` by default; `#show: rookery` (at
// the bottom of this file) changes it.
//
// The prefix is document-wide STATE rather than a parameter on `#idea`,
// because four separate places have to agree on it — `#idea` (minting the
// label), `#window` (looking one up), `_note-file` (deriving a minted page's
// slug from an id) and `.marrow.typ` (minting those pages) — and only
// `#idea`'s call site could ever pass an argument. One wrong reader and the
// id it builds simply does not exist.
//
// Read with `.final()`, NOT `.get()`. `#show: rookery` is applied per FILE
// (imports are per-file), so under rheo a spine sets the same prefix once per
// vertebra; a vertebra that forgot the template would, under `.get()`, mint
// `idea:` ids in the middle of an otherwise `note:` document, and a `#window`
// reaching across that boundary would panic on an id that was never
// registered. `.final()` collapses the whole document to ONE prefix (last
// writer wins), so every reader agrees no matter which file it sits in.
//
// EVERY caller of `_pfx` is therefore inside a `context` block already —
// `#idea`'s deferred body, `#window`, `_note-href` via `#idea`/`#window`/
// `#hyperlink`, and `.marrow.typ`'s own `#context`.
#let _prefix = state("rheo-idea-prefix", "idea")
#let _pfx() = _prefix.final() + ":"

// ---- Theme — configurable the same way ------------------------------------
//
// Every colour the package will set for you, as one dictionary. `#show:
// rookery` publishes it; `rookery.css` holds the DEFAULTS and this state holds
// only the overrides, so an unconfigured document emits nothing extra at all.
//
// Delivered as INLINE CSS CUSTOM PROPERTIES on the elements that root a
// rookery subtree — `.idea-box`, `.idea-window`, and a minted page's `<h1>` —
// whence they inherit to the permalink, the date, and anything nested. That is
// the only mechanism available: this package emits no `<style>` element and
// the template wraps `doc` in nothing, so there is no ancestor to hang a
// `:root` variable on, and emitting a `<style>` per vertebra would duplicate
// it once per output page and is dubious inside an EPUB's body besides.
//
// It degrades cleanly in both directions: the DEFAULT lives in the `var()`
// call in the stylesheet, not here, so a reader that does not understand
// custom properties still gets the default look; and a container that somehow
// carries no property inherits from whichever ancestor does.
//
// Same `.final()` reasoning as `_prefix` above: one theme for the whole
// document, so a note and a window of it cannot disagree about their colours.
//
// Each key maps to exactly one custom property, and `rookery.css` reads each
// through `var(--x, <default>)`. Adding a knob means adding a line here and a
// `var()` there — nothing else.
// The two that carry the look are `link-color` and `fold-color`, and the
// contrast between them is the point: BOTH are hover backgrounds, so they
// compare like with like, and the lighter one belongs to the fold (a block
// that only opens and closes) while the stronger one belongs to every link
// (which actually goes somewhere). Forester makes the same split with one blue
// at two alphas; rookery defaults to two hues, a light blue and a purple, so
// the difference survives being read quickly.
//
// `border-color` (the `.idea-box`/`.idea-window` left rule) has no default of
// its own — `rookery.css` falls it back to `link-color` first, so a note's
// rule and its links read as one colour until a theme sets `border-color`
// apart from `link-color` deliberately.
//
// `pad` is the other length. It is the indent between a note's rule and its
// content — and, on a window, that window's right padding too, so the content sits
// the same distance from both edges. The tab's offset and the top rule's stub span
// exactly this distance in order to close the corner on the rule, so they read the
// same value and a retheme cannot leave a notch. Halved under 600px by the
// stylesheet's own media query, which overrides the one property rather than the
// four rules that depend on it.
//
// `rule-width` is the other odd one out: a LENGTH, not a colour, and it sets ONE
// thickness for every line that frames a note — the left rule on a card and a
// window, the tab that rules off the top of both, and `#ideas-outline`'s own rule
// and row markers. They are one system and they were four literals; a project
// that wants a heavier or lighter frame moves this and they all follow, including
// the corner arithmetic that has to know the rule's width to close on it. The
// separators above a footnotes, references or page-references block are NOT
// governed by it: those are apparatus rules, not the note's frame.
// CONSUMED BY @rheo/rookery-search, and not through an import. That package
// emits rookery's properties onto its own `#search-bar` span and `#search-modal`
// dialog, because neither has an `.idea-*` ancestor to inherit them from — a
// search UI lives in a site's header, not inside a note card. It reaches them by
// reading `state("rheo-idea-theme")` BY NAME (a Typst state is global per key)
// and by keeping its own copy of the table below, exactly as it keeps a copy of
// `_rheo-ctx`. So THREE things here are a cross-package contract, not private
// detail: the state's key string, the shape of the dictionary it holds (theme key
// -> already-stringified CSS value), and every property spelling in the table.
// Change any of them and change `rookery-search/0.4.0/src/lib.typ` in the same
// commit.
#let _THEME-KEYS = (
  "link-color": "--idea-link-color",
  "fold-color": "--idea-fold-color",
  "id-color": "--idea-id-color",
  "date-color": "--idea-date-color",
  "border-color": "--idea-border-color",
  "rule-width": "--idea-rule-width",
  "pad": "--idea-pad",
  "label-font": "--idea-label-font",
  "label-size": "--idea-label-size",
)
#let _theme = state("rheo-idea-theme", (:))

// The `style` attribute value for the configured theme, or `none` when
// nothing is configured (in which case no attribute is emitted at all).
#let _theme-style() = {
  let t = _theme.final()
  let decls = _THEME-KEYS
    .pairs()
    .filter(((key, prop)) => t.at(key, default: none) != none)
    .map(((key, prop)) => prop + ": " + t.at(key))
  if decls.len() == 0 { none } else { decls.join("; ") }
}

// Add that style to an attrs dictionary, or leave it untouched. Every
// container this package emits goes through here, so none can drift.
#let _themed(attrs) = {
  let s = _theme-style()
  if s == none { attrs } else { attrs + (style: s) }
}

// ---- Window depth — how far a nested `#window` unfurls ---------------------
//
// THE SCALE COUNTS LEVELS OF TRANSCLUSION, AND `0` IS NOT THE DEFAULT:
//
//   0   transcludes NOTHING. A `#window` renders as the note's title linked to
//       the note's own page — no summary, no disclosure, no body (see
//       `#window`'s depth-0 branch).
//   1   the default, and today's behaviour: the note renders once, and a
//       `#window` found INSIDE it collapses to a bare permalink (`_flatten`'s
//       WK rule).
//   n   unfurls n-1 further levels of nested windows, collapsing at the nth.
//
// Expanding a nested window with no budget is what makes a cycle — a
// self-window, or A-windows-B/B-windows-A — re-expand forever, and the budget
// is what makes bounded expansion safe. So every comparison against a depth in
// this file asks `> 1`, never `> 0`: the question is always "may I unfurl a
// window found INSIDE this one", and one level of that budget is already spent
// on rendering the window itself.
//
// MIGRATION off the old scale, where `0` was the default and `n` unfurled `n`
// nested levels: add one. A project that set `window-depth: 2` wants `3`.
//
// Document-wide state for the same reason `_prefix` is (`#show: rookery` is
// applied per FILE, and a note written in one vertebra can be windowed from
// another), read with `.final()` so every reader agrees. `#window`'s own
// `depth:` argument overrides it per call site.
#let _window-depth = state("rheo-idea-window-depth", 1)

// ---- The bibliography — one for the whole rookery -------------------------
//
// Configured on the template, taking Typst's own `#bibliography` arguments so
// there is nothing new to learn:
//
//   #show: rookery.with(bibliography: arguments(
//     bytes(read("refs.bib")),
//     style: "chicago-author-date",
//   ))
//
// BYTES, NOT A PATH, and it is not a stylistic choice. Typst resolves a path
// relative to the FILE THE CALL APPEARS IN, and every call this package makes
// appears inside the package: `bibliography("refs.bib")` spread in here looks
// for the file next to `lib.typ`, and so does `read`. MEASURED —
// `file not found (searched at .../rookery/0.1.0/src/refs.bib)`. `bytes` carries
// its data rather than a path, so the author's own `read()` resolves at the
// author's own call site and everything downstream just works. `bytes` is one
// of the source types Typst's own `#bibliography` accepts, so this is still
// literally its argument list.
//
// Document-wide state for the same reason `_prefix` is: `#show: rookery` is
// applied per FILE, and a note written in one vertebra can be windowed from
// another. Read with `.final()` so every reader agrees.
//
// Holds an `arguments` value or `none`, spread straight into `bibliography(..)`
// by the beads that render the blocks.
#let _bib = state("rheo-idea-bib", none)

// Every key in the configured source, as an array of strings.
//
// A KEY-EXISTENCE CHECK, NOT A PARSER. It reads no author, no date and no
// title, and nothing downstream may depend on it for rendering — Typst formats
// every citation and every bibliography entry. Its ONLY job is answering "does
// this idea cite anything", so an idea that cites nothing emits no empty block.
// Growing this into a BibTeX parser is an explicit non-goal: the package reuses
// Typst's bibliography infrastructure rather than reimplementing it.
#let _bib-keys() = {
  let cfg = _bib.final()
  if cfg == none { return () }
  let src = cfg.pos().first()
  let sources = if type(src) == array { src } else { (src,) }
  let keys = ()
  for s in sources {
    let text = str(s)
    // Format is detected from the CONTENT, since bytes carry no filename. A
    // Hayagriva file is a YAML mapping and has no `@type{` entry headers; a
    // BibTeX file is nothing but those.
    let entries = text.matches(regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,"))
    if entries.len() > 0 {
      keys += entries.map(m => m.captures.first())
    } else {
      // Hayagriva is a mapping of key -> entry, so its keys ARE the keys.
      keys += yaml(s).keys()
    }
  }
  keys
}

#let _cited-keys(body) = {
  let keys = _bib-keys()
  if keys.len() == 0 { return () }
  _cite-walk(body).filter(k => k in keys)
}

// ---- The template for a minted note page ----------------------------------
//
// `.marrow.typ` mints one standalone page per note, and those pages are
// separate `#document`s spliced in at the BUNDLE ROOT — outside every
// vertebra, and so outside whatever `#show:` the project applies to its own
// pages. A minted page therefore has no site chrome unless the project hands
// one over, which is what this is for:
//
//   #show: rookery.with(idea-page-template: my-idea-page)
//
//   #let my-idea-page(id: none, note: (:), doc) = {
//     show: chrome.with(current-page: id)
//     doc
//   }
//
// `.marrow.typ` calls it as `tpl(id: <id>, note: <registry record>, page)`,
// wrapping the whole minted page — heading, body and footer — so the template
// sees exactly what a vertebra's own `#show:` would.
//
// WHY A STATE HOLDING A FUNCTION, which nothing else in this package does:
// the project cannot reach `.marrow.typ` and `.marrow.typ` cannot reach the
// project. Marrow's text is inlined into rheo's synthesized bundle root, so a
// relative `#import "template.typ"` there would resolve against the PROJECT
// root and, worse, name a file only one particular project has. A state is
// the only channel that runs from a vertebra to the bundle root. VERIFIED on
// typst 0.15.1 that a state can hold a function, that `.final()` returns it
// callable, and that the document still converges.
//
// Register a NAMED top-level function, not an inline closure built inside the
// template that installs it: a fresh closure per vertebra puts a different
// value on the state timeline for each one, and `.final()` is then whichever
// file happens to be last. A named binding is one value however many
// vertebrae reference it.
//
// `.update(_ => f)`, never `.update(f)` — `state.update` treats a FUNCTION
// argument as an updater to call on the old value, so the plain form would
// call the project's template with the old state as its only argument and
// store the result. The wrapper is what makes the function a value.
#let _idea-page-template = state("rheo-idea-page-template", none)

// Whether `.marrow.typ` should emit an `<rssfeed:item>` beacon alongside each
// minted note page — see the "syndicate" comment in `.marrow.typ` for the
// contract. A plain value, not a function, so this carries the same wrapper
// discipline as `_idea-page-template` in reverse: `.update(syndicate)`, NOT
// `.update(_ => syndicate)` — the `_ =>` wrapper exists only to stop
// `state.update` from calling a FUNCTION value as an updater, and a bool is
// not one.
#let _syndicate = state("rheo-idea-syndicate", false)

// Whether `.marrow.typ` should mint an `ideas/index.html` landing page for the
// whole rookery. Same wrapper discipline as `_syndicate` above and for the same
// reason: a bool is not a function, so `.update(index-page)` is right and
// `.update(_ => index-page)` would store a closure.
//
// DEFAULT OFF. A project with its own index — ohrg.org's homepage is a
// `#window(tags: "post", ..)`, weeknotes' is the same — must not find a second
// one published under it because it upgraded the package.
#let _index-page = state("rheo-idea-index-page", false)

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

// ---- The permalink — the ONE navigational affordance ----------------------
//
// `[idea:etal]`, rendered beside a note's title (or alone, where there is no
// title) by BOTH `#idea` and `#window`. Shared so the two cannot drift: it is
// the same affordance meaning the same thing in both places — "this is the
// note's id, and it goes to the note's own page".
//
// Nothing else in this package is a link. A transcluded body is NOT wrapped
// in an anchor and no trailing arrow is appended (both were tried; see
// `#window`), so the reader's click budget is unambiguous: the permalink
// navigates, everything else folds.
//
// It goes to the note's standalone page when one is minted, and only falls
// back to the same-page `#id` fragment when there is not (plain `typst
// compile`, or the combined PDF). For `#idea`, that fragment points at the
// very heading the reader just clicked — a no-op — which is why the minted
// page is preferred whenever it exists.
// `href: auto` resolves the destination as described above. `.marrow.typ`
// passes an explicit one instead: on a note's OWN minted page the permalink
// must stay a same-page fragment rather than link the page to itself, and
// `_note-href` would happily compute the latter. Routing that case through
// here anyway is what keeps every permalink in the output identical — the
// hand-rolled copy this replaced had already drifted.
//
// Carries no theme properties of its own: it is always emitted inside a
// container that does (`.idea-box`, `.idea-window`, a minted page's `<h1>`), and
// custom properties inherit.
#let _permalink(id, href: auto) = {
  let dest = if href != auto { href } else {
    let page-href = _note-href(id)
    if page-href == none { "#" + id } else { page-href }
  }
  html.elem(
    "a",
    attrs: (
      class: "idea-label",
      href: dest,
      title: if dest.starts-with("#") { "Link to this note" } else { "Open this note's page" },
    ),
    "[" + id + "]",
  )
}

// The permalink as a card's TOP RULE rather than as a word in its heading:
// `.idea-tab` draws the rule (see rookery.css) and this is the id that
// straddles it. Used by every site that renders a note's HEADER — `#idea`, a
// transcluded `#idea`, a `#window` summary, a minted page's `<h1>` — and by
// nothing else: a bare permalink standing in prose (a depth-exhausted nested
// window, below) keeps `_permalink` itself, because a rule across the top of it
// would be a rule across the top of nothing.
//
// `span`, NOT `div`: this goes inside `<summary>` on the window path, whose
// content model is phrasing content, and EPUB output is XHTML, where that
// distinction is enforced rather than merely stated. `display: flex` in the
// stylesheet is what makes it behave as a block.
//
// Carries no theme properties of its own, for the same reason `_permalink`
// does not: it is always emitted inside a container that does — `.idea-box`,
// `.idea-window-summary`, or (on a minted page) the `.idea-head` wrapper — and
// custom properties inherit.
// `date` IS THE HAT'S OTHER END. Emitted LAST and pushed to the far right of the
// rule by `margin-left: auto` in the stylesheet, so the hat reads id-on-the-left,
// date-on-the-right with the frame's top edge between them. It used to render
// inside the heading (`#idea`) or as a third item in the summary row (`#window`) —
// two classes in two places for one piece of metadata. Both now pass it here.
//
// A STRING, already formatted, not a `datetime`: the two call sites resolve which
// date to show and how to display it (`#idea` from `updated`/`minted`/the
// document's own, `_window-content` from the registry record), and the paged
// branches need the same string without a hat to hang it on. Formatting here would
// put that decision in a third place.
// `tags:` renders each tag as a VISIBLE PILL, between the id and the date —
// opt-in per call site (`#idea`/`#window`'s `show-tags:`, off by default,
// same mechanism as `date:` above), and empty when the note carries none
// either way (an empty `tags` array maps to no output).
//
// TWO classes per pill, on purpose: `idea-tag` is the pill's own shape hook
// (see `.idea-tab > .idea-tag` in rookery.css); `idea-tag-<tag>` is the SAME
// class this package already puts on the card and the heading (`_flatten`'s
// IK rule, `#idea` below), and the same class `@rheo/rookery-search` puts on
// its own chips — so one project rule (`.idea-tag-draft { ... }`) now styles
// a tag everywhere it appears, including this pill. A project stylesheet
// that only meant to style the card is affected too — that is the intent of
// sharing the class, not an accident.
#let _permalink-tab(id, href: auto, tags: (), date: none) = html.elem(
  "span",
  attrs: (class: "idea-tab"),
  _permalink(id, href: href)
    + (if tags.len() == 0 { [] } else {
      tags.map(t => html.elem("span", attrs: (class: "idea-tag idea-tag-" + t), t)).join()
    })
    + (if date == none { [] } else { html.elem("span", attrs: (class: "idea-date"), date) }),
)

// The tab and the heading as ONE element, wherever a note wears a header.
//
// NOT two loose siblings, and this is measured rather than tidiness. Typst's
// HTML export wraps a LEADING INLINE run in a `<p>` of its own depending on what
// follows it, and it is not decidable per call site: in one build of this
// package's own `demo/rheo`, one `.idea-box` came out
// `<div class="idea-box"><p><span class="idea-tab">..</span></p><h2>` and the
// next `<div class="idea-box"><span class="idea-tab">..</span><h2>` — same
// construct, same run, different grouping, because their bodies differ. Every
// stylesheet rule that positions the tab against its heading
// (`.idea-tab + h*.idea`) silently stops matching in the first form.
//
// Inside one `html.elem` the two are always real siblings. `.idea-head` is also
// the theme container on a minted note page, where there is no `.idea-box` to be
// one — see `.marrow.typ`, which passes `_themed((:))` here.
//
// `#window`'s summary needs none of this: its tab is a direct child of
// `<summary>`, whose content is inline throughout, and no `<p>` ever appears
// there (checked in the same build).
#let _head(tab, heading, attrs: (:)) = html.elem(
  "div",
  attrs: attrs + (class: "idea-head"),
  tab + heading,
)

// Paged counterpart: no `html.elem`, and the fallback is the Typst label
// rather than an HTML fragment.
#let _permalink-paged(id) = {
  link(_resolve-dest(id, "page"), text(gray, raw("[" + id + "]")))
}

// THE ONE BOTTOM-OUT RENDERING. A `#window` that has no recursion budget left emits
// this, wherever it ran out: `#window` itself at depth 0, and `_flatten`'s WK arm for
// a window nested past the budget. It used to be TWO renderings — a bare `[idea:x]`
// permalink from the WK arm, and this row from the depth-0 branch — so a bottomed-out
// window looked like a different KIND of object depending on WHY it bottomed out.
// Factored here so the two cannot drift again; that drift is what the shared
// `_permalink`/`_note-file`/`_truncate` helpers all exist to prevent.
//
// The note's TITLE, linked to its own page, in the row shape a page backlink uses
// (`.idea-page-row` gives it the frame's bar and indent at body size). A TITLELESS
// note falls back to its permalink — there is nothing else to name it by, and that
// is the one case the old rendering survives in.
//
// Defined HERE, above `_flatten`, for the reason `_blocks` and `_truncate` are: a
// `#let` closure captures the scope visible AT DEFINITION time, and `_flatten` is one
// of the two callers.
#let _window-link(id, rec) = {
  let row = if rec.title == none { _permalink(id) } else {
    link(_resolve-dest(id, "page"), rec.title)
  }
  if _target() == "html" or _target() == "epub" {
    html.elem(
      "ul",
      attrs: _themed((class: "idea-page-list")),
      html.elem("li", attrs: (class: "idea-page-row"), row),
    )
  } else {
    // `align(start)` for the reason `_window-content`'s paged branch uses it: a
    // Typst figure centres its body.
    align(start, block(row))
  }
}

// ---- #idea — marker, idea:<id> label, anchor, flattened registration -----
//
// `#idea[body]`, `#idea("name")[body]`, and `#idea(<name>)[body]` all work via
// an argument sink, since `#idea[body]` passes body as the first positional
// argument. An unnamed note steps a package-wide counter and takes the
// resulting sequence number as its id; a named note is pinned and does not
// perturb that counter. Either way the note gets: an `idea:<id>` Typst label on
// a hidden referenceable anchor, an HTML heading (only when `title` is given)
// carrying that id and an `idea`/`idea-tag-<tag>` class list, and a registry
// entry other beads (#window, #hyperlink) read from.
#let _registry = state("rheo-ideas", (:))

// Stepped ONCE per rendered idea box. It exists only so two renderings of the
// SAME body on one output page (its own `#idea`, plus a `#window` on it) get
// distinct HTML ids. Document-wide and monotonic — uniqueness within a page is
// all that is asked of it, so it never resets.
#let _fn-block = counter("rheo-idea-fn-block")

// The visible footnote number, reset to 0 at the start of every idea box. Two
// ideas on one page may each legitimately carry a footnote "1" — that is the
// point of the feature, not a collision.
#let _fn-seq = counter("rheo-idea-fn")

// The inline reference. `b` is this rendering's block number, `n` the
// footnote's number within it; together they name both anchors.
#let _fn-ref(b, n) = {
  let tag = str(b) + "-" + str(n)
  if _target() == "html" or _target() == "epub" {
    html.elem(
      "sup",
      attrs: (class: "idea-fn-ref", id: "fnref-" + tag),
      html.elem("a", attrs: (href: "#fn-" + tag), str(n)),
    )
  } else {
    super(str(n))
  }
}

// The block itself, at the end of the idea's body. Empty content when there is
// nothing to list: an idea with no footnotes emits no block and no heading.
#let _fn-block-html(notes, b) = {
  if notes.len() == 0 { return [] }
  if _target() == "html" or _target() == "epub" {
    html.elem(
      "div",
      attrs: (class: "idea-footnotes"),
      html.elem("h4", attrs: (class: "idea-footnotes-title"), [Footnotes])
        + html.elem(
          "ol",
          attrs: (class: "idea-footnote-list"),
          notes
            .enumerate()
            .map(((i, body)) => {
              let tag = str(b) + "-" + str(i + 1)
              html.elem(
                "li",
                attrs: (class: "idea-footnote", id: "fn-" + tag),
                html.elem(
                  "a",
                  attrs: (class: "idea-fn-backlink", href: "#fnref-" + tag),
                  "^",
                )
                  + " "
                  + body,
              )
            })
            .join(),
        ),
    )
  } else {
    // Paged target: no ids and no anchors, neither of which means anything in
    // a PDF. The block still renders, so an idea reads the same everywhere.
    [*Footnotes*] + enum(..notes)
  }
}

// ---- References blocks ----------------------------------------------------
//
// Typst partitions citations POSITIONALLY: each `#bibliography` claims the
// citations nearest-following it. That is the whole mechanism — one
// bibliography emitted after an idea's body claims exactly that idea's
// citations, with no key filtering needed and nothing to keep in sync.
//
// Builds the call from `_bib`'s parts rather than spreading and adding
// `title:` on top: passing a named argument the spread already carries is a
// duplicate-argument error the moment an author configures their own title.
#let _bib-call(title) = {
  let cfg = _bib.final()
  let named = cfg.named()
  named.insert("title", title)
  bibliography(..cfg.pos(), ..named)
}

// ---- Whose citation is it, when a note contains another block? ------------
//
// `_cited-keys` answers "what does this content cite", which is a CONTENT
// question. An idea's own block needs a narrower, POSITIONAL one: "what will
// still be unclaimed by the time my block renders".
//
// A nested `#idea` or `#window` emits a references block of its own, INSIDE the
// enclosing idea's body and therefore BEFORE the enclosing idea's block. Typst
// partitions positionally, so that inner block sweeps up everything preceding
// it — including the enclosing idea's own citations. MEASURED before this fix,
// tracing byte offsets in a minted page for
// `#idea("outer")[Outer cites @beta2021. #window("multi")]`:
//
//      191  CITE Beta 2021       <- Outer's OWN citation
//      684  idea-references      <- the WINDOW's block; claimed all of it
//      998  idea-references      <- Outer's own block, nothing left
//
// and that last one rendered `<h2>References</h2><ul></ul>` — a visible empty
// heading, which is precisely what `_cited-keys` exists to prevent, arriving
// through ordering rather than through content.
//
// So scan the body in order, recording citations AND the nested blocks that
// will claim them. Both IK and WK count: a nested idea emits a block just as a
// window does.
#let _cite-scan(node) = {
  let out = ()
  if type(node) != content { return out }
  if node.func() == ref { return ((kind: "cite", key: str(node.target)),) }
  if node.func() == cite { return ((kind: "cite", key: str(node.key)),) }
  // A `#window` builds its `figure(kind: WK)` INSIDE a `context` block, so at
  // raw-body time there is no figure here to find — only the announce marker
  // `#window` emits up front for exactly this kind of walk (`_outbound` reads
  // the same one). MEASURED: scanning for the WK figure alone missed every
  // window and left the empty heading in place.
  if node.func() == metadata {
    if type(node.value) == dictionary and "rookery-window" in node.value {
      return ((kind: "claim", via: "window"),)
    }
    // `#footnote` carries its body as a metadata PAYLOAD, so a citation written
    // inside one is reachable ONLY through the value. Descend into it: "a
    // citation belongs to the idea in which you write it, just as footnotes do"
    // is what the documentation promises, and a footnote is written in this
    // idea. MEASURED before this branch existed, on an idea whose only citation
    // sat inside `#footnote[...]`: the author-date marker rendered, no
    // `.idea-references` block was emitted at all, and the reader saw
    // `(Wajcman 2009)` with nothing anywhere on the site saying what it cited.
    //
    // Counted ONCE, not twice. `_own-cited-keys` scans the RAW body; the
    // rendered footnote content `_footnoted` appends is never fed back through
    // it, so the payload is the only place this citation is ever seen.
    if type(node.value) == dictionary and "rookery-fn" in node.value {
      return _cite-scan(node.value.rookery-fn)
    }
    return out
  }
  // A nested `#idea`, by contrast, IS a figure by the time it lands in the
  // enclosing body: `#idea` returns one directly rather than deferring it.
  if node.func() == figure and node.at("kind", default: none) in (IK, WK) {
    return ((kind: "claim"),)
  }
  if node.has("children") { for k in node.children { out += _cite-scan(k) } }
  else if node.has("body") { out += _cite-scan(node.body) }
  else if node.has("child") { out += _cite-scan(node.child) }
  out
}

// The keys an idea's own block will actually still own.
//
// Everything after the LAST nested claimant, not the first: each nested block
// claims in turn, so it is the final one that decides what is left. A citation
// written between two nested windows belongs to the second, not to the idea.
//
// `windows-claim: false` for a context where nested windows COLLAPSE instead of
// rendering — a minted page, or any `_flatten` scope out of depth budget. A
// collapsed window is a bare permalink: it emits no block and therefore claims
// nothing, so the idea keeps its own citations after all. MEASURED when this
// was missed: `ideas/before.html` cited Beta 2021, emitted no bibliography at
// all, and its citation fell back onto an unrelated minted page's block — the
// same contamination `rookery-bib-minted-m6h` had just fixed, reintroduced from
// the other side. A nested `#idea` always renders its own box and block, so it
// stays a claimant either way.
#let _own-cited-keys(body, windows-claim: true) = {
  let keys = _bib-keys()
  if keys.len() == 0 { return () }
  let scan = _cite-scan(body)
  let last = -1
  for (i, e) in scan.enumerate() {
    if e.kind == "claim" and (windows-claim or e.at("via", default: none) != "window") {
      last = i
    }
  }
  scan.slice(last + 1).filter(e => e.kind == "cite").map(e => e.key).filter(k => k in keys)
}

// One idea's references. Empty content when the idea cites nothing, so no
// stray "References" heading appears — that is what `_own-cited-keys` is for.
#let _refs-block(keys, id: none) = {
  if _bib.final() == none or keys.len() == 0 { return [] }
  if _target() == "html" or _target() == "epub" {
    let attrs = (class: "idea-references")
    if id != none { attrs = attrs + (id: id) }
    html.elem("div", attrs: attrs, _bib-call([References]))
  } else {
    _bib-call([References])
  }
}

// Claims any unclaimed PROSE citations that precede an idea.
//
// Without it they leak into that idea's list, the partition being positional
// and the idea's own bibliography being the nearest one following them.
// MEASURED before the fix: an idea's block listed both the prose citation
// written above it and its own.
//
// UNCONDITIONAL, and `title: none`. Whether unclaimed prose citations precede
// a given idea cannot be determined from inside `#idea` — it never sees page
// prose — and it cannot be determined by querying either: deciding whether to
// emit a bibliography from `query(cite)` is CIRCULAR and hard-errors, because
// with none yet emitted the refs never resolve to cites, so the query finds
// nothing, so nothing is emitted, so the refs fail. MEASURED. A title-less
// bibliography with nothing to list renders `<section><ul></ul></section>` —
// no heading, nothing visible — which is what makes always emitting it safe.
#let _sweep-block() = {
  if _bib.final() == none { return [] }
  if _target() == "html" or _target() == "epub" {
    html.elem("div", attrs: (class: "idea-page-refs"), _bib-call(none))
  } else {
    _bib-call(none)
  }
}

// Wrap one idea box's body: number its markers locally, then append the block.
//
// The `show FNK:` rule installed here is NESTED relative to the document-wide
// fallback `#show: rookery` installs, and the nested rule wins — MEASURED. It
// also travels with the content wherever it is later inserted, the same way
// `_flatten`'s `show ref: hyperlink` does, which is what makes a transcluded
// body number its footnotes against the window's own block rather than the
// origin idea's.
//
// Returns `body` untouched when there is nothing to number, so `_fn-block` is
// not stepped for an idea with no footnotes.
#let _footnoted(body) = {
  let notes = _footnotes(body)
  if notes.len() == 0 { return body }
  _fn-block.step()
  context {
    let b = _fn-block.get().first()
    _fn-seq.update(0)
    {
      show FNK: it => {
        _fn-seq.step()
        context _fn-ref(b, _fn-seq.get().first())
      }
      body
    }
    _fn-block-html(notes, b)
  }
}

// ---- #hyperlink — a plain link to a note, page-or-anchor -------------------
//
// `#hyperlink("etal")[see this]` links to note "etal"'s own minted page when
// one exists, falling back to its in-context anchor otherwise (same
// preference the permalink and `#window` already carry, via
// `_resolve-dest`). `link-to: "anchor"` forces the anchor unconditionally —
// pass it per call, or `.with()` it for a whole-document default (see
// below). Name resolution is `_norm`'s: bare or full, string or label —
// `"etal"`, `"idea:etal"`, `<etal>`, `<idea:etal>` all reach the same note.
// Existence is checked eagerly, so a typo'd name fails at the call site
// rather than producing a dangling link.
//
// THE SAME FUNCTION is also `@idea:x`'s renderer. A note's label lives on a
// hidden anchor FIGURE, so a bare `@idea:etal` would otherwise resolve to
// that figure and render as a bare figure NUMBER, useless to a reader. This
// package installs no document template by design (the author just imports
// and calls `#idea`/`#window`/`#hyperlink`), so there is nowhere to put a
// `show ref:` rule implicitly; it must be an exported rule the author opts
// into:
//
//   #import "@rheo/rookery:0.4.0": idea, window, hyperlink
//   #show ref: hyperlink                          // the default: the note's own minted page
//   #show ref: hyperlink.with(link-to: "anchor")   // in-context anchor, like #hyperlink(..., link-to: "anchor")
//
// ONE function serves both call shapes via an argument sink, the same way
// `#idea[body]`/`#idea("name")[body]` do: Typst's `show ref:` always calls
// its rule with exactly the `ref` element as the sole argument, so a single
// `content` positional whose `.func()` is `ref` means "installed as a show
// rule" — an author can never construct that value by hand (`@label` is
// markup-only syntax, not a callable `ref(...)` constructor), so the two
// shapes cannot collide. That also lets `link-to:` double as the one knob
// for both an explicit `#hyperlink(...)` call and the `show ref:` rule,
// where the previous two-functions-not-one design (`link-to-page`/
// `link-to-anchor`, each a thin wrapper choosing a hardcoded mode) needed a
// separate export per mode instead.
//
// References to anything else (an ordinary figure, a heading, ...) pass
// through untouched via the `else { it }` branch below — checking
// `e.kind == "rheo-idea-anchor"` on the RESOLVED element, not the label's
// text, is what makes this safe to install as a document-wide `show ref:`
// with no narrower selector: it already only touches rookery refs, whatever
// `prefix:` the document is using. A selector-level scope (`ref.where(...)`)
// can't do this instead — `.where()` matches a static field value (one exact
// label), not "resolves to a rookery anchor", which is only knowable by
// resolving the reference. Without the rule, `@idea:x` still compiles — it
// just shows a number; an explicit `#hyperlink("x")[text]` remains
// unaffected either way (a `show ref:` rule only ever touches `ref`
// elements, never the `link` a direct call like this one produces).
//
// CUSTOM TEXT: `@idea:x[custom text]` (or `#ref(<idea:x>, supplement: [...])`)
// sets `it.supplement`, which the ref-mode branch prefers over the note's
// own title whenever it is not `auto` — `auto` is what an unadorned
// `@idea:x` leaves it at, the signal to fall back to the title/raw-id
// default. An explicit call has no such fallback chain: its body is
// whatever the caller wrote, always.
//
// MEASURED CORRECTION to this bead's own sketch: it assumed the registry
// stored a dict with a `.title` field directly. It stores `(title:, body:)`
// now (added by this bead, since nothing previously persisted the title) —
// see `#idea`'s registration step. A note with no title (the common
// frictionless case) falls back to the bare id text, not a blank link.
#let hyperlink(..args) = {
  let pos = args.pos()
  let link-to = args.named().at("link-to", default: "page")
  assert(
    link-to == "page" or link-to == "anchor",
    message: "@rheo/rookery: #hyperlink's link-to must be \"page\" or "
      + "\"anchor\" — got " + repr(link-to),
  )

  if pos.len() == 1 and type(pos.at(0)) == content and pos.at(0).func() == ref {
    // Installed as `show ref: hyperlink` (or `.with(link-to: "anchor")`):
    // Typst hands us the resolved `ref` element itself.
    let it = pos.at(0)
    context {
      let e = it.element
      if e != none and e.func() == figure and e.kind == "rheo-idea-anchor" {
        let id = str(it.target)
        let reg = _registry.final()
        let shown = if it.supplement != auto {
          it.supplement
        } else if id in reg and reg.at(id).title != none {
          reg.at(id).title
        } else {
          raw(id)
        }
        let linked = link(_resolve-dest(id, link-to), shown)
        // Wrapped so `@idea:other` is reachable from CSS and carries the
        // theme. A SPAN around Typst's own `link()`, not a hand-rolled
        // `<a>`: the label-fallback branch has no href to hand-roll WITH,
        // since only Typst can resolve a label to the `#loc-N` it ends up
        // at. And the wrapper has to carry the theme itself — a reference
        // sits in ordinary prose, with no `.idea-box`/`.idea-window`
        // ancestor to inherit from.
        if _target() == "html" or _target() == "epub" {
          html.elem("span", attrs: _themed((class: "idea-ref")), linked)
        } else {
          linked
        }
      } else {
        it
      }
    }
  } else {
    assert(
      pos.len() == 2,
      message: "@rheo/rookery: #hyperlink wants a name and a body — "
        + "#hyperlink(\"etal\")[text] — got " + str(pos.len()) + " argument(s).",
    )
    let (name, body) = (pos.at(0), pos.at(1))
    let n = _norm(name)
    // Announced up front, in an invisible `metadata` element, the same
    // reason `#window` does: this is a way of pointing at a note, so it has
    // to show up in the target's backlinks, and the `link()` below renders
    // inside a `context` block that is not a concrete element yet at
    // registration time / page-walk time (see `_outbound`/`_page-links`).
    metadata((rookery-link: n))
    context {
      let id = _pfx() + n
      if id not in _registry.final() {
        panic("@rheo/rookery: #hyperlink unknown note '" + id + "'")
      }
      link(_resolve-dest(id, link-to), body)
    }
  }
}

// Flatten a note's body ONCE, at registration, so `#window` is pure
// presentation (any number of windows cost nothing) and cycles are safe (a
// self-window, or A-windows-B/B-windows-A, collapses one level instead of
// re-expanding forever). Without this, a transcluded body re-emits its
// embedded machinery live: a self-window fails with "maximum show rule depth
// exceeded", and a nested `#idea` inside a transcluded body re-runs its
// registration and counter step, inflating later ids.
//
// REFUTED APPROACH, do not reintroduce: a `state` depth counter around the
// expansion. Measured failing on typst 0.14.2 AND 0.15.1 — a self-window still
// fails identically, because typst hits its nesting cap before the state
// timeline converges.
//
// The `show` rules below are LOCALLY SCOPED to the content this function
// returns — Typst content carries its own style/show-rule modifications
// wherever it is later inserted, so a nested IK/WK marker anywhere inside
// `body` gets reduced when this returned content is finally rendered, no
// matter how many `#window`s later re-embed it.
//
// GOTCHA (measured): do NOT use `it.body.children.first()` to find the
// metadata child — the marker's body begins with a SPACE element whenever the
// markup block spans multiple lines, so `.first()` returns a `space` and
// fails with `space does not have field "value"`. Use
// `.children.find(c => c.func() == metadata)`.
// ---- Depth markers, for page-level links ----------------------------------
//
// A link that sits DIRECTLY in a page — in its prose, or a page-level `#window`
// — is a backlink from that page. A link inside a note is a backlink from the
// note, and must not also be counted for the page or for any note enclosing
// it. So the question is only ever "how deep am I", and these two invisible
// markers answer it: `#idea` brackets its rendered body with them, `#window`
// brackets each note it transcludes, and `_page-links` walks the document in
// order keeping a depth count. Depth 0 is the page itself.
//
// Bracketing `#window` is what makes a TRANSCLUDED body behave: a note shown on
// five pages renders its links on all five, and without the brackets each of
// those pages would look like it linked directly to whatever the note links
// to. Inside the brackets they are at depth 1 and belong to the note.
//
// REFUTED ALTERNATIVE, do not retry: `show metadata: none` inside `_flatten`,
// to strip a stored body's markers instead of nesting them. MEASURED — a
// metadata element hidden by a show rule is STILL returned by `query`, so it
// strips nothing that matters and the duplicates survive.
//
// Defined BEFORE `_flatten`: its IK rule brackets a reconstructed nested
// header+box itself now, so it needs `_bracket` in scope at definition time.
//
// `container` (IK or WK) rides along on top of `edge` ("open"/"close") so a
// reader of the marker (currently just `#ideas-outline`) can tell an IDEA's
// own bracket apart from a WINDOW's — `_page-links`/`_outbound` don't care
// which, only "how deep", so this is purely additive: an extra key on the
// same dict, ignored by every existing reader.
#let _edge(edge, container) = metadata((rookery-edge: edge, rookery-container: container))
#let _bracket(body, container) = _edge("open", container) + body + _edge("close", container)

// ONE rendering of ONE window — summary row, disclosure, body — shared by
// `#window` itself and by `_flatten`'s WK rule when `depth` lets it expand a
// nested window instead of collapsing it. Shared so the two cannot drift: an
// expanded nested window must be indistinguishable from the same `#window`
// written at the top level, or `depth:` would introduce a second, lesser
// rendering of the same thing.
//
// Takes `shown` already truncated (the caller owns `limit:`) and emits NO
// `figure`/`_bracket` wrapper — the two callers wrap differently. `#window`
// needs the `figure(kind: WK)` so an enclosing `_flatten` can find and
// collapse it; the expansion deliberately emits no such figure, since it has
// already been claimed.
//
// `folded` sets only the INITIAL disclosure state — `false` (the default)
// renders `<details open>`, `true` renders it closed. It is not a second
// layout: a folded window and an unfolded one are the same block, so a reader
// who opens one sees exactly what a `#window` beside it already shows.
// `limit:` is therefore meaningful in both (it truncates the body that folding
// hides) and the two are orthogonal.
//
// CLICK BUDGET (HTML/EPUB) — the whole point of this shape, modelled on
// Forester (www.forester-notes.org, whose `tree.xsl` renders every transcluded
// tree as a `<details>` whose `<summary>` holds the title and an
// `<a class="slug">[tfmt-0006]</a>`):
//
//   - clicking ANYWHERE in the summary — title, date, the whitespace between
//     them — folds or unfolds, and does nothing else;
//   - clicking the `[idea:etal]` permalink, and only that, opens the note's
//     own page.
//
// So the transcluded body is NOT a link and there is no trailing arrow. Both
// were tried and removed. An outer <a> around the body is invalid the moment
// that body contains its own link (MEASURED: browsers and typst's HTML export
// both truncate the outer anchor where the inner one starts and never resume
// it, so only "the first bit" stays clickable), and the arrow was a second
// navigational affordance competing with the permalink for the same click.
//
// The disclosure is native `<details>`/`<summary>`: this package ships no JS,
// and a `:target`/checkbox CSS hack would need a unique control id per window.
// An `<a>` INSIDE `<summary>` does not break the toggle — only an `<a>` around
// the whole summary does, which is what the earlier folded-row design got
// wrong. The permalink navigates on its own click; the summary keeps the rest.
//
// `show-date` is OFF by default, same as `#idea`'s own — a date is always
// RESOLVED and stored on the note's registry record regardless, so passing
// `show-date: true` here can surface it even for a note whose own `#idea`
// call left it hidden; the two are independent per call site, not one shared
// setting.
//
// Must be called from inside a `context` block: `_permalink` reads the page
// handle and the prefix state. Both callers already are.
#let _window-content(id, rec, shown, folded, show-date, show-tags, windows-claim: false) = {
  // `updated`, not `minted`, matching `#idea`'s own hat. The registry record
  // carries both, and `updated` already falls back to `minted` (which falls back
  // to the document's date) when the note never named one — so a note that says
  // nothing looks exactly as it did, and a note that does shows when it was last
  // touched, which is what a reader of a rookery wants off the top of a window.
  let date = if show-date and rec.updated != none {
    rec.updated.display("[year]-[month]-[day]")
  } else { none }

  if _target() == "html" or _target() == "epub" {
    // The id leads the summary as the window's own top rule, so a titleless
    // note needs no special case: the tab is there either way, and the title
    // span is simply absent beneath it. `#idea`'s own heading does the same.
    let title-span = if rec.title == none { [] } else {
      html.elem("span", attrs: (class: "idea-window-title"), rec.title)
    }
    // The tab stays INSIDE the `<summary>`, as its first child. Moving it into
    // the `<details>` body would hide the id whenever the window is folded, and
    // it has to be visible and clickable in both states.
    //
    // THE DATE GOES IN THE TAB, not beside the title as a third item in this row.
    // `.idea-window-date` is gone with it: a date is the same object on a card and
    // on a window, so it wears the same class in the same place, and the summary
    // row is back to a tab plus a title.
    let summary = html.elem(
      "summary",
      attrs: (class: "idea-window-summary"),
      _permalink-tab(
        id,
        tags: if show-tags { rec.at("tags", default: ()) } else { () },
        date: date,
      ) + title-span,
    )
    // `open` is a BOOLEAN html attribute: present means open and there is no
    // value meaning closed, so the attrs dictionary itself has to differ
    // between the two states. `open: "false"` would read as open.
    let d-attrs = if folded { (class: "idea-window-details") } else {
      (class: "idea-window-details", open: "open")
    }
    // `_footnoted(shown)`, not `shown`: a transcluded body carries the origin
    // note's footnote markers, and without a rule of its own here they would be
    // claimed by whatever idea box encloses THIS window and numbered against a
    // block that does not list them — dangling anchors, MEASURED on a
    // `#window` written inside another note's body. Installing the same wrapper
    // `#idea` uses gives the window its own block and its own numbering, and
    // being nested it wins over the enclosing rule.
    //
    // References go in the window's own body too, for the same reason its
    // footnotes do: a transcluded body carries the origin note's citations, a
    // citation link is a same-page fragment, and a window on page B therefore
    // needs its target on page B. Without a block of its own the citations
    // would be claimed by whatever bibliography follows on the host page —
    // an enclosing idea's list, or a sweep block belonging to no one.
    //
    // Cross-page citation links to the note's own minted page were considered
    // and REJECTED: redirecting a citation means de-registering it, and a
    // de-registered citation renders nothing, so the package would have to
    // format the marker itself — which means parsing the bibliography and
    // reimplementing what Typst already does. Do not reintroduce them.
    //
    // Both take `shown`, not the untruncated body — the caller already applied
    // `limit:`, and a window must not list a footnote or a citation whose
    // reference it truncated away. Both blocks sit INSIDE
    // `.idea-window-body`, so they fold away with the window.
    html.elem("div", attrs: _themed((class: "idea-window")),
      html.elem("details", attrs: d-attrs,
        summary + html.elem("div", attrs: (class: "idea-window-body"),
          _footnoted(shown) + _refs-block(_own-cited-keys(shown, windows-claim: windows-claim)))))
  } else {
    // No disclosure in a paged target — nothing to click, so a fold that
    // could not be opened would just hide the body: `folded` is ignored
    // here and the body always shows. The head still renders and the
    // permalink is still the only link, so both targets read the same.
    let head = {
      if rec.title != none { strong(rec.title); [ ] }
      _permalink-paged(id)
      if date != none { [ ]; text(gray, date) }
    }
    // `align(start)` because `#window` puts this inside a `figure`, and a
    // Typst figure CENTRES its body — see the note on `#idea`'s own paged
    // branch, which this shares the defect and the fix with.
    align(start, block[#head#parbreak()#_footnoted(shown)#_refs-block(_own-cited-keys(shown, windows-claim: windows-claim))])
  }
}

// `depth` is the nested-window budget described at `_window-depth`: how many
// further levels of `#window` the returned content may unfurl before falling
// back to the collapsed permalink. It is a CLOSURE-CAPTURED CONSTANT, not
// state, and that is the whole termination argument — each expansion below
// recurses with `depth - 1` baked into a fresh scope, so a self-window or an
// A-windows-B/B-windows-A cycle bottoms out at 0 rather than re-expanding
// forever. (The `state` depth counter this supersedes is REFUTED and must not
// come back: measured failing on typst 0.14.2 AND 0.15.1, where a self-window
// still hit the nesting cap before the state timeline converged.)
//
// MEASURED, the second half of the termination argument: when both an outer
// `_flatten(.., depth: n)` scope and an inner `_flatten(.., depth: n-1)` scope
// carry a rule for the same selector, the INNER one wins and the outer does
// NOT re-fire on content the inner already claimed. Verified on typst 0.15.1
// with a two-level `show figure.where(kind: K)` reproduction: output was
// `OUTER(INNER)`, not a "maximum show rule depth exceeded". Since every
// expansion below wraps its body in a fresh `_flatten` scope — including at
// `depth: 1`, where the rule collapses — every generated WK figure is always
// claimed by a strictly smaller budget.
//
// `depth` here is the budget of the note whose body this IS, so a window found
// in it may only unfurl when there is a level left over for it: hence `depth >
// 1` throughout, and `depth: 1` (the default, and what registration flattens a
// body at) is the collapse. See the scale at `_window-depth`.
#let _flatten(body, depth: 1) = {
  // MEASURED DEFECT this fixes: a `@idea:other` inside a note's body rendered
  // as a bare figure number ("2") on the note's minted page, while rendering
  // correctly in situ. `show ref: hyperlink` is installed by `#show:
  // rookery` on the VERTEBRA, and a minted page is a separate `#document`
  // that `.marrow.typ` contributes at the bundle root — outside every
  // vertebra's show-rule scope. So the stored body has to carry the rule
  // with it, the same way it carries the IK/WK rules below. Always the
  // page-preferring default here regardless of what the vertebra's own
  // `show ref:` was configured to — a nested reference inside a
  // transcluded/minted body has no access to that outer choice, so it gets
  // the same default an unconfigured document would.
  //
  // Attaching it here also covers a `#window` rendered anywhere else the
  // document-level rule happens not to reach, and cannot double-apply: the
  // inner rule turns the `ref` into a `link`, so an outer `show ref:` no
  // longer matches it.
  //
  // (`hyperlink` is defined ABOVE this function for exactly this reason —
  // a `#let` closure captures the scope visible at definition time.)
  show ref: hyperlink
  show figure.where(kind: IK): it => context {
    let m = it.body.children.find(c => c.func() == metadata)
    let v = m.value
    // NAMED only: the id needs `_pfx()`, safe to read here (state, no
    // stepping). An auto-numbered nested idea's id lives on a counter value
    // frozen at its ORIGINAL site — recomputing it here would read the
    // counter's value at THIS (later, transcluded) position instead, so it
    // is left without an id/permalink rather than shown wrong.
    let id = if v.named { _pfx() + v.base } else { none }
    let cls = ("idea",) + v.tags.map(l => "idea-tag-" + l)
    if _target() == "html" or _target() == "epub" {
      let attrs = (class: cls.join(" "))
      if id != none { attrs = attrs + (id: id) }
      // Tab before the heading, and the `id == none` guard travels with it: an
      // auto-numbered nested note has no id to show, so it gets no tab either
      // and its card simply has no top rule.
      let header = _head(
        if id == none { [] } else { _permalink-tab(id) },
        html.elem(
          "h" + str(v.level + 1),
          attrs: attrs,
          (if v.title == none { [] } else {
            html.elem("span", attrs: (class: "idea-title"), v.title)
          }),
        ),
      )
      let box-cls = ("idea-box",) + v.tags.map(l => "idea-tag-" + l)
      // Sweep first, OUTSIDE the bracket: it belongs to the page, claiming
      // prose citations written before this note. The references block goes
      // inside the bracket, so the back-references Typst puts in its entries
      // count as this note's links rather than the page's.
      _sweep-block()
      _bracket(
        html.elem("div", attrs: _themed((class: box-cls.join(" "))), header + _footnoted(v.body))
          + _refs-block(_own-cited-keys(v.body, windows-claim: depth > 1)),
        IK,
      )
    } else {
      _sweep-block()
      _bracket({
        if v.title != none { heading(depth: v.level, v.title) }
        _footnoted(v.body)
      } + _refs-block(_own-cited-keys(v.body, windows-claim: depth > 1)), IK)
    }
  }
  // A `#window` nested inside a transcluded body. With no recursion budget left
  // over for it (`depth: 1`, the default — and `depth: 0`, where nothing is
  // transcluded anywhere) it bottoms out to `_window-link`, THE SAME row
  // `#window` itself emits at depth 0. One rendering for one meaning: the
  // one-link rule holds at every depth, and the row names the note by its title
  // rather than by its id.
  //
  // With budget left, it renders as a real window instead, identical to the
  // same `#window` written at the top level — same summary, same disclosure,
  // same `folded`/`limit`/`show-date`, which is why `#window` records all four
  // on the WK marker rather than the bare id it used to carry.
  //
  // Bracketed as a WINDOW, not left bare: the expanded body's links belong to
  // the note it came from, and its nested `#idea`s are echoes rather than this
  // page's own structure (`_page-links`, `_ideas-outline-data`). On a minted
  // note page there is no enclosing window bracket to inherit that from.
  //
  // Emits NO `figure(kind: WK)` of its own — nothing needs to match the
  // expansion again, and the inner `_flatten` below has already claimed
  // whatever it contains.
  //
  // Wrapped in `context` for `_permalink`/`_pfx`, which read the page handle
  // and the prefix state.
  show figure.where(kind: WK): it => context {
    let m = it.body.children.find(c => c.func() == metadata)
    let v = m.value
    let id = v.rookery-window-id
    if depth <= 1 {
      _window-link(id, _registry.final().at(id))
    } else {
      let rec = _registry.final().at(id)
      // The nested `#window` has already run in full by the time this rule
      // sees its figure — including building a body at ITS budget, which is
      // then thrown away for the one built here at the ENCLOSING budget. That
      // is the right answer (the enclosing scope owns how deep its own
      // transclusion goes) at the cost of one discarded body per level; free
      // at the default, where both sides are the cached `rec.body`. `_flatten`
      // is pure — no counter steps, no registration — so discarding it costs
      // nothing but the work.
      //
      // `depth == 2` reuses the record's already-flattened body rather than
      // re-flattening at the same budget: `rec.body` IS `_flatten(raw)` at
      // depth 1, computed once at registration.
      let inner = if depth == 2 { rec.body } else {
        _flatten(rec.raw, depth: depth - 1)
      }
      let shown = _truncate(inner, v.limit)
      // `.at(..., default: false)`, not a bare field access: a WK marker
      // minted before this bead (or by an older rookery version) carries no
      // `show-tags` key at all. NOTE: `v.show-date` just above is a bare
      // field access with no such guard — a pre-existing risk this bead does
      // not touch.
      _bracket(
        _window-content(
          id,
          rec,
          shown,
          v.folded,
          v.show-date,
          v.at("show-tags", default: false),
          windows-claim: depth - 1 > 1,
        ),
        WK,
      )
    }
  }
  body
}

// A note's body at a given nested-window budget. `auto` takes the
// document-wide default (`#show: rookery.with(window-depth: n)`), which is what
// lets a `#window` unfurl by the document's setting without naming a number.
//
// `.marrow.typ` passes an EXPLICIT depth instead, `window-depth + 1`: a minted
// page shows the note at the page's own top level rather than transcluding it,
// so a window written in that body is a top-level window and must render in
// full even at the default of 1. See the note beside `minted-depth` there.
//
// `d <= 1` short-circuits to the cached body rather than re-flattening at the
// same budget: `rec.body` IS `_flatten(rec.raw)` at depth 1 (registration's
// default), and depth 0 transcludes nothing at all, so neither has any nested
// window to unfurl. See the scale at `_window-depth`.
//
// Must be called from inside `context`: `.final()` on both states.
#let _body-at(rec, depth: auto) = {
  let d = if depth == auto { _window-depth.final() } else { depth }
  if d <= 1 { rec.body } else { _flatten(rec.raw, depth: d) }
}

// ---- Outbound links, for backlinks ----------------------------------------
//
// Every note this note points at, walked out of its body ONCE at registration.
// Backlinks are the inverse of this map, computed by `.marrow.typ`.
//
// Registration is the only place this can happen. A link is an element buried
// in a content tree, and `query()` returns a flat list of elements with no way
// to ask which note a given one sits inside — which is precisely the question
// a backlink asks. Here, the containing note is not in question: it is the one
// being registered.
//
// Four things count as pointing at a note, all of which a reader would call a
// link to it:
//
//   #link(label("idea:etal"))[...]   an explicit jump
//   @idea:etal                        a reference
//   #window("etal")                   a transclusion
//   #hyperlink("etal")[...]           an explicit call, `link-to:` page or anchor
//
// A link to something that is not a note (a URL, an author's own label, a
// heading) is ignored, by testing the target against the current prefix.
//
// Does NOT descend into a nested `#idea`: that note registers itself and owns
// its own links, so recursing would attribute them to the outer note as well.
// It DOES descend through everything else by walking `fields()` generically,
// rather than special-casing `body`/`children`/`child` — a `styled` node (any
// `show` rule scope) wraps content in `.child`, a sequence in `.children`, and
// most elements in `.body`, and missing one silently loses every link beneath
// it.
#let _outbound(node) = {
  if type(node) == array { return node.map(_outbound).flatten() }
  if type(node) != content { return () }

  let f = node.func()
  let kind = node.at("kind", default: none)

  // A nested note: its links are its own.
  if f == figure and kind == IK { return () }

  // A nested `#window`. NOT the `WK` figure — at registration `#window` is still
  // an unevaluated `context` block and that figure does not exist yet, which
  // is exactly why `#window` announces its targets in a `metadata` element up
  // front (see `window`). Bare names, so the prefix goes back on here.
  if f == metadata and type(node.value) == dictionary and "rookery-window" in node.value {
    return node.value.rookery-window.map(n => _pfx() + n)
  }

  // A nested `#hyperlink(...)` explicit call — same reason as `#window`
  // above: at registration its `link()` is still hidden inside an
  // unevaluated `context` block (needed to resolve `link-to: "page"`'s
  // href), so it announces its target the same way. `@idea:etal`/`#window`
  // don't need this: a `ref` is already a concrete element here, and
  // `#hyperlink` used AS the `show ref:` rule never runs at registration
  // time at all (it renders when the ref itself is shown, later).
  if f == metadata and type(node.value) == dictionary and "rookery-link" in node.value {
    return (_pfx() + node.value.rookery-link,)
  }

  // A `#footnote`'s body, same blind spot `_cite-scan` had: the body is a
  // metadata payload, and the generic `node.fields()` recursion below cannot
  // reach it because a dictionary is not content. MEASURED: `#footnote[See
  // #window("etal").]` registered NO outbound link, so the windowed note showed
  // no backlink from the idea that windowed it. One traversal bug with two
  // symptoms — a missing reference and a missing backlink — so both walks
  // descend here.
  if f == metadata and type(node.value) == dictionary and "rookery-fn" in node.value {
    return _outbound(node.value.rookery-fn)
  }

  let out = ()
  if f == link and type(node.dest) == label { out.push(str(node.dest)) }
  if f == ref { out.push(str(node.target)) }
  for (_, v) in node.fields() { out += _outbound(v) }
  out
}

#let idea(level: 1, title: none, tags: (), minted: none, updated: none, show-date: false, show-tags: false, ..args) = {
  // Same leniency as `#window`/`#ideas-outline`/`#ideas`: a single tag needs
  // no array ceremony. Without this, a bare string reached `v.tags.map(...)`
  // below and further down at render time — str has no `.map`, so the error
  // surfaced as an opaque method-not-found far from the actual mistake.
  assert(
    tags == none
      or type(tags) == str
      or (type(tags) == array and tags.all(t => type(t) == str)),
    message: "@rheo/rookery: #idea's `tags` must be none, a string, or an "
      + "array of strings — got " + repr(tags),
  )
  let tags = if tags == none { () } else if type(tags) == str { (tags,) } else { tags }
  let pos = args.pos()
  let (name, body) = if pos.len() == 1 {
    (none, pos.at(0))
  } else {
    (pos.at(0), pos.at(1))
  }
  let named = name != none
  let base = if named { _norm(name) } else { none }

  // The marker wraps the whole idea. Its body carries the RAW body as
  // metadata so a later _flatten can render a nested idea's content without
  // re-registering or re-counting it.
  figure(kind: IK, supplement: none, [
    // `title`/`named`/`base`/`level`/`tags` let `_flatten`'s IK rule rebuild
    // this note's own heading+box when it is shown nested inside a
    // transcluded/minted parent, without re-running the context block below
    // (which would re-register and, for an auto id, re-step the counter).
    #metadata((body: body, title: title, named: named, base: base, level: level, tags: tags))
    // counter.step() RETURNS CONTENT: emit it here, never inside a code block
    // whose value is used, or it silently turns the id into content.
    #if not named { counter("rheo-ideas-seq").step() }
    #context {
      let id = if named {
        _pfx() + base
      } else {
        let n = counter("rheo-ideas-seq").get().first()
        _pfx() + str(n)
      }

      // Resolution order, most specific first: explicit minted:/updated:
      // arguments, then the containing document's own
      // `#set document(date:)`, else no date. MEASURED: a document with no
      // date set yields `auto`, NOT `none` — must be tested for explicitly.
      // Resolved HERE, outside the state.update() closure below: anything
      // contextual fails inside that closure with "can only be used when
      // context is known", since it runs lazily at `.final()` time.
      let doc-date = {
        let d = document.date
        if d == auto { none } else { d }
      }
      let resolved-minted = if minted != none { minted } else { doc-date }
      let resolved-updated = if updated != none { updated } else { resolved-minted }

      // `show-date` gates display only — the date is always RESOLVED and
      // stored on the registry record above, so a #window of this note can
      // still show it even when the note's own hat (here) does not.
      //
      // `resolved-updated`, NOT `resolved-minted`: the date a reader wants off the
      // top of a card is when the note was last touched. Nothing changes for a note
      // that never says `updated:`, because `resolved-updated` falls back to
      // `resolved-minted` one line above, which falls back to the document's own
      // date. `_window-content` reads the same field off the registry record.
      let date = if show-date and resolved-updated != none {
        resolved-updated.display("[year]-[month]-[day]")
      } else { none }

      // The note's CONTEXT: the handle of the page this `#idea` was written
      // in, captured HERE because this is the only moment anything knows it.
      // A minted note page is a separate `#document` and inherits nothing from
      // its origin, and `#window` can transclude a note into any number of other
      // pages — so "where was this written" has to be recorded at the call
      // site or it is gone.
      //
      // `state("rheo-handle")` is published per page by rheo's own
      // `rheo-page-init`. `.get()`, not `.final()`: the point is the handle
      // HERE, at this position in the spine, not wherever the document ends.
      // Non-str (a plain `typst compile`, where nothing publishes it) means no
      // context to record — `.marrow.typ`, the only reader, does not run there
      // anyway.
      let handle = state("rheo-handle").get()
      let origin = if type(handle) == str { handle } else { none }

      // Store the FLATTENED body plus the title, resolved dates and origin, so
      // a #window is pure presentation and any number of windows cost nothing, and
      // `#hyperlink`'s ref-mode can render a note's title without re-deriving
      // it. A duplicate EXPLICIT id only errors if something
      // observes the registry (e.g. #window or a ref) — an identical
      // re-insertion is a re-emission, not a collision.
      // A Typst footnote in here is one this package cannot claim: its body
      // would go to the page's endnote section instead of this idea's block,
      // and the build would otherwise SUCCEED while doing it. Checked at
      // registration rather than at render, so it runs once per idea however
      // many windows transclude it, and so the error names the authoring
      // mistake rather than firing from whatever page happens to window the
      // note.
      if _std-footnotes(body).len() > 0 {
        panic(
          "@rheo/rookery: `#footnote` inside an idea is Typst's, not rookery's — "
            + "its body would land in the page's endnote section instead of this "
            + "idea's Footnotes block. Add `footnote` to your import: "
            + "`#import \"@rheo/rookery:0.4.0\": idea, footnote`.",
        )
      }

      // Outbound links, filtered to real note ids and deduped, with a
      // self-link dropped — a note is not its own backlink. Walked from the
      // RAW body, before `_flatten`: flattening rewrites `#window` markers into
      // permalinks, which would turn every transclusion into an
      // indistinguishable `link` and lose the ones nested inside other notes.
      let links = _outbound(body)
        .filter(t => t.starts-with(_pfx()) and t != id)
        .dedup()

      // `raw` is the body BEFORE flattening, kept alongside the flattened one
      // so a `#window` with a nested-window budget can re-flatten at a smaller
      // depth (see `_body-at`). Re-flattening the FLATTENED body would be
      // wrong: its WK markers have already been reduced to permalinks by the
      // depth-0 rule baked into it, so there would be nothing left to expand.
      //
      // `tags` is stored exactly as `#idea` received it — already deduped and
      // in the author's order, because `#note`/`#todo` prepend theirs via
      // `_dedup-tag` before calling in. It therefore takes part in the identity
      // comparison below: two notes pinned to one id whose tags differ now
      // collide, exactly as they already did when `raw` or `origin` differed.
      let rec = (
        title: title,
        raw: body,
        body: _flatten(body),
        minted: resolved-minted,
        updated: resolved-updated,
        origin: origin,
        links: links,
        tags: tags,
      )
      _registry.update(r => {
        let existing = r.at(id, default: none)
        if id in r and existing != rec {
          panic(
            "@rheo/rookery: duplicate note id " + id + " — already registered"
              + (if existing.origin != none { " in " + existing.origin } else { "" })
              + ", registered again" + (if origin != none { " in " + origin } else { "" })
              + ". A pinned id must be unique across the whole rookery.",
          )
        }
        r.insert(id, rec)
        r
      })

      // Hidden referenceable anchor. VERIFIED: a locally scoped
      // `show ...: none` still hides it while leaving it referenceable, in-page
      // AND cross-page; it exports as <span id="loc-N">, and typst's own bundle
      // export turns a cross-vertebra #link(label(id)) into
      // ../<page>.html#loc-N.
      {
        show figure.where(kind: "rheo-idea-anchor"): none
        [#figure([], kind: "rheo-idea-anchor", supplement: none)#label(id)]
      }

      let ttl = if title == none { none } else { title }
      let cls = ("idea",) + tags.map(l => "idea-tag-" + l)
      if _target() == "html" or _target() == "epub" {
        // The permalink is the ONLY way to discover an auto-generated id —
        // there is no `show heading` rule and no template to hook into, so
        // `#idea` emits it directly, always (even with no title), showing
        // the FULL `idea:name` id so it is copy-pasteable straight into
        // `#window("...")`. `#window` renders the identical affordance in its own
        // summary; both go through `_permalink-tab`.
        //
        // ABOVE the heading, not inside it: the id is the card's top rule (see
        // `_permalink-tab` and `.idea-tab`), so a titleless note needs no
        // special case — the tab is the same either way. The title keeps its
        // span, which nothing styles by default: it stays a hook a project can
        // reach for, and `#window`'s summary wraps its title the same way.
        //
        // THE DATE IS IN THE TAB TOO, at its far right, and no longer a second
        // child of the heading. It belongs to the frame rather than to the
        // sentence: read inside the `<h2>` it was a subtitle, and it made a
        // titleless note's heading non-empty for nothing (see the note below on
        // `h*.idea:empty`).
        //
        // The heading element survives even with NO children — a titleless note.
        // Its `id` attribute is the note's in-page anchor, the destination of every
        // `@idea:etal` fragment link, so dropping the element would break them;
        // `h*.idea:empty` in the stylesheet is what keeps it from taking any space,
        // and it now applies to a dated titleless note as well.
        let header = _head(
          _permalink-tab(id, tags: if show-tags { tags } else { () }, date: date),
          html.elem(
            "h" + str(level + 1),
            attrs: (id: id, class: cls.join(" ")),
            if ttl == none { [] } else {
              html.elem("span", attrs: (class: "idea-title"), ttl)
            },
          ),
        )
        // Header and body wrap together in one card, HTML/EPUB only — no box
        // for a paged target. The box classes mirror `cls` (tags included)
        // so a tag can style the whole card, not just the heading; the
        // heading's own class list (above) is untouched for existing
        // stylesheets.
        let box-cls = ("idea-box",) + tags.map(l => "idea-tag-" + l)
        _sweep-block()
        // Bracketed so a link written INSIDE this note counts as the note's,
        // not as its page's — see `_edge`.
        _bracket(
          html.elem("div", attrs: _themed((class: box-cls.join(" "))), header + _footnoted(body))
            + _refs-block(_own-cited-keys(body)),
          IK,
        )
      } else {
        // `align(start)`, and it is load-bearing: this whole branch renders
        // INSIDE the `figure(kind: IK)` that marks the note, and a Typst
        // figure CENTRES its body. On html/epub that is inert — the figure
        // exports as `<figure>` and CSS decides — but on a paged target it
        // centred every note in the document: headings, prose, raw blocks and
        // all. MEASURED on rookery.ohrg.org's PDF, and reproduced down to a
        // bare `#figure(kind: "k", supplement: none)[long paragraph]`, which
        // centres while the same text outside one does not. A rheo project
        // with no notes in it was left-aligned, which is what placed the
        // defect here rather than in rheo.
        //
        // `start`, not `left`: it follows text direction, so an RTL document
        // is not forced the wrong way round. The figure is not optional — it
        // is the marker `_flatten`, `_outbound` and `#ideas-outline` all find
        // notes by — so undoing its alignment is the fix, not removing it.
        // The paged target needs these just as much as HTML does, and it is
        // not cosmetic there: a citation with no bibliography anywhere is a
        // HARD ERROR (`label <key> does not exist in the document`), so a
        // combined PDF fails to build without them. MEASURED.
        _sweep-block()
        _bracket(align(start, {
          if ttl != none { heading(depth: level, ttl) }
          if date != none { text(gray, date); linebreak() }
          _footnoted(body)
        }) + _refs-block(_own-cited-keys(body)), IK)
      }
    }
  ])
}

// ---- #note / #todo — sugar over tags, NOT a kind/type axis --------------
//
// Pure sugar: each PREPENDS its own tag to whatever `tags` the caller
// passed, so `#note("x")[...]` is exactly `#idea("x", tags: ("note",))[...]`
// — no new parameter on `#idea`, no recognised set of tags, no subclassing.
// Forwards every other argument (level, title, minted, updated) and the
// positional sink untouched, so `#note[body]`, `#note("name")[body]` and
// `#note(<name>)[body]` all work exactly as the `#idea` forms do.
//
// THE TRAP, do not reintroduce: `#let note = idea.with(tags: ("note",))`.
// An explicit `tags:` argument at the call site OVERRIDES a value bound by
// `.with()`, so `#note("x", tags: ("draft",))` would silently drop "note" —
// the tag the caller chose `#note` for in the first place.
#let note(tags: (), ..args) = idea(tags: _dedup-tag("note", tags), ..args)
#let todo(tags: (), ..args) = idea(tags: _dedup-tag("todo", tags), ..args)

// ---- #tags-of — a note's tags, for callers outside this file -------------
//
//   #context tags-of("etal")   // -> ("note", "draft")
//
// Takes a bare name, a full id or a Typst label — whatever `_norm` accepts,
// which is the same set of forms `#window` and `#hyperlink` take. Returns the
// tags the note was registered with, in the order the author gave them
// (`#note`/`#todo` prepend theirs, so `#todo("b", tags: ("draft",))` reads
// `("todo", "draft")`), and `()` both for an untagged note and for an id that
// does not exist — a missing note is not an error here, because a caller
// asking "what is this tagged" is filtering, not dereferencing.
//
// Must be called INSIDE a `#context` block: it reads `_registry.final()`. It
// is not itself a context function, because a context function may only
// return content and the whole point here is to return data.
#let tags-of(name) = {
  let id = _pfx() + _norm(name)
  _registry.final().at(id, default: (:)).at("tags", default: ())
}

// ---- #footnote — shadows Typst's, scoped to the enclosing idea ------------
//
// Import it alongside `#idea` and write footnotes exactly as before:
//
//   #import "@rheo/rookery:0.4.0": idea, footnote
//   #idea("etal")[A claim#footnote[The evidence.] worth qualifying.]
//
// Emits nothing on its own — it is an invisible marker. Inside an idea,
// `_footnoted` claims it, numbers it against that idea and lists its body in
// the idea's own Footnotes block. Outside one, the document-wide rule
// `#show: rookery` installs falls back to `std.footnote`, so a footnote in
// ordinary page prose behaves exactly like Typst's: page-wide numbering, body
// in the page's endnote section.
//
// It must NOT call `std.footnote`, step a counter, or emit a `<sup>` — all of
// that belongs to whichever show rule claims the marker, and doing any of it
// here would put a real footnote element in the document that nothing can
// then remove (see the note on FNK above).
#let footnote(body) = [#metadata((rookery-fn: body))<rkfn>]

// ---- #window — transclusion, array form, working limit --------------------
//
// `#window("etal")` transcludes the target note: its title, its permalink, and
// its stored (flattened) body, as one foldable block. `names` accepts a
// string, a label, or an array of either — bare (`"etal"`, `<etal>`) or full
// id (`"idea:etal"`, `<idea:etal>` — the same id `@idea:etal` resolves), see
// `_norm`. Reads the registry via `.final()`, not `.get()` — that is what
// lets a note defined in ANOTHER vertebra resolve, since the whole spine
// compiles as one Typst document.
//
// `tags:` selects notes instead of naming them, and COMBINES with the names
// rather than replacing them: the window shows the union of what was named and
// what carries the tags, with a note that is both appearing once, where it was
// named. `match:` is "any" (the default) or "all". Selection is always
// rookery-wide — the registry is the whole bundle's, so where the window sits
// makes no difference to what a tag pulls in. Either half may be omitted, but
// not both.
//
// `sort:` is `auto`, "date" or "lexicographic". `auto` keeps named ids in
// call-site order and appends the tag matches by id, so a window that names
// its notes and asks for no sort behaves exactly as it always has; naming a
// sort orders the whole selection instead. See `_sort-ids`.
//
// A `#window` is pure presentation: it never registers, never advances the
// counter, and never re-registers a nested `#idea`. That guarantee is
// delivered by `_flatten` (defined above, next to `IK`/`WK`), not by any
// suppression logic here.
//
// `depth:` is the transclusion budget (see `_window-depth` for the whole
// scale): `0` transcludes nothing and renders this window as a LINK to the
// note's page, `1` renders the note and collapses a `#window` written inside it
// to its bare permalink, `n` unfurls n-1 levels of those as real windows.
// `auto`, the default, takes the document-wide setting from
// `#show: rookery.with(window-depth: n)` — which itself defaults to 1, the
// one-level rendering every document already has. Per call site, because
// "unfurl the whole tree here", "show it" and "just point at it" are all
// reasonable on the same page: an index that shows one note in full wants
// depth, a backlinks list of forty does not, and a dense index may want no
// transclusion at all.
//
// Nesting counts WINDOWS only. A `#idea` written inside a transcluded note is
// always rebuilt in full whatever the budget (that is `_flatten`'s IK rule,
// and it cannot cycle — an idea's body is finite and literally contains its
// nested ones), so `depth` measures exactly the thing that can cycle.
//
// Rendering — `folded`, `show-date`, `limit:`, click budget: `_window-content`.
#let window(
  ..args,
  limit: none,
  folded: false,
  show-date: false,
  show-tags: false,
  depth: auto,
  tags: none,
  match: "any",
  sort: auto,
) = {
  assert(
    depth == auto or (type(depth) == int and depth >= 0),
    message: "@rheo/rookery: #window's `depth` must be auto or a non-negative "
      + "integer — `0` renders the note as a link to its own page, `1` (the "
      + "document default) renders it once and collapses any window inside it "
      + "to a permalink, `n` unfurls n-1 nested levels — got " + repr(depth),
  )
  // `>= 1`, not `>= 0`: a window showing nothing but an ellipsis truncates
  // nothing, so `limit: 0` reads as a mistake rather than a request.
  assert(
    limit == none or (type(limit) == int and limit >= 1),
    message: "@rheo/rookery: #window's `limit` must be none or a positive "
      + "integer (the number of leading blocks to show) — got " + repr(limit),
  )
  assert(
    tags == none
      or type(tags) == str
      or (type(tags) == array and tags.all(t => type(t) == str)),
    message: "@rheo/rookery: #window's `tags` must be none, a string, or an "
      + "array of strings — got " + repr(tags),
  )
  assert(
    match == "any" or match == "all",
    message: "@rheo/rookery: #window's `match` must be \"any\" or \"all\" — got "
      + repr(match),
  )
  assert(
    sort == auto or sort == "date" or sort == "lexicographic",
    message: "@rheo/rookery: #window's `sort` must be auto, \"date\" or "
      + "\"lexicographic\" — got " + repr(sort),
  )
  // Variadic, not a plain positional: a positional parameter cannot carry a
  // default in typst, and `#window(tags: "todo")` has to be callable with no
  // name at all. `#hyperlink` takes the same shape for the same reason.
  let pos = args.pos()
  assert(
    pos.len() <= 1,
    message: "@rheo/rookery: #window wants one name or one array of names — "
      + "#window((\"a\", \"b\")), not #window(\"a\", \"b\") — got "
      + str(pos.len()) + " positional arguments.",
  )
  assert(
    pos.len() == 1 or tags != none,
    message: "@rheo/rookery: #window needs something to show — name at least "
      + "one note, or pass `tags:` to select them by tag.",
  )
  let ids = if pos.len() == 0 { () } else {
    let names = pos.first()
    (if type(names) == array { names } else { (names,) }).map(_norm)
  }

  // A transclusion is a way of pointing at a note, so it has to show up in the
  // target's backlinks. `_outbound` walks a note's RAW body at registration,
  // where everything below is still an unevaluated `context` block with
  // nothing inspectable in it — so the names are announced up front, in an
  // invisible `metadata` element, where the walk can see them without
  // rendering anything.
  //
  // Bare names, not full ids: this runs outside `context`, so `_pfx()` is not
  // available here. `_outbound` re-adds the prefix, which it can.
  //
  // Only the NAMED ids can be announced. A tag selection is not known until
  // the registry is readable, which needs `context`, and by then this walk has
  // already happened — so tag-matched notes get no backlink from this window.
  // That asymmetry is documented in the readme; do not "fix" it by announcing
  // the tags instead, which would have `_outbound` read the registry while it
  // is still being built.
  metadata((rookery-window: ids))

  context {
  let reg = _registry.final()

  // Named ids first, in call-site order, and the only ones that can be wrong:
  // a tag scan reads the registry it filters, so it cannot name a missing note.
  let named = ids.map(n => _pfx() + n)
  for id in named {
    if id not in reg {
      panic("@rheo/rookery: #window unknown note '" + id + "'")
    }
  }

  // Tag matches minus anything already named — a note that is both shows once,
  // in the position the author named it.
  let tagged = if tags == none { () } else {
    let pred = _tag-pred(tags, match)
    if pred == none { () } else {
      reg
        .pairs()
        .filter(p => pred(p.at(1).at("tags", default: ())))
        .map(p => p.at(0))
        .filter(id => id not in named)
        .sorted()
    }
  }

  // `auto` keeps the author's own order for what they named and appends the
  // tag matches; naming a sort orders the whole selection instead.
  let full-ids = if sort == auto { named + tagged } else {
    _sort-ids(named + tagged, reg, sort)
  }

  for id in full-ids {
    let rec = reg.at(id)

    // THIS CALL SITE'S OWN BUDGET, resolved once: `auto` takes the
    // document-wide setting. Both the depth-0 branch below and `windows-claim`
    // need the number rather than `auto`, and reading it twice invited them to
    // disagree.
    let d = if depth == auto { _window-depth.final() } else { depth }

    // The marker an ENCLOSING `_flatten` reads when this window turns out to
    // be nested inside a transcluded body. It carries the presentation
    // arguments as well as the id, so the collapse-or-expand decision up
    // there can rebuild this exact window rather than a default one. NOT
    // `depth`, though — the budget belongs to the scope doing the expanding,
    // not to the call site being expanded.
    //
    // The key is `rookery-window-id`, not `rookery-window`: that name is
    // taken by the announce marker above, and `_outbound`/`_page-links` both
    // test for it by exact key on any dictionary-valued metadata they walk.
    let marker = metadata((
      rookery-window-id: id,
      folded: folded,
      show-date: show-date,
      show-tags: show-tags,
      limit: limit,
    ))

    // DEPTH 0 — A LINK, NOT A TRANSCLUSION. The note's title, linked to the
    // note's own page, and nothing else: no summary row, no `<details>`, no
    // body, so there is no `_window-content` on this path at all.
    //
    // It wears the row shape a minted page already gives a PAGE it names —
    // `.idea-page-list`/`.idea-page-row`, built by `.marrow.typ`'s `page-list`
    // for Context and for the page half of Backlinks — rather than a third row
    // style of its own: "a pointer to somewhere you can read this" is the same
    // kind of thing here as it is there, and the stylesheet already draws it
    // (the same left rule and indent a window gets, no box).
    //
    // `_resolve-dest` for the href, the same resolution `_permalink` and
    // `#hyperlink` use, so this link cannot disagree with them about where a
    // note lives: the minted page where there is one, and the note's in-context
    // label where there is not (plain `typst compile`, the combined PDF).
    // A TITLELESS note has no title to link, so the permalink IS the row — the
    // same `[idea:x]` a depth-exhausted nested window collapses to.
    //
    // `limit:` and `folded:` are simply inert here, not an error: a link has no
    // body to truncate and nothing to fold. Both still ride on `marker`, so an
    // enclosing `_flatten` that DOES have budget rebuilds the full window with
    // them intact — the budget belongs to the scope doing the expanding, and
    // that is as true of `depth: 0` as of any other value.
    if d <= 0 {
      let shape = _window-link(id, rec)
      _bracket(figure(kind: WK, supplement: none, [#marker#shape]), WK)
      continue
    }

    let body = _body-at(rec, depth: depth)
    let shown = _truncate(body, limit)

    // Bracketed: the body being shown belongs to the note it came from, so
    // its links must not read as links from whatever page is showing it.
    _bracket(
      figure(kind: WK, supplement: none, [
        #marker#_window-content(id, rec, shown, folded, show-date, show-tags, windows-claim: d > 1)
      ]),
      WK,
    )
  }
  }
}

// ---- #idea-body — one note's body, as CONTENT ------------------------------
//
//   #context idea-body("etal")                 // -> content, or a panic
//   #context idea-body("etal", limit: 3)        // first three blocks
//
// The note's body as the REAL Typst-rendered thing — links, styling,
// footnotes, citations — not the plain string `#ideas()`'s `body` field
// gives out. For a consumer that wants to show the actual note rather than
// tell about it, the way `@rheo/rookery-search`'s preview pane does: a
// `body` string can be matched and excerpted, and that is exactly what it is
// for, but a code block inside it reads as bare, unstyled source text with
// no separation from the prose around it — MEASURED as "Typst markup peeking
// through" the moment a note quotes any code at all. Rendering the real
// content fixes that at the root: the browser gets an actual `<pre><code>`,
// not a paragraph that happens to contain one.
//
// NOT `#window`, despite doing almost the same rendering underneath. Two
// differences, both load-bearing:
//
//   1. `#window` ANNOUNCES the note it shows, up front, via the same
//      `metadata((rookery-window: ids))` marker `_outbound` reads at
//      REGISTRATION time to build the backlinks graph — a note shown in a
//      `#window` counts as a link TO it from wherever the window sits. That
//      is correct for a window written into a note's own prose, and
//      catastrophic for a call site meant to run once per note on EVERY
//      page, as a search preview does: every page on the site would end up
//      "linking" to every note in the whole rookery. `idea-body` skips the
//      announcement entirely — it renders, and nothing more.
//   2. `#window` draws chrome: a summary line (title, permalink, date) and a
//      `<details>` disclosure. `idea-body` is body only, always fully shown
//      — a caller wanting a title has it already, from whatever listed the
//      note in the first place (`#ideas()`'s `text` field, here).
//
// STILL `_bracket`ed, the same edges `#window` draws, for the same reason
// `#window` needs them: `_page-links` walks a page's own outbound links by
// COUNTING BRACKET DEPTH (see `_edge`), and unbracketed content here would
// make every link inside every previewed note look like a link the page
// itself wrote — corrupting the page-backlinks half of `.marrow.typ`'s
// Backlinks section for every page that calls this.
//
// Wrapped in `.idea-window`/`.idea-window-body` — the same classes
// `#window` wraps its own body in — so it inherits every rule rookery.css
// already writes for prose inside a window: link colours, raw/code styling,
// list and footnote layout. A consumer never has to restyle any of that
// itself. `_themed` carries the document's theme along as an inline style,
// the same way every other container this package emits does, since a
// caller's own container (rookery-search's hidden preview templates, say)
// has no `.idea-*` ancestor to inherit the custom properties from.
//
// `limit:` truncates by BLOCK — a paragraph, a list — the same unit
// `#window`'s own `limit:` uses, because that is the unit that can be cut
// without leaving half a sentence. `none` (the default) shows the whole
// body.
//
// `depth` is the same transclusion budget `#window` takes (see
// `_window-depth`); `1` (the default) renders the body with any nested
// `#window` collapsed to its permalink rather than unfurled, which keeps a
// preview's own size bounded regardless of how deep the note it is showing
// nests. PINNED rather than `auto` for that reason, and `1` rather than `0`
// because this function's job is to render a body: `@rheo/rookery-search`'s
// preview pane calls it without passing `depth` at all, and a default of 0
// would turn every search preview into a link. (`depth: 0` here renders the
// body all the same — there is no chrome and no link shape to fall back to,
// which is `#window`'s job; it simply asks for no unfurling, as `1` does.)
//
// HTML/EPUB only, like `#window`'s own chrome — its only realistic consumer
// is a web preview, and `html.elem` is what builds the `.idea-window`
// wrapping. On a paged target the body still renders, just without that
// wrapping, so a stray direct call does not hard-error.
//
// Must be called INSIDE a `#context` block — it reads `_registry.final()`.
#let idea-body(name, depth: 1, limit: none) = context {
  // Both asserts are copied verbatim from `#window`, which takes the same two
  // parameters with the same meaning — the messages have to agree, or one call
  // site teaches a rule the other contradicts. `>= 1` on `limit` for the reason
  // stated there.
  assert(
    depth == auto or (type(depth) == int and depth >= 0),
    message: "@rheo/rookery: #idea-body's `depth` must be auto or a "
      + "non-negative integer — got " + repr(depth),
  )
  assert(
    limit == none or (type(limit) == int and limit >= 1),
    message: "@rheo/rookery: #idea-body's `limit` must be none or a positive "
      + "integer (the number of leading blocks to show) — got " + repr(limit),
  )
  let id = _pfx() + _norm(name)
  let reg = _registry.final()
  if id not in reg {
    panic("@rheo/rookery: #idea-body unknown note '" + id + "'")
  }
  let rec = reg.at(id)
  let body = _body-at(rec, depth: depth)
  let shown = _truncate(body, limit)
  let inner = _footnoted(shown) + _refs-block(_own-cited-keys(shown, windows-claim: depth > 1))
  if _target() == "html" or _target() == "epub" {
    // `idea-window-plain`: this render has no chrome by design (no summary,
    // no disclosure), so it should not carry `.idea-window`'s BOX either —
    // the border, padding and hover tint that make sense around an actual
    // on-page `#window`, not around a body a caller is embedding inside a
    // box of its own. See rookery.css for why this needs a second class
    // rather than a downstream override.
    _bracket(
      html.elem(
        "div",
        attrs: _themed((class: "idea-window idea-window-plain")),
        html.elem("div", attrs: (class: "idea-window-body"), inner),
      ),
      WK,
    )
  } else {
    _bracket(align(start, block(inner)), WK)
  }
}

// ---- Page-level links ------------------------------------------------------
//
// `handle -> (note ids that page links to DIRECTLY)`, for the page half of the
// backlinks list. Directly means at depth 0: not inside an `#idea`, and not
// inside a `#window`'s transcluded body (see `_edge`).
//
// This is the one thing in the package that cannot come from the registry.
// The registry holds notes, and a link in a page's own prose belongs to no
// note — so the document itself has to be asked. `query` returns elements in
// DOCUMENT ORDER (measured), which is what makes a single left-to-right pass
// with a depth counter sufficient; no tree, no ancestry API needed.
//
// Four shapes count, the same four `_outbound` counts inside a note:
//
//   #link(label("idea:etal"))   a `link` element whose dest is a label
//   @idea:etal                   a `ref` element
//   #window("etal")               the `rookery-window` marker `#window` emits
//   #hyperlink("etal")[...]       the `rookery-link` marker `#hyperlink` emits
//
// `#hyperlink` needs its own marker, like `#window`, because its `link-to:
// "page"` default resolves to a plain href STRING (not a label) whenever a
// page is minted — invisible to the `f == link and type(el.dest) == label`
// check below. `link-to: "anchor"` would have stayed a label link and been
// caught by that check anyway, but the marker covers both modes uniformly
// rather than depending on which one was passed. `#hyperlink` used AS the
// `show ref:` rule needs no marker of its own: it renders a `ref` element,
// already the second shape above.
//
// A `ref` also renders INTO a link, so it can be seen twice; the result is a
// set per page, so seeing it twice costs nothing.
#let _page-links() = {
  let pfx = _pfx()
  let out = (:)
  let depth = 0

  for el in query(selector(metadata).or(selector(link)).or(selector(ref))) {
    let f = el.func()

    if f == metadata {
      let v = el.value
      if type(v) != dictionary { continue }
      let edge = v.at("rookery-edge", default: none)
      if edge == "open" { depth += 1; continue }
      if edge == "close" { depth -= 1; continue }
      if depth != 0 { continue }
      let names = if "rookery-window" in v {
        v.rookery-window
      } else if "rookery-link" in v {
        (v.rookery-link,)
      } else {
        continue
      }
      let handle = state("rheo-handle").at(el.location())
      if type(handle) != str or not _is-vertebra(handle) { continue }
      for name in names {
        let seen = out.at(handle, default: ())
        if pfx + name not in seen { out.insert(handle, seen + (pfx + name,)) }
      }
      continue
    }

    if depth != 0 { continue }
    let target = if f == link and type(el.dest) == label {
      str(el.dest)
    } else if f == ref {
      str(el.target)
    } else {
      none
    }
    if target == none or not target.starts-with(pfx) { continue }
    let handle = state("rheo-handle").at(el.location())
    if type(handle) != str or not _is-vertebra(handle) { continue }
    let seen = out.at(handle, default: ())
    if target not in seen { out.insert(handle, seen + (target,)) }
  }
  out
}

// ---- #ideas-outline — a table of contents for THIS page's own ideas -------
//
// Typst's own `#outline()` can't see ideas: it lists `heading` elements, and
// an idea only ever becomes one on the PAGED target (`heading(depth: level,
// ...)`, inside `#idea`'s `else` branch) — never on html/epub, where the
// title renders as a raw `html.elem("h" + ..., ...)`, a plain HTML tag with
// no Typst-level `heading` behind it at all. `#outline()` would therefore
// see every idea on PDF but NONE on the primary html/epub targets. Built
// instead off the same query-time machinery `_page-links` already uses (the
// `rookery-edge` open/close markers `_bracket` wraps every idea AND window
// in), so it works identically on every target.
//
// Nesting is the idea's LITERAL containment depth in the document (one
// `#idea` written inside another's body) — not the author-set `level:`
// (a heading-level knob authors are free to leave untouched regardless of
// nesting, and usually do; concepts.typ's own nested ideas never set it).
// Depth from real nesting means the outline is correct with zero ceremony,
// matching `#idea`'s own "hatch without ceremony" design.
//
// MEASURED, the reason this tracks TWO separate depths (`idea-depth`,
// `window-depth`) instead of one: a `show figure.where(kind: ...): ...`
// rule (which is all `_flatten`'s IK rule is) does NOT remove the original
// figure from `query()` — exactly like `show ref: hyperlink` leaves a `ref`
// still queryable as one (see `_page-links`'s own comment, "a ref also
// renders into a link, so it can be seen twice"). So a note windowed
// (possibly transitively, A-windows-B-windows-C) onto THIS page re-exposes
// every `figure(kind: IK)` its stored body ever contained, each a REAL
// match here, indistinguishable by `kind` alone from one actually hatched
// on this page. Confirmed by a two-page reproduction with mutual
// transclusion (rookery.ohrg.org's index.typ <-> concepts.typ, via
// `#window((<rookery>, <idea>), ...)`): without this check, ideas authored
// elsewhere surfaced nested under the WRONG local idea, several levels deep
// and wrongly attributed. A note is only ever counted at `window-depth ==
// 0`, i.e. not currently inside ANY `#window`'s content, cascaded through
// any number of levels — `idea-depth` (recorded before ITS OWN bracket
// opens) is then a clean count of real enclosing `#idea`s alone.
//
// Scoped to the CURRENT page (`origin`, in `_page-links` terms) unless
// `rookery-wide`: `query()` sees the whole spine (it compiles as one Typst
// document), so the `state("rheo-handle").at(...)` check below is the only
// thing that makes this a page's table of contents rather than the rookery's.
//
// ROOKERY-WIDE drops that check and keeps everything else — one tree of every
// idea in the spine, in spine order, nested by real containment exactly as
// the per-page form is. It substitutes a WEAKER check rather than none at
// all: only vertebrae count. `.marrow.typ` mints one page per note, each
// re-rendering that note's stored body, and a stored body's nested
// `figure(kind: IK)`s stay queryable through the show rule that rebuilds
// them (the same fact the `window-depth` check above turns on). The per-page
// form never had to care — a minted page's handle is `ideas:<slug>`, which
// simply is not `here` — so this hazard arrives with `rookery-wide`, and
// `handle not in spine` is the answer (the same predicate `_is-vertebra`
// applies for `_page-links`, spelled against the handle list this function
// already builds for ordering, so it costs one pass instead of one walk of
// `spine-flat` per entry). MEASURED on a three-vertebra spine: without it,
// `ideas:b-one` and `ideas:i-one` each re-exposed the nested idea in their
// own stored body, listing it a second time.
//
// That guard is gated on `multi-page` and must be: MEASURED on the combined
// PDF, where `.marrow.typ` is skipped outright, every vertebra's
// `state("rheo-handle")` is the empty string — a str, and not in the spine,
// so an ungated check swallowed the entire outline. Applying the guard only
// where the hazard exists is also why no exemption for `""` is needed.
//
// WHERE THERE IS ONLY ONE PAGE, the two forms agree and list the whole spine
// — which is the right answer, not a degradation: "this page's ideas" and
// "the rookery's ideas" are the same set when the output is one document.
// Both single-page targets reach it without a special case:
//
//   - the combined PDF, because every vertebra's handle is `""` and so is
//     equal to `here`;
//   - plain `typst compile` with no rheo, because nothing publishes
//     `state("rheo-handle")` at all, so `here` and every handle are `none`.
//
// The second used to be an early `return ()` on a non-str `here`, which made
// a standalone `#ideas-outline()` render its title over an empty list. Not
// worth keeping: the comparison below already gives the correct answer, and
// the two one-page targets now behave identically instead of one listing
// everything and the other nothing.
//
// Neither reorders (see `multi-page` below): a one-page target has one page
// order, its own, and the two forms would otherwise disagree about it on the
// very target where they list the same set.
//
// Untitled ideas (the bare `#idea[body]` form, auto-numbered) are omitted —
// nothing to label them with, and an outline entry is a heading text, not
// an id. Each entry links to `el.location()` directly, no href/label
// reconstruction: VERIFIED to resolve cross-page too under rheo's bundle
// export (`../<page>.html#loc-N`, the same shape `#link(label(id))` gets),
// so `rookery-wide` needs no second linking path.
#let _ideas-outline-data(rookery-wide: false) = {
  let here = state("rheo-handle").get()
  let c = _rheo-ctx()
  // Every vertebra's handle, IN SPINE ORDER — the order the author configured
  // (`[[spine.section]]` and the directory scan), not the order the files
  // happen to be named in. Empty without rheo, which is what "if it exists"
  // amounts to: nothing to order by, so document order stands.
  //
  // Doubles as the vertebra test below, replacing a call to `_is-vertebra`
  // (which walks `spine-flat` afresh per entry). Same predicate, one pass.
  let spine = if c == none { () } else {
    c.at("spine-flat", default: ()).map(v => v.at("handle", default: none))
  }
  // Is the output MULTI-PAGE? `ext` is present for html/epub and absent for
  // the combined PDF (and there is no context at all under plain `typst
  // compile`) — the same test `_note-href` uses. Two things hang off it, and
  // they are the same fact seen twice:
  //
  //   - `.marrow.typ` mints one page per note only here, so only here can a
  //     minted page re-expose a stored body's ideas (see the filter below);
  //   - only here does an ORDER OF PAGES exist for the spine — or for
  //     index-first — to mean anything. A combined PDF is one linear
  //     document; its outline should follow that document, and reordering it
  //     against the page sequence the reader is holding would be a lie.
  let multi-page = c != none and c.at("ext", default: none) != none
  let idea-depth = 0
  let window-depth = 0
  let out = ()
  for el in query(selector(metadata).or(selector(figure.where(kind: IK)))) {
    let f = el.func()
    if f == metadata {
      let v = el.value
      if type(v) != dictionary { continue }
      let edge = v.at("rookery-edge", default: none)
      let container = v.at("rookery-container", default: none)
      if edge == "open" and container == IK { idea-depth += 1 }
      if edge == "close" and container == IK { idea-depth -= 1 }
      if edge == "open" and container == WK { window-depth += 1 }
      if edge == "close" and container == WK { window-depth -= 1 }
      continue
    }
    // Inside a `#window`, at any cascade depth: an echo of a note stored
    // (and possibly authored) elsewhere, not this page's own structure.
    if window-depth > 0 { continue }
    let handle = state("rheo-handle").at(el.location())
    if rookery-wide {
      if multi-page and type(handle) == str and handle not in spine { continue }
    } else if handle != here {
      continue
    }
    let m = el.body.children.find(x => x.func() == metadata)
    if m == none { continue }
    let v = m.value
    if v.title == none { continue }
    // `tags` with a default, not `v.tags`: this metadata is read on the paged
    // and no-rheo paths too, and a default costs nothing where a missing key
    // would panic.
    out.push((
      depth: idea-depth,
      title: v.title,
      loc: el.location(),
      handle: handle,
      tags: v.at("tags", default: ()),
    ))
  }

  // SPINE ORDER, explicitly. `query()` returns document order, and MEASURED
  // (typst 0.15.1, rheo 0.5.1) that already IS spine order today — verified
  // against a spine deliberately ordered AGAINST filename order with two
  // `[[spine.section]]`s, where `("aaa-first:gamma", "beta", "zzz-last:alpha")`
  // came out in exactly that sequence rather than alphabetically. So this
  // reorders nothing at present. It is here to make the guarantee the
  // OUTLINE's rather than one borrowed from how rheo happens to assemble its
  // bundle: an author who reorders the spine is entitled to have the index of
  // their rookery follow, and nothing else in this package would notice if
  // that coincidence ever ended.
  //
  // Bucketing, not `.sorted(key:)`: within one vertebra the entries must keep
  // document order EXACTLY, because that order is what carries the nesting
  // (`_nest-outline` reads a depth-tagged run, not a tree), and this does not
  // depend on Typst's sort being stable. Each vertebra's entries are already
  // contiguous — a vertebra's content is contiguous in the document, and
  // minted-page entries are filtered out above — so moving whole buckets
  // cannot split or merge a subtree.
  //
  // The trailing bucket catches a handle that is not a spine vertebra at all:
  // nothing reaches it today (the filter above drops those wherever minted
  // pages exist, and a `none`/`""` handle means a single-page target where
  // the whole list is one bucket anyway), but it keeps such entries in
  // document order at the end rather than dropping them.
  // INDEX FIRST. A rookery's `index.typ` is its front door — the page a
  // reader lands on — so an index of the whole rookery leads with it whatever
  // the spine says. rheo already does this for a NESTED directory, where
  // `index.typ` becomes that directory's landing page and therefore sorts
  // ahead of its siblings in the pre-order walk; at the ROOT it deliberately
  // does not ("Root-level index.typ is a normal leaf; only nested dirs treat
  // it as a landing page" — rheo's `reticulate/spine.rs`), so the root index
  // lands wherever the alphabet puts it. MEASURED on rookery.ohrg.org:
  // `("about", "concepts", "index", "install")`. Hoisting it here is what
  // makes the two cases read the same way — a landing page first, at every
  // level — rather than the root being the one place the front door turns up
  // in the middle.
  //
  // Exactly the handle `"index"`, not any handle ENDING in it: a nested
  // `sub:index` is already first within its own subtree by rheo's own rule,
  // and pulling it to the top of the rookery would tear it out of the section
  // it lands.
  let order = if "index" in spine { ("index",) + spine.filter(h => h != "index") } else { spine }

  if rookery-wide and multi-page and order.len() > 0 {
    let rank = (:)
    for (i, h) in order.enumerate() {
      if type(h) == str { rank.insert(h, i) }
    }
    let buckets = range(order.len() + 1).map(x => ())
    for e in out {
      let b = if type(e.handle) == str { rank.at(e.handle, default: order.len()) } else { order.len() }
      buckets.at(b) = buckets.at(b) + (e,)
    }
    out = buckets.flatten()
  }
  out
}

// `title`/`depth` mirror Typst's own `outline()`
// (https://typst.app/docs/reference/model/outline/) so the two feel like
// one family: `title: auto` (the default) prints "Contents" — the same
// text Typst's own `#outline()` defaults to (MEASURED: `#outline()`'s
// title heading has `body: "Contents"` — there is no localization anywhere
// else in this package, so this doesn't attempt any either); `none` omits
// it entirely; any other content replaces it outright. Rendered as a real
// `heading`, `outlined: false` + `numbering: none` — the exact two
// properties MEASURED on Typst's own outline title — so it neither
// self-lists in a LATER `#outline()` targeting headings nor picks up the
// document's own heading numbering.
//
// `depth` (`none` or a positive integer) caps how many nesting LEVELS show,
// counting the same way Typst's own heading `level` does: top-level ideas
// are level 1. `_ideas-outline-data`'s `depth` field is 0-indexed (a
// top-level idea is `0`), so the comparison adds 1 to match.
//
// `rookery-wide: true` lists EVERY idea in the rookery instead of only this
// page's — one tree, in spine order, nested by the same real containment.
// The whole spine compiles as one Typst document, so this costs nothing
// extra: it is the per-page filter being lifted, not a second pass. `depth`
// composes with it, and caps containment levels either way — it does not
// mean "pages".
//
// Deliberately NOT grouped under per-page headings. An idea's id is flat and
// travels between files precisely so a reader never has to know which file
// holds it (see "Flat ids, and why" in the readme); an index that led with
// filenames would put that back. Entries link straight to the idea wherever
// it was written.
//
// `tags`/`match` are the same pair `#window` and `ideas()` take, through the
// same shared `_tag-pred`, and `filter` is a predicate of the caller's own over
// the same tag array, ANDed with them — see `_tag-pred` in `pure.typ` for why
// exclusion and an OR of ANDs are a function value here rather than four more
// keyword parameters. What differs is that an outline is a TREE, so a
// filter cannot be a `.filter()`: `_nest-outline` reads a FLAT depth-tagged run
// and assumes it is well formed, so a depth-1 entry left behind by a dropped
// depth-0 parent is silently read as a sibling of whatever came before. Hence
// `_prune-outline` below, which prunes AND PROMOTES.
#let _prune-outline(entries, pred) = {
  if pred == none { return entries }
  // `kept` holds the ORIGINAL depths of the entries that survived. Popping every
  // one whose depth is >= the current entry's leaves exactly the surviving
  // ANCESTORS on the stack, so `kept.len()` is the re-based depth: a matching
  // idea whose parent was filtered out lands at its nearest kept ancestor's
  // level rather than dangling at a depth with no parent above it.
  //
  // REJECTED: keeping unmatched ancestors as unlinked scaffolding, for context.
  // It puts notes in the index the filter said to exclude, and this package has
  // no styling for a row that is not a link.
  let kept = ()
  let out = ()
  for e in entries {
    while kept.len() > 0 and kept.last() >= e.depth { kept = kept.slice(0, kept.len() - 1) }
    if pred(e.tags) {
      out.push((..e, depth: kept.len()))
      kept.push(e.depth)
    }
  }
  out
}
#let ideas-outline(
  title: auto,
  depth: none,
  rookery-wide: false,
  tags: none,
  match: "any",
  filter: none,
) = context {
  assert(
    depth == none or (type(depth) == int and depth >= 1),
    message: "@rheo/rookery: #ideas-outline's `depth` must be none or a "
      + "positive integer — got " + repr(depth),
  )
  assert(
    type(rookery-wide) == bool,
    message: "@rheo/rookery: #ideas-outline's `rookery-wide` must be a boolean "
      + "— got " + repr(rookery-wide),
  )
  assert(
    tags == none
      or type(tags) == str
      or (type(tags) == array and tags.all(t => type(t) == str)),
    message: "@rheo/rookery: #ideas-outline's `tags` must be none, a string, or "
      + "an array of strings — got " + repr(tags),
  )
  assert(
    match == "any" or match == "all",
    message: "@rheo/rookery: #ideas-outline's `match` must be \"any\" or \"all\" "
      + "— got " + repr(match),
  )
  assert(
    filter == none or type(filter) == function,
    message: "@rheo/rookery: #ideas-outline's `filter` must be none or a "
      + "function taking the note's tag array — got " + repr(filter),
  )
  let title-content = if title == auto { [Contents] } else { title }
  let entries = _ideas-outline-data(rookery-wide: rookery-wide)
  // Pruned BEFORE the `depth:` cap, and that order is the whole point: `depth`
  // then counts levels in the FILTERED tree, so `depth: 1` means "the top level
  // of what I asked for" rather than "whatever survived from the top level of
  // everything".
  let pred = _tag-pred(tags, match, filter: filter)
  entries = _prune-outline(entries, pred)
  if depth != none { entries = entries.filter(e => e.depth + 1 <= depth) }

  // On HTML an explicit `h4` carrying a class, the same shape (and the same
  // reason) as the Footnotes block's heading: a bare `heading()` compiled to
  // an unclassed `<h2>`, which took the host site's heading scale and made
  // "Contents" as loud as a section title — for a label on a list of links.
  // The class is what lets it be sized down, and there is nothing else on the
  // element to target.
  //
  // `idea-tab` ALONGSIDE IT, so this title is A HAT — the same object a note's
  // id sits on, a stub of rule out of the corner with the label on its end. The
  // tab treatment goes on the `<h4>` ITSELF rather than wrapping it, because
  // `.idea-tab` is emitted elsewhere as a `<span>` (`_permalink-tab`) and a
  // `<span>` may not contain an `<h4>`; the tab is only `display: flex` plus a
  // `::before`, so an element can wear it directly. It stays an `<h4>` — see
  // above for why the element matters and the stylesheet for how it is kept from
  // reading like one.
  //
  // `_themed`, AND IT IS NOT OPTIONAL HERE. The theme travels as inline custom
  // properties, which inherit DOWN the DOM, and this title is a SIBLING of the
  // `<ul>` rather than a descendant — the same reason `_nest-outline` themes the
  // outermost `<ul>` itself. MEASURED without it, on a project setting
  // `border-color: #ff0000, rule-width: 3px, label-font: Berkeley Mono`: the
  // list drew a 3px red rule while the hat above it drew a 2px last-resort
  // purple stub in the reader's plain monospace — a corner in two colours and
  // two widths. With it, both read `--idea-rule-width`/`--idea-border-color` and
  // the title reads `--idea-label-font`.
  //
  // The paged target keeps the real `heading()`: there it IS a document
  // structure, it belongs in the PDF outline, and nothing is styling it by
  // class.
  let title-heading = if title-content == none { none } else if (
    _target() == "html" or _target() == "epub"
  ) {
    html.elem("h4", attrs: _themed((class: "idea-outline-title idea-tab")), title-content)
  } else {
    heading(depth: 1, outlined: false, numbering: none, title-content)
  }
  // An empty UNFILTERED outline is an answer: the page said "here is the index
  // of this page's notes", there are none, and the heading is the sentence. An
  // empty FILTERED one is a promise the filter already ruled out — a page
  // carrying `#ideas-outline(title: [Todos], tags: "todo")` on every section
  // would render a "Todos" heading over emptiness on every section without one.
  // So the two cases differ on purpose, and `pred != none` is exactly "a filter
  // is active" — no separate flag, and no `hide-when-empty:` knob.
  //
  // `depth:` deliberately does NOT count as a filter here. It drops levels below
  // the first, so it cannot empty an outline that had anything in it at all.
  if entries.len() == 0 { return if pred == none { title-heading } else { none } }

  let list-content = if _target() == "html" or _target() == "epub" {
    _nest-outline(
      entries,
      (items, root) => html.elem(
        "ul",
        attrs: if root { _themed((class: "idea-outline")) } else { (class: "idea-outline") },
        items.join(),
      ),
      // The title in a span of its own, so the hairline marker and the row's
      // left rule can be positioned against the ROW while the link keeps the
      // hover treatment every other rookery link has.
      //
      // The note's tags go on the row as `idea-tag-<tag>` classes, built the
      // same way `#idea` builds them for the heading and for the card — one
      // convention, three emission sites, so a site styling a todo note in the
      // body can style the same note's row in the index. It is also the zero-API
      // half of tag filtering: with the classes here a site can grey, badge or
      // hide rows in its own CSS, with no Typst-side filter at all. The package
      // ships NO default rule for any of them — `#note`/`#todo` are sugar, not a
      // recognised set, and styling one here would invent an opinion.
      (e, sub) => html.elem(
        "li",
        attrs: (class: (("idea-outline-row",) + e.tags.map(l => "idea-tag-" + l)).join(" ")),
        link(e.loc, e.title) + if sub == none { [] } else { sub },
      ),
    )
  } else {
    // No theme container and no marker styling on the paged target: `#idea`
    // renders as a plain `heading` there with no `.idea-box` rule to be in
    // line with, so an outline that grew rules and hairlines would be the
    // only thing on the page wearing them. Typst's own list, unchanged.
    _nest-outline(
      entries,
      (items, root) => list(..items),
      (e, sub) => list.item(link(e.loc, e.title) + if sub == none { [] } else { sub }),
    )
  }
  if title-heading == none { list-content } else { title-heading + list-content }
}


// Depth-relative href from the CURRENT page to another vertebra's page — the
// same arithmetic as `_note-href`, against a spine handle rather than a note
// id. rheo's own `show link:` rule would do this for a `#link(<handle>)`, but
// that rule lives in the document template and a marrow contribution is
// spliced in outside it, so the package computes its own.
#let _page-href(handle) = {
  let c = _rheo-ctx()
  if c == none { return none }
  let ext = c.at("ext", default: none)
  if ext == none { return none }
  let here = state("rheo-handle").get()
  if type(here) != str { return none }
  _rel-prefix(here) + handle.replace(":", "/") + "." + ext
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

// ---- #ideas — every registered note, as data ------------------------------
//
//   #context ideas()                 // -> ((id: "idea:etal", name: "etal", ..), ..)
//   #context ideas(tags: "phd")      // only the notes tagged phd
//   #context ideas(tags: ("phd", "draft"), match: "all")  // both tags
//
// The whole rookery as a plain ARRAY of dictionaries, ordered by id so a build
// is reproducible. This is the primitive other packages and custom site code
// are written against — `@rheo/rookery-search` ranks it, a site can render it
// as an index, a feed can walk it — and it is deliberately a snapshot of
// STABLE fields rather than the internal record:
//
//   (id:      "idea:etal",     // the full id, prefix included
//    name:    "etal",          // the id with the prefix stripped
//    title:   [Et al.],        // the title as CONTENT, or none
//    text:    "Et al.",        // the same title as plain text, "" if none
//    tags:    ("note", "draft"), // as the author gave them, () if untagged
//    body:    "Et al. is ...", // the note's body as plain text, "" if empty
//    href:    "ideas/etal.html", // depth-relative, or none — see `note-href`
//    page:    "ideas/etal.html", // site-root-relative, or none — see `note-path`
//    minted:  datetime or none,
//    updated: datetime or none)
//
// `tags` is in the AUTHOR'S OWN ORDER, which is not alphabetical and not the
// order they were written either: `#note`/`#todo` PREPEND their own tag through
// `_dedup-tag`, so `#todo("b", tags: ("draft",))` reads `("todo", "draft")`.
// A consumer sorting them is welcome to; this hands them over as given.
//
// `#tags-of(name)` exposes ONE note's tags too, and still does. This field is
// the bulk form and the cheap one: `tags-of` resolves `_registry.final()` once
// PER NOTE, where `ideas()` resolves it once for the whole pass — and
// `@rheo/rookery-search`'s `#search-index` runs on every page of a site, so the
// difference is one state resolution per note per page against one per page.
//
// NOT exposed IN BULK: `raw`, `body`-as-CONTENT and `links`. `body` above is
// a plain STRING derived from `raw` — matchable and excerptable, but not
// renderable, so returning it in an array of every note in the rookery does
// not make a consumer a second transclusion engine the way handing out every
// note's content here would; `links` is backlink plumbing that `.marrow.typ`
// already owns. Add fields here when a consumer genuinely needs them — this
// list is a contract other packages depend on, so removing one is a breaking
// change.
//
// A SINGLE note's body-as-content IS available, on request: `#idea-body(name)`
// below renders one note at a time, the same rendering `#window` gives it —
// links, styling, footnotes, citations — for a consumer that wants to show
// the actual note rather than describe it. The distinction is bulk vs.
// one-at-a-time: `#ideas()` handing out `title` (content) for the WHOLE
// rookery would already be the transclusion-engine problem above if it
// contained the full body instead of a heading; asking for one note's body
// by name is what `#window` has always let an author do explicitly, and
// `#idea-body` is that same permission, minus the chrome.
//
// `tags:`/`match:` narrow the corpus to the notes carrying a tag, and are the
// SAME pair `#window` takes, with the same meanings, through the same shared
// `_tag-pred`: `tags` is `none`, one string or an array; `match` is "any" (the
// default) or "all". They exist because the workaround does not scale and does
// not reach far enough — `ideas().filter(e => "phd" in tags-of(e.name))` works
// and is VERIFIED, but it costs one `_registry.final()` read per row, and
// `#search-bar` builds its index internally with no hook for a caller's filter
// at all.
//
// Filtered BEFORE the `.map`, so a note that is dropped never pays for its
// `_body-plain`/`_note-href`/`_plain` conversions. That is the whole reason the
// parameter is here rather than left to a caller's own `.filter`.
//
// Must be called INSIDE a `#context` block (it reads `_registry.final()`); it
// is not itself a context function, because a context function can only return
// content and the whole point here is to return data.
#let ideas(tags: none, match: "any") = {
  assert(
    tags == none
      or type(tags) == str
      or (type(tags) == array and tags.all(t => type(t) == str)),
    message: "@rheo/rookery: #ideas' `tags` must be none, a string, or an "
      + "array of strings — got " + repr(tags),
  )
  assert(
    match == "any" or match == "all",
    message: "@rheo/rookery: #ideas' `match` must be \"any\" or \"all\" — got "
      + repr(match),
  )
  let reg = _registry.final()
  let keep = _tag-pred(tags, match)
  reg
    .pairs()
    .sorted(key: p => p.at(0))
    .filter(p => keep == none or keep(p.at(1).at("tags", default: ())))
    .map(p => {
      let (id, rec) = p
      (
        id: id,
        name: _norm(id),
        title: rec.at("title", default: none),
        text: _plain(rec.at("title", default: none)),
        tags: rec.at("tags", default: ()),
        body: _body-plain(rec.at("raw", default: none)),
        href: _note-href(id),
        page: _note-path(id),
        minted: rec.at("minted", default: none),
        updated: rec.at("updated", default: none),
      )
    })
}

// ---- #show: rookery — the setup, and the knobs ----------------------------
//
//   #import "@rheo/rookery:0.4.0": rookery, idea, window
//   #show: rookery.with(
//     prefix: "note",
//     theme: (link-color: rgb("#ffe08a"), fold-color: rgb("#fffbe8")),
//   )
//
// Does exactly five things, and deliberately nothing else:
//
//   1. publishes `prefix` (so `#idea("etal")` mints `<note:etal>`);
//   2. publishes `window-depth`, the document-wide transclusion budget (see
//      `_window-depth` for the whole scale; `1`, the default, renders a
//      windowed note once and collapses a `#window` nested inside it to its
//      permalink, which is the behaviour every existing document already has,
//      while `0` transcludes nothing and renders every `#window` as a link to
//      the note's page). A `#window(..., depth: n)` overrides it per call
//      site;
//   3. publishes `idea-page-template`, the project's own chrome for the
//      standalone pages `.marrow.typ` mints (see `_idea-page-template`;
//      `none`, the default, mints them bare as before);
//   4. publishes the theme — every colour the package will set for you;
//   5. installs `show ref: hyperlink` (or `hyperlink.with(link-to:
//      "anchor")`, see `ref-target:` below), so `@note:etal` renders the
//      note rather than a bare figure number.
//
// It does NOT transform the document. It sets no page/text/heading style,
// wraps `doc` in no container, and emits nothing of its own — `#show:
// rookery` on a document with no notes in it is a no-op. The blast radius is
// exactly one element type: `ref`. Even there the installed rule passes every
// reference that is NOT a rookery note straight through untouched (its `else
// { it }` branch — see `#hyperlink` above), so an ordinary `@fig:x` in the
// same document is unaffected.
//
// WHY NOT NARROWER — i.e. a rule scoped to `#idea` alone. The prefix cannot
// ride on a show rule over idea markers, because `#window` and `.marrow.typ`
// need the same value and neither is inside an idea. It has to be state (see
// `_prefix` at the top of this file), and a plain function CANNOT install the
// `ref` rule: a `show` inside a function body scopes to the content that body
// returns, not to the document that later inserts it. Hence a template — kept
// as thin as a template can be.
//
// THEME. `theme:` takes the whole set at once; the granular parameters named
// after each key take one at a time and WIN over `theme`, so the two compose:
//
//   #show: rookery.with(theme: DARK, link-color: rgb("#ff0"))
//
// reads as "the dark theme, but that one colour". Precedence, least specific
// first: `rookery.css`'s own default -> `theme:` -> the granular parameter.
// Anything left unset at every level stays a CSS default and is not emitted.
//
// Each value is a Typst colour or a raw CSS string. A colour is converted with
// `.to-hex()` HERE, once, rather than at every element: this is the only place
// that knows the value is destined for CSS. A string passes through untouched,
// which is what makes `rgba(…)`, `var(--accent)`, `transparent` and any other
// CSS-valid value available — Typst's colour type cannot express those.
//
// An unknown `theme:` key is an ERROR naming the valid ones, rather than a
// silently ignored typo: a misspelled colour that just does not apply is
// exactly the kind of thing an author would chase through their own
// stylesheet first.
//
// `refs: false` opts out of (3) alone, for an author who wants stock `@`
// behaviour or their own `show ref` rule. The `show` sits INSIDE the branch,
// wrapping `doc` there: a `show` in an `if` block's body scopes to that block,
// so hoisting it out of the branch would scope it to nothing at all.
//
// `ref-target: "page"` (the default) installs plain `hyperlink`; `"anchor"`
// installs `hyperlink.with(link-to: "anchor")` instead, making every
// `@idea:etal` in the document behave like `#hyperlink("idea:etal", ...,
// link-to: "anchor")` rather than jumping to the note's minted page. Only
// meaningful alongside `refs: true`; ignored (with no error) when `refs:
// false`, since there is then no installed rule for it to configure — an
// author who set `refs: false` already opted into supplying their own
// `show ref` rule, anchor-targeted or not.
//
// Defined last in this file because a `#let` closure captures the scope
// visible AT DEFINITION time — `hyperlink` must already exist.
#let rookery(
  prefix: "idea",
  window-depth: 1,
  idea-page-template: none,
  bibliography: none,
  theme: (:),
  link-color: none,
  fold-color: none,
  id-color: none,
  date-color: none,
  border-color: none,
  rule-width: none,
  pad: none,
  label-font: none,
  label-size: none,
  refs: true,
  ref-target: "page",
  syndicate: false,
  index-page: false,
  doc,
) = {
  assert(
    type(prefix) == str and prefix != "" and not prefix.contains(":"),
    message: "@rheo/rookery: `prefix` must be a non-empty string containing no `:` "
      + "(the `:` between prefix and name is added for you) — got "
      + repr(prefix),
  )
  assert(
    type(window-depth) == int and window-depth >= 0,
    message: "@rheo/rookery: `window-depth` must be a non-negative integer — `0` "
      + "renders every #window as a link to the note's page, `1` (the default) "
      + "renders a windowed note once, `n` unfurls n-1 nested levels — got "
      + repr(window-depth),
  )
  assert(
    idea-page-template == none or type(idea-page-template) == function,
    message: "@rheo/rookery: `idea-page-template` must be a function taking "
      + "`(id: str, note: dictionary, doc)` — got " + repr(idea-page-template),
  )
  assert(
    type(theme) == dictionary,
    message: "@rheo/rookery: `theme` must be a dictionary of "
      + _THEME-KEYS.keys().join(", ") + " — got " + repr(theme),
  )
  assert(
    bibliography == none or type(bibliography) == arguments,
    message: "@rheo/rookery: `bibliography` must be an `arguments` value carrying "
      + "Typst's own #bibliography arguments, e.g. "
      + "`arguments(bytes(read(\"refs.bib\")), style: \"chicago-author-date\")` — got "
      + repr(bibliography),
  )
  // A PATH CANNOT WORK HERE, so say so rather than failing later with a
  // "file not found" naming a directory inside the package. Typst resolves a
  // path relative to the file the call appears in, and every call this package
  // makes is inside the package — see the note on `_bib`.
  if bibliography != none {
    let src = bibliography.pos().at(0, default: none)
    let sources = if type(src) == array { src } else { (src,) }
    for s in sources {
      assert(
        type(s) == bytes,
        message: "@rheo/rookery: `bibliography` sources must be `bytes`, not a path — "
          + "write `bytes(read(\"refs.bib\"))` so the path resolves against YOUR "
          + "file rather than against the package. Got " + repr(s),
      )
    }
  }
  assert(
    ref-target == "page" or ref-target == "anchor",
    message: "@rheo/rookery: `ref-target` must be \"page\" or \"anchor\" — got "
      + repr(ref-target),
  )
  assert(
    type(syndicate) == bool,
    message: "@rheo/rookery: `syndicate` must be a boolean — got " + repr(syndicate),
  )
  assert(
    type(index-page) == bool,
    message: "@rheo/rookery: `index-page` must be a boolean — got " + repr(index-page),
  )

  // One converter for both sources, so `theme: (link-color: c)` and
  // `link-color: c` cannot disagree about what a value may be.
  //
  // THREE KINDS OF VALUE, not two. Colours are the default and the majority;
  // `rule-width`/`pad`/`label-size` are LENGTHS; `label-font` is a FONT STACK,
  // which is neither — it is CSS text this package cannot validate and must
  // not mangle, so it is passed straight through. An array is accepted and
  // joined with `", "`, because a stack is what a font is and writing it as
  // `("Berkeley Mono", "monospace")` reads better than embedding the commas
  // in a string.
  //
  // The LENGTH branch: `repr` on a Typst length gives exactly the CSS it needs —
  // `2pt` -> "2pt", `0.15em` -> "0.15em" — so both spellings work and neither
  // needs a unit table here. A string passes through for the units Typst has no
  // literal for, `px` above all, which is what a hairline wants.
  let css(key, value) = if key == "label-font" {
    assert(
      type(value) == str or (type(value) == array and value.all(f => type(f) == str)),
      message: "@rheo/rookery: theme `label-font` must be a CSS font stack as a "
        + "string (\"Berkeley Mono, monospace\") or an array of family names "
        + "((\"Berkeley Mono\", \"monospace\")) — got " + repr(value),
    )
    if type(value) == array { value.join(", ") } else { value }
  } else if key in ("rule-width", "pad", "label-size") {
    // For `label-size` specifically, the STRING path is the primary one,
    // unlike `rule-width`/`pad` where a Typst length is more commonly used —
    // this key's whole point is staying in `rem` (see the readme), and Typst
    // has no `rem` literal, so `"0.8rem"` rather than a length is expected to
    // be the normal spelling here.
    assert(
      type(value) == length or type(value) == str,
      message: "@rheo/rookery: theme `" + key + "` must be a length (2pt, 0.15em) "
        + "or a CSS length string (\"3px\") — got " + repr(value),
    )
    if type(value) == length { repr(value) } else { value }
  } else {
    assert(
      type(value) == color or type(value) == str,
      message: "@rheo/rookery: theme `" + key + "` must be a colour or a CSS "
        + "colour string — got " + repr(value),
    )
    if type(value) == color { value.to-hex() } else { value }
  }

  let resolved = (:)
  for (key, value) in theme {
    assert(
      key in _THEME-KEYS,
      message: "@rheo/rookery: unknown theme key `" + key + "` — valid keys are "
        + _THEME-KEYS.keys().join(", "),
    )
    if value != none { resolved.insert(key, css(key, value)) }
  }
  // Granular arguments last: they override whatever `theme:` set.
  for (key, value) in (
    link-color: link-color,
    fold-color: fold-color,
    id-color: id-color,
    date-color: date-color,
    border-color: border-color,
    rule-width: rule-width,
    pad: pad,
    label-font: label-font,
    label-size: label-size,
  ) {
    if value != none { resolved.insert(key, css(key, value)) }
  }

  _prefix.update(prefix)
  _window-depth.update(window-depth)
  // Default the style to author-date, and ONLY when the author passed none.
  //
  // WHY: citation numbering is document-wide and cannot be reset. `counter(
  // bibliography).update(0)` does nothing — CSL assigns the numbers, not a
  // Typst counter — so under a numeric style the third idea on a page reads
  // `[3]` and a standalone page can show its only reference as `[7]`. MEASURED.
  // An author-date style has no numbers and the problem does not arise. A
  // numeric style is still honoured without complaint: this is a default, not
  // a restriction.
  //
  // `_ => v`, never a bare value that happens to be callable — see
  // `_idea-page-template` for why `state.update` needs the wrapper.
  _bib.update(_ => if bibliography == none { none } else {
    let named = bibliography.named()
    if "style" not in named { named.insert("style", "chicago-author-date") }
    arguments(..bibliography.pos(), ..named)
  })
  // `_ => f`, not `f` — see `_idea-page-template`.
  _idea-page-template.update(_ => idea-page-template)
  _syndicate.update(syndicate)
  _index-page.update(index-page)
  _theme.update(resolved)
  // DOCUMENT-SCOPE theme publication, ADDITIVE to the per-container INLINE
  // styling `_themed` still applies everywhere it already did (see that
  // function and its callers) — this does not replace them, it gives
  // anything ELSE on the page a `:root` to inherit from. Custom properties
  // inherit DOWN the DOM, but only from an ancestor that carries them: before
  // this, that was ever only `.idea-box`/`.idea-window`/etc, so a sibling
  // element with no rookery ancestor (a `<dialog>` in a site's own header, a
  // search bar not nested inside a note) saw nothing. MEASURED bug this
  // fixes: `@rheo/rookery-search`'s `#search-modal` reading an empty string
  // for `--idea-border-color` and having to carry its own copy of the theme
  // table to cope (see the banner above `_THEME-KEYS`).
  //
  // EXACTLY ONCE PER OUTPUT PAGE: `#show: rookery` is applied PER FILE, and
  // under rheo one FILE is one VERTEBRA is one OUTPUT PAGE (the same fact
  // `_prefix`/`_bib`/`_theme` above are already document-wide state for) —
  // so one call to this function is one page, and this line runs exactly
  // once per call. `demo/rheo/content/lib.typ` is the shape every multi-page
  // project already uses: ONE shared `#show: rookery.with(..)` wrapper that
  // EVERY vertebra applies, so every page gets its own `<style>`, all of them
  // carrying the same document-wide `.final()` theme. A minted note page
  // (`.marrow.typ`) is a separate `#document` that never calls `rookery()`
  // again, so it is untouched by this — same as it always was.
  //
  // Reuses `_theme-style()` rather than re-deriving anything: it already
  // returns `none` for an unconfigured theme, so an unthemed project's
  // `<style>` count stays exactly zero, matching the promise inline theming
  // already keeps ("an unconfigured document emits nothing extra at all").
  //
  // GATED to html/epub, exactly like every other `html.elem` call in this
  // file: `html.elem` renders nothing meaningful on the paged (PDF) target,
  // and unconditionally calling it there is what `demo/pure`'s two PDF roots
  // exist to catch.
  context {
    if _target() == "html" or _target() == "epub" {
      let style = _theme-style()
      if style != none {
        html.elem("style", ":root { " + style + "; }")
      }
    }
  }
  // The fallback for a rookery `#footnote` written OUTSIDE any idea: page-wide
  // numbering and a body in the page's own endnote section, exactly as Typst's
  // own footnote behaves. `#idea` installs a nested rule that wins over this
  // one inside a note — MEASURED.
  //
  // Installed unconditionally: `refs: false` is about the `show ref:` rule
  // only, and a document that opted out of reference rendering has not thereby
  // opted out of footnotes.
  show FNK: it => std.footnote(it.value.rookery-fn)
  if refs {
    show ref: if ref-target == "anchor" { hyperlink.with(link-to: "anchor") } else { hyperlink }
    doc
  } else {
    doc
  }
  // TRAILING PROSE CITATIONS. A citation in page prose before an idea is
  // claimed by that idea's sweep block, but one written after the LAST idea or
  // window on the page has nothing following it — and a citation no
  // bibliography claims is a hard error (`label <key> does not exist in the
  // document`), so this is required for the page to build at all, not polish.
  //
  // `_own-cited-keys(doc)` is exactly the right question here, and it is the
  // same one an idea asks about its own body: every `#idea` and `#window` on
  // the page is a claimant, so what survives the last of them is precisely the
  // trailing prose. Both always render at page level, hence the default
  // `windows-claim: true`.
  //
  // The template CAN ask this where `#idea` cannot: it receives the whole page
  // as `doc`, whereas an idea never sees the prose around it. That asymmetry is
  // why the sweep block before each idea has to be unconditional while this one
  // does not.
  //
  // Emitted only when something is actually left, so `#show: rookery` keeps its
  // promise to emit nothing of its own on a page with no notes — and on any
  // page with no configured bibliography, since `_own-cited-keys` is then empty.
  context {
    let own = _own-cited-keys(doc)
    if own.len() > 0 {
      if _target() == "html" or _target() == "epub" {
        html.elem("div", attrs: (class: "idea-page-refs"), _bib-call([References]))
      } else {
        _bib-call([References])
      }
    }
  }
}
