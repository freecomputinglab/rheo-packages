// HTML element helpers
#let div(_class, ..body) = html.elem("div", attrs: (class: _class), ..body)
#let button(_class, _aria, ..body) = html.elem("button", attrs: (class: _class, aria-label: _aria), ..body)
#let ul(_class, ..body) = html.elem("ul", attrs: (class: _class), ..body)
#let li(_class, ..body) = html.elem("li", attrs: (class: _class), ..body)
#let a(_href, ..body) = html.elem("a", attrs: (href: _href), ..body)
#let a-with-class(_href, _class, ..body) = html.elem("a", attrs: (href: _href, class: _class), ..body)
#let nav-elem(_class, ..body) = html.elem("nav", attrs: (class: _class), ..body)
#let span(_class, ..body) = html.elem("span", attrs: (class: _class), ..body)

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
  // Flatten all clickable items in nav order for prev/next computation
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

  let prev-page = if current-index != none and current-index > 0 {
    flat-items.at(current-index - 1)
  } else { none }

  let next-page = if current-index != none and current-index < flat-items.len() - 1 {
    flat-items.at(current-index + 1)
  } else { none }

  context if target() == "html" {
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
    context if target() == "paged" {
      set heading(numbering: "1.")
    }
    show raw.where(block: true): set block(fill: luma(250), stroke: 0.5pt + luma(200), radius: 2pt, inset: 8pt)
    doc
  }
}
