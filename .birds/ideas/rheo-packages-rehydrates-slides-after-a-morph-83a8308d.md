---
id: rheo-packages-rehydrates-slides-after-a-morph-83a8308d
short-id: '83'
title: Rehydrates slides after a morph
priority: 4
labels:
- rehydrate-slides
deps:
- blocked-by:rheo-packages-ships-the-rehydrate-helper-package-9ffb793f
closed: true
---
Touches: slides/0.1.1/typst.toml, slides/0.1.1/src/lib.ts, slides/0.1.1/package.json, slides/0.1.1/readme.md

Cut `@rheo/slides:0.1.1` and make it survive `rheo watch` patching a page. This
is the hardest of the rehydrate migrations: a naive re-run resets the deck to
slide one and appends a duplicate `<style>` element to `<head>` on **every**
page, deck or not.

## The background a worker needs

`rheo watch` no longer reloads the page on a content edit. It refetches the page
and morphs the new HTML into the live DOM, preserving scroll, focus and
selection. Two consequences:

- **Scripts are not re-executed**, and the markup that arrives is the
  *pre-hydration* build output, so anything done at boot is reverted with
  nothing re-running to redo it.
- **Elements are mutated in place** where the morph can match them, so
  listeners bound to surviving nodes **survive**; re-wiring naively double-fires.

A package opts in by declaring `js_rehydrate = true` in its
`[tool.rheo.<format>]` block and pushing a callback onto
`globalThis.__rheoRehydrate`. rheo renders declaring scripts with
`data-rheo-rehydrate`, surveys **every** script on a page before morphing, and
reloads instead if any one is undeclared — so one unmigrated package on a page
denies the whole page a patch. Protocol:
`/home/lox/code/_fcl/rheo/docs/contract.md`, section
`Dev-server rehydrate protocol`.

## Version bump, not an in-place edit

`slides/0.1.0` is a **released version** — the tag `slides-0.1.0` exists — and
this repo treats a released version as permanent and immutable (see
`/home/lox/code/_fcl/rheo-packages/CLAUDE.md`). Cut `0.1.1` with the root
`Justfile`'s bump recipe, which copies the directory and rewrites every
`@rheo/slides:<ver>` spec in the repo. One hit at line 108 as of filing:

```bash
rg -n '^bump PKG OLD NEW:' /home/lox/code/_fcl/rheo-packages/Justfile
```

```bash
cd /home/lox/code/_fcl/rheo-packages && just bump slides 0.1.0 0.1.1
```

Do all the work below in `slides/0.1.1/`. **Leave `slides/0.1.0/` untouched.**

## Locate the sites

All anchors are in `slides/0.1.1/src/lib.ts` after the bump, and each was
confirmed a single hit in the `0.1.0` source at filing time. Scope searches to
the package directory so a rename still resolves. If an anchor genuinely does
not hit, widen to `/home/lox/code/_fcl/rheo-packages` and report the miss
rather than inventing a replacement.

- **The `<style>` element creation** — line 22 as of filing. Landmark: the
  `applyStyles` function. This is the duplicate-append bug.

  ```bash
  rg -n "const style = document.createElement\('style'\)" /home/lox/code/_fcl/rheo-packages/slides
  ```

- **The title-bar element creation** — line 31 as of filing. Landmark: the
  `setupSlideTitle` function. Second duplicate-append bug.

  ```bash
  rg -n "header.className = 'slide-title-bar'" /home/lox/code/_fcl/rheo-packages/slides
  ```

- **The Reveal.js initialisation** — line 48 as of filing. Landmark: the `init`
  function. Calling this again is what resets the reader to slide one.

  ```bash
  rg -n 'Reveal.initialize' /home/lox/code/_fcl/rheo-packages/slides
  ```

- **The Reveal event registrations** — lines 39 and 40 as of filing. Landmark:
  the `setupSlideTitle` function.

  ```bash
  rg -n "Reveal.on\('ready', update\)" /home/lox/code/_fcl/rheo-packages/slides
  ```

- **Where the current slide is read** — line 34 as of filing. Landmark: the
  `update` function, selecting `.reveal .slides section.present`.

- **The boot block** — line 51 as of filing. Landmark: module scope, the last
  statement in the file.

  ```bash
  rg -n "if \(document.readyState === 'loading'\)" /home/lox/code/_fcl/rheo-packages/slides
  ```

## The three real problems, and what to do about each

1. **`init` has no early-return when the page carries no deck.** `applyStyles`
   creates and appends its `<style>` unconditionally; only `setupSlideTitle`
   checks for `.reveal` (its `if (!reveal) return;`, line 29 as of filing). So
   on a page with no deck this package still mutates `<head>`, and under
   rehydrate it would do so once per edit, for ever.

   Add an early-return at the top of `init`: if `document.querySelector('.reveal')`
   finds nothing, return before doing anything. This also makes rehydrate free
   on every non-deck page, which is most of them.

