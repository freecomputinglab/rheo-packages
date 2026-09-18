---
id: rheo-packages-ships-the-rehydrate-helper-package-9ffb793f
short-id: 9f
title: Ships the rehydrate helper package
priority: 5
labels:
- rehydrate-helper-package
deps: []
closed: true
---
Touches: rehydrate/0.1.0/typst.toml, rehydrate/0.1.0/package.json, rehydrate/0.1.0/vite.config.js, rehydrate/0.1.0/Justfile, rehydrate/0.1.0/readme.md, rehydrate/0.1.0/src/lib.typ, rehydrate/0.1.0/src/lib.js, rehydrate/0.1.0/test/rehydrate.test.mjs

A new, small package: `@rheo/rehydrate:0.1.0`. It holds the three things every
package has had to hand-roll in order to survive `rheo watch` patching a page,
so that each one is written and tested once.

## The background a worker needs

`rheo watch` no longer reloads the page on a content edit. It refetches the
page and morphs the new HTML into the live DOM with Idiomorph, which preserves
scroll, focus and selection — but has two consequences a package must handle:

- **Scripts are not re-executed.** The page bytes that arrive are the
  *pre-hydration* build output, so anything a script did at boot is reverted
  and nothing re-runs to redo it.
- **Elements are mutated in place** where the morph can match them, so event
  listeners bound to surviving nodes **survive**. Wiring a surviving element a
  second time makes one click fire two handlers.

So a package opts in by declaring `js_rehydrate = true` in its
`[tool.rheo.<format>]` block and pushing a callback onto
`globalThis.__rheoRehydrate`. rheo renders declaring scripts with
`data-rheo-rehydrate`, surveys every script on a page before morphing, and
falls back to a full reload if any one of them is undeclared. The protocol is
documented in `/home/lox/code/_fcl/rheo/docs/contract.md` under
`Dev-server rehydrate protocol`.

Four packages in the sibling `rookery` repo already implement this by hand,
and the same three patterns appear in each. This package is those patterns.

## The surface — exactly three exports

1. **`wiring(key)` → `AbortSignal`.** Keyed on any object (an element, or
   `document` for page-level listeners). Aborts the previous signal issued for
   that same key, then returns a fresh one. Callers pass it as
   `addEventListener(..., { signal })`, so one call drops every listener the
   previous pass added. Back it with a `WeakMap`, not a property on the
   element: where a morph *replaces* an element instead of matching it, the
   entry dies with the node and the fresh node is correctly unwired.

2. **`only(parent, selector, make)` → Element.** Removes every existing
   `parent.querySelectorAll(selector)` match, calls `make()`, appends the
   result to `parent`, returns it. This is the duplicate-append guard: a boot
   that creates and appends an element adds a second copy on every re-run
   otherwise, which is a real defect in at least three packages today.

3. **`rehydrate(fn)`.** Pushes `fn` onto `globalThis.__rheoRehydrate`, creating
   the array with `??=` if absent.

## Two constraints that are not optional

- **Use `globalThis`, never `window`.** The node test suites in this ecosystem
  supply a `document` and no `window`, so reading `window` at module-evaluation
  time throws there while working on every real page. This exact mistake has
  already been made and fixed once.

- **Every export must be safe to call before a DOM exists.** The package is
  imported by node test suites. `wiring` and `only` may assume they are handed
  live objects when called, but merely *importing* the module must not touch
  `document`, `window` or `globalThis.__rheoRehydrate`.

## Repository conventions to follow

The repo's own `CLAUDE.md` at `/home/lox/code/_fcl/rheo-packages/CLAUDE.md` is
authoritative; the parts that matter here:

- Packages live at `<name>/<version>/`. Create `rehydrate/0.1.0/`.
- `src/` is checked in; **`dist/` is gitignored** and built by
  `just build`, which runs `pnpm install && pnpm run build`.
- Every `@rheo/<pkg>:<x.y.z>` spec written anywhere must name a directory that
  exists. The root `Justfile` validates this — one hit at line 44 as of filing:

  ```bash
  rg -n '^check-versions:' /home/lox/code/_fcl/rheo-packages/Justfile
  ```

Copy the layout from an existing JavaScript package rather than inventing one.
`sitemap/0.1.0/` is the closest model: plain JS source, a `vite.config.js`
building an iife bundle to `dist/lib.js`, and a per-package `Justfile`.

