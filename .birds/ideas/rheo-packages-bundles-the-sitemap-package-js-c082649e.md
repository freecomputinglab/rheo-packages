---
id: rheo-packages-bundles-the-sitemap-package-js-c082649e
short-id: c0
title: Bundles the sitemap package JS
priority: 3
labels:
- sitemap-package
deps:
- blocked-by:rheo-packages-folds-sidebar-into-rheo-sitemap-90a0faaf
closed: true
---
Touches: sitemap/0.1.0/package.json, sitemap/0.1.0/vite.config.js, sitemap/0.1.0/src/index.js, sitemap/0.1.0/typst.toml, sitemap/0.1.0/Justfile, sitemap/0.1.0/.gitignore

# What and why

`@rheo/sitemap` (`/home/lox/code/_fcl/rheo-packages/sitemap/0.1.0/`) now carries two
JavaScript files it does not yet ship: `src/blogfeed.js` (the tag-filter toggles) and
`src/sidebar.js` (the off-canvas drawer), copied in by the blogfeed and sidebar port
birds. This bird makes the package a BUILT package in this repo's usual shape, bundling
both into one `dist/lib.js` and declaring it in the manifest.

Two facts the shape rests on, both from this repo's `CLAUDE.md`:

- A built package's `entrypoint` and `css_stylesheet` point at `src/`, not `dist/` —
  vite copies them byte-identically, so the manifest names the originals — and `dist/`
  holds ONLY the built JS bundle. That is what lets the package be consumed straight off
  a git ref with no build step.
- `dist/` is gitignored; it is a build artifact.

Models: `blogfeed/0.1.1/` and `sidebar/0.1.1/` each have the exact four files being
written here. Read `blogfeed/0.1.1/package.json`, `blogfeed/0.1.1/vite.config.js`,
`blogfeed/0.1.1/typst.toml` and `blogfeed/0.1.1/Justfile` before starting. The one
difference is that both of those bundle a SINGLE entry and this package bundles two.

# Steps

1. `sitemap/0.1.0/src/index.js` — the single bundle entry, two lines plus a comment
   saying why it exists (vite's library mode takes one entry, and rheo's manifest names
   one `js_scripts` file, so the two behaviours are composed here rather than shipped
   separately):

   ```js
   import "./blogfeed.js";
   import "./sidebar.js";
   ```

   Both files are top-level side-effecting scripts, not modules exporting anything —
   check that they still behave when imported this way. `sidebar.js` queries
   `.sidebar`/`.topbar` at line 1–2 and `blogfeed.js` queries its own elements; a page
   that renders neither view must not throw. If either script dereferences a `null`
   query result at top level, guard it with an early return inside that file and say so
   in a comment. That guard is the only edit either JS file may receive.

2. `sitemap/0.1.0/package.json`, copied from `blogfeed/0.1.1/package.json` with
   `"name": "rheo-sitemap"` and `"version": "0.1.0"`. Same `build: vite build` script,
   same `packageManager` and `devDependencies` pins.

3. `sitemap/0.1.0/vite.config.js`, copied from `blogfeed/0.1.1/vite.config.js` with
   `entry: "src/index.js"`, `name: "RheoSitemap"`, `fileName: () => "lib.js"`,
   `formats: ["iife"]`, `outDir: "dist"`.

4. `sitemap/0.1.0/typst.toml` — add to the existing `[tool.rheo.html]` table, leaving
   `css_stylesheet = "src/sitemap.css"` exactly as it is:

   ```toml
   [tool.rheo.html]
   js_scripts = "dist/lib.js"
   css_stylesheet = "src/sitemap.css"

   [tool.rheo.source.html]
   js_scripts = ["src/index.js"]
   js_module = true
   ```

   (`[tool.rheo.source.html]` is what lets a source consumer — a project resolving the
   package off this working copy rather than a release — load the unbundled sources;
   both `blogfeed/0.1.1` and `sidebar/0.1.1` declare it.)

5. `sitemap/0.1.0/Justfile` — replace the buildless `default` notice with the build
   recipe the other built packages use:

   ```
   build:
       pnpm install
       pnpm run build
   ```

   Keep any other recipes already in the file.

6. `sitemap/0.1.0/.gitignore` — make sure it ignores `dist/`, `node_modules/` and
   `pnpm-lock.yaml` exactly as `blogfeed/0.1.1/.gitignore` does. Match that file; do not
   invent entries.

7. Check `.github/workflows/publish-packages.yml` needs no change: its per-package logic
   is "a `package.json` present means `pnpm install && pnpm run build`", so adding one
   here is sufficient on its own. If reading the workflow shows a hardcoded list of
   package names, add `sitemap` to it; if it discovers packages by walking directories,
   change nothing. Say which you found in the flight's own notes.

# Non-goals

- Do not merge, minify by hand, or otherwise rewrite the two JS files beyond the null
  guard in step 1.
- Do not rename any CSS class or any DOM id the scripts select on.
- Do not create a demo project or `check.sh` — the next bird does.
- Do not touch `blogfeed/0.1.1/` or `sidebar/0.1.1/`.

# VERIFY

1. `cd /home/lox/code/_fcl/rheo-packages/sitemap/0.1.0 && just build` exits 0 and
   `dist/lib.js` exists.
2. `rg -c 'sidebar-backdrop' dist/lib.js` and `rg -c 'filter-btn' dist/lib.js` both
   report a non-zero count — both scripts really are in the one bundle.
3. `rg -n 'dist/' typst.toml` shows `dist/lib.js` as the only `dist` path in the
   manifest, and `css_stylesheet` still reads `src/sitemap.css`.
4. `git check-ignore -q dist/lib.js`-equivalent check WITHOUT version control: `rg -n
   'dist' .gitignore` matches. (Do not run `git` or `jj`.)
5. The package still parses after the manifest edit: from `sitemap/0.1.0`,
   `typst compile --features html --root . --format pdf /tmp/sitemap-smoke.typ /dev/null`
   using a fixture that imports `sitemap`, `blogfeed` and `sidebar` from `/src/lib.typ`
   exits 0.