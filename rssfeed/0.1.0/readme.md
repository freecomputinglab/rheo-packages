# @rheo/rssfeed

Atom 1.0 feed generation for Rheo projects, in pure Typst — replacing the
Rust feed generator removed from rheo core.

## Status

Implemented: the entry model, `feed`/`resolve-entries`/`atom`, the
built-in `spine`/`items` sources, and the `configure`/`.marrow.typ`
minting path — see `src/lib.typ`'s own header comment for the full
surface, and "## Demo" below for a working end-to-end proof.

## Local development

Pure Typst, no build step: `typst.toml`'s entrypoint points straight at
`src/lib.typ`, so editing `src/` takes effect immediately — no `dist/`, no
copy step to forget to re-run.

```sh
ln -sfn "$PWD" ~/.cache/typst/packages/rheo   # one time, per machine — symlinks the whole namespace
```

Symlink the whole `rheo` namespace from the repo root, not this package on
its own — under the namespace symlink, `ln -sfn` targeting an existing
`rssfeed/` directory writes the link *inside* it instead of replacing it,
leaving a self-referential `rssfeed/rssfeed`.

No package-specific devShell either: this repo's own root `flake.nix`/
`.envrc` already provide `just` and `typst`, and direnv finds them by
walking up from anywhere under this directory.

## Demo

`demo/` is a runnable proof of this package's headline capability: ONE
project, TWO Atom feeds built from different subsets of the same small
site.

- `feed.xml` — the three dated posts under `demo/content/posts/`, selected
  by filtering the spine on each vertebra's handle. One of them
  (`posts/deep/three.typ`) is nested a directory deep, to show the entry
  model doesn't care.
- `notes.xml` — the notes tagged `note` on `demo/content/notes.typ`,
  sourced through `@rheo/rookery`'s own `ideas(tags:)` primitive rather
  than this package's `<rssfeed:item>` beacon protocol — see
  `demo/content/index.typ`'s `from-ideas`, five lines, with no import
  between the two packages in either direction: a source is just a
  function `cfg => (entries)`, and `ideas()` is called by the PROJECT, not
  by `@rheo/rssfeed`.

Needs an UNRELEASED rheo (>= 0.6.0, currently the `feat/transclusion`
line): `<rheo-content>` transclusion and the `.rheo/` control-asset
convention (both of which this demo depends on, the second to mint its two
feeds' autodiscovery `<link>` tags) do not exist in 0.5.2. With that binary
on `PATH` (and this package reachable through the namespace symlink above,
so `@rheo/rookery` resolves from the same checkout):

```sh
rheo compile demo   # from the package root — or: just demo
./demo/check.sh     # asserts on the output — or: just check
```

OBSERVED (rheo `feat/transclusion`, this package's own build): both feeds
compiled to valid, non-empty Atom with disjoint entry sets. Every page's
`<head>` — the root vertebra, the nested one, and every minted note page
alike — carried BOTH feeds' autodiscovery
`<link rel="alternate" type="application/atom+xml">` tags, minted once as
`.rheo/head.html` and spliced into every page rheo compiled, not just the
one vertebra that called `configure(...)`. `notes.xml`'s entries linked to
absolute URLs ending in `ideas/<slug>.html`, each matching a real minted
file on disk — including the note nested inside another note's body
(`ideas/alpha-inner.html`). Neither feed's `<content>` retained a
`<rheo-content>` placeholder: both had already been resolved to the real,
escaped HTML of the page they named.
