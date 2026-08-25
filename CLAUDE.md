# CLAUDE.md — rheo-packages

A collection of [Rheo](https://rheo.ohrg.org) Typst packages published under the
`@rheo` namespace. Each package lives in `<name>/<version>/` (e.g.
`blogfeed/0.1.1/`) and mirrors the same layout: `typst.toml`, `src/`, a
`Justfile` that builds `dist/` (the published entrypoint), and `flake.nix`.
Most packages also ship JS via `package.json`/vite — see "Pure-Typst
packages" below for the one that doesn't.

One dependency between packages so far: `@rheo/rookery-search` (fuzzy search
over a rookery — ranking, a JSON index, an embeddable search bar, and an
overlay search modal) imports `@rheo/rookery` for its `ideas()` and
`note-href()` primitives. It is built like every other JS package here;
rookery is not. A project using it must
import BOTH in its own `.typ` files — see that package's readme for why.

## Build

- Per package: `cd <name>/<version> && just build` (copies/bundles `src/` into
  `dist/`). `dist/` is gitignored — it is a build artifact.
- All packages: `just build` at the repo root (walks every nested `Justfile`).
- There is no separate linter. "Lint" = the package builds and its demo/test
  project compiles with `rheo compile`.

## Local development against a live rheo project

`@rheo/<pkg>` resolves from the Typst package cache
(`~/.cache/typst/packages/rheo/<pkg>`). The whole NAMESPACE is symlinked at once
on this machine, so every package and every version directory already resolves
live out of the repo with no per-package step:

```sh
ln -sfn "$PWD" ~/.cache/typst/packages/rheo   # one time, per machine
```

Do NOT symlink a single package into the cache
(`ln -sfn "$PWD/<pkg>" ~/.cache/typst/packages/rheo/<pkg>`). Under the namespace
symlink the link argument resolves back into the repo, where `<pkg>/` already
exists — and `ln -sfn TARGET DIR` on an existing directory writes the link
*inside* it, leaving a self-referential `<pkg>/<pkg>` symlink that jj reports as
a new file.

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
#show: template.with(ctx: rheo-context())
```

**Guard requirement (do this in every package using this pattern):** assert
that `ctx` is a valid rheo-context and fail with a message pointing to rheo.
Put the assert at the top of the template, before any use of `ctx`:

```typ
#let template(ctx: none, doc) = {
  assert(
    type(ctx) == dictionary and "handle" in ctx,
    message: "@rheo/<pkg>: the template needs the per-file `rheo-context` "
      + "injected by Rheo. Apply it as `#show: template.with(ctx: rheo-context())` "
      + "and compile the project with Rheo (https://rheo.ohrg.org), not native Typst.",
  )
  // ...
}
```

This catches the common misuses: `ctx` omitted, passed as `none`, or not
rheo-context-shaped.

**Detect a rheo build before calling `rheo-context()`** rather than letting
pure native `typst compile` hard-error on an unbound variable:

```typ
#let ctx = if "rheo-context" in sys.inputs { rheo-context() } else {
  panic("@rheo/<pkg>: compile this project with Rheo (https://rheo.ohrg.org), not native Typst.")
}
```

`sys.inputs` is global to the bundle compile, so it is readable even where
the per-vertebra `rheo-context()` binding is not — this gives a native-Typst
build the friendly panic message instead of Typst's own
`unknown variable: rheo-context`. Still true, and still worth the warning:
**any in-file fallback binding of `rheo-context` clobbers rheo's real
injection.** An `#import "@rheo/<pkg>": rheo-context` sentinel, or a
top-level `#let rheo-context = ...`, both shadow the injected value under
rheo (the injection is prepended, so a later import/let wins). So do NOT
ship a package-level `rheo-context` fallback binding — it breaks the rheo
build; use the `sys.inputs` guard above instead.

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
  the primary supported mode for this kind of package. For the exact keys
  `sys.inputs.rheo-context` carries and their stability, see rheo core's
  `docs/contract.md` rather than re-deriving the field list here — this
  repo doesn't own that inventory, and it has already gone stale here once.
  **`sys.inputs.rheo-context` carries no `handle`** (it is bundle-global,
  not per-file) — a package needing the CURRENT file's own handle still
  needs Pattern A's `rheo-context()` or `state("rheo-handle")` below.
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
also be pure Typst (+ CSS) — no `package.json`, no `pnpm-lock.yaml`, no build
step at all: `@rheo/rookery` points `typst.toml`'s `entrypoint` and
`css_stylesheet` straight at `src/` — editing `src/` takes effect immediately,
nothing to rebuild or forget to re-run. `@rheo/feeds` is the same shape
minus the CSS: `entrypoint` alone, straight at `src/lib.typ`, no
`css_stylesheet` because it emits XML, not HTML — no `dist/` for either
package, and nothing to build before `just test`/`rheo compile` picks up an
edit.

