// `#hyperlink` — a plain link to a note, page-or-anchor, and the `show ref:`
// rule that makes `@idea:etal` render as one.
//
// BEFORE `transclusion.typ` in the import order, and that is load-bearing:
// `_flatten` installs `show ref: hyperlink` on a transcluded body, so the name
// has to already exist when that module is evaluated. A `#let` closure captures
// the scope visible at definition time.
#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *

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
//   #import "@rheo/rookery:0.5.0": idea, window, hyperlink
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
