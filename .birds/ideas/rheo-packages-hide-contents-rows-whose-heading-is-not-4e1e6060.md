---
id: rheo-packages-hide-contents-rows-whose-heading-is-not-4e1e6060
short-id: 4e
title: Hide contents rows whose heading is not rendered
priority: 3
labels:
- feat-horizontal-footnotes
deps: []
closed: true
---
Touches: contents-panel/0.1.1/src/contents.js, contents-panel/0.1.1/demo/rheo/content/hidden.typ, contents-panel/0.1.1/demo/rheo/check.sh

## Goal

`@rheo/contents-panel` lists a row for every heading its Typst side collects. A consuming package may hide some of those headings with CSS. The motivating case is `@rookery/core`: in its horizontal-citations mode, an idea's References block (whose `References` title is a real heading) is always emitted but `display: none`. So the panel shows a "References" row whose target is invisible. Clicking it scrolls nowhere, and the progress and active-row tracking treat an invisible section as if it were there. Every path below is relative to the repo root `/home/lox/code/_fcl/rheo-packages`.

The fix: at runtime, the panel hides every row whose target element is not rendered (it has no layout boxes), and re-checks on resize, since media queries can change what is rendered. Hidden rows take no part in active-row or progress tracking.

## What exists (researched)

- `contents-panel/0.1.1/src/contents.js`:
  - `const links = Array.from(aside.querySelectorAll(".rheo-contents-link"));` (~216) collects the rows;
  - the active-section and progress logic reads `links` and their targets (`data-level`, and the scrollY maths around ~243-300);
  - `function scrollTo(el)` (~302);
  - `window.addEventListener("resize", …)` (~331).

  Find how a link maps to its target element (by `href` fragment or a data attribute) by reading the code near ~216-260.
- The typst.toml `[tool.rheo.source.html]` block lists `src/contents.js` as an ES module (source mode), and `just build` bundles it to `dist/lib.js`. `cd contents-panel/0.1.1 && just check` builds, compiles `demo/rheo` and runs `demo/rheo/check.sh` (HTML assertions). The demo pages are `content/{frame,index,nested,plain,sections,side,wrapped}.typ`.
- If an XDG/cache redirect is needed for the demo build to use the checkout, follow what `just check` already does. If the package cache holds a stale copy, set `XDG_CACHE_HOME` to a scratch dir with a symlink `typst/packages/rheo/contents-panel/0.1.1 -> <flight>/contents-panel/0.1.1` for the command, and never modify ~/.cache.

## Steps

1. In contents.js, add `const rendered = (el) => el !== null && el.getClientRects().length > 0;`.
   - After collecting `links`, compute each link's target once.
   - Set `row.hidden = !rendered(target)` on the link's row element: the link itself, or its wrapper if rows are wrapped. Check the markup.
   - Filter the active and progress logic to visible rows only.
   - Re-run the visibility pass inside the existing resize handler, before the existing work.
   - Add a header-comment sentence stating the contract: a heading hidden by another package's CSS gets no row.
2. **Demo.** Add `demo/rheo/content/hidden.typ`: three headings, the second wrapped in `html.elem("div", attrs: (style: "display: none"), heading[Hidden])`, or placed after a `<style>` hiding it. Apply the contents rule as the other demo pages do.
3. **check.sh.** The static HTML still lists 3 rows for `hidden.html`; the JS is what hides one. Add a headless-Chromium assertion:
   - after load, exactly one `.rheo-contents-link` in `hidden.html` has a `hidden` row;
   - its text is "Hidden".

   Use `timeout 60 chromium --headless=new --disable-gpu --no-sandbox --window-size=1440,900 --virtual-time-budget=3000 --dump-dom <url>`, with an injected script that writes base64 JSON into `document.title`. The recipe is at /etc/nixos/home-manager/server/llms/examples/headless-chromium-layout-assert.md. Serve over `python3 -m http.server` if the page uses root-absolute URLs; otherwise file:// is fine. Stop the server afterwards.

## Non-goals

- No change to the Typst side or the row markup.
- Do not special-case `@rookery` or `data-rookery` anywhere.
- No change to pinning or `setTop`.

## VERIFY

1. `cd contents-panel/0.1.1 && just check` passes, including the new assertion.
2. `rg -n 'getClientRects' contents-panel/0.1.1/src/contents.js` finds the check.