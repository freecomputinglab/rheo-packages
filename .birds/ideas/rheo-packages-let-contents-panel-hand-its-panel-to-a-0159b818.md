---
id: rheo-packages-let-contents-panel-hand-its-panel-to-a-0159b818
short-id: '01'
title: Let contents-panel hand its panel to a wrapper
priority: 3
labels:
- feat-horizontal-footnotes
deps: []
closed: false
---
Touches: contents-panel/0.1.1/src/lib.typ, contents-panel/0.1.1/src/contents.css, contents-panel/0.1.1/demo/rheo/content/wrapped.typ, contents-panel/0.1.1/demo/rheo/check.sh

## Goal

Let a caller of `@rheo/contents-panel`'s `contents` show rule hand the panel to a container of its own choosing, instead of the panel pinning itself with `position: fixed`. Every path below is relative to the repo root `/home/lox/code/_fcl/rheo-packages`.

The motivating consumer is a site built on `@rookery/core`. That package gains a `#gutter(body, sticky: true)` function, which floats a block into the right gutter of the idea cards and pins it with `position: sticky`. The site wants to write:

```
show: contents.with(wrap: gutter.with(sticky: true), reserve: none, breakpoint: none, ...)
```

so the contents panel sits at the top of that gutter and the margin notes are pushed below it. This package must NOT import or name `@rookery/core`. `wrap` is a plain function parameter.

## What exists (researched)

- `#let contents(` in contents-panel/0.1.1/src/lib.typ (`rg -n '#let contents\(' contents-panel/0.1.1/src`, one hit, ~479). Its params are `title, separator, title-of, depth-of, levels, numbered, top, breakpoint: "64rem", side: right, reserve: "body", offset-selector, align-selector, doc`. They are documented in the comment block just above (~441-478).
- The panel is emitted BEFORE the page body, inside a `context`. Anchor: `rg -n 'box-of\(r.all, r.ids, r.levels, heading-text\)' contents-panel/0.1.1/src` (one hit, ~759). It is followed by `body` and `region.step()`.
- `.rheo-panel-aside {` in contents-panel/0.1.1/src/contents.css (~152) is `position: fixed; top: var(--rheo-panel-top); right: var(--rheo-panel-right); width: var(--rheo-panel-width); z-index: 20;`.
- There is precedent for the panel going back into the flow inside a host that cannot hold a fixed element. The `[data-rookery="window"] .rheo-panel-aside {` rule (~305, `rg -n 'data-rookery="window"\] .rheo-panel-aside' contents-panel/0.1.1/src`) makes it `position: static; width: auto`.
- The JavaScript (`src/contents.js`) positions the panel ONLY while it is pinned. `pinned()` walks up from the aside looking for `position: fixed`, and `setTop()` returns early when that finds none. Scroll-spy and the active-row highlight run regardless. So a panel that is not fixed needs no JS change. Confirm with `rg -n 'function setTop' contents-panel/0.1.1/src/contents.js`.
- Demo and check: `cd contents-panel/0.1.1 && just check` builds, compiles `demo/rheo`, and runs `demo/rheo/check.sh`, which asserts on the built HTML.

## Steps

1. **Parameter.** Add `wrap: none` to `#let contents(` after `align-selector`. Document it in the comment block above: it is a function applied to the finished panel (the aside) before it is emitted, so a caller can place the panel in a container of its own. When given, the panel carries `data-rheo-panel-wrapped` and is not pinned.
   - Validate it: `none` or a function, else assert `@rheo/contents-panel: \`wrap\` must be none or a function — got …`.
   - If `wrap != none` and `reserve != none`, assert `@rheo/contents-panel: \`wrap\` and \`reserve\` cannot be combined — a wrapped panel is in the flow and reserves nothing; pass \`reserve: none\``.
2. **Emission.** At the `box-of(...)` call site, when `wrap` is a function, emit `wrap(<the aside>)` instead of the aside. Add the attribute `data-rheo-panel-wrapped: "wrapped"` to the aside element itself. `box-of` builds the aside, so thread a flag into it or add the attribute where the aside `html.elem` is built; locate it with `rg -n 'rheo-panel-aside' contents-panel/0.1.1/src/lib.typ`.
3. **CSS.** In contents.css, next to the window rule, add `.rheo-panel-aside[data-rheo-panel-wrapped] { position: static; width: auto; top: auto; right: auto; }`. Comment it: a wrapped panel is placed by its container, and the JS only positions a panel that is fixed.
4. **Demo.** Add `contents-panel/0.1.1/demo/rheo/content/wrapped.typ`, a page with three headings. It applies `contents.with(wrap: body => html.elem("div", attrs: (class: "demo-wrap"), body), reserve: none)`. Follow how the other demo pages import the package and apply the rule.
5. **Check.** Extend `demo/rheo/check.sh`. In the built `wrapped.html`:
   - (a) a `class="demo-wrap"` div directly contains the `rheo-panel-aside` element;
   - (b) that aside carries `data-rheo-panel-wrapped`;
   - (c) the page's contents links are still present.

   Pages without `wrap` must still have no `data-rheo-panel-wrapped` attribute.

## Non-goals

- Do not import, name or special-case `@rookery/core` or `data-rookery="gutter"`. The existing `[data-rookery="window"]` rule is the only rookery reference, and it stays.
- No JS changes unless step 3's claim about `setTop` turns out false. If it does, report it rather than rewriting the positioning logic.
- Do not change the default, unwrapped behaviour.

## VERIFY

1. `cd contents-panel/0.1.1 && just check` passes.
2. `rg -n 'wrap: none' contents-panel/0.1.1/src/lib.typ` finds the parameter.
3. `rg -n 'data-rheo-panel-wrapped' contents-panel/0.1.1/src/contents.css` finds the rule.