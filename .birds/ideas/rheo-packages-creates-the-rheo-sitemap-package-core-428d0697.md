---
id: rheo-packages-creates-the-rheo-sitemap-package-core-428d0697
short-id: '4'
title: Creates the @rheo/sitemap package core
priority: 3
labels:
- sitemap-package
deps: []
closed: true
---
Touches: sitemap/0.1.0/typst.toml, sitemap/0.1.0/src/core.typ, sitemap/0.1.0/src/tree.typ, sitemap/0.1.0/src/lib.typ, sitemap/0.1.0/src/sitemap.css, sitemap/0.1.0/readme.md, sitemap/0.1.0/Justfile, sitemap/0.1.0/flake.nix, sitemap/0.1.0/.gitignore

# What and why

A new package, `@rheo/sitemap`, in this repository (`/home/lox/code/_fcl/rheo-packages`).
It becomes THE place spine-walking lives: this bird ports one working view into it and
establishes the shared data layer, and three later birds fold `@rheo/blogfeed` and
`@rheo/sidebar` into the same package so that all three views are built on one walk.

The view being ported already exists and works. It is a single-file vertebra in another
repository: `/home/lox/code/waterline/rookery/sitemap.typ` (172 lines), with its
stylesheet at `/home/lox/code/waterline/rookery/style.css` lines 902–1015 (the block
headed `Sitemap`, ending at line 1015; line 1016 begins the `Tables` block). READ BOTH
IN FULL before writing anything — they carry long comments recording measurements
(why the tree's rules are CSS borders on empty cells rather than box-drawing characters,
why a group node's name is read off the first path below it, why one page's title can
resolve wrong under a one-pass build). Those comments are the value of the port; carry
them across, adjusting only where the wording refers to waterline specifically.

Do NOT edit anything under `/home/lox/code/waterline` in this bird. That repository has
its own bird for adopting the package.

# The shape of the package

Buildless for now: pure Typst plus one stylesheet, no `package.json`, no vite, no
`dist/`. The repo's `CLAUDE.md` makes the built shape the default and asks for a reason
to go buildless — the reason here is that this bird ships no JavaScript at all, so there
is nothing for vite to bundle. A later bird (JS bundle wiring) adds `package.json`,
`vite.config.js` and the `js_scripts` keys once blogfeed's and sidebar's JS lands here.
Do not add them now.

# Steps

1. Create `sitemap/0.1.0/`.

2. `sitemap/0.1.0/typst.toml`, modelled on `blogfeed/0.1.1/typst.toml`:

   ```toml
   [package]
   name = "sitemap"
   version = "0.1.0"
   entrypoint = "src/lib.typ"
   authors = ["The Free Computing Lab <https://freecomputinglab.ohrg.org>"]
   license = "MIT"
   description = "Spine-derived views for Rheo projects: a tree(1)-style sitemap, and the shared spine walk behind it"
   repository = "https://github.com/freecomputinglab/rheo-packages"

   [tool.rheo.html]
   css_stylesheet = "src/sitemap.css"
   ```

   No `js_scripts` key and no `[tool.rheo.source.html]` table — there is no JS yet.

