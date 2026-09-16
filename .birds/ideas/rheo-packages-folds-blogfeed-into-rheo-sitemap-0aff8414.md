---
id: rheo-packages-folds-blogfeed-into-rheo-sitemap-0aff8414
short-id: '0'
title: Folds blogfeed into @rheo/sitemap
priority: 3
labels:
- sitemap-package
deps:
- blocked-by:rheo-packages-creates-the-rheo-sitemap-package-core-428d0697
closed: false
---
Touches: sitemap/0.1.0/src/blogfeed.typ, sitemap/0.1.0/src/blogfeed.js, sitemap/0.1.0/src/sitemap.css, sitemap/0.1.0/src/lib.typ, sitemap/0.1.0/readme.md

# What and why

`@rheo/sitemap` (this repo, `/home/lox/code/_fcl/rheo-packages/sitemap/0.1.0/`) is being
made the one package that walks a Rheo spine. `@rheo/blogfeed` already derives a blog
index from the same spine, and is now DEPRECATED in favour of it: its code moves into
`@rheo/sitemap`, which exports `blogfeed` alongside `sitemap`.

`blogfeed/0.1.1/` is NOT to be modified, renumbered or deleted by this bird. It stays
exactly as released; a separate bird adds a deprecation note to its readme. This bird
only copies out of it.

The source is `/home/lox/code/_fcl/rheo-packages/blogfeed/0.1.1/src/` — `lib.typ` (129
lines), `blogfeed.css` (230 lines), `blogfeed.js` (83 lines). Read `lib.typ` in full
first.

# Steps

1. Copy `blogfeed/0.1.1/src/blogfeed.js` to `sitemap/0.1.0/src/blogfeed.js` byte for
   byte. No edits — the JS is wired up by a later bird.

2. Create `sitemap/0.1.0/src/blogfeed.typ` from `blogfeed/0.1.1/src/lib.typ`, keeping
   every comment, with exactly these changes:

   a. DELETE its local `rheo-context()` definition (line 32 there:
      `#let rheo-context() = sys.inputs.at("rheo-context", default: (spine-flat: ()))`)
      and its doc comment, and import the shared one instead. At the top of the file:

      ```typ
      #import "core.typ": entries, handle-url
      ```

      `core.typ`'s `entries()` returns `context-of().at("spine-flat", default: ())` —
      the same array `rheo-context().spine-flat` returned there, with the same absent-rheo
      fallback. Rewrite `posts()` to call `entries()`:

      ```typ
      #let posts() = {
        let dated = entries().filter(entry => post-date(entry) != none)
        dated.sorted(key: post-date).rev()
      }
      ```

      Leave `post-date` and `post-tags` (which read `entry.metadata`) untouched.

   b. Rename the exported `feed(..)` function to `blogfeed(..)`, and keep `feed` as an
      alias in `lib.typ` (step 4) so the old spelling still resolves. Nothing else about
      its signature or body changes.

   c. Its `href:` default is `entry => entry.handle + ".html"`, which is correct only
      from the site root — a nested page linking to `guide/intro` would need `../`.
      `core.typ` already has that arithmetic. Change the default to
      `entry => handle-url(entry.handle, from: current-handle())` (importing
      `current-handle` too), and keep a comment saying what changed and why: the old
      default silently produced broken links from any page below the root, and
      `handle-url` is the same function `sidebar` uses for the identical reason.
      This is the one behaviour change in this bird — state it in the readme (step 5).

3. Append blogfeed's stylesheet to `sitemap/0.1.0/src/sitemap.css`: the whole of
   `blogfeed/0.1.1/src/blogfeed.css`, comments included, under a banner comment
   matching the file's existing section-banner style, e.g.

   ```css
   /* ============================================
      Blogfeed — the spine-derived post list, ported from @rheo/blogfeed 0.1.1
      ============================================ */
   ```

   The package manifest allows ONE `css_stylesheet`, which is why the three views share
   this file rather than shipping one apiece. Do not rename any class: `.post-list`,
   `.post-item`, `.post-title`, `.post-date`, `.post-tags`, `.tag-label`, `.filter-btn`,
   `.filter-container` and the `--blogfeed-order-N` custom properties are all part of
   blogfeed's published contract and the bundled JS selects on them.

4. Add one import line to `sitemap/0.1.0/src/lib.typ`, keeping that file to re-exports
   only:

   ```typ
   #import "blogfeed.typ": blogfeed, blogfeed as feed, date-cell, date-range, filter-bar, post-date, post-tags, posts, tags-cell, week-range
   ```

5. In `sitemap/0.1.0/readme.md`, add a `## Blog index` section: the import line, a
   worked `#blogfeed(meta: e => date-cell(...))` call, the note that `feed` is an alias
   for callers coming from `@rheo/blogfeed`, and the changed `href:` default from step
   2c stated as a migration note.

# Non-goals

- Do not touch `blogfeed/0.1.1/` at all, and do not create a `blogfeed/0.1.2/`.
- Do not wire the JS into `typst.toml` — no `js_scripts` key, no `package.json`, no
  `vite.config.js`. A later bird does the whole bundle at once.
- Do not port sidebar; that is the next bird.
- No demo project or `check.sh` here.

# VERIFY

1. From `sitemap/0.1.0`, the entrypoint parses and both spellings export:

   ```sh
   printf '#import "/src/lib.typ": blogfeed, feed, posts, date-range, sitemap\n#let _ = assert.eq(type(blogfeed), function)\n#let _ = assert.eq(posts(), ())\n' > /tmp/blogfeed-smoke.typ
   typst compile --features html --root . --format pdf /tmp/blogfeed-smoke.typ /dev/null
   ```

   Exits 0. `posts()` returning `()` is the absent-rheo fallback working — a hard error
   here means `entries()` was wired wrong.
2. `date-range` still formats: a fixture asserting
   `date-range(datetime(year: 2026, month: 7, day: 13), datetime(year: 2026, month: 7, day: 19)) == "July 13–19, 2026"` compiles clean.
3. `rg -c 'post-list|filter-btn' src/sitemap.css` reports a non-zero count, and
   `rg -n 'sitemap-row' src/sitemap.css` still finds the tree block — the append did not
   overwrite.
4. `rg -n 'sys.inputs' src/blogfeed.typ` prints nothing — the only reader of
   `sys.inputs` in this package is `core.typ`.