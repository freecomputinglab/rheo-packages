// HTML element helpers
#let div(_class, ..body) = html.elem("div", attrs: (class: _class), ..body)
#let button(_class, _aria, ..body) = html.elem("button", attrs: (class: _class, aria-label: _aria), ..body)
#let ul(_class, ..body) = html.elem("ul", attrs: (class: _class), ..body)
#let li(_class, ..body) = html.elem("li", attrs: (class: _class), ..body)
#let a(_href, ..body) = html.elem("a", attrs: (href: _href), ..body)
#let a-with-class(_href, _class, ..body) = html.elem("a", attrs: (href: _href, class: _class), ..body)
#let nav-elem(_class, ..body) = html.elem("nav", attrs: (class: _class), ..body)
#let span(_class, ..body) = html.elem("span", attrs: (class: _class), ..body)

// ---- Building the nav from rheo's own spine -------------------------------
//
// Through 0.1.0 an author hand-wrote the whole `nav` array and passed `current`
// per page. Both are now derivable: rheo injects the spine as a TREE in
// `rheo-context`, and publishes the current page's handle as a state. So a
// project under rheo passes neither, and shapes its navigation by editing
// `rheo.toml` (`[spine] exclude`, `[[spine.section]]`) rather than by keeping a
// second copy of the site structure in Typst.
//
// The explicit `nav:` argument stays as an ESCAPE HATCH — a project not under
// rheo, or one wanting navigation that deliberately differs from the spine, is
// unaffected. Passing it skips everything here.

// The injected spine-wide context, or an empty stand-in where there is no rheo.
// Read from `sys.inputs` rather than taken as a `ctx:` parameter, because it is
// spine-wide data rather than anything about the calling file — the same
// feature-detect pattern `@rheo/rookery` and `@rheo/blogfeed` use.
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: (:))

// A handle's output path, measured FROM THE SITE ROOT.
//
// A handle's `:` segments are DIRECTORIES in the output, not part of the
// filename. MEASURED on rheo 0.6.0: a vertebra at `content/guide/intro.typ`
// has the handle `guide:intro` and is written to `guide/intro.html` — NOT
// `guide:intro.html`, which is what a naive `"./" + handle + ".html"` would
// link to and which exists nowhere on disk.
#let _handle-path(handle) = handle.replace(":", "/") + ".html"

// One `../` per `:` level of the CURRENT page's handle, so a link from a nested
// page reaches the site root before descending again.
//
// Needed because the sidebar renders the SAME nav on every page: a bare
// `guide/intro.html` works from the root and resolves to
// `guide/guide/intro.html` from inside `guide/`. rookery's `_rel-prefix` does
// the identical arithmetic for the identical reason.
#let _rel-prefix(handle) = {
  if handle == none { return "" }
  let depth = handle.split(":").len() - 1
  if depth == 0 { "" } else { range(depth).map(x => "../").join() }
}

// A tree node's URL as written on the page currently being rendered.
#let _handle-url(handle, from: none) = _rel-prefix(from) + _handle-path(handle)

// One spine tree node -> one nav node.
//
// TWO LEVELS ONLY, because that is what the renderer draws: a group or chapter
// at the top, its `items` beneath. The spine tree recurses to any depth, so
// anything DEEPER than the second level is flattened into the nearest
// second-level ancestor's `items` rather than dropped. Flattening loses the
// grouping; dropping would lose the page, and a page missing from the nav is
// the worse failure — a reader cannot reach what is not listed.
//
// Extending the renderer to arbitrary depth is the alternative and was not
// taken here: it changes the rendered markup and the stylesheet with it, which
// is a bigger change than this bead, and three-level spines are rare enough
// that flattening is a fair default until one exists to design against.
#let _flatten-descendants(node, from: none) = {
  let out = ()
  for child in node.at("children", default: ()) {
    let handle = child.at("handle", default: none)
    if handle != none {
      out += ((
        id: handle,
        title: child.at("title", default: handle),
        url: _handle-url(handle, from: from),
      ),)
    }
    // Recurse REGARDLESS of whether this child was itself clickable: a group
    // nested inside a chapter contributes its own children, not itself.
    out += _flatten-descendants(child, from: from)
  }
  out
}

