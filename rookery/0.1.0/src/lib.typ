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
// per-note pages `.marrow.typ` mints, whose handles are `notes:<slug>` — and
// that distinction is load-bearing for backlinks. A minted page carries links
// of its own (its permalink, its context link, the windows in its own backlinks
// list), all of which would otherwise be harvested as "this page links to that
// note" and every note would list every other note's page. MEASURED: without
// this filter, `notes/rookery.html` claimed six page backlinks, four of them
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
#let _THEME-KEYS = (
  "link-color": "--idea-link-color",
  "fold-color": "--idea-fold-color",
  "id-color": "--idea-id-color",
  "date-color": "--idea-date-color",
  "border-color": "--idea-border-color",
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
#let _note-file(id) = "notes/" + id.trim(_pfx(), at: start) + ".html"

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
  let depth = handle.split(":").len() - 1
  let prefix = if depth == 0 { "" } else { range(depth).map(x => "../").join() }
  prefix + _note-file(id)
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

// Paged counterpart: no `html.elem`, and the fallback is the Typst label
// rather than an HTML fragment.
#let _permalink-paged(id) = {
  link(_resolve-dest(id, "page"), text(gray, raw("[" + id + "]")))
}

// Normalise a name (string or Typst label) to its bare string form, with no
// prefix. Strips a leading "prefix:" when present, so the bare form
// ("etal", <etal>) and the full id ("idea:etal", <idea:etal> — the same id
// `@idea:etal` resolves) name the same note either way: whichever is closer
// to hand — a fresh name to pin, or a full id copied from elsewhere — just
// works. Shared by `#idea` (pinning an explicit id), `#window` (looking one
// up), and `#hyperlink` (linking to one). Defined before the registry below
// because `hyperlink` needs both and must come before `_flatten`, which
// installs it as a `show ref:` rule.
#let _norm(name) = {
  let s = if type(name) == label { str(name) } else { name }
  let i = s.position(":")
  if i == none { s } else { s.slice(i + 1) }
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
#let IK = "rheo-idea" // marker for an idea
#let WK = "rheo-idea-window" // marker for a window; defined here (not next to
// `#window` below) because `_flatten` needs both marker kinds and must be
// defined before `#idea`, which calls it at registration time.

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
//   #import "@rheo/rookery:0.1.0": idea, window, hyperlink
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
#let _edge(kind) = metadata((rookery-edge: kind))
#let _bracket(body) = _edge("open") + body + _edge("close")

#let _flatten(body) = {
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
      let header = html.elem(
        "h" + str(v.level + 1),
        attrs: attrs,
        (if v.title == none { [] } else {
          html.elem("span", attrs: (class: "idea-title"), v.title)
        }) + (if id == none { [] } else { _permalink(id) }),
      )
      let box-cls = ("idea-box",) + v.tags.map(l => "idea-tag-" + l)
      _bracket(html.elem("div", attrs: _themed((class: box-cls.join(" "))), header + v.body))
    } else {
      _bracket({
        if v.title != none { heading(depth: v.level, v.title) }
        v.body
      })
    }
  }
  // A `#window` nested inside a transcluded body collapses to the SAME
  // permalink affordance the window's own summary would have carried — so the
  // one-link rule holds at every depth: the id navigates, nothing else does.
  // (It used to collapse to a `[window of idea:x]` link on the label anchor,
  // which was a second, differently-styled navigational form for the same
  // destination.) Wrapped in `context` for `_permalink`, which reads the page
  // handle and the prefix state.
  show figure.where(kind: WK): it => context {
    let m = it.body.children.find(c => c.func() == metadata)
    if _target() == "html" or _target() == "epub" {
      _permalink(m.value)
    } else {
      _permalink-paged(m.value)
    }
  }
  body
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

  let out = ()
  if f == link and type(node.dest) == label { out.push(str(node.dest)) }
  if f == ref { out.push(str(node.target)) }
  for (_, v) in node.fields() { out += _outbound(v) }
  out
}

