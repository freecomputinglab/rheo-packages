#let slide(inline: false, body) = {
  context if target() == "html" {
    html.elem("section", body)
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

#let template(theme: "black", first-slide: none, doc) = {
  assert(theme in _themes, message: "Unknown slides theme: " + theme)
  assert(first-slide != none, message: "`first-slide` is required")
  context if target() == "html" {
    html.elem(
      "div",
      attrs: (class: "reveal", "data-theme": theme),
      html.elem(
        "div",
        attrs: (class: "slides"),
        slide(first-slide) + doc,
      ),
    )
  } else {
    slide(first-slide)
    doc
  }
}
