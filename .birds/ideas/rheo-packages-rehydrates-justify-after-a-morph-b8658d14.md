---
id: rheo-packages-rehydrates-justify-after-a-morph-b8658d14
short-id: b8
title: Rehydrates justify after a morph
priority: 4
labels:
- rehydrate-justify
deps:
- blocked-by:rheo-packages-ships-the-rehydrate-helper-package-9ffb793f
closed: false
---
Touches: justify/0.1.2/typst.toml, justify/0.1.2/src/lib.ts, justify/0.1.2/package.json, justify/0.1.2/readme.md

Cut `@rheo/justify:0.1.2` and make it rebuild its own justification after
`rheo watch` patches a page, instead of leaving the page with rheo falling back
to a full reload.

## The background a worker needs

`rheo watch` no longer reloads the page on a content edit. It refetches the page
and morphs the new HTML into the live DOM, which preserves scroll, focus and
selection. Two consequences:

- **Scripts are not re-executed**, and the markup that arrives is the
  *pre-hydration* build output — so this package's justified text (it rewrites
  `textContent` with NBSP-encoded line breaks) is reverted to the plain source
  text and nothing re-runs to re-justify it.
- **Elements are mutated in place** where the morph can match them, so
  listeners bound to surviving nodes **survive**; re-wiring naively double-fires.

A package opts in by declaring `js_rehydrate = true` in its
`[tool.rheo.<format>]` block and pushing a callback onto
`globalThis.__rheoRehydrate`. rheo renders declaring scripts with
`data-rheo-rehydrate`, surveys **every** script on a page before morphing, and
reloads instead if any one is undeclared — so one unmigrated package on a page
is enough to deny the whole page a patch. The protocol is documented in
`/home/lox/code/_fcl/rheo/docs/contract.md` under
`Dev-server rehydrate protocol`.

This package is the easy case: it already stores each block's original text in
a `WeakMap` so re-runs measure the pristine string, and its `init` already
early-returns when the page carries no justified blocks.

## Version bump, not an in-place edit

`justify/0.1.1` is a **released version** — the tag `justify-0.1.1` exists — and
this repo treats a released version as permanent and immutable (see
`/home/lox/code/_fcl/rheo-packages/CLAUDE.md`). So this bird cuts `0.1.2`.

Use the root `Justfile`'s bump recipe, which copies the version directory and
rewrites every `@rheo/justify:<ver>` spec in the repo. One hit at line 108 as
of filing:

```bash
rg -n '^bump PKG OLD NEW:' /home/lox/code/_fcl/rheo-packages/Justfile
```

```bash
cd /home/lox/code/_fcl/rheo-packages && just bump justify 0.1.1 0.1.2
```

Do all the work below in `justify/0.1.2/`. **Leave `justify/0.1.1/` and
`justify/0.1.0/` completely untouched.**

## A trap that will waste your time if you skip this

`src/lib.ts` contains NUL bytes (lines 111, 116 and 172 as of filing — they are
sentinels in the justification encoder). Both `rg` and `grep` therefore treat
the file as **binary and print nothing at all**, silently, for every search.
Pass `-a` to search it:

```bash
rg -a -n 'pristineText' /home/lox/code/_fcl/rheo-packages/justify
```

A search without `-a` returning nothing is the tool refusing to read the file,
not the text being absent. Do not conclude an anchor is missing on that basis.

## Locate the sites

All anchors below are in `justify/0.1.2/src/lib.ts` after the bump, and each
was confirmed to be a single hit in the `0.1.1` source at filing time. Search
with `-a`, scoped to the package directory so a rename still resolves. If an
anchor genuinely does not hit, widen to
`/home/lox/code/_fcl/rheo-packages` and report the miss rather than
inventing a replacement site.

- **The pristine-text store** — line 47 as of filing. Landmark: module scope.

  ```bash
  rg -a -n 'const pristineText = new WeakMap' /home/lox/code/_fcl/rheo-packages/justify
  ```

- **The early-return when the page has no justified blocks** — line 417 as of
  filing. Landmark: the `init` function. Note the file also contains two
  `if (words.length === 0) return;` lines; this one says `blocks`.

  ```bash
  rg -a -n 'if (blocks.length === 0) return;' /home/lox/code/_fcl/rheo-packages/justify
  ```

- **Where a block is registered with the shared ResizeObserver** — line 431 as
  of filing. Landmark: the `init` function.

  ```bash
  rg -a -n 'observer.observe(el);' /home/lox/code/_fcl/rheo-packages/justify
  ```

