#import "core.typ": current-handle, spine as spine-of

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
        // `url: none` + `handle:` means: let the renderer emit
        // `link(label(handle))` and rheo's own link rule resolve it. `from:`
        // is no longer consulted here — see the comment on `nav-from-context`.
        url: none,
        handle: handle,
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
/// `from:` was the handle of the page the nav is being rendered ON, back when
/// every url here was computed by hand (`handle-url(..., from: from)`). The
/// derived path now carries a bare `handle:` per node instead and leaves
/// resolving it — depth included — to rheo's own `rheo-link-rule` at
/// `link(label(handle))` realization time, so `from:` is unused on that path.
/// It stays as a parameter, and is still honoured wherever a caller passes an
/// explicit, already-`url:`-bearing nav (see `sidebar()`'s `nav:` argument),
/// which this function does not itself produce.
#let nav-from-context(spine: auto, from: none) = {
  let spine = if spine == auto {
    spine-of()
  } else { spine }
  spine.map(node => {
    let handle = node.at("handle", default: none)
    let title = node.at("title", default: if handle == none { "" } else { handle })
    let items = _flatten-descendants(node, from: from)
    if handle == none {
      (title: title, items: items)
    } else {
      (id: handle, title: title, url: none, handle: handle, items: items)
    }
  })
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

  // Flatten all clickable items in nav order for prev/next computation. Each
  // flat entry carries BOTH `url` and `handle` — a node from an explicit
  // `nav:` array has a `url` and no `handle`; a node derived from the spine
  // (`nav-from-context`) has a `handle` and `url: none` — so the renderer
  // below picks whichever is present.
  let flatten(nav) = {
    let flat-items = ()
    for node in nav {
      let node-url = node.at("url", default: none)
      let node-handle = node.at("handle", default: none)
      let node-id = node.at("id", default: none)
      let node-items = node.at("items", default: ())
      if node-url != none or node-handle != none {
        flat-items = flat-items + ((id: node-id, title: node.title, url: node-url, handle: node-handle),)
      }
      for item in node-items {
        flat-items = flat-items + ((
          id: item.id,
          title: item.title,
          url: item.at("url", default: none),
          handle: item.at("handle", default: none),
        ),)
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
    let current = if current != none { current } else { current-handle() }
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
  let current = if current != none { current } else { current-handle() }
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

  // A prev/next arrow, either an explicit `url` (old `a-with-class` path) or
  // a spine-derived `handle` resolved through rheo's link rule. The class
  // cannot ride on `link()` itself, so it moves onto a wrapping `span` on the
  // handle path — same reason `blogfeed()` wraps its post link in a span.
  let link-arrow(page, cls, body) = if page.url != none {
    a-with-class(page.url, cls)[#body]
  } else {
    span(cls)[#link(label(page.handle), body)]
  }

  if target() == "html" {
    if accent-color != none {
      let css = ":root { --accent-color: " + accent-color + "; }"
      html.elem("style")[#css]
    }

    // Wrapper scopes sitemap.css's sidebar block (see banner comment there) to
    // this template's own markup, so a project importing only `sitemap()` or
    // `blogfeed()` never inherits the sidebar layout. A plain `div` creates no
    // containing block, so `.topbar`/`.sidebar` keep `position: fixed` against
    // the viewport — do not add `transform`/`filter`/`perspective`/
    // `will-change`/`contain: paint`/`backdrop-filter` to this wrapper.
    div("rheo-sidebar-layout")[
    #div("topbar")[
      #button("sidebar-toggle", "Toggle sidebar")[
        #span("hamburger")
      ]
      #a(home-url)[
        #div("topbar-title")[
          #if logo != none { logo } else { title }
        ]
      ]
    ]

    #nav-elem("sidebar")[
      #div("banner")[]
      #ul("sidebar-nav")[
        #for node in nav {
          let node-url = node.at("url", default: none)
          let node-handle = node.at("handle", default: none)
          let node-id = node.at("id", default: none)
          let node-items = node.at("items", default: ())
          let node-num = node.at("num", default: none)

          // Group vs. chapter is decided by `id`, not `url`: a derived
          // chapter now carries `url: none` and a `handle` instead, so `url`
          // alone can no longer tell a chapter from a group. A group never
          // has an `id` in either shape (explicit `nav:` or spine-derived).
          if node-id == none {
            // Group: non-clickable section header with child links
            li("section-label")[
              #span("section-title")[#node.title]
              #ul("subsection-nav")[
                #for item in node-items {
                  let item-num = item.at("num", default: none)
                  let item-url = item.at("url", default: none)
                  let item-handle = item.at("handle", default: none)
                  let class = if item.id == current { "active" } else { "" }
                  let item-body = [
                    #if item-num != none { span("chapter-num")[#item-num] }
                    #item.title
                  ]
                  li(class)[
                    #if item-url != none { a(item-url)[#item-body] } else { link(label(item-handle), item-body) }
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
            let node-body = [
              #if node-num != none { span("chapter-num")[#node-num] }
              #node.title
            ]
            li(top-class)[
              #if node-url != none { a(node-url)[#node-body] } else { link(label(node-handle), node-body) }
              #if node-items.len() > 0 {
                ul("subsection-nav")[
                  #for item in node-items {
                    let item-num = item.at("num", default: none)
                    let item-url = item.at("url", default: none)
                    let item-handle = item.at("handle", default: none)
                    let class = if item.id == current { "active" } else { "" }
                    let item-body = [
                      #if item-num != none { span("chapter-num")[#item-num] }
                      #item.title
                    ]
                    li(class)[
                      #if item-url != none { a(item-url)[#item-body] } else { link(label(item-handle), item-body) }
                    ]
                  }
                ]
              }
            ]
          }
        }
      ]
    ]

    #div("content")[#doc]

    #div("nav-arrows desktop-nav")[
      #if prev-page != none {
        link-arrow(prev-page, "nav-arrow prev-arrow", [
          #span("arrow-icon")[←]
          #span("arrow-text")[#prev-page.title]
        ])
      }
      #if next-page != none {
        link-arrow(next-page, "nav-arrow next-arrow", [
          #span("arrow-text")[#next-page.title]
          #span("arrow-icon")[→]
        ])
      }
    ]

    #div("nav-arrows mobile-nav")[
      #if prev-page != none {
        link-arrow(prev-page, "nav-arrow prev-arrow", [
          #span("arrow-icon")[←]
          #span("arrow-text")[Previous]
        ])
      }
      #if next-page != none {
        link-arrow(next-page, "nav-arrow next-arrow", [
          #span("arrow-text")[Next]
          #span("arrow-icon")[→]
        ])
      }
    ]
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
