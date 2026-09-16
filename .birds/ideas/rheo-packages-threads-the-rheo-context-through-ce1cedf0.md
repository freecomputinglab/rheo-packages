---
id: rheo-packages-threads-the-rheo-context-through-ce1cedf0
short-id: ce
title: Threads the rheo context through blogfeed
priority: 4
labels:
- sitemap-package
deps: []
closed: false
---
Touches: sitemap/0.1.0/src/blogfeed.typ, sitemap/0.1.0/readme.md, sitemap/0.1.0/demo/rheo/content/posts/index.typ, blogfeed/0.1.1/readme.md

# What and why

`@rheo/sitemap`'s `blogfeed()` view cannot compile at all under rheo 0.6.3. It reads a
`metadata` key off each spine entry, and no such key exists:

```
#let post-date(entry) = entry.metadata.at("date", default: none)   // src/blogfeed.typ:25
#let post-tags(entry) = entry.metadata.at("keywords", default: ())  // src/blogfeed.typ:28
```

A `spine-flat` entry carries exactly `handle`, `path`, `title` and `synthesized` (rheo's
own `docs/contract.md`, the `spine-flat` row of its context table; the checkout is at
`/home/lox/code/_fcl/rheo`). So any page calling `blogfeed()` fails the whole build with
`dictionary does not contain key "metadata"`.

MEASURED, and the important part: this is INHERITED, not introduced by the port. The
published `@rheo/blogfeed 0.1.1` fails identically —
`cd blogfeed/0.1.1 && rheo compile demo` under rheo 0.6.3 errors at `src/lib.typ:119`,
`dictionary does not contain key "metadata"`. Some earlier rheo must have put document
metadata on the spine entries; 0.6.x does not. So this bird fixes a real bug rather than
a porting slip, and the deprecated package's readme should warn about it (step 4).

# How the data is actually reached

The same way `src/tree.typ` already reaches a page's title: through `metadata-of`, which
lives only on the per-vertebra `rheo-context()` and is a function, so it cannot travel
through `sys.inputs`. It is a dict FIELD, not a method — call it as
`(ctx.metadata-of)(handle)` — and it requires `#context`. The dict it returns holds the
resolved `date`, `keywords`, `title`, `author`, `description` for that handle, with any
key the page never set OMITTED entirely (never present as `none`).

So `blogfeed()` becomes a view that takes `ctx:`, exactly like `sitemap()` does, and for
the same reason.

# Steps

1. `sitemap/0.1.0/src/blogfeed.typ` — thread the context through:

   a. Give `posts()` the signature `posts(ctx: none)`. Build its rows by merging each
      spine entry with that entry's resolved metadata, so a row is flat:

      ```typ
      #let posts(ctx: none) = {
        assert(
          type(ctx) == dictionary and "metadata-of" in ctx,
          message: "@rheo/sitemap: blogfeed needs the per-file `rheo-context` injected by "
            + "Rheo, for the document dates it sorts on. Call it as "
            + "`#blogfeed(ctx: rheo-context())` and compile the project with Rheo "
            + "(https://rheo.ohrg.org).",
        )
        let meta = ctx.metadata-of
        entries()
          .map(e => e + meta(e.handle))
          .filter(e => post-date(e) != none)
          .sorted(key: post-date)
          .rev()
      }
      ```

      An assert rather than a silent empty list: a feed that renders nothing looks like
      a site with no posts, which is the failure mode this package should never ship
      quietly. This makes `blogfeed` a "Pattern A" view in this repo's `CLAUDE.md` terms,
      alongside `sidebar`'s own guard — say so in a comment.

   b. `post-date(entry)` becomes `entry.at("date", default: none)` and
      `post-tags(entry)` becomes `entry.at("keywords", default: ())`, reading the merged
      row from (a). Keep both public and keep their doc comments, noting that a row is
      now a spine entry merged with its resolved document metadata.

   c. Give `blogfeed()` a `ctx: none` parameter and pass it to `posts(ctx: ctx)` in the
      `entries == none` branch (currently `src/blogfeed.typ:119`, `let rows = if entries
      == none { posts() } else { entries }`). An explicitly passed `entries:` must still
      work with NO `ctx` — that is the escape hatch for a caller assembling its own rows,
      and the assert must not fire on that path. So the assert belongs in `posts()`, as
      written above, and not at the top of `blogfeed()`.

   d. `posts()` and `blogfeed()` both need `#context` to be in effect for `metadata-of`
      to resolve. `blogfeed()`'s body already opens with `context if target() == "html"`,
      so it is covered; `posts()` called directly by a project is not, so document in its
      doc comment that it must be called inside `#context`.

2. `sitemap/0.1.0/demo/rheo/content/posts/index.typ` — pass the context:
   `#blogfeed(ctx: rheo-context(), meta: ...)`, keeping whatever `meta:` cell it already
   uses. This is the page whose compile currently fails.

3. `sitemap/0.1.0/readme.md` — in the `## Blog index` section, show the `ctx:` argument in
   the worked example, say why it is needed (a package's scope cannot see rheo's
   per-vertebra injection, and `metadata-of` is a function so it cannot travel through
   `sys.inputs`), and note the same prelude trick the `#sitemap()` section already
   documents for dropping the argument at every call site. Record the two breaking
   changes for anyone migrating from `@rheo/blogfeed 0.1.1`: `posts()` now takes `ctx:`,
   and a row's date/tags are read off the row itself rather than a `metadata` sub-dict.

4. `blogfeed/0.1.1/readme.md` — add ONE sentence to the deprecation admonition already at
   the top of that file: this package does not build against rheo 0.6.x at all, because
   the spine entries it reads document metadata off no longer carry it, and the fix lives
   in `@rheo/sitemap`. Change nothing else in that package — no `src/` edit, no version
   bump, no new version directory.

# Non-goals

- Do not fix `blogfeed/0.1.1/src/`. It is deprecated and frozen; the readme sentence is
  the whole of its change.
- Do not touch `src/core.typ`. A second bird (`bd show` the "Fixes the group-node name"
  bird) owns a separate bug there, and `just check` will keep failing on that one after
  this bird lands — that is expected, and not yours to fix.
- Do not touch `src/tree.typ`, `src/sidebar.typ`, `src/sitemap.css` or the JS.
- Do not edit `demo/rheo/check.sh` or `demo/rheo/rheo.toml`.
- Nothing in `/home/lox/code/waterline`.

# VERIFY

1. The demo's feed page compiles. From `sitemap/0.1.0`:
   `just build && rheo compile demo/rheo` exits 0, where before this bird it failed with
   `dictionary does not contain key "metadata"`.
2. `demo/rheo/build/html/posts.html` (or `posts/index.html` — check which path the build
   actually writes, since rheo folds a directory's `index.typ` into the directory's own
   node) contains a `ul.post-list` with exactly two `li.post-item`, newest first.
3. The escape hatch still works with no context: a fixture inside the package root (NOT
   `/tmp` — that fails `--root .` with "source file must be contained in project root")
   calling `blogfeed(entries: ((handle: "a", title: "A", date: datetime(year: 2026, month: 1, day: 1)),))`
   with no `ctx:` compiles clean.
4. The missing-context case fails LOUDLY, not silently: a fixture calling
   `#context posts()` with no `ctx:` fails the compile with the assert's own message, and
   that message names `rheo-context()`.
5. `rg -n 'entry\.metadata|\.metadata\.at' src/blogfeed.typ` prints nothing.