3. `sitemap/0.1.0/src/core.typ` — the shared spine layer, which is the part the later
   birds consume. It must work with NO rheo present (the repo `CLAUDE.md`'s "Pattern B —
   feature-detect"): read the context off `sys.inputs`, never assert, never panic.

   ```typ
   #let context-of() = sys.inputs.at("rheo-context", default: (spine: (), spine-flat: ()))
   #let spine() = context-of().at("spine", default: ())
   #let entries() = context-of().at("spine-flat", default: ())
   ```

   Then the path arithmetic, copied VERBATIM (comments included) from
   `sidebar/0.1.1/src/lib.typ` lines 33–54 — `_handle-path`, `_rel-prefix`,
   `_handle-url` — renamed without the leading underscore (`handle-path`,
   `rel-prefix`, `handle-url`) since they are public here. A handle's `:` segments are
   directories in the output, so `guide:intro` links to `guide/intro.html`; the
   `../` prefix arithmetic is what makes one nav correct on every page.

   Then the current page's handle, copied from `sidebar/0.1.1/src/lib.typ` lines
   117–127 (`_current-handle`), public here as `current-handle()`. It reads
   `state("rheo-handle")` with `.get()`, and returns `none` off rheo.

   Then the walk, ported from `/home/lox/code/waterline/rookery/sitemap.typ`:
   `first-path(node)`, `segment(node, depth)` (the `_first-path`/`_segment` pair,
   lines 25–43 there) and `walk(nodes, stems, depth)` (`_walk`, lines 53–65), all
   public. Give `walk` the signature `walk(nodes: auto, stems: (), depth: 0)` where
   `auto` means `spine()`, so a caller under rheo writes `walk()` and a test passes a
   literal tree. It returns a flat array of `(stems, last, node, depth)` dictionaries —
   keep that shape and the comment explaining why it is flat and why the closure returns
   an array rather than pushing to an outer binding.

   Finally the two content helpers from the same file: `plain(content)` (lines 70–77,
   `_plain`) and `key(str)` (line 81, `_key`).

4. `sitemap/0.1.0/src/tree.typ` — the view, ported from the `#context { ... }` block of
   `/home/lox/code/waterline/rookery/sitemap.typ` (lines 83–172), turned from a page
   body into a function:

   ```typ
   #let sitemap(ctx: none, root: ".") = context { ... }
   ```

   - `root` is the string on the tree's first row (`"."` in waterline).
   - `ctx` is optional and is the ONLY way the title column can be drawn. Pass it as
     `#sitemap(ctx: rheo-context())` from a vertebra. Rheo injects `rheo-context()` and
     `rheo-metadata` into each vertebra's own scope but NOT into an imported package's
     scope (a Typst function captures its definition scope), and
     `sys.inputs.rheo-context` carries no `metadata-of` — it is a function, and
     `sys.inputs` values are data. So with `ctx: none` the package CANNOT read page
     titles: render the tree with the file column only, silently, no assert and no
     panic. With a `ctx` given, take the title lookup from `(ctx.metadata-of)(handle)`
     exactly as the waterline original does, including the rule that a title is printed
     ONLY where `key(plain(title)) != key(segment)` — a title that merely restates the
     file name is noise down the whole tree.
   - Keep the paged-output branch (`target() != "html"`): the same tree set as `raw`
     with `│   `/`├── `/`└── ` character prefixes, since a PDF has no borders to stretch
     and no links to click.
   - Keep the long comment about the one page that reads the wrong title under a
     one-pass build and about `rheo compile --metadata-two-pass`, but rewrite its
     waterline-specific evidence (the `knuth.typ` measurement) as a general statement:
     a page whose `#show:` rule swallows its body swallows rheo's metadata beacon with
     it, and the query then resolves to the previous page's document title.

5. `sitemap/0.1.0/src/lib.typ` — the entrypoint, which only re-exports:

   ```typ
   #import "core.typ": context-of, current-handle, entries, handle-path, handle-url, key, plain, rel-prefix, segment, spine, walk
   #import "tree.typ": sitemap
   ```

   Later birds add one import line each here for `blogfeed` and `sidebar`. Keep this
   file to re-exports only so those edits stay one line apiece.

6. `sitemap/0.1.0/src/sitemap.css` — the block from
   `/home/lox/code/waterline/rookery/style.css` lines 902–1015, comments included, with
   one change: every `var(--x)` must gain a fallback, because waterline's variables do
   not exist in an arbitrary project. Use `var(--mono-font, ui-monospace, monospace)`,
   `var(--label-size, 0.85rem)`, `var(--edge, rgba(128, 128, 128, 0.4))`,
   `var(--text-color, inherit)`, `var(--muted-color, #666)`,
   `var(--heading-font, inherit)`. A project that defines those variables keeps its own
   look; one that does not still gets a readable tree.

7. `sitemap/0.1.0/Justfile`, modelled on `feeds/0.1.0/Justfile`'s buildless shape:
   a `default` recipe echoing that this is a pure-Typst package with nothing to build.
   Leave `demo`/`check` recipes to the later demo bird.

8. `sitemap/0.1.0/flake.nix` and `sitemap/0.1.0/.gitignore`: copy
   `blogfeed/0.1.1/flake.nix` and `blogfeed/0.1.1/.gitignore` and change only the
   package name where it appears.

9. `sitemap/0.1.0/readme.md`: what the package is, the `#import "@rheo/sitemap:0.1.0": sitemap`
   line, a worked `#sitemap(ctx: rheo-context())` call, and a section "Calling it as
   `#sitemap()`" giving the prelude recipe a rheo project uses to drop the argument at
   every call site:

   ```typ
   // in the project's `[spine] prelude` file
   #import "@rheo/sitemap:0.1.0": sitemap as _sitemap
   #let sitemap = _sitemap.with(ctx: rheo-context())
   ```

   Say plainly why the argument exists at all (step 4's scope rule) rather than
   presenting it as a style choice.

10. Register the package in the local Typst package cache so a project can resolve it,
    following `CLAUDE.md`'s "Local development against a live rheo project". Check by
    hand first — a downloaded copy in there wins silently over an edit:

    ```sh
    ls -la ~/.cache/typst/packages/rheo/sitemap/    # expect: no such directory
    mkdir -p ~/.cache/typst/packages/rheo/sitemap
    ln -s /home/lox/code/_fcl/rheo-packages/sitemap/0.1.0 ~/.cache/typst/packages/rheo/sitemap/0.1.0
    ```

    The link path must end in the version and must not already exist.

# Non-goals

- No blogfeed and no sidebar code here. Three later birds do that.
- No JavaScript, no `package.json`, no `vite.config.js`, no `dist/`.
- No demo project and no `check.sh` — a later bird adds them.
- No edits to any other package's files, to `CLAUDE.md`, or to the root `Justfile`.
- No edits in `/home/lox/code/waterline`.

# VERIFY

1. `cd /home/lox/code/_fcl/rheo-packages/sitemap/0.1.0 && just` prints the buildless
   notice and exits 0.
2. The entrypoint parses and the exports exist. From `sitemap/0.1.0`:

   ```sh
   printf '#import "/src/lib.typ": sitemap, walk, handle-url, segment, spine\n#let _ = assert.eq(type(walk), function)\n#let _ = assert.eq(handle-url("guide:intro"), "guide/intro.html")\n' > /tmp/sitemap-smoke.typ
   typst compile --features html --root . --format pdf /tmp/sitemap-smoke.typ /dev/null
   ```

   Exits 0. A missing export or a syntax error fails the compile with a line number.
3. The walk works on a literal tree with no rheo present. Compile a fixture that calls
   `walk(nodes: ((title: "a", handle: "a", path: "a.typ", children: ()), (title: "b", handle: none, path: none, children: ((title: "c", handle: "b:c", path: "b/c.typ", children: ()),))))`
   and asserts the result has 3 rows, that row 0 has `last: false`, and that
   `segment(row.node, row.depth)` for the group node is `"b/"`. Exits 0.
4. `rg -n 'var\(--[a-z-]+\)' src/sitemap.css` prints nothing — every variable has a
   fallback.
5. `ls -la ~/.cache/typst/packages/rheo/sitemap/0.1.0` shows a symlink to this
   directory.