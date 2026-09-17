---
id: rheo-packages-corrects-the-stale-sitemap-readme-ecf51942
short-id: e
title: Corrects the stale sitemap readme
priority: 2
labels:
- sitemap-review
deps:
- blocked-by:rheo-packages-links-by-handle-label-not-hand-rolled-6ba5f39f
- blocked-by:rheo-packages-scopes-and-prefixes-the-blogfeed-css-b015cd16
- blocked-by:rheo-packages-derives-the-sidebar-nav-once-and-from-ce275be2
closed: false
---
Touches: sitemap/0.1.0/readme.md

# What and why

`sitemap/0.1.0/readme.md` opens with two statements that are both false, and they are the
first eight lines a reader sees:

```markdown
Spine-derived views for Rheo projects. This version ships one view, `sitemap`:
a `tree(1)`-style listing of the project's spine — one row per page, box rules
down the left, the file as the node and its title beside it — plus the shared
spine-walking layer (`core.typ`) that later views in this package build on.

Buildless: pure Typst plus one stylesheet, no JavaScript, no `dist/`.
```

The package ships **three** views — `sitemap`, `blogfeed` and `sidebar`, all exported from
`sitemap/0.1.0/src/lib.typ` — and the readme's own later sections ("Blog index" at line 71,
"Sidebar template" at line 111) document the other two, contradicting its own opening.

And it is **not** buildless. `sitemap/0.1.0/` carries a `package.json`, a
`pnpm-lock.yaml`, a `vite.config.js`, a `src/index.js` entry that imports
`src/blogfeed.js` and `src/sidebar.js`, and a `Justfile` whose `build:` recipe runs
`pnpm install && pnpm run build`. `sitemap/0.1.0/typst.toml` declares
`js_scripts = "dist/lib.js"`. This repo's `CLAUDE.md` ("Pure-Typst packages") makes that
distinction load-bearing: it governs what `.github/workflows/publish-packages.yml` does
per package, and it names `@rheo/feeds` as "currently the only buildless package left in
this repo" — a claim this readme's line 8 flatly contradicts for anyone reading only the
package.

The readme is otherwise accurate and well-written; this is an opening-paragraph fix plus
whatever the blocking birds below changed.

# Blocked on, and what each changed that the readme documents

- `Scopes and prefixes the blogfeed CSS` — renamed every class the blogfeed view emits to
  a `sitemap-post-*` / `sitemap-filter-*` prefix (`.post-list` → `.sitemap-post-list`,
  `.post-item` → `.sitemap-post-item`, `.post-title`, `.post-date`, `.post-tags`,
  `.post-link`, `.tag-label` → `.sitemap-tag-label`, `.filter-container`, `.filter-btn`,
  `.tooltip`, and `.post-item.hidden` → `.sitemap-post-hidden`), and moved the
  `--blogfeed-*` variables off `:root` onto the feed's own root elements. Read the final
  names out of `sitemap/0.1.0/src/sitemap.css` rather than trusting this list.
- `Links by handle label instead of hand-rolled hrefs` — changed `blogfeed()`'s `href:`
  default from `entry => handle-url(entry.handle, from: current-handle())` to `none`,
  meaning "emit `#link(<handle>)` and let rheo's own link rule resolve it".
  `handle-url` / `handle-path` / `rel-prefix` remain exported as the escape hatch for a
  caller passing an explicit `href:`. This supersedes the migration note currently at
  readme lines 99-103.
- `Derives the sidebar nav once and titles it from metadata` — added an **optional**
  `ctx:` parameter to `sidebar()` and to `nav-from-context()`. With it, nav and prev/next
  labels use pages' real `#set document(title: ...)`; without it they fall back to rheo's
  path-derived spine titles, as before. This qualifies the claim currently at readme lines
  124-128 that `sidebar()` "never took one".

# Steps

1. Rewrite `sitemap/0.1.0/readme.md` lines 3-8 so the opening says the package ships three
   spine-derived views — `sitemap` (a `tree(1)`-style listing), `blogfeed` (a dated post
   index) and `sidebar` (a book-style page shell) — over one shared spine-walking layer
   (`core.typ`). Keep the existing one-line description of the tree view.

2. Replace the "Buildless" line with an accurate one: the package ships Typst plus one
   stylesheet (`src/sitemap.css`) plus one JavaScript bundle built by vite into
   `dist/lib.js`, and `just build` must be run before a demo or test project will pick up
   a JS change. Note that `typst.toml`'s `entrypoint` and `css_stylesheet` point at `src/`
   and only the JS bundle lives in `dist/` — which is what lets the package be consumed
   straight off a git ref. That shape is described in this repo's `CLAUDE.md` under
   "Pure-Typst packages"; state it, do not just cross-reference it.

3. Update the "Blog index" section (lines 71-109) for the renamed classes. It currently
   names `<ul class="post-list">` at line 76; correct that and any other class it cites.

4. Replace the `href:` migration note at lines 99-103 with one describing the new default
   (`href: none` → rheo's link rule resolves the handle) and why it is better: rheo's
   `rheo-link-rule` is installed on every spine document, resolves per-format and
   per-depth, validates against the spine, and is correct for content transcluded onto
   pages at different depths. Say that `handle-url` is still exported for a caller passing
   an explicit `href:`.

5. Update the "Sidebar template" section (lines 111-142). Its claim that `sidebar()` takes
   no `ctx:` is now a default rather than an absolute: document the optional `ctx:`, what
   it buys (nav and arrow labels from pages' real document titles instead of path-derived
   stems), and that omitting it keeps the previous behaviour. Keep the existing
   `.rheo-sidebar-layout` migration note at lines 130-142 — it is still accurate.

6. Add a short migration note for the blogfeed class rename, in the same voice as the
   existing two: a project styling `.post-item` / `.tag-label` / etc. from its own
   stylesheet must move to the prefixed names, and say why the rename happened — one
   manifest carries one `css_stylesheet`, rheo links it into every page of every importing
   project, and rheo offers no per-package CSS scoping, so generic names like `.hidden`
   and `.tooltip` collided with any project that used them.

# Non-goals

- Do NOT edit any file other than `sitemap/0.1.0/readme.md`.
- Do NOT edit the repo-root `CLAUDE.md` or `readme.md`.
- Do NOT rewrite the sections that are already accurate: "Why `ctx:` and not an implicit
  read" (lines 25-34), "Calling it as `#sitemap()`" (lines 36-49) and "`core.typ`" (lines
  51-69) all still hold.
- Do NOT invent API that does not exist. Read the final signatures out of
  `sitemap/0.1.0/src/lib.typ`, `core.typ`, `tree.typ`, `blogfeed.typ` and `sidebar.typ`
  and document what is actually there.
- Do NOT bump the package version in `sitemap/0.1.0/typst.toml`.

# VERIFY

Run from `sitemap/0.1.0`:

1. `rg -n 'Buildless|ships one view|no JavaScript|no `dist/`' readme.md` prints nothing.
2. `rg -c 'blogfeed|sidebar' readme.md` reports a non-zero count and the opening paragraph
   (first 10 lines) names all three views: `head -10 readme.md` mentions `sitemap`,
   `blogfeed` and `sidebar`.
3. Every class name the readme cites exists in the stylesheet. For each `.foo` in
   `rg -o '`\.[a-z-]+`' readme.md`, `rg -q "\.foo" src/sitemap.css` succeeds.
4. `just check` still exits 0 and prints `demo/rheo OK` — this bird changes no code, so
   the check must be unaffected.