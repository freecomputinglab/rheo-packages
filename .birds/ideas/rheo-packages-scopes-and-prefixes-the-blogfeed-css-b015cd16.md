---
id: rheo-packages-scopes-and-prefixes-the-blogfeed-css-b015cd16
short-id: b0
title: Scopes and prefixes the blogfeed CSS
priority: 3
labels:
- sitemap-review
deps:
- blocked-by:rheo-packages-names-the-root-index-node-from-its-adbc04fb
closed: false
---
Touches: sitemap/0.1.0/src/sitemap.css, sitemap/0.1.0/src/blogfeed.typ, sitemap/0.1.0/src/blogfeed.js, sitemap/0.1.0/demo/rheo/check.sh

# What and why

`@rheo/sitemap` ships one stylesheet for three views, and rheo links that stylesheet into
**every page of every project that imports any part of the package**. That constraint is
already recorded in this repo's `CLAUDE.md` ("Consolidation into `@rheo/sitemap`") and
CONFIRMED against rheo core: `crates/core/src/assets/mod.rs` emits a package's declared
`css_stylesheet` site-wide, rheo offers no per-package CSS namespacing, no shadow DOM and
no per-page opt-out, and package assets are purely additive to the project's own
`style.css`.

Two of the three views respect that. `sitemap`'s rules are all `.sitemap-*`-prefixed
(`sitemap/0.1.0/src/sitemap.css` lines 28-112). `sidebar`'s were scoped behind a
`.rheo-sidebar-layout` wrapper by the retired bird
`rheo-packages-scopes-the-sidebar-css-to-a-wrapper-c073075b` (lines 426-817).

**The blogfeed block was left unprefixed and unscoped** — `sitemap/0.1.0/src/sitemap.css`
lines 118-378. It ships these global selectors to every importing project:

`.filter-container`, `.filter-btn`, `.filter-btn .tooltip`, `.post-list`, `.post-item`,
`.post-item.hidden`, `.post-link`, `.post-title`, `.post-date`, `.post-tags`, `.tag-label`,
plus an unscoped `:root` block (line 125) declaring `--blogfeed-*` variables.

`.hidden` and `.tooltip` are the dangerous two: both are maximally generic names that any
project or any other package is likely to already use, and `.post-item.hidden` sets
`display: none`, so a collision silently hides content. `.post-title`, `.post-date` and
`.tag-label` are only slightly better.

The fix follows `sitemap`'s own precedent rather than `sidebar`'s: **prefix every class**,
because unlike the sidebar template — which owns the whole page shell and therefore needs
one wrapper element to scope a layout — the blogfeed is an inline component whose rules are
all local to its own elements. A prefix needs no wrapper and no `:has()`. Prefix with
`sitemap-post-` / `sitemap-filter-` to match the package name, keeping `.sitemap-` as the
one namespace the package owns.

Class names are part of a package's public surface, and callers style them. The blogfeed
view is a fresh port in an unreleased `0.1.0` and the classes it inherited came from
`@rheo/blogfeed 0.1.1`, so this is the last moment the rename is free. Note it as a
migration note in `sitemap/0.1.0/readme.md` — no, do NOT edit the readme here; a separate
bird (`Corrects the stale sitemap readme`) owns that file and is blocked on this one.

# Steps

1. In `sitemap/0.1.0/src/sitemap.css`, rename every selector in the blogfeed block (lines
   118-378, and the `@media (max-width: 600px)` block at line 330 which restyles the same
   classes):

   | old | new |
   |---|---|
   | `.filter-container` | `.sitemap-filter-container` |
   | `.filter-btn` | `.sitemap-filter-btn` |
   | `.tooltip` | `.sitemap-filter-tooltip` |
   | `.post-list` | `.sitemap-post-list` |
   | `.post-item` | `.sitemap-post-item` |
   | `.hidden` (only where it qualifies `.post-item`) | `.sitemap-post-hidden` |
   | `.post-link` | `.sitemap-post-link` |
   | `.post-title` | `.sitemap-post-title` |
   | `.post-date` | `.sitemap-post-date` |
   | `.post-tags` | `.sitemap-post-tags` |
   | `.tag-label` | `.sitemap-tag-label` |

   Leave the `.order-1` … `.order-6` click-order classes alone: they never appear
   unqualified, always as `.sitemap-filter-btn.active.order-N` or
   `.sitemap-tag-label.active.order-N`, so they cannot collide on their own. Leave the
   `.tag-<id>` per-tag classes alone too — those are author-supplied tag ids and renaming
   them would change the author-facing contract.

2. Still in `sitemap.css`, move the `:root` block at line 125 off `:root`. The `--blogfeed-*`
   variables are read only by blogfeed's own rules, so declare them on the feed's own root
   element instead:

   ```css
   .sitemap-post-list,
   .sitemap-filter-container {
     /* …the existing --blogfeed-* declarations, unchanged… */
   }
   ```

   Both selectors are needed because `filter-bar()` and `blogfeed()` render as siblings,
   not nested, so neither inherits from the other. The variables are consumed inside each
   subtree, so declaring them on both roots is sufficient. Keep the existing explanatory
   comment above the block and add one sentence saying why it is no longer on `:root`.

   MEASURED consequence worth knowing: two of these read host variables
   (`--blogfeed-text: var(--text-color, #1a1a1a)`, `--blogfeed-accent:
   var(--primary-color, #9abddc)`). On `:root` they resolve against `html`, where the
   sidebar block's own `--text-color` — declared on `body:has(.rheo-sidebar-layout)` at
   line 385 — is invisible. Moving them down into the feed's own subtree means they now
   *do* see it. That is a behaviour change and an improvement; do not try to preserve the
   old resolution.

