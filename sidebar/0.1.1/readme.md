# @rheo/sidebar

Book-style site navigation for [rheo](https://rheo.ohrg.org) projects: a
sidebar, a topbar, and prev/next arrows.

```typst
#import "@rheo/sidebar:0.1.1": sidebar

#show: sidebar.with(title: "My Book")
```

That is the whole setup under rheo. The navigation comes from the project's
own spine.

## 0.1.1

**The nav builds itself from the spine.** Through 0.1.0 an author hand-wrote a
`nav` array and passed `current:` on every page — a second copy of the site
structure, kept in Typst, that had to be edited in step with the first.

Both are derived now. rheo injects the spine as a tree in `rheo-context`, and
publishes the current page's handle as a state, so a project under rheo passes
neither and shapes its navigation by editing `rheo.toml` instead:

```toml
[spine]
exclude = ["_template.typ"]

[[spine.section]]
name = "guide"
```

`nav:` remains as an escape hatch — see "Overriding the nav" below. Nothing
about the 0.1.0 API changed, so an existing project keeps working untouched.

## What gets derived

| | from |
| --- | --- |
| the nav tree | `rheo-context.spine` |
| each link's url | the node's handle, made relative to the current page |
| the active entry | `state("rheo-handle")` |
| the document title | the active entry's title, plus `title:` |
| prev/next | spine order |

A spine node with no handle is a **group**: a non-clickable section header. One
with a handle is a **chapter**: a clickable top-level link. Either way its
descendants become that node's `items`.

### Urls are directory paths, and depth-relative

A handle's `:` segments are **directories** in rheo's output. A vertebra at
`content/guide/intro.typ` has the handle `guide:intro` and is written to
`guide/intro.html` — not `guide:intro.html`.

And because the same nav renders on every page, each url is written relative to
the page it appears on: `guide/intro.html` from the site root, but
`../guide/intro.html` from inside `guide/`. Both are asserted in
`demo/rheo/check.sh`, which is why that demo has a nested vertebra.

### Two levels, and what happens below them

The renderer draws a group or chapter and its `items` — two levels. The spine
tree recurses to any depth, so anything **deeper** is flattened into its nearest
second-level ancestor's `items` rather than dropped.

Flattening loses the grouping; dropping would lose the page, and a page missing
from the nav is the worse failure — a reader cannot reach what is not listed.
Extending the renderer to arbitrary depth would change the markup and the
stylesheet with it; that is worth doing against a real three-level spine rather
than in anticipation of one.

## Overriding the nav

Pass a non-empty `nav:` and everything above is skipped. This is for a project
not under rheo, or one whose navigation deliberately differs from its spine.

```typst
#show: sidebar.with(
  title: "My Book",
  nav: (
    (title: "Section", items: ((id: "p1", title: "Page", url: "p1.html"),)),
    (id: "ch", title: "Chapter", url: "ch.html", items: ()),
  ),
  current: "p1",
)
```

A group has no `url`; a chapter has one. Items at either level may carry a
`num` field for numbered display. With an explicit `nav` you own the urls,
including their depth, and you should pass `current:` too — the automatic one
matches against spine handles, which a hand-authored nav need not use.

`nav-from-context(spine: auto, from: none)` is exported if you want the derived
array to inspect or post-process rather than to replace.

## Other arguments

- `title` — site title, used in the topbar and as the document title's suffix
- `home-url` — where the topbar title links (default `/`)
- `logo` — content shown in the topbar instead of the title text
- `accent-color` — a CSS colour string, published as `--accent-color`

## Requirements

- rheo 0.6.0 or later for the derived nav. The explicit-`nav` path needs no
  rheo at all.
- A built package: `dist/` must exist before a project sees an edit.

## Development

```sh
cd sidebar/0.1.1
just build   # bundles src/ into dist/
just check   # builds the demo and asserts on its output
```