#let idea(level: 1, title: none, tags: (), minted: none, updated: none, show-date: false, ..args) = {
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
      // still show it even when the note's own heading (here) does not.
      let date = if show-date and resolved-minted != none {
        resolved-minted.display("[year]-[month]-[day]")
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
      // Outbound links, filtered to real note ids and deduped, with a
      // self-link dropped — a note is not its own backlink. Walked from the
      // RAW body, before `_flatten`: flattening rewrites `#window` markers into
      // permalinks, which would turn every transclusion into an
      // indistinguishable `link` and lose the ones nested inside other notes.
      let links = _outbound(body)
        .filter(t => t.starts-with(_pfx()) and t != id)
        .dedup()

      let rec = (
        title: title,
        body: _flatten(body),
        minted: resolved-minted,
        updated: resolved-updated,
        origin: origin,
        links: links,
      )
      _registry.update(r => {
        if id in r and r.at(id) != rec {
          panic("rookery: duplicate note id " + id)
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
        // `#idea` appends it directly, always (even with no title), showing
        // the FULL `idea:name` id so it is copy-pasteable straight into
        // `#window("...")`. `#window` renders the identical affordance in its own
        // summary; both go through `_permalink`.
        // The title goes in a span even though nothing styles it by default,
        // so that `.idea-label:first-child` can mean "this note has no title".
        // A bare title is a TEXT node, and CSS `:first-child` counts elements
        // only — so without the span the permalink is the first element child
        // either way, and the rule that un-indents a titleless note would
        // strip the separating margin from a titled one too. `#window`'s summary
        // has always wrapped its title for the same reason.
        let date-span = if date == none { [] } else {
          html.elem("span", attrs: (class: "idea-date"), date)
        }
        let header = html.elem("h" + str(level + 1), attrs: (id: id, class: cls.join(" ")),
                  (if ttl == none { [] } else {
                    html.elem("span", attrs: (class: "idea-title"), ttl)
                  }) + _permalink(id) + date-span)
        // Header and body wrap together in one card, HTML/EPUB only — no box
        // for a paged target. The box classes mirror `cls` (tags included)
        // so a tag can style the whole card, not just the heading; the
        // heading's own class list (above) is untouched for existing
        // stylesheets.
        let box-cls = ("idea-box",) + tags.map(l => "idea-tag-" + l)
        // Bracketed so a link written INSIDE this note counts as the note's,
        // not as its page's — see `_edge`.
        _bracket(html.elem("div", attrs: _themed((class: box-cls.join(" "))), header + body))
      } else {
        _bracket({
          if ttl != none { heading(depth: level, ttl) }
          if date != none { text(gray, date); linebreak() }
          body
        })
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
//
// Prepends `tag`, unless the caller already passed it — `#todo("x", tags:
// ("todo",))` must yield `("todo",)`, not `("todo", "todo")`, or the heading
// gets a duplicated CSS class. Defined before `note`/`todo` below: a `#let`
// closure captures the scope visible AT DEFINITION time, so a forward
// reference to a not-yet-defined name fails at call time.
#let _dedup-tag(tag, tags) = if tag in tags { tags } else { (tag,) + tags }
#let note(tags: (), ..args) = idea(tags: _dedup-tag("note", tags), ..args)
#let todo(tags: (), ..args) = idea(tags: _dedup-tag("todo", tags), ..args)

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
// A `#window` is pure presentation: it never registers, never advances the
// counter, and never re-registers a nested `#idea`. That guarantee is
// delivered by `_flatten` (defined above, next to `IK`/`WK`), not by any
// suppression logic here.

// Split a body into block-level chunks for `limit:` truncation. A naive
// `body.children.slice(0, limit)` is WRONG: whitespace (`space`/`parbreak`)
// children make it select nothing, and list items are bare `item` children
// with no wrapping `list` element, so a naive slice also cuts lists in half.
// This groups consecutive `item`s into one block and drops whitespace.
// Compares `repr(c.func())` against "space"/"parbreak" because there is no
// public element function to compare those against directly.
//
// MEASURED REGRESSION FIX: every registry body has been through `_flatten`
// since v6y.7, which wraps it in a `show`-rule scope — Typst represents that
// as a `styled` node with `.has("children") == false`, not the `sequence` it
// wraps. Without unwrapping, `_blocks` always fell into the single-block
// fallback below, silently disabling `limit:` truncation for every note.
// `styled` (like `space`/`parbreak`) has no public function value to compare
// against directly, hence `repr(...)`. A `styled` node exposes the wrapped
// content as `.child` — verified this stays a single layer even with two
// `show` rules in the scope (`_flatten` sets exactly two), but loop anyway
// in case that ever changes.
#let _blocks(body) = {
  let body = body
  while repr(body.func()) == "styled" { body = body.child }
  if not body.has("children") { return (body,) }
  let out = ()
  let prev-item = false
  for c in body.children {
    let f = repr(c.func())
    if f == "space" or f == "parbreak" { prev-item = false; continue }
    if f == "item" and prev-item {
      out.at(-1) = out.at(-1) + c
    } else {
      out.push(c)
      prev-item = f == "item"
    }
  }
  out
}

// ONE rendering, whatever `folded` says. `folded` sets only the INITIAL
// disclosure state — `false` (the default) renders `<details open>`, `true`
// renders it closed. It is not a second layout: a folded window and an unfolded
// one are the same block, so a reader who opens one sees exactly what a
// `#window` beside it already shows. `limit:` is therefore meaningful in both
// (it truncates the body that folding hides) and the two are orthogonal.
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
#let window(names, limit: none, folded: false, show-date: false) = {
  let ids = (if type(names) == array { names } else { (names,) }).map(_norm)

  // A transclusion is a way of pointing at a note, so it has to show up in the
  // target's backlinks. `_outbound` walks a note's RAW body at registration,
  // where everything below is still an unevaluated `context` block with
  // nothing inspectable in it — so the names are announced up front, in an
  // invisible `metadata` element, where the walk can see them without
  // rendering anything.
  //
  // Bare names, not full ids: this runs outside `context`, so `_pfx()` is not
  // available here. `_outbound` re-adds the prefix, which it can.
  metadata((rookery-window: ids))

  context {
  let reg = _registry.final()

  for n in ids {
    // Already normalised above, where the marker was emitted.
    let id = _pfx() + n
    if id not in reg {
      panic("@rheo/rookery: #window unknown note '" + id + "'")
    }
    let rec = reg.at(id)

    let bs = _blocks(rec.body)
    let shown = if limit != none and bs.len() > limit {
      bs.slice(0, limit).join() + [#text(gray)[ ... ]]
    } else {
      rec.body
    }
    let date = if show-date and rec.minted != none {
      rec.minted.display("[year]-[month]-[day]")
    } else { none }

    if _target() == "html" or _target() == "epub" {
      // A titleless note contributes no title span at all, so the permalink
      // comes first in the summary — "at the top of the window", the id doing
      // double duty as the note's name. `#idea`'s own heading does the same.
      let title-span = if rec.title == none { [] } else {
        html.elem("span", attrs: (class: "idea-window-title"), rec.title)
      }
      let date-span = if date == none { [] } else {
        html.elem("span", attrs: (class: "idea-window-date"), date)
      }
      let summary = html.elem(
        "summary",
        attrs: (class: "idea-window-summary"),
        title-span + _permalink(id) + date-span,
      )
      // `open` is a BOOLEAN html attribute: present means open and there is no
      // value meaning closed, so the attrs dictionary itself has to differ
      // between the two states. `open: "false"` would read as open.
      let d-attrs = if folded { (class: "idea-window-details") } else {
        (class: "idea-window-details", open: "open")
      }
      let content = html.elem("div", attrs: _themed((class: "idea-window")),
        html.elem("details", attrs: d-attrs,
          summary + html.elem("div", attrs: (class: "idea-window-body"), shown)))
      // Bracketed: the body being shown belongs to the note it came from, so
      // its links must not read as links from whatever page is showing it.
      _bracket(figure(kind: WK, supplement: none, [#metadata(id)#content]))
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
      _bracket(figure(kind: WK, supplement: none, [#metadata(id)#block[#head#parbreak()#shown]]))
    }
  }
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
  let depth = here.split(":").len() - 1
  let prefix = if depth == 0 { "" } else { range(depth).map(x => "../").join() }
  prefix + handle.replace(":", "/") + "." + ext
}

// ---- #show: rookery — the setup, and the knobs ----------------------------
//
//   #import "@rheo/rookery:0.1.0": rookery, idea, window
//   #show: rookery.with(
//     prefix: "note",
//     theme: (link-color: rgb("#ffe08a"), fold-color: rgb("#fffbe8")),
//   )
//
// Does exactly three things, and deliberately nothing else:
//
//   1. publishes `prefix` (so `#idea("etal")` mints `<note:etal>`);
//   2. publishes the theme — every colour the package will set for you;
//   3. installs `show ref: hyperlink` (or `hyperlink.with(link-to:
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
  theme: (:),
  link-color: none,
  fold-color: none,
  id-color: none,
  date-color: none,
  border-color: none,
  refs: true,
  ref-target: "page",
  doc,
) = {
  assert(
    type(prefix) == str and prefix != "" and not prefix.contains(":"),
    message: "@rheo/rookery: `prefix` must be a non-empty string containing no `:` "
      + "(the `:` between prefix and name is added for you) — got "
      + repr(prefix),
  )
  assert(
    type(theme) == dictionary,
    message: "@rheo/rookery: `theme` must be a dictionary of "
      + _THEME-KEYS.keys().join(", ") + " — got " + repr(theme),
  )
  assert(
    ref-target == "page" or ref-target == "anchor",
    message: "@rheo/rookery: `ref-target` must be \"page\" or \"anchor\" — got "
      + repr(ref-target),
  )

  // One converter for both sources, so `theme: (link-color: c)` and
  // `link-color: c` cannot disagree about what a value may be.
  let css(key, value) = {
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
  ) {
    if value != none { resolved.insert(key, css(key, value)) }
  }

  _prefix.update(prefix)
  _theme.update(resolved)
  if refs {
    show ref: if ref-target == "anchor" { hyperlink.with(link-to: "anchor") } else { hyperlink }
    doc
  } else {
    doc
  }
}
