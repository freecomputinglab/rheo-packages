# slides

A Rheo plugin for writing slides with Typst.

## Usage

```typ
#import "@rheo/slides:0.1.0": slide, template
```

## Exports

- **`slide(body)`** — Wraps content in a `<section>` element when targeting HTML. In other output formats, renders a red "SLIDE" badge.
- **`template(doc)`** — Wraps the document in a Reveal.js-compatible `<div class="reveal"><div class="slides">` structure when targeting HTML. In other formats, passes content through unchanged.
