# tooltip

A Rheo plugin for adding tooltips with Typst.

## Usage

```typ
#import "@rheo/tooltip:0.1.0": tooltip, tooltip-modal, tooltip-content
```

## Exports

- **`tooltip(placement: "top-end", body)`** — Wraps content in a `<my-tooltip>` custom element with a placement attribute. When targeting HTML/EPUB, renders the element; otherwise passes content through.
- **`tooltip-modal(body)`** — Wraps content in a `<my-tooltip-modal>` custom element. Hidden entirely in non-HTML output.
- **`tooltip-content(body)`** — Wraps content in a `<my-tooltip-content>` custom element.