## Steps

1. Create `rehydrate/0.1.0/` with `typst.toml`, `package.json`,
   `vite.config.js`, `Justfile`, `readme.md`, `src/lib.typ`, `src/lib.js`.

2. `src/lib.js` implements the three exports above, as ES module exports, and
   also publishes them as the global `RheoRehydrate` when a `document` exists —
   guarded on `typeof document !== "undefined"` and assigned with `??=` so a
   bundled iife copy wins where both run. This mirrors how
   `@rookery/search`'s `src/search.js` publishes `RookerySearch`; read that file
   for the pattern and the reasoning in its comments.

3. `src/lib.typ` is the Typst entrypoint `typst.toml` requires. It needs no
   user-facing API — a package depends on this one to get its JavaScript
   injected, not to call Typst functions. Keep it minimal and say so in a
   comment, so a later reader does not mistake the emptiness for an oversight.

4. `typst.toml` declares `name = "rehydrate"`, `version = "0.1.0"`,
   `entrypoint = "src/lib.typ"`, and:

   ```toml
   [tool.rheo.html]
   js_scripts = "dist/lib.js"
   js_rehydrate = true

   [tool.rheo.source.html]
   js_scripts = ["src/lib.js"]
   js_module = true
   js_rehydrate = true
   ```

   Both blocks need `js_rehydrate`: rheo merges source over release **per key**,
   so a key absent from the source table is not inherited from the release one.
   Set `[tool.rheo] min_version` to the rheo version that understands
   `js_rehydrate`. If you cannot determine that version, use `"0.6.4"` and say
   in your report that you assumed it.

5. `vite.config.js` builds `src/lib.js` to `dist/lib.js` as an iife exposing
   the global `RheoRehydrate`. Copy `sitemap/0.1.0/vite.config.js` and change
   the entry and global name.

6. `readme.md` documents the three functions with a short usage example, and
   states plainly that the package is an optimisation: a package that does not
   use it still works, it just gets a full page reload instead of a patch.

7. Add `test/rehydrate.test.mjs`, a node suite using `node:test`,
   `node:assert/strict` and `linkedom` for a throwaway document — the shape
   `@rookery/search`'s `test/urlstate.test.mjs` uses. Cover:
   - `wiring` returns an unaborted signal on first call for a key;
   - a second call for the same key aborts the first signal and returns a live one;
   - two different keys do not affect each other;
   - `only` leaves exactly one matching child after being called three times;
   - `only` returns the element it appended;
   - `rehydrate` appends to `globalThis.__rheoRehydrate` and creates the array when absent.

8. Add a `test` recipe to the package `Justfile` running
   `node --test test/*.test.mjs`. Use the glob, not a bare directory: `node
   --test test/` fails on this machine's node.

## Non-goals

- **Do not migrate any other package to use this.** Separate birds own
  `@rheo/justify`, `@rheo/slides` and the four `rookery` packages. This bird
  ships the helper and its tests, nothing else.
- **Do not add a fourth export.** Teardown of a timer belongs on the caller's
  own `signal.addEventListener("abort", ...)`; document that idiom in the
  readme rather than wrapping it.
- **Do not add runtime dependencies.** No npm deps beyond dev tooling.
- **Do not commit `dist/`.** It is gitignored on purpose.
- **Do not edit the root `Justfile`**, and do not run `just bump`.

## Honest uncertainty

This helper is only *reachable* by a depending package once rheo resolves a
package's own `@`-imports transitively, which it does not do yet — that is bird
`rheo-resolves-a-package-s-own-package-imports-00b44cf9` in the `rheo` repo. The package, its bundle and its tests are all
buildable and testable without that, which is why this bird does not wait on
it. Do not try to wire a consumer up as part of this bird.

## VERIFY

```bash
cd /home/lox/code/_fcl/rheo-packages/rehydrate/0.1.0
just build
just test
```

Both must succeed, with the test run reporting `fail 0`. Then confirm the
bundle exposes the global and the version specs are consistent:

```bash
rg -n 'RheoRehydrate' /home/lox/code/_fcl/rheo-packages/rehydrate/0.1.0/dist/lib.js
cd /home/lox/code/_fcl/rheo-packages && just check-versions
```

The first must hit; `check-versions` must pass with no complaint about
`rehydrate`.