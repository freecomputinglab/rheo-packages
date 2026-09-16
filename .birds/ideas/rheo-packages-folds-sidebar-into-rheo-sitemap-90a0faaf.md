---
id: rheo-packages-folds-sidebar-into-rheo-sitemap-90a0faaf
short-id: '9'
title: Folds sidebar into @rheo/sitemap
priority: 3
labels:
- sitemap-package
deps:
- blocked-by:rheo-packages-folds-blogfeed-into-rheo-sitemap-0aff8414
closed: true
---
Touches: sitemap/0.1.0/src/sidebar.typ, sitemap/0.1.0/src/sidebar.js, sitemap/0.1.0/src/sitemap.css, sitemap/0.1.0/src/lib.typ, sitemap/0.1.0/readme.md

# What and why

Third step of consolidating every spine-derived view into `@rheo/sitemap`
(`/home/lox/code/_fcl/rheo-packages/sitemap/0.1.0/`). `@rheo/sidebar` — the book-style
HTML/PDF/EPUB template whose nav is derived from the spine — is now DEPRECATED in favour
of it, and its code moves here so that its nav and the sitemap tree walk the same data
through one set of functions.

`sidebar/0.1.1/` is NOT to be modified, renumbered or deleted by this bird. It stays
exactly as released; a separate bird adds a deprecation note to its readme. This bird
only copies out of it.

The source is `/home/lox/code/_fcl/rheo-packages/sidebar/0.1.1/src/` — `lib.typ` (352
lines), `sidebar.css` (445 lines), `sidebar.js` (101 lines). Read `lib.typ` in full
first; it is the largest file in this port.

# Steps

1. Copy `sidebar/0.1.1/src/sidebar.js` to `sitemap/0.1.0/src/sidebar.js` byte for byte.
   No edits — the JS is wired up by a later bird.

2. Create `sitemap/0.1.0/src/sidebar.typ` from `sidebar/0.1.1/src/lib.typ`, keeping
   every comment, with exactly these changes:

   a. DELETE these five private helpers and their doc comments, which `core.typ`
      already carries verbatim (they were copied there by the package-core bird):
      `_rheo-ctx` (line 28), `_handle-path` (line 38), `_rel-prefix` (line 47),
      `_handle-url` (line 53), `_current-handle` (lines 117–127). Import the shared
      ones at the top of the file instead:

      ```typ
      #import "core.typ": current-handle, handle-url, spine
      ```

      Then replace every call site: `_handle-url(..)` becomes `handle-url(..)`,
      `_current-handle()` becomes `current-handle()`, and in `nav-from-context` the
      `_rheo-ctx().at("spine", default: ())` fallback becomes `spine()`. Grep for the
      underscored names afterwards to be sure none survives.

   b. Keep `_flatten-descendants` and `nav-from-context` where they are — they are
      sidebar's own two-level nav shape, not shared data, and the long comment
      explaining why a third level is flattened rather than dropped comes with them.

   c. Keep the `ctx:` assert on the template exactly as it is. Sidebar is a "Pattern A"
      consumer per this repo's `CLAUDE.md` — it needs the CURRENT file's handle — and
      the assert's message must keep pointing the user at applying
      `#show: sidebar.with(ctx: rheo-context())`. Update only the package name in that
      message, from `@rheo/sidebar` to `@rheo/sitemap`.

   d. Whatever the exported template is called in the original, export it here as
      `sidebar`.

3. Append sidebar's stylesheet to `sitemap/0.1.0/src/sitemap.css` — the whole of
   `sidebar/0.1.1/src/sidebar.css`, comments included, under a banner comment in the
   file's existing section-banner style.

   THEN SCOPE IT, which is the one piece of real design in this bird. The package
   manifest allows one `css_stylesheet` and rheo injects it into every project that
   imports ANY part of the package — so a project that only wants `#sitemap()` would
   otherwise have a whole page template's layout rules (body grid, topbar, off-canvas
   drawer) applied to it. Wrap the appended block so its rules only bite where the
   sidebar template is actually used:

   - Have the sidebar template emit a wrapper class `rheo-sidebar-layout` on the
     outermost element it already produces (it renders the page shell, so there is one
     — find it rather than adding a new element).
   - Prefix every appended selector that targets `body`, the page grid, or a bare
     element with `.rheo-sidebar-layout`. Selectors already scoped to a sidebar-specific
     class (`.sidebar`, `.topbar`, `.sidebar-backdrop`, `.sidebar-toggle`, …) can stay as
     they are — they match nothing in a project that never renders the template.
   - Media queries keep their bodies; only the selectors inside them change.
   - `sidebar.js` selects on `.sidebar`, `.topbar` and `.sidebar-toggle`
     (`sidebar/0.1.1/src/sidebar.js` lines 1–3) and creates `.sidebar-backdrop`. Do NOT
     rename any of those four classes, or the bundled JS stops finding them.

   Record the reasoning in the banner comment: one stylesheet per package, so an unused
   view's rules must be inert rather than merely unused.

4. Add one import line to `sitemap/0.1.0/src/lib.typ`, keeping that file to re-exports
   only:

   ```typ
   #import "sidebar.typ": nav-from-context, sidebar
   ```

   Add any other symbol `sidebar/0.1.1/src/lib.typ` exported and a consumer would call.

5. In `sitemap/0.1.0/readme.md`, add a `## Sidebar template` section: the import line,
   the `#show: sidebar.with(ctx: rheo-context())` application, why `ctx:` is required
   here when `#sitemap()` merely benefits from it, and a migration note for anyone
   coming from `@rheo/sidebar` — same API, same class names, one new wrapper class
   `.rheo-sidebar-layout` on the shell, which matters only to a project that overrode
   the package's CSS.

# Non-goals

- Do not touch `sidebar/0.1.1/` at all, and do not create a `sidebar/0.1.2/`.
- Do not wire the JS into `typst.toml` — the next bird does the whole bundle at once.
- Do not redesign the nav, extend it past two levels, or change any class name other
  than adding the wrapper in step 3.
- No demo project or `check.sh` here.

# VERIFY

1. From `sitemap/0.1.0`, the entrypoint parses and all three views export together:

   ```sh
   printf '#import "/src/lib.typ": sidebar, sitemap, blogfeed, nav-from-context\n#let _ = assert.eq(type(sidebar), function)\n#let _ = assert.eq(nav-from-context(spine: ()), ())\n' > /tmp/sidebar-smoke.typ
   typst compile --features html --root . --format pdf /tmp/sidebar-smoke.typ /dev/null
   ```

   Exits 0.
2. `nav-from-context` still builds the two-level shape from a literal tree: a fixture
   passing `spine: ((title: "Guide", handle: none, path: none, children: ((title: "Intro", handle: "guide:intro", path: "guide/intro.typ", children: ()),)),)`
   asserts the single returned node has `title: "Guide"`, no `id` key, and
   `items.at(0).url == "guide/intro.html"`. Compiles clean.
3. `rg -n '_handle-url|_rel-prefix|_current-handle|_rheo-ctx|_handle-path' src/sidebar.typ`
   prints nothing.
4. `rg -n 'sys.inputs' src/sidebar.typ` prints nothing — `core.typ` is the only reader.
5. `rg -c 'sitemap-row|post-list|\.sidebar' src/sitemap.css` shows all three view blocks
   present in the one stylesheet.