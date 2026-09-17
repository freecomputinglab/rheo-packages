---
id: rheo-packages-links-by-handle-label-not-hand-rolled-6ba5f39f
short-id: 6b
title: Links by handle label not hand-rolled hrefs
priority: 3
labels:
- sitemap-review
deps:
- blocked-by:rheo-packages-fixes-the-shadowed-spine-parameter-b4a1e95d
- blocked-by:rheo-packages-names-the-root-index-node-from-its-adbc04fb
- blocked-by:rheo-packages-scopes-and-prefixes-the-blogfeed-css-b015cd16
closed: true
---
Touches: sitemap/0.1.0/src/core.typ, sitemap/0.1.0/src/blogfeed.typ, sitemap/0.1.0/src/sidebar.typ

# What and why

`@rheo/sitemap` uses **two different strategies for the same job** — turning a spine handle
into a link — and the one used by two of its three views is the one rheo core's own
documentation warns against.

`sitemap/0.1.0/src/tree.typ` line 75 does it the contracted way:

```typ
html.elem("span", attrs: (class: "sitemap-name"), link(label(handle), seg))
```

`blogfeed.typ` line 136 and `sidebar.typ` lines 47 and 81 hand-roll the href instead, via
`core.typ`'s own string arithmetic (`sitemap/0.1.0/src/core.typ` lines 20-36):

```typ
#let handle-path(handle) = handle.replace(":", "/") + ".html"
#let rel-prefix(handle) = { ... range(depth).map(x => "../").join() }
#let handle-url(handle, from: none) = rel-prefix(from) + handle-path(handle)
```

CONFIRMED against the rheo core checkout at `/home/lox/code/_fcl/rheo` (v0.6.3):

- `rheo-link-rule(handle)` (`crates/core/src/typ/rheo.typ` lines 55-75) is installed as a
  `#show link:` rule on **every** spine `#document`, by
  `crates/core/src/reticulate/bundle_source.rs`. It rewrites `#link(<handle>)` into a
  per-format, depth-correct href at realization time, using `_rheo-href(from, target, ext)`
  (rheo.typ lines 49-53) — the same `../`-per-`:`-level arithmetic `rel-prefix` duplicates.
  It also validates the target against `_rheo-handles()` and strips `.typ` escape suffixes.
- `_rheo-href` is private and rheo ships **no public handle→URL function**, deliberately:
  `docs/link-rule.md` lines 52-63 say a package wanting a URL for a handle should emit
  `#link(<handle>)` and let the rule rewrite it.