3. In `sitemap/0.1.0/src/blogfeed.typ`, update every emitted class name to match. The
   sites are:
   - line 78 `span("post-date")` → `span("sitemap-post-date")`
   - line 82 `span("post-tags")` → `span("sitemap-post-tags")`
   - line 83 `span("tag-label tag-" + tag)` → `span("sitemap-tag-label tag-" + tag)`
   - line 105 `div("filter-container")` → `div("sitemap-filter-container")`
   - line 107 `button("filter-btn tag-" + t.id, ...)` →
     `button("sitemap-filter-btn tag-" + t.id, ...)`
   - line 141 `attrs: (class: "post-list")` → `"sitemap-post-list"`
   - line 142 `(class: "post-item")` → `"sitemap-post-item"`
   - line 146 `class: "post-link"` → `"sitemap-post-link"`
   - line 147 `span("post-title")` → `span("sitemap-post-title")`

4. In `sitemap/0.1.0/src/blogfeed.js`, update the four DOM queries and the one toggled
   class:
   - line 28 `querySelectorAll(".filter-btn")` → `".sitemap-filter-btn"`
   - line 31 `querySelectorAll(".post-item")` → `".sitemap-post-item"`
   - line 39 `tip.className = "tooltip"` → `"sitemap-filter-tooltip"`
   - line 50 `item.classList.toggle("hidden", !show)` →
     `toggle("sitemap-post-hidden", !show)`
   - line 57 `querySelectorAll(".tag-label")` → `".sitemap-tag-label"`
   - line 59-61: the `c.startsWith("tag-") && c !== "tag-label"` guard must become
     `c.startsWith("tag-")` alone, since the label class is no longer `tag-label` and so no
     longer needs excluding. Confirm by reading the loop that this is the only place the
     old name was special-cased.

5. Re-run the build so `dist/lib.js` picks up the JS change: `just build` from
   `sitemap/0.1.0`.

# Non-goals

- Do NOT touch the `.sitemap-*` tree rules (lines 28-112) or the `.rheo-sidebar-layout`
  block (lines 380-821) — both are already correctly namespaced.
- Do NOT edit `sitemap/0.1.0/readme.md`. A separate bird owns it.
- Do NOT edit `sitemap/0.1.0/src/core.typ`, `tree.typ`, or `sidebar.typ`.
- Do NOT rename the author-supplied `.tag-<id>` classes or the `.order-N` classes.
- Do NOT introduce a wrapper element for the blogfeed — prefixing is the chosen approach
  and a wrapper would change the emitted markup for no gain.
- Do NOT bump the package version in `sitemap/0.1.0/typst.toml`.

# VERIFY

Run from `sitemap/0.1.0`:

1. No unprefixed blogfeed selector survives in the stylesheet:

   ```sh
   rg -n '^\s*\.(post-|filter-|tag-label|tooltip|hidden)' src/sitemap.css
   ```

   must print nothing.

2. `rg -n '^:root' src/sitemap.css` must print nothing — no `:root` block remains.

3. `just check` exits 0 and prints `demo/rheo OK`. Note that `check.sh` asserts
   `<ul class="post-list">` and `<li class="post-item">` at its `THE FEED` section; those
   two assertions must be updated to the new names as part of this step, and that is the
   one edit to `check.sh` this bird may make.

4. The built feed page carries the new names and none of the old:

   ```sh
   rg -c 'sitemap-post-list' demo/rheo/build/html/posts.html   # 1
   rg -c 'class="post-list"' demo/rheo/build/html/posts.html   # 0
   ```

# Two stale comments in `check.sh`, to fix in the same flight

`sitemap/0.1.0/demo/rheo/check.sh` carries two comments that were true when written and
are now false. This bird already edits that file (VERIFY step 3 below), so correct them
here rather than leaving them to mislead the next reader.

1. **The file header, lines 8-12**, says:

   ```
   # Two of these assertions are currently known to fail against real rheo
   # 0.6.3 output, for reasons outside this demo/check — see the comments at
   # each one. They are asserted as the CORRECT behavior on purpose: an
   # assertion bent to match a bug would certify the bug instead of catching
   # it, which is the one thing this file exists to avoid.
   ```

   Both of those bugs are fixed and `just check` now passes in full. Delete the paragraph.
   Keep the sentence it contains about not bending an assertion to match a bug — that rule
   is still the point of the file — by rewriting the paragraph as a short standing note:
   an assertion here is asserted as the CORRECT behaviour, so a failure means the code is
   wrong, not that the assertion should be relaxed.

2. **The `KNOWN BUG` block at lines 88-95**, immediately under the `---- THE FEED ----`
   banner, says `blogfeed.typ`'s `post-date`/`post-tags` read `entry.metadata`, that
   `blogfeed()` "has no such parameter" for `ctx:`, and that "`just demo` fails to compile
   at all as soon as a page calls `blogfeed()`". All three are false now: `blogfeed.typ`
   line 40 defines `posts(ctx: none)` and asserts on it, `blogfeed()` takes `ctx:` at line
   129, `demo/rheo/content/posts/index.typ` calls `#blogfeed(ctx: rheo-context(), ...)`,
   and the demo compiles and passes. Delete the block. The assertions below it are correct
   and stay — only the comment goes.

   MEASURED: `rg -c 'KNOWN BUG' demo/rheo/check.sh` currently reports `1`, which is this
   block. After this change it must report `0`, which SUPERSEDES the older VERIFY step
   elsewhere in this bird expecting `1`.