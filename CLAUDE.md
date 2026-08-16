# CLAUDE.md — rheo-packages

A collection of [Rheo](https://rheo.ohrg.org) Typst packages published under the
`@rheo` namespace. Each package lives in `<name>/<version>/` (e.g.
`blogfeed/0.1.1/`) and mirrors the same layout: `typst.toml`, `src/`, a
`Justfile` that builds `dist/` (the published entrypoint), and `flake.nix`.
Most packages also ship JS via `package.json`/vite — see "Pure-Typst
packages" below for the one that doesn't.

One dependency between packages so far: `@rheo/rookery-search` (fuzzy search
over a rookery — ranking, a JSON index, an embeddable search bar) imports
`@rheo/rookery` for its `ideas()` and `note-href()` primitives. It is built
like every other JS package here; rookery is not. A project using it must
import BOTH in its own `.typ` files — see that package's readme for why.

## Build

- Per package: `cd <name>/<version> && just build` (copies/bundles `src/` into
  `dist/`). `dist/` is gitignored — it is a build artifact.
- All packages: `just build` at the repo root (walks every nested `Justfile`).
- There is no separate linter. "Lint" = the package builds and its demo/test
  project compiles with `rheo compile`.

## Local development against a live rheo project

`@rheo/<pkg>` resolves from the Typst package cache
(`~/.cache/typst/packages/rheo/<pkg>`). For local iteration, symlink the
in-repo package into the cache (mirrors how `justify` is wired):

```sh
ln -sfn "$PWD/<pkg>" ~/.cache/typst/packages/rheo/<pkg>
```

Then `just build` the package (skip this for a dist-less pure-Typst package —
see "Pure-Typst packages" below) and `rheo compile` a test project that
imports it. No per-package devShell needed either: this repo's own root
`flake.nix`/`.envrc` provide `just` and `typst`, and direnv finds them by
walking up from anywhere under the repo.

## Pattern: consuming the injected `rheo-context`

Core rheo injects per-file build context that a package cannot read
implicitly — a Typst function captures its definition scope, not the call
site. There are now TWO valid patterns, depending on what the package needs.

### Pattern A — template packages: explicit `ctx:`

A package that needs the CURRENT FILE's own handle (for a per-page template,
nav, etc.) takes it as an explicit parameter, because only the call site (the
vertebra itself) has `rheo-context` in scope:

```typ
#import "@rheo/<pkg>:x.y.z": template
#show: template.with(ctx: rheo-context)
```

**Guard requirement (do this in every package using this pattern):** assert
that `ctx` is a valid rheo-context and fail with a message pointing to rheo.
Put the assert at the top of the template, before any use of `ctx`:

```typ
#let template(ctx: none, doc) = {
  assert(
    type(ctx) == dictionary and "handle" in ctx,
    message: "@rheo/<pkg>: the template needs the per-file `rheo-context` "
      + "injected by Rheo. Apply it as `#show: template.with(ctx: rheo-context)` "
      + "and compile the project with Rheo (https://rheo.ohrg.org), not native Typst.",
  )
  // ...
}
```

This catches the common misuses: `ctx` omitted, passed as `none`, or not
rheo-context-shaped.

**Known limitation** (tested 2026-07-11, rheo 0.4.0): the assert does NOT
catch pure native `typst compile`, where `rheo-context` is an unbound
variable and Typst hard-errors (`unknown variable: rheo-context`) before the
template runs. This cannot be fixed package-side: **any in-file fallback
binding of `rheo-context` clobbers rheo's real injection.** Verified —

- `#import "@rheo/<pkg>": rheo-context` (a sentinel) shadows the injected
  value (import comes after the prepended injection, so the sentinel wins
  even under rheo).
- A top-level `#let rheo-context = "..."` also wins over injection under
  rheo; a non-string `#let rheo-context = (...)` trips rheo's `rheo-*`
  harvester (`rheo-context must be a string or boolean`).

So do NOT ship a package-level `rheo-context` fallback binding — it breaks
the rheo build. The friendlier native-Typst error is deferred to a rheo-core
change (shadow-proof injection or a `require-rheo-context()` hook); track it
in the rheo repo (bead `rheo-d1h`).

### Pattern B — packages that work without rheo: feature-detect

A package that doesn't need the CURRENT FILE's handle — only the shared
spine-wide data, or nothing rheo-specific at all — should instead detect
rheo's presence rather than require it. This is the pattern for a package
whose primary supported mode is running under plain `typst compile` with no
rheo present at all.

- Shared spine data (title, spine tree, etc.) is reachable from ANY scope via
  `sys.inputs`, not just the injected per-file binding:

  ```typ
  #let rheo-context() = sys.inputs.at("rheo-context", default: (spine-flat: ()))
  ```

  (`blogfeed/0.1.1/src/lib.typ:32`.) Falls back to an empty/absent spine when
  built without rheo — no assert, no error, because running without rheo is
  the primary supported mode for this kind of package.
- The CURRENT OUTPUT PAGE's own handle (if needed) is `state("rheo-handle")`,
  which rheo publishes per page in `rheo-page-init`
  (`/home/lox/code/_rheo/rheo/crates/core/src/typ/rheo.typ:70-75`) — readable
  from package scope without any `ctx:` parameter.
- `@rheo/rookery` uses this pattern throughout and takes NO `ctx` parameter at
  all: see `rookery/0.1.0/src/lib.typ`'s `_rheo-ctx()`/`_target()` helpers.

DO NOT assert or panic when rheo is absent under this pattern — that's
Pattern A's job for packages that genuinely can't function without rheo.
Pick the pattern by whether the package's primary mode is "always under
rheo" (A) or "works standalone, rheo optionally enhances it" (B).

## Pure-Typst packages

Most packages here ship JS (a `package.json` + vite build). A package can
also be pure Typst + CSS — no `package.json`, no `pnpm-lock.yaml`, no build
step at all: `@rheo/rookery` points `typst.toml`'s `entrypoint` and
`css_stylesheet` straight at `src/` — editing `src/` takes effect immediately,
nothing to rebuild or forget to re-run.

It is the first such package and still the **only** one, deliberately. Do not
read it as a direction of travel: `@rheo/rookery-search` shares its name and
hard-imports it, and is nonetheless an ORDINARY built package — `package.json`
+ vite → `dist/`, manifest pointing at `dist/lib.typ`, `dist/lib.js` and
`dist/rookery-search.css`, exactly like `sidebar`, `blogfeed`, `justify`,
`slides` and `tooltip`. That is precisely why search lives in its own package:
search is only worth having with JavaScript, and rookery is the one package
here that ships none. Splitting kept that true instead of trading it away.
When adding a package, the built shape is the default; buildless needs a
reason as good as rookery's.

`.github/workflows/publish-packages.yml` handles three cases per package: a
`package.json` present means `pnpm install && pnpm run build`; no
`package.json` but a `build:` recipe in the package's own `Justfile` means
`just build`; neither means no build step at all. The release archive step
then tars `dist/` if the build produced one, else `src/` — so a dist-less
package like `@rheo/rookery` ships its `src/` directly, matching what its
manifest's entrypoint already points at.

## Issue tracking

`.beads/` is gitignored and local-only — never commit it, never `br sync`. Use
`br` per the global workflow.
