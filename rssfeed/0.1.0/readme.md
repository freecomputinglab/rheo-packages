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

## Migrating from the retired Rust feed generator

`@rheo/rssfeed` pins parity against the Rust Atom generator retired from
rheo core (`rheo/crates/html/src/feed.rs`), but is not a drop-in: a few
things are deliberate simplifications or genuine fixes, not oversights.

- **`title` is REQUIRED — there is no fallback chain.** The retired
  generator fell back from an explicit title, to the HTML spine's own
  title, to the project's directory name
  (`crates/html/src/lib.rs`'s `resolve_title`). `feed(...)` here panics
  instead (`@rheo/rssfeed: feed's \`title\` must be a non-empty string.`) —
  see `verify/no-title/` for a fixture that pins exactly this failure.
- **`datetime.today()` is a trap.** It resolves to the REAL date the build
  ran on, so a vertebra dated with it produces a feed timestamp that
  CHANGES ON EVERY BUILD — every reader re-surfaces that entry as "updated"
  on each deploy, forever. Use a literal `datetime(year: .., month: ..,
  day: ..)` for a post's own `#set document(date: ..)` instead.
- **An undated entry is DROPPED, not dated.** Atom requires `<updated>`
  (RFC 4287 §4.2.15), and Typst cannot stat a compiled output file, so the
  retired generator's mtime fallback
  (`crates/html/src/feed.rs:169-178`) has no equivalent here: a `spine()`
  entry with no `#set document(date: ..)` (and no other source of
  `published`/`updated`) is silently excluded from every feed rather than
  timestamped some other way. This doubles as the replacement for the
  retired `rheo-feed-exclude` variable — an undated cover page or index
  simply never becomes a candidate entry.
- **`<published>` is a genuine addition, not parity.** The retired
  generator never emitted `atom:published` at all, mapping a page's date
  onto `atom:updated` only. Here, an entry with a `published` gets BOTH
  elements, with their own distinct values when they differ.

### Per-entry overrides: no more `rheo-feed-title`/`rheo-feed-updated`

The retired generator let a vertebra override its own feed title/timestamp
with `rheo-feed-title`/`rheo-feed-updated` document variables, read back by
the plugin per-output. There is no equivalent variable here — the same
effect is reached by composing a small function over a built-in source
(`spine()`, `items()`, or any other) rather than annotating the page
itself:

```typ
#import "@rheo/rssfeed:0.1.0": feed, configure, spine

#let with-overrides(s) = spine()(s).map(e => if e.page == "a.html" {
  e + (title: "Override", updated: datetime(year: 2026, month: 6, day: 1))
} else {
  e
})

#configure(feeds: (
  feed(
    path: "feed.xml",
    title: "My Site",
    base-url: "https://example.com",
    sources: (with-overrides,),
  ),
))
```

`e + (..)` merges just the keys being overridden into the entry `spine()`
already built for that page — every other field (`published`, `categories`,
`author`, ...) passes through untouched. This composes with ANY source, not
just `spine()`, and needs no `#set document` on the page being overridden at
all. See `verify/override/` for a working fixture (bead
rheo-packages-parity-qrd, rows 2, 11, 12) — its `content/index.typ` is this
exact pattern, adjusted only to that fixture's own page names.

## Verify

`verify/` pins the retired Rust generator's parity matrix (bead
rheo-packages-parity-qrd) that `demo/` above cannot exercise without
changing what THAT demo demonstrates: a `feed(...)` call missing `title`
(must fail the build), a project that imports the package but never calls
`configure(...)` (must mint nothing), and per-entry overrides composed over
`spine()` (see "Per-entry overrides" above). `demo/check.sh` itself pins the
rest of the matrix — feed/entry authorship, the feed title doubling as the
autodiscovery link's own `title=`, autodiscovery on every page, entry URL
correctness (including the `id`-is-not-a-url exception `notes.xml`'s
rookery-sourced entries take), an excluded page still being built, and an
entry's timestamp tracking its own `#set document(date: ..)`.

Same unreleased-rheo requirement as `demo/` above:

```sh
just verify   # builds its own fixtures — some of them are SUPPOSED to fail
```

`verify/EXPECTED.md` records the observed output of every row in the
matrix, row by row.
