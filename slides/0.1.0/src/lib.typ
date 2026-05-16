#let _slide-title = state("rheo-slide-title", none)

#let slide(title: auto, inline: false, body) = {
  if title != auto {
    _slide-title.update(title)
  }
  context if target() == "html" {
    let current = _slide-title.get()
    let attrs = if current != none { ("data-slide-title": current) } else { (:) }
    html.elem("section", attrs: attrs, body)
  } else {
    box(
      fill: rgb("#ff4444"),
      stroke: 2pt + rgb("#ff0000"),
      inset: (x: 8pt, y: 4pt),
      radius: 4pt,
      text(fill: white, weight: "bold", size: 0.9em)[SLIDE],
    )
    if inline { body }
  }
}

#let _themes = (
  "beige",
  "black",
  "black-contrast",
  "blood",
  "dracula",
  "league",
  "moon",
  "night",
  "serif",
  "simple",
  "sky",
  "solarized",
  "white",
  "white-contrast",
)

#let template(theme: "black", title: none, first-slide: none, doc) = {
  assert(theme in _themes, message: "Unknown slides theme: " + theme)
  assert(
    first-slide != none or title != none,
    message: "`template` requires `first-slide` or `title`",
  )
  if first-slide == none {
    first-slide = heading(level: 1, title)
  }
  let after-cover = if title != none { _slide-title.update(title) } else { [] }
  context if target() == "html" {
    html.elem(
      "div",
      attrs: (class: "reveal", "data-theme": theme),
      html.elem(
        "div",
        attrs: (class: "slides"),
        slide(first-slide) + after-cover + doc,
      ),
    )
  } else {
    slide(first-slide)
    after-cover
    doc
  }
}