- `docs/link-rule.md` lines 65-74 is a MEASURED warning against exactly what `core.typ`
  does: a package computing its own relative paths from handles produced **72 dead links**
  on a real site (`@rookery/core`'s state-based approach), fixed by going through the link
  rule. It also notes the rule is correct for content transcluded onto several pages at
  different depths, which a single `from:` handle computed once cannot be.
- The `.html` suffix is hardcoded. rheo's own extension is `sys.inputs.rheo-context.ext`,
  which is `"html"` **or `"xhtml"` for EPUB**, and absent for PDF. `rheo-link-rule` reads
  it; `handle-path` cannot.
- A spine node may be `synthesized: true` (an `auto_index`-minted page with no file), and
  the link rule handles those; the string arithmetic has no notion of them.

Today the `.html` hardcode does not bite, because `blogfeed()` and `sidebar()` both render
their markup only under `target() == "html"`. That is luck, not design, and it is exactly
the kind of latent breakage a one-line format change surfaces.

The obstacle, and why this needs care rather than a find-and-replace: `blogfeed()` needs
the href as an **attribute**, because it wraps the title and meta cells in one `<a>`
(`blogfeed.typ` lines 146-149), and `link(label(h))` returns content, not a string. The
answer is to invert the nesting — emit `link(label(e.handle))[...]` around the
already-built inner content instead of `html.elem("a", attrs: (href: ...))`. rheo's rule
rewrites the `link` into an `<a>` itself, so the rendered markup keeps its single anchor;
the `class: "sitemap-post-link"` attribute is the thing that cannot ride on a `link`, so
move that class onto a wrapping `span` inside the `li`.

`sidebar()` has the same shape and the same answer at `sidebar.typ` lines 208, 232, 251,
262, 279 and 286 (its `a`, `a-with-class` and topbar helpers).

Keep `handle-url` / `handle-path` / `rel-prefix` **exported but documented as the escape
hatch** rather than deleting them: `blogfeed()`'s `href:` parameter is public API, a caller
may pass their own, and `sitemap/0.1.0/readme.md` lines 99-103 already documents
`handle-url` as the new default. Deleting them is a bigger, later decision.

# Blocked on, and what those birds leave behind

- `Fixes the shadowed spine parameter in nav-from-context` — aliases `core.typ`'s `spine`
  import to `spine-of` inside `sidebar.typ`, because a `spine: auto` parameter shadowed it
  and `spine()` resolved to `auto`. Until that lands `sidebar()` panics on every call and
  this bird's VERIFY cannot run.
- `Names the root index node from the handle not the path` — rewrites `segment()`'s
  `index.typ` branch in `core.typ`. Same file; work on top of it.
- `Scopes and prefixes the blogfeed CSS` — renames blogfeed's emitted class names to
  `sitemap-post-*` / `sitemap-filter-*`. Same file; use whatever names it left.

# Steps

1. In `sitemap/0.1.0/src/core.typ`, leave `handle-path`, `rel-prefix` and `handle-url`
   defined and exported, but replace their comments with the reason they are no longer the
   default: rheo's `rheo-link-rule` is installed on every spine document and rewrites
   `#link(<handle>)` format- and depth-correctly, so these exist only for a caller passing
   an explicit `href:` or a project not under rheo. Cite
   `/home/lox/code/_fcl/rheo/docs/link-rule.md` and note the hardcoded `.html` as the
   reason not to reach for them under EPUB.

2. In `sitemap/0.1.0/src/blogfeed.typ`, change the `href:` parameter's default (line 136)
   from a URL-producing closure to `none`, meaning "let rheo's link rule resolve the
   handle":

   ```typ
   // `none` means: emit `#link(<handle>)` and let rheo's own `rheo-link-rule`
   // resolve it — format- and depth-correct, and validated against the spine.
   // Pass a closure to override with an explicit href string.
   href: none,
   ```

   Update the doc comment above (lines 122-124) to match.

3. Restructure the row body (lines 141-152) so the default path emits a `link` to the
   handle's label and the override path keeps the old `html.elem("a", ...)`:

   ```typ
   html.elem("ul", attrs: (class: "sitemap-post-list"))[
     #for e in rows {
       let li-attrs = (class: "sitemap-post-item")
       if data-tags != none { li-attrs.insert("data-tags", data-tags(e)) }
       let inner = {
         span("sitemap-post-title")[#title(e)]
         if meta != none { meta(e) }
       }
       html.elem("li", attrs: li-attrs)[
         #span("sitemap-post-link")[
           #if href == none { link(label(e.handle), inner) } else {
             html.elem("a", attrs: (href: href(e)), inner)
           }
         ]
       ]
     }
   ]
   ```

   The `sitemap-post-link` class moves from the anchor onto a wrapping `span`, because a
   `link` takes no class. Adjust the two `.sitemap-post-link` rules in
   `sitemap/0.1.0/src/sitemap.css` only if they use `a`-specific selectors; if they are
   plain class selectors they keep working on the `span`. Reading them is required — do
   not guess.

4. In `sitemap/0.1.0/src/sidebar.typ`, replace the hand-rolled urls. In
   `_flatten-descendants` (lines 39-55) and `nav-from-context` (lines 70-84), stop calling
   `handle-url(handle, from: from)` and carry the **handle** through instead, so the
   renderer can emit `link(label(...))`. Concretely: keep the `url:` key for a caller who
   passes an explicit `nav:` array (it is documented public API at lines 88-97), but add a
   `handle:` key alongside it and set `url: none` on the derived path.

5. In `sidebar()`'s renderer, at each of the six link sites (lines 208, 232, 251, 262, 279,
   286), emit `link(label(node.handle), body)` when the node carries a handle and
   `url: none`, and keep the existing `a(node.url)` / `a-with-class(...)` call when a `url`
   is present. For the `a-with-class` prev/next arrows the class must move onto a wrapping
   `span`, same as step 3, for the same reason.

6. The `from:` parameter of `nav-from-context` becomes unused on the derived path. Keep the
   parameter and keep honouring it when a caller passes `url`-bearing nodes, but note in its
   doc comment (lines 67-69) that it is now only consulted for explicitly-passed navs.

7. The `home-url` parameter (default `"/"`, `sidebar.typ` line 104) is an author-supplied
   absolute URL, not a handle. Leave it exactly as it is — it must stay an `a(home-url)`.

# Non-goals

- Do NOT delete `handle-path`, `rel-prefix` or `handle-url`, and do NOT remove them from
  `lib.typ`'s export list. They stay as the escape hatch.
- Do NOT change `sitemap/0.1.0/src/tree.typ` — it already links correctly.
- Do NOT touch `sitemap/0.1.0/src/sitemap.css` beyond the `.sitemap-post-link` /
  prev-next-arrow selector adjustments steps 3 and 5 require.
- Do NOT edit `sitemap/0.1.0/readme.md`. A separate bird owns it.
- Do NOT attempt to make `blogfeed()` or `sidebar()` render under EPUB or PDF. Both are
  `target() == "html"`-gated today and widening that is a separate decision.
- Do NOT change `home-url`.
- Do NOT bump the package version in `sitemap/0.1.0/typst.toml`.

# VERIFY

Run from `sitemap/0.1.0`. Note that `just check` only exercises `sidebar()` once the bird
`Points the demo at sitemap's own sidebar view` has landed; if it has not, VERIFY steps 3
and 4 below cover the feed only and that is expected.

1. `just check` exits 0 and prints `demo/rheo OK`. Its `THE FEED` section already asserts
   `post-link` hrefs are `["posts/second.html", "posts/first.html"]` from `posts.html`, and
   its `THE NAV` section already walks every nav href and fails on any that resolves to no
   file — so the existing assertions are the regression test for this change.
2. No hand-rolled href survives in the two ported views:

   ```sh
   rg -n 'handle-url' src/blogfeed.typ src/sidebar.typ
   ```

   must print nothing outside a comment.
3. Every anchor in the built feed page resolves to a real file:

   ```sh
   rg -o 'href="[^"]*\.html"' demo/rheo/build/html/posts.html
   ```

   and each printed path, resolved relative to `demo/rheo/build/html/`, exists on disk.
4. A nested page's links still carry a `../` prefix:
   `rg -o 'href="\.\./[^"]*"' demo/rheo/build/html/posts/first.html` prints at least one
   match — proving rheo's link rule is doing the depth arithmetic that `rel-prefix` used
   to.