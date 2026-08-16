# @rheo/rookery-search

Fuzzy search over the notes in a [`@rheo/rookery`](../../rookery/0.1.0) — a
Typst primitive that ranks them, a JSON index of the corpus, and a search bar
you can drop into a page.

It is a separate package rather than part of rookery because search is only
worth having with JavaScript, and rookery is deliberately the one package here
that ships none. Splitting keeps rookery buildless and puts the JavaScript in a
package built like every other one in this repo.

```typst
#import "@rheo/rookery:0.1.0": idea, rookery
#import "@rheo/rookery-search:0.1.0": search-bar
#show: rookery

#search-bar()
```

## Import both packages, in your own files

**A project using search must import `@rheo/rookery` AND `@rheo/rookery-search`
in its own `.typ` files.** This is a requirement, not a tidiness preference.

rheo only scans a project's own files for package imports — not the packages
those files' packages import in turn. So importing only `rookery-search` and
reaching rookery through it does not register rookery with the build. The cost
is not cosmetic: rookery's `.marrow.typ` never runs, **no note pages are minted
at all**, and with no minted pages there are no hrefs, so the index comes out
empty and the bar has nothing to link to. Its stylesheet is missing too.

In practice this is free — a project with notes in it writes `#idea`, and so
imports rookery already. It is stated here because the failure is silent: a
build with no rookery import succeeds, and produces a search bar that finds
nothing.

For the same reason this package does **not** re-export rookery's functions.
There is no arrangement in which importing rookery-search alone is correct, so
it does not offer one.

## What needs rheo

`search-ideas(query)` is pure Typst. It ranks the corpus and hands you the
matches; you render them however you like, and it works under plain `typst
compile` with no rheo present.

`search-index()` and `search-bar()` are **rheo only**. The index links to
minted note pages, and only rheo mints them; the bar's behaviour lives in
JavaScript that rheo injects from this package's manifest. Neither is useful in
a single-document build, where there are no pages to navigate between and
nothing to run a script.

## Working on it locally

Unlike rookery, this package is **built**. `typst.toml` points at `dist/`, and
`dist/` is produced by vite:

```sh
cd rookery-search/0.1.0
just build          # pnpm install && pnpm run build
```

That copies `src/lib.typ` and `src/rookery-search.css` into `dist/` unchanged
and bundles `src/rookery-search.js` into `dist/lib.js`.

**Editing `src/` does nothing until you rebuild.** This is the one place
rookery's habits mislead: there, `src/` *is* the published package and an edit
is live immediately. Here the loop is edit `src/`, `just build`, then rebuild
the consuming project. `dist/` is a build artifact and is gitignored.

To develop against a live rheo project, symlink the package into the Typst
package cache:

```sh
ln -sfn "$PWD" ~/.cache/typst/packages/rheo/rookery-search
```