These are two of a kind, deliberately, not a direction of travel:
`@rheo/rookery-search` shares rookery's name and hard-imports it, and is
nonetheless an ORDINARY built package — `package.json` + vite → `dist/`, manifest
pointing at `dist/lib.typ`, `dist/lib.js` and `dist/rookery-search.css`,
exactly like `sidebar`, `blogfeed`, `justify`, `slides` and `tooltip`. That is
precisely why search lives in its own package: search is only worth having
with JavaScript, and rookery is the one package here that ships none.
Splitting kept that true instead of trading it away. When adding a package,
the built shape is the default; buildless needs a reason as good as
rookery's or feeds's.

`.github/workflows/publish-packages.yml` handles three cases per package: a
`package.json` present means `pnpm install && pnpm run build`; no
`package.json` but a `build:` recipe in the package's own `Justfile` means
`just build`; neither means no build step at all. The release archive step
then tars `dist/` if the build produced one, else `src/` — so a dist-less
package like `@rheo/rookery` ships its `src/` directly, matching what its
manifest's entrypoint already points at.

## Cross-package data without an import: the beacon protocol

A package can contribute data to another package it has no import
relationship with, in either direction, by emitting a `#metadata((..))
<label>` beacon and letting the other side `query()` for it back.
`@rheo/feeds`'s `<feeds:item>` protocol (`feeds/0.1.0/src/lib.typ`'s
`items()`/`item()`) is the first instance of this pattern in the repo: any
vertebra, or any package, can emit `#metadata((title: ..., ...))
<feeds:item>`, and its `items()` source reads every one of them back
from the bundle root — with nothing importing anything in either direction.
rheo compiles a whole project in one `typst::compile` pass, so a `query()`
at bundle root sees a beacon from any vertebra, the same fact rookery's own
cross-vertebra beacons (`<rheo-meta:<handle>>`) already rely on.

This is the FALLBACK, not the first thing to reach for. Where the data
already has a synchronous accessor — a function you can call directly, the
way `@rheo/rookery`'s `ideas()` hands back every note as a plain array — call
it directly instead, with a small function reshaping its output for the
consumer and no beacon or `query()` involved. `@rheo/feeds`'s own readme
carries both worked examples side by side ("Sourcing from another package"
for the accessor path, "The `<feeds:item>` beacon protocol" for this one)
along with the reasoning for reaching for a beacon only when no accessor
exists to call — an arbitrary hand-authored page with no registry behind it,
or a package that holds data but exposes no accessor for it.

## Issue tracking

`.beads/` is gitignored and local-only here, as it is everywhere else — the db,
its lock files, and `issues.jsonl` all stay machine-local, and a `br` mutation
therefore produces nothing to commit. Use `br` per the global workflow.

Tracking `issues.jsonl` was tried in this repo and reverted. It did carry bead
state between machines, but br REIMPORTS from that file, so a copy arriving from
another machine can silently revert a close, and two machines mutating beads at
once conflict over the whole file. Bringing beads in from elsewhere is now an
explicit act, not a side effect of a pull: put the entries in
`.beads/issues.jsonl` and run `br sync --import-only --force` (plain
`--import-only` short-circuits on an unchanged content hash and does nothing).

Two things about `br` in this repo that cost time to find out:

- **It does not reliably re-export after a mutation.** MEASURED: a
  `br delete --force --hard` of eleven issues left all eleven in
  `issues.jsonl` still marked `open`, so the next import resurrected them.
  Run `br sync --flush-only --force` after any delete or close, and re-check
  with `br list` — the export guard refuses a flush that would drop issues the
  JSONL still holds, which is exactly the case after a delete.
- **`br list -a` silently caps at 50 rows.** Pass `--limit` before trusting any
  count or diff taken from it.

The prefix is `rp`. Beads for this repo previously lived in the machine-global
`~/.beads/` db — there was no `.beads/` here, so `br` fell back to it — which
is why the CLOSED history of the rookery/rookery-search work carries
`br-vio-core-*` ids and is absent from this repo's db. Source comments citing
bead ids like `rookery-bib-minted-m6h` refer to that history.