/// Converts rheo's injected spine tree into the `nav` shape this package
/// renders.
///
/// Call it with no arguments under rheo — `nav-from-context()` reads the
/// context itself — or pass a tree explicitly to test it.
///
/// A node with `handle: none` is a GROUP: a non-clickable section header.
/// A node with a handle is a CHAPTER: a clickable top-level link.
/// Either way its descendants become `items`.
///
/// `from:` is the handle of the page the nav is being rendered ON, which every
/// url is made relative to. Omit it and the urls come out site-root-relative,
/// which is correct only at the root.
#let nav-from-context(spine: auto, from: none) = {
  let spine = if spine == auto {
    _rheo-ctx().at("spine", default: ())
  } else { spine }
  spine.map(node => {
    let handle = node.at("handle", default: none)
    let title = node.at("title", default: if handle == none { "" } else { handle })
    let items = _flatten-descendants(node, from: from)
    if handle == none {
      (title: title, items: items)
    } else {
      (id: handle, title: title, url: _handle-url(handle, from: from), items: items)
    }
  })
}

// The handle of the page being compiled, or `none` outside rheo.
//
// `state("rheo-handle")`, NOT a key on `rheo-context`: the injected context is
// spine-wide and identical on every page, so it cannot say which page this is.
// rheo publishes the per-page handle as a state in its `rheo-page-init`, and
// that is readable from package scope. MEASURED on rheo 0.6.0: `"index"` at the
// root and `"sub:page"` for a nested vertebra — the same strings the spine
// tree's `handle` fields carry, which is what lets `current` match by equality.
//
// `.get()`, not `.final()`: the question is which page this is, not where the
// document ends.
#let _current-handle() = {
  let h = state("rheo-handle").get()
  if type(h) == str { h } else { none }
}

