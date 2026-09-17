---
id: rheo-packages-derives-the-sidebar-nav-once-and-from-ce275be2
short-id: ce2
title: Derives the sidebar nav once and from metadata
priority: 3
labels:
- sitemap-review
deps:
- blocked-by:rheo-packages-links-by-handle-label-not-hand-rolled-6ba5f39f
closed: false
---
Touches: sitemap/0.1.0/src/sidebar.typ

# What and why

Two defects in `sitemap/0.1.0/src/sidebar.typ`, sharing one fix: the sidebar nav labels
every page with its **filename**, not its title, and it derives the whole nav **twice** per
page.

## Nav labels are path-derived, never the document's own title

`nav-from-context` (lines 70-84) and `_flatten-descendants` (lines 39-55) take each nav
entry's label from the spine node's `title` field:

```typ
let title = node.at("title", default: if handle == none { "" } else { handle })
```

CONFIRMED against rheo core at `/home/lox/code/_fcl/rheo`
(`crates/core/src/reticulate/spine/serialize.rs` lines 84-138, and `docs/contract.md`):
a spine tree node carries exactly `title`, `handle`, `path`, `synthesized`, `children` —
and **`title` is path-derived only, never the page's `#set document(title: ...)`**. The
authored title lives solely behind a `query()`, reachable as
`(rheo-context().metadata-of)(handle)` or `rheo-metadata(handle)`.

MEASURED in `sitemap/0.1.0/demo/rheo/build/html/index.html`, the rendered nav is:

```html
<li class="active"><a href="index.html">Index</a></li>
<li class=""><a href="posts.html">Index</a>
```

Two entries both reading `Index`, because `content/index.typ` and `content/posts/index.typ`
both have the path-derived stem `index`. The prev/next arrow labels (lines 281, 288) take
the same strings, so the arrows read `Index` too. This is the defect `tree.typ`'s own
`titled()` already solves with its `ctx:` parameter and `(ctx.metadata-of)(n.handle)`
(`tree.typ` lines 24-28).

The fix is an **optional** `ctx:` parameter, not a required one. `sidebar()` is documented
as the one view that needs no `ctx:` (`sitemap/0.1.0/readme.md` lines 124-128), and the
path-derived title is a real fallback rather than an error — a nav labelled by filename is
worse than one labelled by title, but far better than a panic. So: when `ctx` is supplied,
prefer the metadata title and fall back to the node's own; when it is not, behave exactly
as today. That is this repo's Pattern B with an optional Pattern A upgrade, and it does not
break a single existing caller.

## The nav is derived twice per page

`sidebar()` opens **two** separate `context` blocks. The first (lines 147-169) resolves
`current`, calls `nav-for(current)` and `flatten(...)`, computes `current-index` and
`current-title`, and uses all of it for one thing: `set document(title: doc-title)`. The
second (lines 171-314) resolves `current` again, calls `nav-for(current)` again, calls
`flatten(...)` again, and recomputes `current-index` again — then renders.

So the full spine walk, the recursive `_flatten-descendants`, and the flatten run twice on
every page of every site. Adding metadata reads (above) would double the `query()` count
too, and rheo core's `docs/limitations.md` lines 72-82 is explicit that every metadata read
is a `query()` and is "the price of staying at a single bundle compile" — doubling them is
the wrong direction.

Both `flatten` (lines 126-140) and `_flatten-descendants` (lines 39-55) also build their
arrays by **reassigning a concatenation** in a loop:

```typ
flat-items = flat-items + ((id: node-id, title: node.title, url: node-url),)
out += ((id: handle, ...),)
```

Each iteration copies the whole array, which is quadratic in the number of pages. Typst's
`.push()` mutates in place; `core.typ`'s own `_walk-inner` (line 118) already uses it. The
`out += _walk-inner(...)` form for merging a recursive *result* is fine and should stay —
it is the per-element concatenation that is the problem.

Merging the two context blocks is safe: `sidebar.typ` lines 142-146 record that
`set document(title:)` was MEASURED to work from inside a context block, which is why the
title machinery was moved in there in the first place. One block can do both.

# Blocked on

`Links by handle label instead of hand-rolled hrefs`, which reworks the same two functions
— it stops `_flatten-descendants` / `nav-from-context` calling `handle-url(...)` and carries
a `handle:` key through instead, so the renderer can emit `link(label(...))` and let rheo's
own link rule resolve it. Work on top of the shape that bird leaves, not the shape quoted
above.

# Steps

