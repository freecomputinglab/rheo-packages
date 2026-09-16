---
id: rheo-packages-deprecates-blogfeed-and-sidebar-847b7ae7
short-id: '8'
title: Deprecates blogfeed and sidebar
priority: 2
labels:
- sitemap-package
deps:
- blocked-by:rheo-packages-folds-sidebar-into-rheo-sitemap-90a0faaf
closed: false
---
Touches: blogfeed/0.1.1/readme.md, sidebar/0.1.1/readme.md, CLAUDE.md, readme.md

# What and why

`@rheo/blogfeed` and `@rheo/sidebar` have been superseded: their code now lives in
`@rheo/sitemap` (`/home/lox/code/_fcl/rheo-packages/sitemap/0.1.0/`), which exports
`sitemap`, `blogfeed` and `sidebar` from one package built on one shared spine walk
(`sitemap/0.1.0/src/core.typ`). This bird writes that down in the four places a reader
looks, so nobody starts new work against the deprecated packages.

BOTH OLD PACKAGES STAY EXACTLY WHERE THEY ARE, at `blogfeed/0.1.1/` and
`sidebar/0.1.1/`, still released, still resolvable, still building. Nothing is deleted,
renumbered or rewritten — the only edit either package receives is a deprecation note at
the top of its own `readme.md`. Their `src/` is what `@rheo/sitemap` was ported from,
and that history should stay readable.

# Steps

1. `blogfeed/0.1.1/readme.md` — a `> **Deprecated.**` admonition immediately under the
   title, before any other prose. It must say: superseded by `@rheo/sitemap`, which
   exports `blogfeed` with the same API; this package is unchanged and keeps working;
   new projects should import `#import "@rheo/sitemap:0.1.0": blogfeed`; and the ONE
   behaviour difference a migrating project will notice — `@rheo/sitemap`'s `blogfeed`
   defaults `href:` to a url made relative to the page it is rendered on
   (`handle-url(entry.handle, from: current-handle())`), where this package's default
   `entry => entry.handle + ".html"` is correct only at the site root.

2. `sidebar/0.1.1/readme.md` — the same admonition, adapted: superseded by
   `@rheo/sitemap`, which exports `sidebar` with the same API and the same class names;
   `#import "@rheo/sitemap:0.1.0": sidebar` and `#show: sidebar.with(ctx: rheo-context())`
   are unchanged; the one difference is a wrapper class `.rheo-sidebar-layout` on the
   page shell, which scopes the layout rules so a project importing the package for
   `#sitemap()` alone is not restyled by them — it matters only to a project that
   overrode this package's CSS.

3. `CLAUDE.md` at the repo root — this is the file that most needs to stay true, because
   it is read as ground truth by every agent working here. Make these edits:

   - In the opening paragraph's inventory of packages, name `sitemap` and describe it as
     the consolidated spine-view package.
   - Add a short section (or extend the existing "Pattern: consuming the injected
     `rheo-context`" section) recording the consolidation: `@rheo/sitemap` owns the
     spine walk — `context-of()`, `spine()`, `entries()`, `walk()`, `segment()`,
     `handle-url()`, `current-handle()` in `sitemap/0.1.0/src/core.typ` — and any new
     view over the spine belongs there rather than in a package of its own. Note that
     `blogfeed` and `sidebar` are deprecated and why they were not deleted.
   - Record the constraint that drove the CSS scoping, since it will govern the next
     view added: a package manifest carries ONE `css_stylesheet`, so every view in this
     package shares `src/sitemap.css`, and rheo injects it into any project importing
     any part of the package. A view whose rules would restyle a page that never renders
     it must be scoped behind a wrapper class the view itself emits.
   - Only if reading it shows a stale claim: the "Pure-Typst packages" section says
     `@rheo/feeds` is "currently the only buildless package left in this repo". That is
     still true — `@rheo/sitemap` ships JS and is a built package — so check the sentence
     rather than assuming, and leave it alone if it reads correctly.

4. `readme.md` at the repo root — its usage example imports `@rheo/slides`. Leave that,
   and add `@rheo/sitemap` to whatever inventory of packages the file carries. If it
   carries none, add a one-line mention of the new package and nothing more; this file
   is short on purpose.

# Non-goals

- Do NOT delete, move or renumber `blogfeed/0.1.1/` or `sidebar/0.1.1/`, and do not
  touch their `src/`, `typst.toml`, `Justfile` or demos.
- Do not remove their entries from `~/.cache/typst/packages/rheo/` — projects still
  resolve them.
- Do not edit `.github/workflows/publish-packages.yml`.
- No code changes anywhere. This bird is documentation only.

# VERIFY

1. `rg -n -i 'deprecat' blogfeed/0.1.1/readme.md sidebar/0.1.1/readme.md` prints a hit in
   each, within the first 10 lines of each file.
2. `rg -n 'sitemap' CLAUDE.md readme.md` prints hits in both.
3. `rg -n 'css_stylesheet' CLAUDE.md` shows the one-stylesheet-per-package constraint is
   written down.
4. Nothing outside the four files changed: `ls blogfeed/0.1.1/src sidebar/0.1.1/src`
   lists the same files as before, and `cd sidebar/0.1.1 && just check` still exits 0.