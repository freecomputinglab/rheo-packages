---
id: rheo-packages-scopes-the-sidebar-css-to-a-wrapper-c073075b
short-id: c07
title: Scopes the sidebar CSS to a wrapper element
priority: 3
labels:
- sitemap-package
deps: []
closed: false
---
Touches: sitemap/0.1.0/src/sidebar.typ, sitemap/0.1.0/src/sitemap.css, sitemap/0.1.0/readme.md

# What and why

`@rheo/sitemap` (`/home/lox/code/_fcl/rheo-packages/sitemap/0.1.0/`) ships three views —
`sitemap()`, `blogfeed()` and `sidebar()` — and a Typst package manifest allows ONE
`css_stylesheet`, which rheo injects into any project that imports ANY part of the
package. So a project that imports the package only for `#sitemap()` currently receives
the whole `sidebar()` page template's layout: a `body` reset, a fixed topbar and
sidebar, content margins, and a `:root` block of generic variable names. That is a bug
for every consumer that is not a sidebar site, and it blocks the waterline project from
adopting the package at all.

The port bird that appended this CSS was told to scope it behind a wrapper class the
template already emitted, found that no such element exists, and correctly stopped
rather than restructuring the page on its own. Its finding is recorded in a banner
comment at `sitemap/0.1.0/src/sitemap.css` lines 352–377 — READ THAT COMMENT FIRST; it
names the options and this bird is the resolution of them.

The decision, made by the repository's owner: **add the wrapper element.** The template
gains one outer `div.rheo-sidebar-layout`, and the appended CSS is scoped to it.

# The two leaks, and how each is scoped

Read `sitemap/0.1.0/src/sitemap.css` from line 352 to the end of the file (821 lines
total) before editing. Everything below line 352 is the sidebar block. Two rules in it
target the page itself rather than any sidebar element, and a wrapper class cannot reach
either of them — a descendant class cannot scope a `body` or `:root` rule:

- `body { padding: 0; margin: 0; overflow-x: hidden; }` (around line 396)
- `:root { --sidebar-width; --topbar-height; --sidebar-bg; --border-color; --text-color;
  --accent-color; --arrow-bg; --arrow-color; --sidebar-link-color; --background-color; }`
  (around line 380). Note `--text-color`, `--border-color` and `--background-color`:
  generic names that will silently clobber a consuming project's own variables of the
  same name. This is the leak with the widest blast radius and the one least likely to
  be noticed.

So the scoping is a HYBRID, deliberately, and the readme and the banner comment must both
say so: the wrapper class carries everything it can reach, and these two page-level rules
are merged into one `body:has(.rheo-sidebar-layout)` rule. `:has()` is the only selector
that can make a `body` rule conditional on the template having rendered. It is supported
in every current browser; a browser without it gets an unstyled body reset and correct
variables everywhere else, which is a graceful degradation and not a broken page.

# Steps

1. `sitemap/0.1.0/src/sidebar.typ` — wrap the HTML branch. The `target() == "html"`
   branch (line 190 onward) emits, as siblings straight into the page body: an optional
   `<style>` element, `div.topbar`, `nav.sidebar`, `div.content`, and two
   `div.nav-arrows` (desktop and mobile). Wrap all of them EXCEPT the `<style>` element
   in one wrapper:

   ```typ
   div("rheo-sidebar-layout")[ ... the topbar, nav, content and both nav-arrows ... ]
   ```

   The file already has a `div(_class, ..body)` helper at line 4; use it. Leave the
   `html.elem("style")` emission (lines 191–194) outside the wrapper — it carries the
   `--accent-color` override and belongs at the top of the document.

   POSITIONING IS SAFE across this change and the comment you leave should say why: a
   plain `div` does not create a containing block for a `position: fixed` descendant,
   so `.topbar` and `nav.sidebar` keep positioning against the viewport. (A `transform`,
   `filter`, `perspective`, `will-change`, `contain: paint` or `backdrop-filter` on the
   wrapper WOULD create one — so the wrapper must carry no such property, now or later.)

   Do not change the `else` branch (paged/EPUB, lines 300–307). There is no wrapper
   there and none is wanted.

