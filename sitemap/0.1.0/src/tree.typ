#import "core.typ": key, plain, segment, walk

/// Renders `spine()` (or `ctx.spine` where `ctx` supplies one) the way `tree(1)`
/// draws a directory: one row per page, box rules down the left, the file as the
/// node and its title beside it.
///
/// `root` is the string printed on the tree's own first row.
///
/// `ctx` is optional and is the ONLY way the title column can be drawn. Pass it
/// as `#sitemap(ctx: rheo-context())` from a vertebra. Rheo injects
/// `rheo-context()` and `rheo-metadata` into each vertebra's own scope but NOT
/// into an imported package's scope (a Typst function captures its definition
/// scope), and `sys.inputs.rheo-context` carries no `metadata-of` — it is a
/// function, and `sys.inputs` values are data. So with `ctx: none` this package
/// CANNOT read page titles: the tree renders with the file column only, silently
/// — no assert, no panic.
#let sitemap(ctx: none, root: ".") = context {
  let rows = walk()

  // A TITLE IS PRINTED ONLY WHERE IT SAYS SOMETHING THE FILE DOES NOT. `cassirer.typ`
  // is titled "Cassirer" and `deutsch.typ` "Deutsch" — a second column repeating the
  // first in sentence case is noise down the whole tree. What survives the test is
  // every title that was actually decided.
  let titled(n, seg) = {
    if ctx == none or n.handle == none { return none }
    let t = (ctx.metadata-of)(n.handle).at("title", default: none)
    if t == none or key(plain(t)) == key(seg) { none } else { t }
  }

  // THE RULES ARE CELLS, NOT CHARACTERS, and that is a browser fact rather than a
  // preference. MEASURED with `│`/`├──`/`└──` written as text: a box-drawing glyph is
  // drawn to the font's own height and not to the line BOX, so every point of leading
  // opens a hole and the vertical rule reads as a column of dashes — at 1.25 line
  // height and still at 1.05, which is already tighter than most prose. Worse, which
  // font draws them is a fallback question this package does not control: the reader's
  // monospace stack is whatever their system has, and the box block is not certain to
  // be in it.
  //
  // So one empty cell per level, and `sitemap.css` draws the strokes as BORDERS on
  // those cells. A border stretches to the row, so the rule is continuous at any line
  // height and identical in any font. The cost is that the tree's shape no longer
  // survives being copied out of the page as text — which the paged branch below is
  // the answer to.
  let rules(stems, last) = {
    for s in stems {
      html.elem("span", attrs: (class: if s { "sitemap-cell sitemap-stem" } else { "sitemap-cell" }), [])
    }
    html.elem("span", attrs: (class: "sitemap-cell " + if last { "sitemap-elbow" } else { "sitemap-tee" }), [])
  }

  // The same rules as characters, for a target with no stylesheet to draw them. `last`
  // is `none` on the root row, which hangs from nothing and takes no rules.
  let prefix(stems, last) = {
    if last == none { return "" }
    stems.map(s => if s { "│   " } else { "    " }).fold("", (a, b) => a + b)
    if last { "└── " } else { "├── " }
  }

  let row(stems, last, seg, handle, title) = {
    if target() != "html" {
      // Paged output has no borders to stretch and no links to click: the same tree,
      // set as one preformatted block, is as much as a PDF can carry.
      raw(prefix(stems, last) + seg)
      if title != none [ #title]
      linebreak()
      return
    }
    html.elem("div", attrs: (class: "sitemap-row"), {
      if stems.len() > 0 or last != none { rules(stems, last) }
      if handle == none {
        // A directory with no landing page. It is a real node in the tree and not a
        // page, so it is named and not linked.
        html.elem("span", attrs: (class: "sitemap-name sitemap-dir"), seg)
      } else {
        html.elem("span", attrs: (class: "sitemap-name"), link(label(handle), seg))
      }
      if title != none { html.elem("span", attrs: (class: "sitemap-title"), title) }
    })
  }

  let tree = {
    // `tree`'s own first line: the root the rest hangs from, and the one row with no
    // rules at all (`last: none`).
    row((), none, root, none, none)
    for r in rows {
      let seg = segment(r.node, r.depth)
      row(r.stems, r.last, seg, r.node.handle, titled(r.node, seg))
    }
  }

  if target() == "html" { html.elem("div", attrs: (class: "sitemap"), tree) } else { tree }
}

// ONE PAGE CAN READ THE WRONG TITLE UNDER A ONE-PASS BUILD, and it is the price of
// the read above. rheo appends the beacon `metadata-of` queries INSIDE the
// vertebra's own body, so a page whose `#show:` rule swallows its body swallows
// rheo's metadata beacon with it — and the query then resolves to whatever
// document title was set last, which is the page BEFORE it in the spine. A page
// whose `#show:` rule cuts its body into several notes (one per heading, say) is
// the shape that triggers this: its own `<title>` is correct, but this view's
// title column for it reads the previous page's title instead.
//
// `rheo compile --metadata-two-pass` fixes it, by compiling once more and
// resolving the beacons against the finished document. It is not the default
// because it doubles the build for the sake of one mistitled row; reach for the
// flag once a page like that exists in a given project.
