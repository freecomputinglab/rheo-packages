// `_outbound` — the walk that records where a note points, so the other end can
// show a backlink.
//
// After `transclusion.typ`: it descends into the same markers `#window` emits.
#import "base.typ": *
#import "state.typ": *
#import "urls.typ": *
#import "transclusion.typ": *

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