2. `sitemap/0.1.0/src/sitemap.css` — scope the sidebar block, from line 352 to the end
   of the file:

   a. Replace the `:root` variable block and the `body` reset with ONE rule:

      ```css
      body:has(.rheo-sidebar-layout) {
        --sidebar-width: 260px;
        /* ... every variable the `:root` block declared, values unchanged ... */
        padding: 0;
        margin: 0;
        overflow-x: hidden;
      }
      ```

      Keep every variable name and value exactly as it is — they are part of the
      published contract, and the readme tells projects to override them. Variables
      declared on `body` inherit to every descendant, including `.sidebar-backdrop`,
      which `sidebar.js` appends to `document.body` OUTSIDE the wrapper. Check that
      claim against the backdrop's own rules before relying on it.

   b. Prefix every remaining selector in the block with `.rheo-sidebar-layout `
      (descendant, with the space), including inside `@media` blocks — their bodies keep
      their rules, only the selectors change. The selectors needing it include
      `nav.sidebar` (around line 475), `[role="doc-endnotes"]` (around line 590), and
      every `.topbar*`, `.content`, `.nav-arrow*`, `.sidebar-*` and `.hamburger` rule.

   c. TWO EXCEPTIONS that must stay unprefixed, because the elements they style are not
      inside the wrapper: `.sidebar-backdrop` and `.sidebar-backdrop.visible`
      (`sidebar.js` creates that element and appends it to `document.body`). Leave both
      exactly as they are, and leave a one-line comment above them saying why they are
      the exception — otherwise the next reader will "fix" them.

   d. Do NOT rename any class. `sidebar.js` queries `.sidebar-toggle`, `.sidebar` and
      `.topbar` (lines 1–3 of `sitemap/0.1.0/src/sidebar.js`) and toggles `.hidden`,
      `.sidebar-open` and `.visible`. Those queries are unscoped `document.querySelector`
      calls, so they still find the elements inside the wrapper — but only if the class
      names are untouched.

   e. Replace the banner comment at lines 352–377 with one that states what was done and
      why the hybrid exists: one stylesheet per package, injected into every importer, so
      an unrendered view's rules must be inert; the wrapper carries what a class can
      reach; `body:has(.rheo-sidebar-layout)` carries the page reset and the variables,
      which no descendant class can. Keep the measurement that motivated it (the template
      emitted siblings with no outer element, so the wrapper is new as of this change).

3. `sitemap/0.1.0/readme.md` — in the `## Sidebar template` section, state the wrapper as
   a migration note for anyone coming from `@rheo/sidebar 0.1.1`: the rendered HTML now
   has one extra `div.rheo-sidebar-layout` around the shell, every layout rule is scoped
   to it, and the package's variables are declared on `body:has(.rheo-sidebar-layout)`
   rather than `:root`. A project that overrode those variables in its own `:root` should
   re-check that its override still wins, because the package's own declaration is no
   longer on `:root` and the specificity has changed.

# Honest uncertainty, and what is NOT verified here

There is no demo project in this package yet — a separate bird (`bd show 6`, "Adds the
sitemap demo and output check") adds one, and it is the bird that will assert on rendered
output. So VERIFY below is static: it proves the scoping was applied, not that a sidebar
site still LOOKS right. Do not add a demo here to close that gap; say in your report that
the visual check lands with bird `6`.

# Non-goals

- Do not touch `sidebar/0.1.1/` or `blogfeed/0.1.1/`.
- Do not rename a class, an id, or a CSS variable.
- Do not add `package.json`, `vite.config.js` or any `typst.toml` key — a separate bird
  (`bd show c0`) owns the JS bundle.
- Do not create a demo, a `check.sh`, or edit the `Justfile`.
- Do not scope the tree (`.sitemap*`) or blogfeed (`.post-*`, `.filter-*`) blocks. They
  are already narrow class selectors that match nothing in a project not rendering them.
- Nothing in `/home/lox/code/waterline`.

# VERIFY

1. The wrapper is emitted exactly once, and nothing else moved:
   `rg -c 'rheo-sidebar-layout' src/sidebar.typ` reports 1, and
   `rg -n 'html.elem\("style"\)' src/sidebar.typ` still shows that element in the
   `target() == "html"` branch above the wrapper.
2. The package still compiles. From `sitemap/0.1.0`, put the fixture INSIDE the project
   root (a `/tmp` path fails with "source file must be contained in project root" under
   `--root .`):

   ```sh
   printf '#import "/src/lib.typ": sidebar, sitemap, blogfeed\n#let _ = assert.eq(type(sidebar), function)\n' > smoke.typ
   typst compile --features html --root . --format pdf smoke.typ /dev/null && rm smoke.typ
   ```

   Exits 0.
3. No unscoped page-level rule survives in the sidebar block:
   `awk 'NR>=352' src/sitemap.css | rg -n '^(body|:root)\s*\{'` prints nothing, and
   `rg -c 'body:has\(\.rheo-sidebar-layout\)' src/sitemap.css` reports 1.
4. Every sidebar variable survived the move: `rg -n '\-\-sidebar-width|--topbar-height|--sidebar-bg|--border-color|--text-color|--accent-color|--arrow-bg|--arrow-color|--sidebar-link-color|--background-color' src/sitemap.css`
   finds all ten declared inside the `body:has(...)` rule.
5. The backdrop is still unscoped: `rg -n -B1 '^\.sidebar-backdrop' src/sitemap.css`
   shows the rule at the start of a line with the explanatory comment above it.
6. The other two blocks are untouched: `rg -c 'sitemap-row' src/sitemap.css` and
   `rg -c 'post-list' src/sitemap.css` both report the same non-zero counts they do
   before your edits (record both numbers before you start).