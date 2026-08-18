# @rheo/rssfeed

Atom 1.0 feed generation for Rheo projects, in pure Typst — replacing the
Rust feed generator removed from rheo core.

## Status

Stub only. The API is not implemented yet — no `configure`, no `atom`, no
entry model. `src/lib.typ` is a module header comment describing the
intended shape; follow-up work lands the actual functions.

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
