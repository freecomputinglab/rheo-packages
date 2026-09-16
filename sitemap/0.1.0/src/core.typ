// The injected spine-wide context, or an empty stand-in where there is no rheo.
// Read from `sys.inputs` rather than taken as a `ctx:` parameter, because it is
// spine-wide data rather than anything about the calling file — the same
// feature-detect pattern `@rheo/blogfeed` and `@rheo/sidebar` use.
#let context-of() = sys.inputs.at("rheo-context", default: (spine: (), spine-flat: ()))

// The spine tree, or an empty one where there is no rheo.
#let spine() = context-of().at("spine", default: ())

// The flat spine, or an empty one where there is no rheo.
#let entries() = context-of().at("spine-flat", default: ())

// A handle's output path, measured FROM THE SITE ROOT.
//
// A handle's `:` segments are DIRECTORIES in the output, not part of the
// filename. MEASURED on rheo 0.6.0: a vertebra at `content/guide/intro.typ`
// has the handle `guide:intro` and is written to `guide/intro.html` — NOT
// `guide:intro.html`, which is what a naive `"./" + handle + ".html"` would
// link to and which exists nowhere on disk.
#let handle-path(handle) = handle.replace(":", "/") + ".html"

// One `../` per `:` level of the CURRENT page's handle, so a link from a nested
// page reaches the site root before descending again.
//
// Needed because a view like this one renders the SAME tree on every page: a
// bare `guide/intro.html` works from the root and resolves to
// `guide/guide/intro.html` from inside `guide/`. `@rheo/sidebar`'s
// `_rel-prefix` does the identical arithmetic for the identical reason.
#let rel-prefix(handle) = {
  if handle == none { return "" }
  let depth = handle.split(":").len() - 1
  if depth == 0 { "" } else { range(depth).map(x => "../").join() }
}

// A tree node's URL as written on the page currently being rendered.
#let handle-url(handle, from: none) = rel-prefix(from) + handle-path(handle)

// The handle of the page being compiled, or `none` outside rheo.
//
// `state("rheo-handle")`, NOT a key on `rheo-context`: the injected context is
// spine-wide and identical on every page, so it cannot say which page this is.
// rheo publishes the per-page handle as a state in its `rheo-page-init`, and
// that is readable from package scope. MEASURED on rheo 0.6.0: `"index"` at the
// root and `"sub:page"` for a nested vertebra — the same strings the spine
// tree's `handle` fields carry, which is what lets a caller match by equality.
//
// `.get()`, not `.final()`: the question is which page this is, not where the
// document ends.
#let current-handle() = {
  let h = state("rheo-handle").get()
  if type(h) == str { h } else { none }
}

// A NODE'S OWN FILE, as `tree` would print it. Three shapes, because a spine node is
// not quite a directory entry:
//
//   `cassirer.typ`     a leaf, printed as itself
//   `digitaltheory/`   a DIRECTORY AND ITS LANDING PAGE AT ONCE — rheo folds
//                      `digitaltheory/index.typ` into the directory's own node, so
//                      printing the file would put `index.typ` on the tree eleven
//                      times and never name the directory
//   `clusters/`        a group node: a directory with no `index.typ`, which has no
//                      path of its own at all
//
// The last of those is why `depth` is threaded through. A group node knows only its
// children, so its name is read off the first path found below it, at the depth the
// node itself sits at — `clusters/aicre/index.typ` at depth 0 is `clusters`.
#let first-path(n) = {
  if n.path != none { return n.path }
  for k in n.children {
    let p = first-path(k)
    if p != none { return p }
  }
  none
}

#let segment(n, depth) = {
  let p = first-path(n)
  if p == none { return "?" }
  let segs = p.split("/")
  if n.path == none {
    segs.at(depth, default: "?") + "/"
  } else if segs.len() > 1 and segs.last() == "index.typ" {
    segs.at(segs.len() - 2) + "/"
  } else {
    segs.last()
  }
}

// THE ROWS, FLAT, each carrying the rules that lead to it. Flat rather than nested
// because a row's whole ancestry is already in `stems`: one flag per level, true where
// that ancestor has a sibling still to come and so keeps its vertical rule running past
// this row. That flag is the entire trick of a `tree` — it is what stops the rule under
// a last child. Built by RETURNING an array rather than pushing to one, since a Typst
// closure cannot write to a binding from an outer scope.
#let _walk-inner(nodes, stems, depth) = {
  let out = ()
  for (i, n) in nodes.enumerate() {
    let last = i == nodes.len() - 1
    out.push((stems: stems, last: last, node: n, depth: depth))
    if n.children.len() > 0 {
      out += _walk-inner(n.children, stems + (not last,), depth + 1)
    }
  }
  out
}

// `nodes: auto` reads the injected spine, so a caller under rheo writes `walk()`
// while a test passes a literal tree.
#let walk(nodes: auto, stems: (), depth: 0) = {
  let nodes = if nodes == auto { spine() } else { nodes }
  _walk-inner(nodes, stems, depth)
}

// A title's text, for the comparison below and nothing else. `metadata-of` hands back
// real content rather than a string — a title can be formatted — so there is no
// `str()` that reaches it, and this walks the three shapes one ever takes.
#let plain(c) = {
  if type(c) == str { c } else if type(c) != content { "" } else if c.has("text") {
    c.text
  } else if c.has("children") {
    c.children.map(plain).fold("", (a, b) => a + b)
  } else if c.has("body") { plain(c.body) } else { "" }
}

// Case and punctuation dropped, so `cassirer.typ` and "Cassirer" compare equal —
// see the title rule in `tree.typ` for why that comparison is worth making.
#let key(s) = lower(s).trim("/").trim(".typ", at: end).replace(regex("[^a-z0-9]"), "")
