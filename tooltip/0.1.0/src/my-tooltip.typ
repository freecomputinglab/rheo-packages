#let html-element(body, name: "div", hideOffTarget: false, attrs: (:)) = context {
    if target() == "html" or target() == "epub" {
      html.elem(name, attrs: attrs, body)
    } else {
      if hideOffTarget {
        []
      } else {
        body
      }      
    }
}

// `max-width`, when given, is forwarded verbatim as the `max-width` attribute
// (a CSS length string, e.g. "480px" or "60vw") the web component reads to
// cap its popper box — `none` (the default) omits the attribute entirely, so
// the component's own default width applies. Non-breaking: existing calls
// with no `max-width` argument are unaffected.
#let tooltip(placement: "top-end", max-width: none, body) = html-element(
  body,
  name: "my-tooltip",
  attrs: (placement: placement) + (if max-width == none { (:) } else { ("max-width": max-width) }),
)

#let tooltip-modal(body) = context {
  if target() == "html" or target() == "epub" {
    html.elem("my-tooltip-modal", attrs: (:), body)
  } else {
    [\{#body\}]
  }
}
#let tooltip-content(body) = html-element(body, name: "my-tooltip-content")
