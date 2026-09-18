# @rheo/sitemap

Spine-derived views for Rheo projects, all built on one shared spine-walking
layer (`core.typ`). This package ships three views:

- `sitemap` — a `tree(1)`-style listing of the project's spine: one row per
  page, box rules down the left, the file as the node and its title beside it.
- `blogfeed` — a dated post index derived from the spine ("Blog index" below).
- `sidebar` — a book-style page shell with a sidebar, topbar, and prev/next
  arrows ("Sidebar template" below).

Not buildless: the package ships Typst plus one stylesheet (`src/sitemap.css`)
plus one JavaScript bundle, built by vite from `package.json`/`src/index.js`
into `dist/lib.js`. `typst.toml`'s `entrypoint` and `css_stylesheet` point at
`src/`, and only the JS bundle lives in `dist/` — so `src/` alone is enough to
consume the package straight off a git ref, and `just build` is only needed to
produce `dist/lib.js` before a demo or test project will pick up a JS change.

## Usage

```typ
#import "@rheo/sitemap:0.1.0": sitemap

#sitemap(ctx: rheo-context())
```

`root` is optional and defaults to `"."`, the string printed on the tree's own
first row:

```typ
#sitemap(ctx: rheo-context(), root: "content/")
```

## Why `ctx:` and not an implicit read

Rheo injects `rheo-context()` and `rheo-metadata` into each vertebra's own
scope, but NOT into an imported package's scope — a Typst function captures
its definition scope, not the call site. And the spine-wide data this package
CAN read implicitly, via `sys.inputs.rheo-context`, carries no
`metadata-of`: that field is a function, and `sys.inputs` values are data.
So the only way `sitemap()` can print a page's title is if the caller hands
its own `rheo-context()` in as `ctx`. Pass `ctx: none` (or omit it) and the
tree still renders, file column only, silently — no assert, no panic.

## Calling it as `#sitemap()`

Passing `ctx: rheo-context()` at every call site is repetitive on a project
with the sitemap on several pages. Drop the argument once, in the project's
own prelude:

```typ
// in the project's `[spine] prelude` file
#import "@rheo/sitemap:0.1.0": sitemap as _sitemap
#let sitemap = _sitemap.with(ctx: rheo-context())
```

Every page that imports the prelude then calls `#sitemap()` with the title
column already wired up.

## `core.typ`

The shared spine layer other views in this package are built on:

- `spine()` / `entries()` — the injected spine tree / flat spine, or empty
  where there is no rheo.
- `handle-path`, `rel-prefix`, `handle-url` — a handle's output path and the
  `../` arithmetic that makes one nav correct from any page.
- `current-handle()` — the handle of the page being compiled, or `none`
  outside rheo.
- `walk(nodes: auto, stems: (), depth: 0)` — flattens a spine tree (the
  injected one by default, or a literal tree passed for a test) into an array
  of `(stems, last, node, depth)` rows, in the order a `tree(1)`-style view
  prints them.
- `plain`, `key` — a title's plain text, and a case/punctuation-insensitive
  key for comparing a title against a file segment.

All of it works with no rheo present: every accessor reads off `sys.inputs`
and falls back to an empty stand-in rather than asserting or panicking.

## Blog index

Ported from `@rheo/blogfeed` 0.1.1, now DEPRECATED in favour of this package.
`posts(ctx:)` returns dated spine vertebrae newest-first, each merged with its
resolved document metadata; `blogfeed(...)` renders them as a
`<ul class="sitemap-post-list">`. Like `sitemap()`, `blogfeed()` needs `ctx:
rheo-context()` — a package's scope cannot see rheo's per-vertebra injection,
and `metadata-of` is a function so it cannot travel through `sys.inputs`:

```typ
#import "@rheo/sitemap:0.1.0": blogfeed, date-cell, post-date

#blogfeed(ctx: rheo-context(), meta: e => date-cell(post-date(e).display("[month repr:long] [day padding:none], [year]")))
```

Drop the argument at every call site with the same prelude trick as
`#sitemap()` above:

```typ
// in the project's `[spine] prelude` file
#import "@rheo/sitemap:0.1.0": blogfeed as _blogfeed
#let blogfeed = _blogfeed.with(ctx: rheo-context())
```

