---
id: rheo-packages-fixes-the-shadowed-spine-parameter-b4a1e95d
short-id: b4
title: Fixes the shadowed spine parameter
priority: 4
labels:
- sitemap-review
deps: []
closed: false
---
Touches: sitemap/0.1.0/src/sidebar.typ

# What and why

`sidebar()` — the whole sidebar/topbar/prev-next view of `@rheo/sitemap` — **panics on
every project that uses it.** It has never worked, in any build.

The cause is a shadowed binding in `sitemap/0.1.0/src/sidebar.typ`. Line 1 imports the
spine accessor:

```typ
#import "core.typ": current-handle, handle-url, spine
```

Line 70 then declares a parameter with the same name, and line 71 tries to call the
imported function from inside the parameter's own scope:

```typ
#let nav-from-context(spine: auto, from: none) = {
  let spine = if spine == auto {
    spine()
  } else { spine }
```

A Typst function parameter is bound for the whole body, so `spine()` on line 72 resolves
to the *parameter* — which on the default path holds `auto`. Calling `auto` is an error.

MEASURED, with a three-line reduction compiled by `typst compile`:

```
error: expected function, found auto
  │   let spine = if spine == auto { spine() } else { spine }
  │                                  ^^^^^
```

And MEASURED end-to-end against real rheo 0.6.3: repointing
`sitemap/0.1.0/demo/rheo/content/_template.typ` from `@rheo/sidebar:0.1.1` to
`@rheo/sitemap:0.1.0` and running `rheo compile demo/rheo` from `sitemap/0.1.0` fails
with exactly that one error and produces no pages.

`sidebar()` reaches this path on every call: line 121-123 is

```typ
let nav-for(cur) = if explicit-nav.len() > 0 { explicit-nav } else {
  nav-from-context(from: cur)
}
```

— no `spine:` argument, so the default `auto` is always taken unless the caller passed a
non-empty `nav:` array. The documented headline of the port (`sitemap/0.1.0/readme.md`
line 121, `#show: sidebar.with(title: "My Book")`) is precisely the broken call.

This shipped undetected because `sitemap/0.1.0/demo/rheo/content/_template.typ` imports
`@rheo/sidebar:0.1.1` — the *deprecated* package — rather than the ported view, so
`just check` exercises the old code. Fixing the demo is a separate bird
(`Points the demo at sitemap's own sidebar view`) that is blocked on this one; do not
touch the demo here.

# Steps

1. In `sitemap/0.1.0/src/sidebar.typ`, change the import on line 1 to alias the spine
   accessor so it cannot be shadowed:

   ```typ
   #import "core.typ": current-handle, handle-url, spine as spine-of
   ```

2. Change the body of `nav-from-context` (lines 70-73) to call the alias:

   ```typ
   #let nav-from-context(spine: auto, from: none) = {
     let spine = if spine == auto { spine-of() } else { spine }
   ```

   Keep the parameter named `spine` — it is the package's public API, documented in the
   doc comment on lines 57-69, and renaming it would silently break any caller passing
   `spine:` explicitly.

3. Leave the rest of the function unchanged. The `spine.map(node => ...)` on line 74
   already reads the local binding and is correct once that binding holds an array.

# Non-goals

- Do NOT edit `sitemap/0.1.0/demo/` or `sitemap/0.1.0/demo/rheo/check.sh`. The demo still
  points at `@rheo/sidebar:0.1.1` on purpose until the bird named above moves it.
- Do NOT restructure `sidebar()`'s two `context` blocks, change how the nav is derived, or
  change where nav titles come from. Those are separate filed birds.
- Do NOT rename the `spine` parameter of `nav-from-context`.
- Do NOT bump the package version in `sitemap/0.1.0/typst.toml`.

# VERIFY

Run from `sitemap/0.1.0`:

1. A direct reduction proves the call no longer errors. Create a scratch file outside the
   repo and compile it:

   ```sh
   cat > /tmp/navcheck.typ <<'TYP'
   #import "/src/sidebar.typ": nav-from-context
   #nav-from-context(spine: ((title: "T", handle: "t", path: "t.typ", children: ()),))
   #nav-from-context()
   TYP
   typst compile --root . /tmp/navcheck.typ -f pdf /tmp/navcheck.pdf
   ```

   It must exit 0. Before the fix the second call errors with
   `expected function, found auto`; after it, the bare `nav-from-context()` returns an
   empty array (there is no rheo, so `spine-of()` falls back to `()`).

2. `just check` must still print `demo/rheo OK`, unchanged — this bird does not alter the
   demo's output.