/// Renders a book-style site with sidebar navigation, topbar, and prev/next arrows.
///
/// nav: array of nav nodes. Each node is either:
///   - A group (no `url`): `(title: "Section", items: ((id: "p1", title: "Page", url: "./p1.html"), ...))`
///     Renders as a non-clickable section header with indented child links.
///   - A chapter (has `url`): `(id: "ch", title: "Chapter", url: "./ch.html", items: (...))`
///     Renders as a clickable top-level link with optional child links.
///   Items at either level may include an optional `num` field for numbered display.
///
/// current: id string of the active page (matches `id` at any level in nav)
/// title: site/book title string, used for document title and topbar text
/// home-url: URL the topbar title links to (default "/")
/// logo: optional content shown in topbar instead of title text (e.g. image(...))
#let sidebar(
  nav: (),
  current: none,
  title: "",
  home-url: "/",
  logo: none,
  accent-color: none,
  doc,
) = {
  // `nav` and `current` both DEFAULT TO THE SPINE as of 0.1.1, so a project
  // under rheo passes neither and shapes its navigation in `rheo.toml`.
  //
  // An empty `nav` means "derive it" rather than "render nothing": an empty
  // sidebar is never what a caller wants, and it is what every 0.1.0 project
  // that forgot the argument already got. Passing a non-empty `nav` still wins
  // outright — the escape hatch for a project not under rheo, or one whose
  // navigation deliberately differs from its spine.
  // Both derivations need the CURRENT PAGE's handle — `current` obviously, and
  // `nav` because every url in it is written relative to the page it appears
  // on. Reading that handle needs context, so both are closures called from
  // inside the context blocks below rather than computed once out here.
  let explicit-nav = nav
  let nav-for(cur) = if explicit-nav.len() > 0 { explicit-nav } else {
    nav-from-context(from: cur)
  }

  // Flatten all clickable items in nav order for prev/next computation
  let flatten(nav) = {
    let flat-items = ()
    for node in nav {
      let node-url = node.at("url", default: none)
      let node-id = node.at("id", default: none)
      let node-items = node.at("items", default: ())
      if node-url != none {
        flat-items = flat-items + ((id: node-id, title: node.title, url: node-url),)
      }
      for item in node-items {
        flat-items = flat-items + ((id: item.id, title: item.title, url: item.url),)
      }
    }
    flat-items
  }

  // THE DOCUMENT TITLE IS SET INSIDE `context`, and that is load-bearing rather
  // than stylistic: resolving `current` from `state("rheo-handle")` requires
  // context, and the title depends on `current`. MEASURED that `set document`
  // works from inside a context block — the whole title machinery moved in here
  // so the active page can name itself without the author passing `current:`.
  context {
    let current = if current != none { current } else { _current-handle() }
    let flat-items = flatten(nav-for(current))

    let current-index = if current != none {
      flat-items.position(p => p.id == current)
    } else {
      none
    }

    let current-title = if current-index != none {
      flat-items.at(current-index).title
    } else { "" }

    let doc-title = if current-title != "" and title != "" {
      current-title + " | " + title
    } else if current-title != "" {
      current-title
    } else {
      title
    }
    set document(title: doc-title)
  }

  context {
  let current = if current != none { current } else { _current-handle() }
  let nav = nav-for(current)
  let flat-items = flatten(nav)

  let current-index = if current != none {
    flat-items.position(p => p.id == current)
  } else {
    none
  }

  let prev-page = if current-index != none and current-index > 0 {
    flat-items.at(current-index - 1)
  } else { none }

  let next-page = if current-index != none and current-index < flat-items.len() - 1 {
    flat-items.at(current-index + 1)
  } else { none }

  if target() == "html" {
    if accent-color != none {
      let css = ":root { --accent-color: " + accent-color + "; }"
      html.elem("style")[#css]
    }

    div("topbar")[
      #button("sidebar-toggle", "Toggle sidebar")[
        #span("hamburger")
      ]
      #a(home-url)[
        #div("topbar-title")[
          #if logo != none { logo } else { title }
        ]
      ]
    ]

    nav-elem("sidebar")[
      #div("banner")[]
      #ul("sidebar-nav")[
        #for node in nav {
          let node-url = node.at("url", default: none)
          let node-id = node.at("id", default: none)
          let node-items = node.at("items", default: ())
          let node-num = node.at("num", default: none)

          if node-url == none {
            // Group: non-clickable section header with child links
            li("section-label")[
              #span("section-title")[#node.title]
              #ul("subsection-nav")[
                #for item in node-items {
                  let item-num = item.at("num", default: none)
                  let class = if item.id == current { "active" } else { "" }
                  li(class)[
                    #a(item.url)[
                      #if item-num != none { span("chapter-num")[#item-num] }
                      #item.title
                    ]
                  ]
                }
              ]
            ]
          } else {
            // Chapter: clickable top-level item with optional child links
            let child-is-active = node-items.any(item => item.id == current)
            let top-class = if node-id == current {
              "active"
            } else if child-is-active {
              "active-parent"
            } else {
              ""
            }
            li(top-class)[
              #a(node-url)[
                #if node-num != none { span("chapter-num")[#node-num] }
                #node.title
              ]
              #if node-items.len() > 0 {
                ul("subsection-nav")[
                  #for item in node-items {
                    let item-num = item.at("num", default: none)
                    let class = if item.id == current { "active" } else { "" }
                    li(class)[
                      #a(item.url)[
                        #if item-num != none { span("chapter-num")[#item-num] }
                        #item.title
                      ]
                    ]
                  }
                ]
              }
            ]
          }
        }
      ]
    ]

    div("content")[#doc]

    div("nav-arrows desktop-nav")[
      #if prev-page != none {
        a-with-class(prev-page.url, "nav-arrow prev-arrow")[
          #span("arrow-icon")[←]
          #span("arrow-text")[#prev-page.title]
        ]
      }
      #if next-page != none {
        a-with-class(next-page.url, "nav-arrow next-arrow")[
          #span("arrow-text")[#next-page.title]
          #span("arrow-icon")[→]
        ]
      }
    ]

    div("nav-arrows mobile-nav")[
      #if prev-page != none {
        a-with-class(prev-page.url, "nav-arrow prev-arrow")[
          #span("arrow-icon")[←]
          #span("arrow-text")[Previous]
        ]
      }
      #if next-page != none {
        a-with-class(next-page.url, "nav-arrow next-arrow")[
          #span("arrow-text")[Next]
          #span("arrow-icon")[→]
        ]
      }
    ]
  } else {
    if target() == "paged" {
      set heading(numbering: "1.")
    }
    show raw.where(block: true): set block(fill: luma(250), stroke: 0.5pt + luma(200), radius: 2pt, inset: 8pt)
    doc
  }
  }
}
