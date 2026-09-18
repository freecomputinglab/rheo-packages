---
id: rheo-packages-names-the-root-index-node-from-its-adbc04fb
short-id: adb
title: Names the root index node from its handle
priority: 3
labels:
- sitemap-review
deps: []
closed: true
---
Touches: sitemap/0.1.0/src/core.typ, sitemap/0.1.0/demo/rheo/check.sh

# What and why

The sitemap tree prints the project's **content-directory name** as the label of the site
root's own landing page. MEASURED against real rheo 0.6.3, in
`sitemap/0.1.0/demo/rheo/build/html/index.html` after `rheo compile demo/rheo`:

```html
<span class="sitemap-name"><a href="./index.html">content/</a></span>
```

That row is `content/index.typ` — the site's front page — and it is labelled `content/`,
leaking the project's own directory layout into published output. It should read the
directory the node actually represents, which at the root is nothing the path can supply.

This is the **same defect** that the retired bird
`rheo-packages-fixes-the-group-node-name-in-segment-bb8e7db7` fixed, left unfixed in the
sibling branch of the same `if`. `segment()` in `sitemap/0.1.0/src/core.typ` lines 94-106
is:

```typ
#let segment(n, depth) = {
  let p = first-path(n)
  if p == none { return "?" }
  let segs = p.split("/")
  if n.path == none {
    let h = first-handle(n)
    if h == none { "?/" } else { h.split(":").at(depth, default: "?") + "/" }
  } else if segs.len() > 1 and segs.last() == "index.typ" {
    segs.at(segs.len() - 2) + "/"
  } else {
    segs.last()
  }
}
```

The `n.path == none` branch (a group directory with no landing page) was already moved off
the path and onto a descendant's handle, for the reason the comment on lines 63-74 gives:
a rheo spine **path** carries the `content_dir` prefix but a **handle** does not, so the
two are not depth-aligned. The `index.typ` branch on lines 101-102 still reads
`segs.at(segs.len() - 2)` off the path, and inherits the identical bug — for
`content/index.typ` that penultimate segment *is* `"content"`.

A handle is the reliable source here too. MEASURED on this demo with `content_dir` unset
and pages under `content/`:

- `content/index.typ` → handle `"index"` → `.split(":")` is `("index",)`, one segment, no
  directory name available at all. This is the **site root**, and rheo folds it into the
  tree's own root; it has no directory of its own to name.
- `content/posts/index.typ` → handle `"posts"` → `.split(":")` is `("posts",)`, and
  `.last()` is `"posts"`, giving `posts/` — which is what the current code also produces
  here (`segs.at(len-2)` on `content/posts/index.typ` is `"posts"`), so this case must not
  regress.

So the rule is: for an index-folded node, take the handle's **last** `:` segment and add a
trailing `/`; when the handle has only one segment AND that segment is the site root
(`"index"`), there is no directory to name and the row should print the tree's own root
string instead — use `"."`, matching `sitemap()`'s `root` default in
`sitemap/0.1.0/src/tree.typ` line 17.

Deriving the root-row label from `sitemap()`'s actual `root:` argument would be tidier but
is NOT wanted here: `segment()` has no access to it, threading it through changes
`segment`'s signature and `walk`'s row shape, and `"."` is already the default that
`tree.typ` line 84 prints on the tree's first row. Hardcoding `"."` keeps this bird to one
function.

# Steps

1. In `sitemap/0.1.0/src/core.typ`, replace the `else if` branch on lines 101-102 so the
   name comes off the node's own handle rather than its path:

   ```typ
   } else if segs.len() > 1 and segs.last() == "index.typ" {
     // An index-folded node names its DIRECTORY, and the directory name has to come
     // off the handle, not the path: a path carries the project's `content_dir`
     // prefix and a handle does not, so `segs.at(segs.len() - 2)` reads `content`
     // for the site root's own `content/index.typ`. Same reason the group-node
     // branch above reads a handle — see the comment on `first-path`.
     let h = n.handle
     if h == none { segs.at(segs.len() - 2) + "/" } else {
       let parts = h.split(":")
       // A single-segment `index` handle IS the site root: rheo folds it into the
       // tree's own first row, so it has no directory of its own to name.
       if parts.len() == 1 and parts.last() == "index" { "." } else { parts.last() + "/" }
     }
   }
   ```

   Keep the `n.path == none` branch above it exactly as it is.

2. In `sitemap/0.1.0/demo/rheo/check.sh`, delete the now-obsolete `KNOWN BUG` paragraph at
   lines 61-66 (it begins `# KNOWN BUG (out of scope for this bird` and ends
   `# — this assertion currently fails, reading "content/" instead of "guide/".`). That
   bug is fixed and the assertion below it now passes, so the comment misleads the next
   reader into thinking a passing check is a known failure. Leave the surrounding
   `dir_cells` assertions themselves untouched.

3. Still in `sitemap/0.1.0/demo/rheo/check.sh`, add an assertion that pins the new
   behaviour, immediately after the existing
   `if 'href="./guide/deep.html"' not in index:` block (around line 75):

   ```python
   # The site root's own landing page (content/index.typ) is the tree's first row.
   # No row may be labelled with the project's content directory — that is the
   # `content/` leak this assertion exists to catch.
   names = re.findall(r'<span class="sitemap-name(?: sitemap-dir)?"><a[^>]*>([^<]*)</span>', index)
   if any(n == "content/" for n in names):
       fail(f"index.html: a sitemap row is labelled 'content/' (got {names}) — is an index-folded node named from its path instead of its handle?")
   if "posts/" not in names:
       fail(f"index.html: no sitemap row labelled 'posts/' (got {names}) — did the index-folded directory name regress?")
   ```

# Non-goals

- Do NOT change `first-path`, `first-handle`, `walk`, or the `n.path == none` branch.
- Do NOT add a `root:` parameter to `segment()` or change `walk()`'s row shape.
- Do NOT touch `sitemap/0.1.0/src/tree.typ`, `blogfeed.typ`, `sidebar.typ`, or
  `sitemap.css`.
- Do NOT edit `sitemap/0.1.0/demo/rheo/content/` — the demo's pages are correct as they
  are, and moving the demo onto a different sidebar package is a separate bird.
- Do NOT bump the package version in `sitemap/0.1.0/typst.toml`.

# VERIFY

Run from `sitemap/0.1.0`:

1. `just check` exits 0 and prints `demo/rheo OK`, including the new assertions.
2. `rg -o 'sitemap-name"><a href="\./index\.html">[^<]*' demo/rheo/build/html/index.html`
   prints a row ending in `>.` — not `>content/`.
3. `rg -c 'KNOWN BUG' demo/rheo/check.sh` reports `1`, not `2` (the blogfeed one below is
   a separate bird's to remove).
4. `rg -o 'sitemap-name"><a href="\./posts\.html">[^<]*' demo/rheo/build/html/index.html`
   still prints a row ending in `>posts/` — the index-folded directory name did not
   regress.