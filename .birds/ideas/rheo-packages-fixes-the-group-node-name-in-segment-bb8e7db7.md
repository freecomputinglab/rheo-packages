---
id: rheo-packages-fixes-the-group-node-name-in-segment-bb8e7db7
short-id: bb
title: Fixes the group-node name in segment
priority: 3
labels:
- sitemap-package
deps:
- blocked-by:rheo-packages-threads-the-rheo-context-through-ce1cedf0
closed: true
---
Touches: sitemap/0.1.0/src/core.typ, sitemap/0.1.0/readme.md

# What and why

`segment()` in `sitemap/0.1.0/src/core.typ` names a GROUP node — a directory with no
landing page, which has no path of its own — by indexing into the first path found
beneath it:

```typ
segs.at(depth, default: "?") + "/"
```

That is wrong whenever a project's spine paths carry a leading segment the spine tree
itself does not have. The tree renders the wrong name: `content/` where the directory is
actually called `guide/`.

MEASURED against rheo 0.6.3, with a probe project whose pages live in a `content/`
subdirectory and whose `rheo.toml` sets no `content_dir` (the shape this package's own
demo uses, and the shape `sidebar/0.1.1/demo/` uses):

- a page at `content/guide/deep.typ` gets `handle: "guide:deep"` and
  `path: "content/guide/deep.typ"` — the handle has TWO segments, the path THREE;
- the spine TREE's top level is `[ <group, handle: none, path: none, children: [deep]>,
  <index> ]` — the group node is `guide`, and there is no `content` node in the tree at
  all.

So the path carries one segment more than the tree's own depth accounts for, and
`segs.at(0)` on that path yields `"content"` instead of `"guide"`. Waterline, where this
code was ported from, never saw it: its pages sit directly in the project root
(`rookery/clusters/aicre/index.typ` with `content_dir` unset), so path depth and tree
depth happened to agree.

# The fix: read the group's name off a descendant's HANDLE, not its path

A handle is depth-aligned with the tree by construction and carries no content-directory
prefix — `guide:deep` at tree depth 1 sits under the group at depth 0, and
`"guide:deep".split(":").at(0)` is exactly the group's name. The path is the wrong
source for this and the handle is the right one.

Keep the path for the OTHER two shapes, which are unaffected and must not change: a leaf
is still named by its path's last segment (`cassirer.typ`), and a directory folded
together with its own `index.typ` is still named by the second-to-last segment
(`digitaltheory/`).

# Steps

1. `sitemap/0.1.0/src/core.typ` — add a `first-handle(node)` helper beside the existing
   `first-path(node)`, with the same recursive shape: the node's own `handle` if it has
   one, else the first non-`none` handle found depth-first among its children, else
   `none`.

2. Rewrite the group-node branch of `segment(node, depth)` to use it. The branch is the
   `if n.path == none { .. }` arm. It becomes:

   ```typ
   let h = first-handle(n)
   if h == none { "?/" } else { h.split(":").at(depth, default: "?") + "/" }
   ```

   Keep `first-path` and the other two branches exactly as they are — `first-path` is
   still what the leaf and folded-directory branches read.

3. Replace the doc comment on `segment()`'s group-node case with what is now true, and
   keep the measurement above in it: the name comes from a descendant's HANDLE because a
   path may carry a content-directory prefix the tree does not have, and the group's own
   depth indexes the handle's segments directly. State the concrete numbers
   (`content/guide/deep.typ` vs `guide:deep` under rheo 0.6.3) so the next reader does
   not have to re-measure.

4. `sitemap/0.1.0/readme.md` — no API change here, so add nothing unless the readme
   documents `segment()` directly. If it does, correct it; if it does not, leave the file
   alone and say so in your report rather than inventing a section.

# Non-goals

- Do not change `walk`, `first-path`, `handle-url`, `rel-prefix`, `current-handle`, or
  any other function in `core.typ`.
- Do not touch `src/tree.typ`, `src/blogfeed.typ`, `src/sidebar.typ`, the CSS or the JS.
- Do not edit `demo/rheo/rheo.toml` or `demo/rheo/check.sh`. The demo already sets
  `[spine] auto_index = false` deliberately, so that a directory without an `index.typ`
  stays a real group node instead of getting a synthesized landing page — that is what
  makes this bug observable, and `check.sh` already asserts the CORRECT name (`guide/`),
  so it should start passing when this lands rather than needing an edit.
- Do not "fix" the demo by pointing `content_dir` at `content/`. That would hide the bug
  rather than fix it: a project is free to leave `content_dir` unset, and the package
  must be right either way.
- Nothing in `/home/lox/code/waterline`.

# VERIFY

1. Unit-level, with no rheo involved. A fixture inside the package root (NOT `/tmp` —
   that fails `--root .` with "source file must be contained in project root") that
   builds the probe's own tree shape:

   ```typ
   #import "/src/core.typ": segment
   #let group = (title: "guide", handle: none, path: none, synthesized: false, children: (
     (title: "Deep", handle: "guide:deep", path: "content/guide/deep.typ", synthesized: false, children: ()),
   ))
   #let _ = assert.eq(segment(group, 0), "guide/")
   ```

   compiles clean via `typst compile --features html --root . --format pdf <fixture> /dev/null`.
   Before the fix this same fixture yields `content/` and the assert fails — run it first
   to see it fail, then fix, then see it pass.
2. The unprefixed case still works: the same fixture with `path: "guide/deep.typ"` also
   gives `guide/`.
3. The other two shapes are untouched: `segment` on a leaf node
   (`path: "content/posts/first.typ"`, handle `posts:first`) gives `first.typ`, and on a
   folded directory node (`path: "content/digitaltheory/index.typ"`, handle
   `digitaltheory`) gives `digitaltheory/`.
4. End to end: from `sitemap/0.1.0`, `just check` exits 0 — including its assertion that
   the group row reads `guide/` and is not a link. If `just check` fails for a reason
   OTHER than the group name, report what and stop; a separate bird owns the blogfeed
   metadata bug that blocks this build, and it must land before this VERIFY can pass.