1. Merge `sidebar()`'s two `context` blocks (lines 147-169 and 171-314) into one. Resolve
   `current`, derive `nav`, and run `flatten` **once**; then `set document(title: ...)` and
   render from the same bindings. Keep the explanatory comment at lines 142-146 about
   `set document` working inside `context`, and add a sentence saying the blocks were
   merged so the nav is derived once.

2. Add an optional `ctx: none` parameter to `sidebar()` (alongside `nav`, `current`,
   `title`, … at lines 99-107). Document it as optional: pass
   `#show: sidebar.with(ctx: rheo-context())` to label the nav with pages' real document
   titles; omit it and the nav falls back to rheo's path-derived spine titles. Do NOT
   assert on it — `sidebar()` must keep working with no `ctx`.

3. Add an optional `ctx: none` parameter to `nav-from-context` and `_flatten-descendants`,
   and in each, resolve a node's label as:

   ```typ
   // rheo's spine `title` is PATH-DERIVED — it is never the page's own
   // `#set document(title: ..)`. The authored title is only reachable through
   // `metadata-of`, which is a `query()` and so needs `#context` and a `ctx`
   // from the call site. Fall back to the spine title when there is no ctx.
   let spine-title = node.at("title", default: ...)
   let label-text = if ctx == none or handle == none { spine-title } else {
     (ctx.metadata-of)(handle).at("title", default: spine-title)
   }
   ```

   `nav-from-context` is public API (its doc comment is lines 57-69); add `ctx:` as a new
   keyword parameter defaulting to `none` so existing calls are unaffected.

4. Replace the per-element array concatenation with `.push()`:
   - `_flatten-descendants` line 44: `out += ((...),)` becomes `out.push((...))`. Leave
     line 52's `out += _flatten-descendants(child, ...)` as a concatenation — it merges a
     whole recursive result, which is the correct use.
   - `flatten` lines 133 and 136: `flat-items = flat-items + ((...),)` becomes
     `flat-items.push((...))`.

5. Call `(ctx.metadata-of)(handle)` **at most once per node**. If both the nav label and
   anything else need a node's metadata, read it into a local binding and reuse it. Every
   such call is a `query()`.

# Non-goals

- Do NOT make `ctx:` required, and do NOT add an `assert` for it. `sidebar()` working with
  no `ctx` is documented behaviour and the primary supported mode.
- Do NOT change the rendered class names or the markup structure (`.topbar`, `.sidebar`,
  `.content`, `.nav-arrow`, `.rheo-sidebar-layout`, …). This bird changes label *text* and
  internal derivation only.
- Do NOT touch `sitemap/0.1.0/src/sitemap.css`, `core.typ`, `tree.typ`, or `blogfeed.typ`.
- Do NOT edit `sitemap/0.1.0/readme.md`. A separate bird owns it.
- Do NOT edit `sitemap/0.1.0/demo/`. If the demo needs a `ctx:` added to exercise the new
  parameter, report that rather than doing it.
- Do NOT try to eliminate the metadata `query()` altogether. rheo's batch accessor
  `rheo-metadata-all()` exists but is marrow-root-only and is NOT callable from a vertebra
  — CONFIRMED at `/home/lox/code/_fcl/rheo/crates/core/src/typ/metadata.typ` line 60 and
  its comment. One query per node is the only route available from package scope.
- Do NOT bump the package version in `sitemap/0.1.0/typst.toml`.

# VERIFY

Run from `sitemap/0.1.0`:

1. `just check` exits 0 and prints `demo/rheo OK`.
2. Exactly one `context` block remains in `sidebar()`: `rg -c '^\s*context \{' src/sidebar.typ`
   reports `1`.
3. No per-element array concatenation remains in the two flatten helpers:

   ```sh
   rg -n 'flat-items = flat-items \+|out \+= \(\(' src/sidebar.typ
   ```

   prints nothing.
4. With no `ctx`, the nav still renders and still labels from the spine — compile the demo
   as it stands (`just demo`) and confirm
   `rg -c 'class="sidebar-nav"' demo/rheo/build/html/index.html` reports `1`.
5. With a `ctx`, a page's real document title reaches the nav. Temporarily add
   `ctx: rheo-context()` to the `sidebar.with(...)` call in
   `demo/rheo/content/_template.typ`, run `just demo`, and confirm that
   `rg -o '<a href="posts.html">[^<]*' demo/rheo/build/html/index.html` no longer prints
   `Index`. **Revert that temporary demo edit before finishing** — this bird does not own
   the demo.