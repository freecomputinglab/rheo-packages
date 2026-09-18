# `@rheo/rehydrate`

Three primitives for surviving a `rheo watch` DOM morph, written and tested
once instead of hand-rolled per package.

**This package is an optimisation.** A package that does not use it still works
correctly — it just declines the patch and takes a full page reload on every
content edit. Nothing breaks by not depending on this; a reload is slower and
loses scroll position, focus and selection.

## Why a package needs any of this

`rheo watch` refetches an edited page and morphs the new HTML into the live DOM
rather than reloading. Two consequences:

- **No script is re-executed**, and the bytes patched in are the
  *pre-hydration* build output. Everything a package did at boot is reverted,
  with nothing left to redo it.
- **Elements are mutated in place** wherever the morph can match them, so
  listeners bound to surviving nodes survive. Wiring a surviving element a
  second time makes one click fire two handlers.

A package opts in by declaring `js_rehydrate = true` in its
`[tool.rheo.<format>]` block and registering a callback. rheo surveys every
script on a page before morphing and falls back to a reload if any one of them
has not declared itself, so one undeclared script disqualifies the whole page.

## The surface

### `rehydrate(fn)`

Registers `fn` to run after each morph. Usually the package's own `boot`.

### `wiring(key)` → `AbortSignal`

One wiring pass for `key`, aborting the previous signal issued for that same
key. Pass it to every listener the pass adds and the next call drops all of
them at once.

`key` is any object: a widget's container element, or `document` for page-level
listeners that no morph ever replaces.

### `only(parent, selector, make)` → `Element`

Removes every existing `selector` match under `parent`, calls `make()`, appends
the result, and returns it. The duplicate-append guard — without it, a boot
that appends an element appends another copy on every re-run.

## Usage

```js
import { rehydrate, wiring, only } from "@rheo/rehydrate";
// Or, from a release, the global the IIFE publishes:
// const { rehydrate, wiring, only } = globalThis.RheoRehydrate;

const boot = () => {
  for (const container of document.querySelectorAll(".my-widget")) {
    const signal = wiring(container);

    const button = only(container, ".my-toggle", () => {
      const el = document.createElement("button");
      el.className = "my-toggle";
      el.textContent = "Toggle";
      return el;
    });

    button.addEventListener("click", onToggle, { signal });
  }

  // `document` as the key, for a listener no morph replaces.
  document.addEventListener("keydown", onKey, { signal: wiring(document) });
};

boot();
rehydrate(boot);
```

And in `typst.toml`:

```toml
[tool.rheo.html]
js_scripts = "dist/lib.js"
js_rehydrate = true
```

## Tearing down something that is not a listener

A timer, an observer or a subscription is not dropped by an `AbortSignal` on
its own. Hang it off the signal you already hold rather than tracking it
separately:

```js
const signal = wiring(container);
const timer = setInterval(tick, 1000);
signal.addEventListener("abort", () => clearInterval(timer), { once: true });
```

This is deliberately not a fourth export — the idiom is two lines and wrapping
it would hide which signal owns the teardown.

## Requirements

Needs rheo **0.6.4** or newer, the release that understands `js_rehydrate`. An
older rheo ignores the key and reloads the page instead, which is why
`typst.toml` declares the floor.
