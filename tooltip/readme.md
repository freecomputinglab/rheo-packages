# tooltip

A Rheo plugin for adding tooltips with Typst.

## Usage

```typ
#import "@rheo/tooltip:0.1.0": tooltip, tooltip-modal, tooltip-content
```

## Exports

- **`tooltip(placement: "top-end", max-width: none, body)`** — Wraps content in a `<my-tooltip>` custom element with a placement attribute. When targeting HTML/EPUB, renders the element; otherwise passes content through. `max-width`, when given, is a CSS length string (e.g. `"480px"`, `"60vw"`) forwarded as the `max-width` attribute the web component reads to cap its popper box; the default (`none`) uses the component's own default width (360px).
- **`tooltip-modal(body)`** — Wraps content in a `<my-tooltip-modal>` custom element. Hidden entirely in non-HTML output. Can hold rich, multi-block content (headings, lists, math, figures) — see "Large previews" below.
- **`tooltip-content(body)`** — Wraps content in a `<my-tooltip-content>` custom element.

## Large previews and adaptive placement

The modal's content box caps at a max-width (360px by default, override via
`max-width:`) and scrolls vertically past 70% of the viewport height, so a
large preview (e.g. a whole note body) never overflows the page — it stays
interactive (scrollable, clickable) rather than clipping.

`placement: "auto"` (also `"auto-start"`/`"auto-end"`) is genuinely adaptive:
it flips across all four sides (top/bottom/left/right) to whichever has the
most room, and stays within the viewport rather than spilling off it. If the
content is too large to fit on ANY side even after flipping, it falls back to
a centered overlay with a dismissible backdrop instead of a popper that would
still clip. Explicit placements (`"top-end"`, etc.) are unaffected — they keep
their existing fixed behavior.