`filter-bar`, `tags-cell`, `date-range` and `week-range` carry over unchanged.
`feed` is kept as an alias of `blogfeed` for callers migrating from
`@rheo/blogfeed`.

**Migration note:** `blogfeed`'s `href:` default is now `none`, meaning: emit
`#link(label(entry.handle))` and let rheo's own `rheo-link-rule` — installed
on every spine document — resolve it, per format and per depth, validated
against the spine. That is correct even for content transcluded onto pages at
different depths, which a hand-computed relative path is not. `handle-url`
(and `handle-path`/`rel-prefix`, the arithmetic it is built from) are still
exported for a caller that wants to pass an explicit `href:` instead.

**Migration note:** `posts()` now takes `ctx:` and asserts it is present — the
published `@rheo/blogfeed` read metadata straight off the spine entry
(`entry.metadata.at(...)`), which no longer exists under rheo 0.6.x. A row is
now a spine entry merged with its resolved metadata, so `entry.date` and
`entry.keywords` replace `entry.metadata.date` / `entry.metadata.keywords`.

**Migration note:** every class this view emits now carries a `sitemap-`
prefix — `.post-list` → `.sitemap-post-list`, `.post-item` →
`.sitemap-post-item`, `.post-title` → `.sitemap-post-title`, `.post-date` →
`.sitemap-post-date`, `.post-tags` → `.sitemap-post-tags`, `.post-link` →
`.sitemap-post-link`, `.tag-label` → `.sitemap-tag-label`,
`.filter-container` → `.sitemap-filter-container`, `.filter-btn` →
`.sitemap-filter-btn`, `.tooltip` → `.sitemap-filter-tooltip`, and a hidden
post item's marker class changed from `.post-item.hidden` to
`.sitemap-post-item.sitemap-post-hidden`. A project styling any of the old
names from its own stylesheet needs to move to the prefixed ones. The rename
happened because a package manifest carries one `css_stylesheet`, which rheo
links into every page of every project importing any view here, and rheo
offers no per-package CSS scoping — so generic names like `.hidden` and
`.tooltip` collided with whatever a host project already used them for.

## Sidebar template

Ported from `@rheo/sidebar` 0.1.1, now DEPRECATED in favour of this package.
Book-style site navigation: a sidebar, a topbar, and prev/next arrows, with
the nav built from the spine the same way `sitemap()` and `blogfeed()` read
it.

```typ
#import "@rheo/sitemap:0.1.0": sidebar

#show: sidebar.with(title: "My Book")
```

`sidebar()` reads the spine and the current page's handle straight off
`sys.inputs`/`state("rheo-handle")`, the same feature-detect route `core.typ`'s
own accessors use, so nothing needs threading through from the call site by
default. It also takes an **optional** `ctx:` (a `rheo-context()` handle):

```typ
#show: sidebar.with(title: "My Book", ctx: rheo-context())
```

With `ctx:`, the nav and the prev/next arrow labels prefer each page's own
authored `#set document(title: ...)` over rheo's path-derived spine title.
Omitting `ctx:` keeps the previous behaviour — labels fall back to the
path-derived spine title, exactly as before this parameter existed.

**Migration note from `@rheo/sidebar`:** same API, same class names
(`.sidebar`, `.topbar`, `.content`, `.nav-arrow`, …) and the same bundled
`sidebar.js`. One change: the rendered HTML now has an extra wrapper,
`div.rheo-sidebar-layout`, around the topbar/nav/content/arrows shell, and
every layout rule in `sitemap.css`'s sidebar block is scoped to it — so a
project that imports only `#sitemap()` or `#blogfeed()` no longer inherits
this template's page-shell rules. The package's CSS variables (`--sidebar-width`,
`--sidebar-bg`, `--border-color`, …) are now declared on
`body:has(.rheo-sidebar-layout)` rather than `:root`, because a wrapper class
can't scope a `:root` or `body` rule. If your project overrides these
variables in its own `:root`, re-check that the override still wins — the
package's declaration is no longer on `:root` and the specificity has
changed.
