// The injected spine-wide context, or an empty stand-in where there is no rheo.
// Read from `sys.inputs` rather than taken as a `ctx:` parameter, because it is
// spine-wide data rather than anything about the calling file — the same
// feature-detect pattern `@rheo/blogfeed` and `@rheo/sidebar` use.
#let context-of() = sys.inputs.at("rheo-context", default: (spine: (), spine-flat: ()))

// The spine tree, or an empty one where there is no rheo.
#let spine() = context-of().at("spine", default: ())

// The flat spine, or an empty one where there is no rheo.
#let entries() = context-of().at("spine-flat", default: ())

// NOT THE DEFAULT ANY MORE — kept as the escape hatch for a caller passing an
// explicit `href:`/`url:`, or a project not under rheo at all.
//
// Under rheo, every spine `#document` installs `rheo-link-rule` as a `#show
// link:` rule (rheo core's `crates/core/src/typ/rheo.typ`), which rewrites
// `#link(<handle>)` into a per-format, depth-correct href at realization
// time and validates the target against the spine — see
// `/home/lox/code/_fcl/rheo/docs/link-rule.md`. That is format- and
// depth-aware in a way this string arithmetic is not: `handle-path` hardcodes
// `.html`, which is wrong for EPUB's `.xhtml` and meaningless for a page with
// no separate file at all (a `synthesized: true` spine node). Prefer
// `link(label(handle))` and let the rule resolve it; reach for these only
// when there is no rheo build to install the rule, or a caller wants an
// explicit href string rather than a rewritten link.
//
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
// Also part of the escape hatch above — `rheo-link-rule` does this same
// arithmetic itself, correctly, whenever the rule is installed.
#let rel-prefix(handle) = {
  if handle == none { return "" }
  let depth = handle.split(":").len() - 1
  if depth == 0 { "" } else { range(depth).map(x => "../").join() }
}

// A tree node's URL as written on the page currently being rendered. Escape
// hatch — see the comment above `handle-path`.
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
//   `guide/`           a group node: a directory with no `index.typ`, which has no
//                      path of its own at all
//
// The last of those cannot be read off a descendant's PATH: a path carries the
// project's `content_dir` prefix (or lack of one) but the spine tree does not, so
// `segs.at(depth)` on a path picks up the wrong segment whenever the two disagree.
// MEASURED against rheo 0.6.3 with `content_dir` unset and pages under `content/`: a
// page at `content/guide/deep.typ` has path `content/guide/deep.typ` (three segments)
// but handle `guide:deep` (two segments), and the group node for `guide/` sits at tree
// depth 0 — `first-path(group).split("/").at(0)` gives `"content"`, not `"guide"`. A
// handle carries no such prefix and is depth-aligned with the tree by construction, so
// the group's name is read off a descendant's HANDLE instead: `first-handle(group)` is
// `"guide:deep"`, and `.split(":").at(0)` is exactly `"guide"`.
#let first-path(n) = {
  if n.path != none { return n.path }
  for k in n.children {
    let p = first-path(k)
    if p != none { return p }
  }
  none
}

// Same recursive shape as `first-path`, over `handle` instead of `path`.
#let first-handle(n) = {
  if n.handle != none { return n.handle }
  for k in n.children {
    let h = first-handle(k)
    if h != none { return h }
  }
  none
}

#let segment(n, depth) = {
  let p = first-path(n)
  if p == none { return "?" }
  let segs = p.split("/")
  if n.path == none {
    let h = first-handle(n)
    if h == none { "?/" } else { h.split(":").at(depth, default: "?") + "/" }
  } else if segs.len() > 1 and segs.last() == "index.typ" {
    // An index-folded node names its DIRECTORY, and the directory name has to come
    // off the handle, not the path: a path carries the project's `content_dir`
    // prefix and a handle does not, so `segs.at(segs.len() - 2)` reads `content`
    // for the site root's own `content/index.typ`. Same reason the group-node
    // branch above reads a handle — see the comment on `first-path`.
    let h = n.handle
    if h == none { segs.at(segs.len() - 2) + "/" } else {
      let parts = h.split(":")
      // A single-segment `index` handle IS the site root: rheo folds it into the
      // tree's own first row, so it has no directory of its own to name.
      if parts.len() == 1 and parts.last() == "index" { "." } else { parts.last() + "/" }
    }
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
