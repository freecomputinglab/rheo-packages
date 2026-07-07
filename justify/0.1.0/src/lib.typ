// rheo-justify: whole-document template for client-side Knuth-Plass
// justification of HTML output.
//
// Usage:
//   #import "@preview/justify:0.1.0": *
//   #show: template
//   #set par(justify: true)
//   Your text...
//
// On HTML export the template installs a `show par` rule that wraps every
// justified paragraph in `<p class="rheo-kp" data-...>`, forwarding the
// author's effective text/justification settings (read from `context`) to the
// client script (dist/lib.js), which performs the optimal line breaking. On any
// other target (PDF, EPUB) the document passes through untouched so Typst's own
// justification handles it — the output is byte-identical to not using the
// package. See issue rheo-packages-vhv.

// Set to `true` inside a `no-justify` block so the `show par` rule leaves that
// content to Typst's native justification.
#let _skip = state("rheo-kp-skip", false)

// Convert a relative length (`ratio + length`, e.g. `90% + 0pt`) to a plain
// object: the ratio as a fraction and the absolute part in points. The absolute
// part must be expressible in pt (no unresolved `em`); v1 justification bounds
// are ratio-based, so this holds in practice.
#let _rel-to-obj(r) = (ratio: r.ratio / 100%, length: r.length.pt())

// The package DEFAULT word-space bounds ("column 4" book-quality values), used
// when the author has not set `justification-limits`. Mirrors DEFAULT_LIMITS in
// src/limits.ts.
#let _package-default-spacing = (
  min: (ratio: 0.83, length: 0.0),
  max: (ratio: 1.5, length: 0.0),
)

// Typst's own built-in default word-space bounds (spacing 2/3 .. 3/2). When the
// author leaves `justification-limits` at this value we treat it as "unset" and
// substitute the package default instead.
#let _typst-default-spacing = (
  min: (ratio: 2 / 3, length: 0.0),
  max: (ratio: 1.5, length: 0.0),
)

// Serialize the `spacing` bounds of a justification-limits value to JSON. Only
// `spacing` (word spacing) is honored in v1; `tracking` (letter spacing) is
// deferred, so it is omitted and the client supplies its default (src/limits.ts).
#let _limits-json(spacing) = json.encode((spacing: spacing))

// Build the data attributes for one justified paragraph. Must be called inside
// a `context` block so the text/par fields resolve to their effective values.
#let _data-attrs(justification-limits) = {
  let spacing = if justification-limits != auto {
    (
      min: _rel-to-obj(justification-limits.spacing.min),
      max: _rel-to-obj(justification-limits.spacing.max),
    )
  } else {
    let limits = par.justification-limits
    let s = (
      min: _rel-to-obj(limits.spacing.min),
      max: _rel-to-obj(limits.spacing.max),
    )
    // Author left it at the Typst default -> use the package (column-4) default.
    if s == _typst-default-spacing { _package-default-spacing } else { s }
  }
  let font = text.font
  if type(font) == array { font = font.first() }
  (
    class: "rheo-kp",
    "data-justify": repr(par.justify),
    "data-font": font,
    "data-size": str(text.size.pt()) + "pt",
    "data-lang": text.lang,
    "data-hyphenate": repr(text.hyphenate),
    "data-justify-limits": _limits-json(spacing),
  )
}

// Opt a block out of client-side justification: it is wrapped in
// `<div class="rheo-kp-skip">` and its paragraphs are left to Typst.
#let no-justify(body) = context {
  if target() == "html" {
    _skip.update(true)
    html.elem("div", attrs: (class: "rheo-kp-skip"), body)
    _skip.update(false)
  } else {
    body
  }
}

#let template(justification-limits: auto, doc) = context {
  if target() == "html" {
    show par: it => context {
      if _skip.get() or not par.justify {
        it
      } else {
        html.elem("p", attrs: _data-attrs(justification-limits), it.body)
      }
    }
    doc
  } else {
    // PDF / EPUB: no marker, no show rule — Typst's native justification runs.
    doc
  }
}
