---
id: rheo-packages-points-the-demo-at-sitemap-s-sidebar-90de3e7a
short-id: 90d
title: Points the demo at sitemap's sidebar view
priority: 4
labels:
- sitemap-review
deps:
- blocked-by:rheo-packages-fixes-the-shadowed-spine-parameter-b4a1e95d
- blocked-by:rheo-packages-scopes-and-prefixes-the-blogfeed-css-b015cd16
closed: false
---
Touches: sitemap/0.1.0/demo/rheo/content/_template.typ, sitemap/0.1.0/demo/rheo/check.sh

# What and why

`@rheo/sitemap`'s demo — the only automated check the package has — exercises the
**deprecated** `@rheo/sidebar` package instead of the sidebar view this package ported
from it. `sitemap/0.1.0/demo/rheo/content/_template.typ` reads:

```typ
#import "@rheo/sidebar:0.1.1": sidebar

#let template(doc) = {
  show: sidebar.with(title: "Sitemap Demo", home-url: "/")
  doc
}
```

`sidebar.typ` is the largest file in the package (315 lines) and its
`.rheo-sidebar-layout` wrapper had a whole bird filed for it
(`rheo-packages-scopes-the-sidebar-css-to-a-wrapper-c073075b`), yet **none of it runs in
the demo**. MEASURED against real rheo 0.6.3: the built pages under
`sitemap/0.1.0/demo/rheo/build/html/` carry `<div class="topbar">` with no
`.rheo-sidebar-layout` wrapper anywhere, and their `<head>` links *two* stylesheets and
*two* script bundles — `rheo/sidebar/sidebar.css` + `rheo/sitemap/sitemap.css` and
`rheo/sidebar/lib.js` + `rheo/sitemap/lib.js` — because both packages are imported. So
every scoped rule in `sitemap.css`'s sidebar block currently matches nothing on these
pages, and `check.sh`'s entire `THE NAV` section certifies `@rheo/sidebar 0.1.1`'s
behaviour rather than this package's.

The cost of that gap is already demonstrated: `sidebar()` panics on every call, and the
demo did not catch it. That fix is the bird
`Fixes the shadowed spine parameter in nav-from-context`, which this bird is blocked on —
it aliases `core.typ`'s `spine` accessor to `spine-of` inside `sidebar.typ`, because a
`spine: auto` parameter was shadowing the imported function and `spine()` resolved to
`auto`. Without that fix this bird's own VERIFY cannot pass.

This bird is also blocked on `Scopes and prefixes the blogfeed CSS`, which renames the
feed's emitted class names and updates the two `check.sh` assertions that read them. Work
on top of whatever names that bird left in place rather than the ones quoted in any older
text.

# Steps

1. In `sitemap/0.1.0/demo/rheo/content/_template.typ`, change the import from the
   deprecated package to this one:

   ```typ
   // The one `#show: sidebar.with(..)` every vertebra applies. `sidebar()` takes
   // no `ctx:` — it feature-detects via `state("rheo-handle")` and `sys.inputs`.
   #import "@rheo/sitemap:0.1.0": sidebar
   ```

   Leave the `template` body and its arguments exactly as they are.

2. `@rheo/sitemap:0.1.0` must resolve out of this repo for the demo to compile against the
   working tree rather than a downloaded tarball. Per this repo's `CLAUDE.md`
   ("Local development against a live rheo project"), the Typst package cache is a MIX of
   symlinks into this repo and downloaded copies, and a downloaded copy wins silently.
   Check it before compiling, from `sitemap/0.1.0`:

   ```sh
   ls -la ~/.cache/typst/packages/rheo/sitemap/
   ```

   If `0.1.0` is a real directory rather than a symlink to this repo, remove it and link
   it (note the link path ends in the version and must not already exist):

   ```sh
   rm -rf ~/.cache/typst/packages/rheo/sitemap/0.1.0
   ln -s "$PWD" ~/.cache/typst/packages/rheo/sitemap/0.1.0
   ```

   Do not relink the `rheo` namespace wholesale — that would clobber the other packages'
   working entries.

3. In `sitemap/0.1.0/demo/rheo/check.sh`, add an assertion to the `THE NAV` section that
   pins the wrapper this package emits and the deprecated one does not. Inside the existing
   `for page in pages:` loop, next to the `if 'class="sidebar"' not in h:` check:

   ```python
   # The wrapper `@rheo/sitemap`'s own sidebar view emits, and the scope every
   # layout rule in sitemap.css's sidebar block hangs off. `@rheo/sidebar 0.1.1`
   # emits no such wrapper, so this is what proves the demo is exercising THIS
   # package's view and not the deprecated one.
   if 'class="rheo-sidebar-layout"' not in h:
       fail(f"{page}: no div.rheo-sidebar-layout — is the demo still importing @rheo/sidebar instead of @rheo/sitemap?")
   ```

4. Still in `check.sh`, tighten the `THE BUNDLE` section so a second package's assets
   cannot creep back in unnoticed. The existing loop already asserts `sitemap.css` is
   linked exactly once; add, in the same loop:

   ```python
   if "rheo/sidebar/" in h:
       fail(f"{page}: links an asset from the deprecated @rheo/sidebar package")
   ```

5. Re-run `just check` and fix any assertion that fails because this package's markup
   legitimately differs from `@rheo/sidebar 0.1.1`'s. Two are known candidates, both in
   `THE NAV`: the `class="active"` assertion and the `../`-prefix depth assertions. If one
   fails, the failure is real information — report which, and whether the cause is a
   genuine difference in this package's view or a stale expectation. Do NOT weaken an
   assertion to make it pass; if the port's behaviour is wrong, say so in the flight's
   report and leave the assertion asserting the correct behaviour with a comment naming
   what it catches.

# Non-goals

- Do NOT delete or modify `sidebar/0.1.1/` or `blogfeed/0.1.1/`. Both stay building and
  resolving at their existing versions on purpose — this repo's `CLAUDE.md` says so.
- Do NOT edit `sitemap/0.1.0/src/`. Any source defect found here gets reported, not fixed.
- Do NOT add, remove, or rename pages under `sitemap/0.1.0/demo/rheo/content/`.
- Do NOT edit `sitemap/0.1.0/demo/rheo/rheo.toml`.
- Do NOT bump the package version in `sitemap/0.1.0/typst.toml`.

# VERIFY

Run from `sitemap/0.1.0`:

1. `just check` exits 0 and prints `demo/rheo OK`.
2. `rg -c 'rheo/sidebar' demo/rheo/build/html/index.html` reports `0` — no asset from the
   deprecated package is linked any more.
3. `rg -c 'rheo-sidebar-layout' demo/rheo/build/html/index.html` reports at least `1` —
   this package's own wrapper is in the output.
4. `rg -n '@rheo/sidebar' demo/rheo/content/_template.typ` prints nothing.