2. **Duplicate appends.** Route both the `<style>` and the `.slide-title-bar`
   element through the helper's `only(parent, selector, make)`, which removes
   every existing match before appending a fresh one. Give each a stable,
   specific selector — the `<style>` needs a distinguishing class or
   `data-` attribute of its own, since a bare `style` selector in `<head>`
   would delete unrelated stylesheets. **Do not use a bare tag selector here.**

3. **`Reveal.initialize()` resets the deck to slide one.** It must be called
   exactly once per page load and **never** on a rehydrate pass. Split the boot
   into a first-load path and a rehydrate path:

   - First load: current behaviour, `Reveal.initialize(...)` included.
   - Rehydrate: re-apply the styles and the title bar against the new DOM, and
     re-register the Reveal event handlers, but **do not** call
     `Reveal.initialize` again.

   Make the distinction an explicit parameter, not a flag with a default that
   happens to work — a reader must be able to see which path they are in.

   Reveal.js keeps its own slide state, and a morph preserves the deck's DOM,
   so not re-initialising is what keeps the reader where they were. If the
   morph has changed the number of slides, Reveal needs telling: call
   `Reveal.sync()` on the rehydrate path if that function is available on the
   Reveal object, guarded so an older Reveal without it is not a crash.

4. `Reveal.on('ready', ...)` and `Reveal.on('slidechanged', ...)` accumulate a
   handler per pass. Reveal's API has `Reveal.off(...)`; use it to drop the
   previous pass's handlers before registering, or register them only on first
   load if `update` does not need rebinding. Say which you chose and why in a
   code comment.

## Steps

1. `just bump slides 0.1.0 0.1.1`, then work only in `slides/0.1.1/`.
2. Add `@rheo/rehydrate:0.1.0` as a dependency: import it in `src/lib.typ` so
   rheo injects its JavaScript, and reach its helpers through the global
   `RheoRehydrate` **inside** your functions, never at module-evaluation time —
   script order between two packages is not something either can assume. Give
   each use a one-line fallback so a missing helper degrades rather than
   breaking first load, e.g.
   `const only = globalThis.RheoRehydrate?.only ?? ((p, s, make) => { p.querySelectorAll(s).forEach(n => n.remove()); const el = make(); p.append(el); return el; });`
3. Add the `init` early-return of problem 1.
4. Route both appends through `only()` per problem 2.
5. Split first-load from rehydrate per problem 3.
6. Handle the Reveal event registrations per problem 4.
7. Register the callback at the boot block with
   `(globalThis.__rheoRehydrate ??= []).push(...)`. Use `globalThis`, never
   `window`: reading `window` at module-evaluation time throws under node.
8. Add `js_rehydrate = true` to `[tool.rheo.html]` in
   `slides/0.1.1/typst.toml`. This package has **no**
   `[tool.rheo.source.html]` block; do not add one.
9. Note the change in `readme.md`.

## Non-goals

- **Do not touch `slides/0.1.0/`.** Released versions are immutable here.
- **Do not upgrade, vendor or reconfigure Reveal.js**, and do not change the
  theme handling or the `themes`/`themeMap` module constants.
- **Do not add a test suite or a demo fixture.** This package has neither, and
  building one is its own piece of work — file it separately if you think it is
  needed.
- **Do not update any consuming project's import spec.** A separate bird in the
  `waterline` repo owns that.
- **Do not commit `dist/`.** It is gitignored.

## Honest uncertainty

Two things this bird cannot promise:

- Step 2 depends on rheo resolving a package's own `@`-imports transitively, so
  that depending on `@rheo/rehydrate` is enough to get its script on the page.
  That is bird `rheo-resolves-a-package-s-own-package-imports-00b44cf9` in the `rheo` repo and is not in place until it lands. The
  fallbacks in step 2 are what keep this package correct meanwhile. Report the
  helper being absent; do not copy its code into this package.
- Whether `Reveal.sync()` and `Reveal.off()` exist depends on the Reveal.js
  version this package loads. Check before relying on either, guard the call,
  and if neither is available say so in your report rather than leaving a
  silent no-op.

Because this package has no tests, the behaviour in problem 3 is **not**
verifiable by the commands below. State clearly in your report that
first-load-versus-rehydrate was verified by reading only, and describe what a
reader should check by hand in a browser.

## VERIFY

```bash
cd /home/lox/code/_fcl/rheo-packages/slides/0.1.1
just build
```

Must succeed. Then confirm the declaration, the early-return and the
registration are present, and the repo's specs are consistent:

```bash
rg -n 'js_rehydrate' /home/lox/code/_fcl/rheo-packages/slides/0.1.1/typst.toml
rg -n '__rheoRehydrate' /home/lox/code/_fcl/rheo-packages/slides/0.1.1/src
rg -n "querySelector\('.reveal'\)" /home/lox/code/_fcl/rheo-packages/slides/0.1.1/src
cd /home/lox/code/_fcl/rheo-packages && just check-versions
```

The first three must hit; `check-versions` must pass. Then confirm
`Reveal.initialize` is reached from exactly one path, by reading the file and
stating in your report which path that is.