- **The font-loading listener** — line 437 as of filing. Landmark: the `init`
  function. It is bound to `document.fonts`, which no morph ever replaces, so
  it is the one listener here that accumulates.

  ```bash
  rg -a -n 'loadingdone' /home/lox/code/_fcl/rheo-packages/justify
  ```

- **The boot block** — line 442 as of filing. Landmark: module scope, the last
  statement in the file.

  ```bash
  rg -a -n 'if (document.readyState === "loading")' /home/lox/code/_fcl/rheo-packages/justify
  ```

## Steps

1. Add `@rheo/rehydrate:0.1.0` as a dependency: import it in `src/lib.typ` so
   rheo injects its JavaScript, and use its helpers from `src/lib.js`/`lib.ts`
   via the global `RheoRehydrate`, read **inside** your functions rather than at
   module-evaluation time. Script execution order between two packages is not
   something either can assume, so a module body that reads the global is a
   bug; a function called after a morph is safe. Give each use a one-line
   fallback so a missing helper degrades instead of breaking first load, e.g.
   `const wiring = globalThis.RheoRehydrate?.wiring ?? (() => new AbortController().signal);`

   The helper's three functions: `wiring(key)` returns an `AbortSignal`,
   aborting the previous one issued for that key; `only(parent, selector, make)`
   ensures exactly one matching child; `rehydrate(fn)` registers a post-morph
   callback.

2. Scope the `document.fonts` `loadingdone` listener to
   `{ signal: wiring(document) }` so a second pass replaces it rather than
   adding a second copy.

3. The `ResizeObserver` is shared and created once at module scope. It does not
   need re-creating, but the set of blocks it observes does: after a morph the
   observed elements may be different nodes. Re-running `init` calls
   `observer.observe(el)` again, which is idempotent per element in the
   platform — but any element the morph *replaced* is still observed as a dead
   node. Call `observer.disconnect()` before re-observing on a rehydrate pass,
   and leave first load unchanged.

4. Register the rehydrate callback at the boot block, beside the existing
   `readyState` check, with `(globalThis.__rheoRehydrate ??= []).push(init)` —
   or `RheoRehydrate.rehydrate(init)` if you read the global lazily. Use
   `globalThis`, never `window`: reading `window` at module-evaluation time
   throws under node, where these suites run.

5. Confirm re-running `init` is idempotent. It early-returns with no blocks, it
   re-reads pristine text from the `WeakMap`, and it writes `textContent` and
   inline styles rather than appending anything — so it should already be safe.
   **Verify this rather than assuming it**, and if you find a create-and-append
   anywhere in the boot path, route it through `only()`.

6. Add `js_rehydrate = true` to `[tool.rheo.html]` in
   `justify/0.1.2/typst.toml`. This package has **no** `[tool.rheo.source.html]`
   block; do not add one.

7. Note the change in `readme.md`.

## Non-goals

- **Do not touch `justify/0.1.1/` or `justify/0.1.0/`.** Released versions are
  immutable here.
- **Do not change the justification algorithm**, the Knuth-Plass core, the
  hyphenation, the encoder, or any measurement cache. The four module-level
  measurement caches are keyed by font and text and stay correct across a
  morph; leave them alone.
- **Do not remove the NUL-byte sentinels** in the encoder.
- **Do not update any consuming project's import spec.** A separate bird in the
  `waterline` repo owns that.
- **Do not commit `dist/`.** It is gitignored.

## Honest uncertainty

Step 1 depends on rheo resolving a package's own `@`-imports transitively so
that depending on `@rheo/rehydrate` is enough to get its script onto the page.
That is bird `rheo-resolves-a-package-s-own-package-imports-00b44cf9` in the `rheo` repo and is **not** in place until it lands.
If you find the helper's global is absent at runtime, that is the expected
symptom of `rheo-resolves-a-package-s-own-package-imports-00b44cf9` not having landed — the fallbacks in step 1 are what keep
this package correct in the meantime. Report it; do not work around it by
copying the helper's code into this package.

## VERIFY

```bash
cd /home/lox/code/_fcl/rheo-packages/justify/0.1.2
just build
```

Must succeed. Then confirm the declaration and the registration are present,
and that the repo's version specs are consistent:

```bash
rg -n 'js_rehydrate' /home/lox/code/_fcl/rheo-packages/justify/0.1.2/typst.toml
rg -a -n '__rheoRehydrate' /home/lox/code/_fcl/rheo-packages/justify/0.1.2/src
cd /home/lox/code/_fcl/rheo-packages && just check-versions
```

The first two must hit. `check-versions` must pass. Finally, confirm no
`window.` reference was introduced at module scope in the boot path:

```bash
rg -a -n 'window.__rheoRehydrate' /home/lox/code/_fcl/rheo-packages/justify/0.1.2/src
```

That must return nothing.