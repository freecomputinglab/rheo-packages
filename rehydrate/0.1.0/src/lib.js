// @rheo/rehydrate — the three things a package needs in order to survive
// `rheo watch` patching a page instead of reloading it.
//
// A morph re-executes no script, and the bytes it patches in are the
// PRE-HYDRATION build output, so everything a package did at boot is reverted
// with nothing left to redo it. A package therefore re-runs its own boot from a
// `globalThis.__rheoRehydrate` callback (`rehydrate` below).
//
// And because a morph mutates elements IN PLACE wherever it can match them,
// listeners bound to surviving nodes SURVIVE it. A second pass over a surviving
// element makes one click fire two handlers, and a boot that appends an element
// appends a second copy. `wiring` and `only` are the guards for those two.
//
// NOTHING HERE TOUCHES `document`, `window` OR `__rheoRehydrate` AT MODULE
// EVALUATION TIME. Node suites in this ecosystem import this module with a
// `document` supplied and no `window` at all, so `window` is never read and the
// hook array is created only when `rehydrate` is actually called.

// A WeakMap rather than a property on the key: where a morph REPLACES an
// element instead of matching it, the entry dies with the node and the fresh
// node is correctly unwired rather than inheriting a stale signal.
const wirings = new WeakMap();

// One wiring pass for `key`, as an `AbortSignal` to hand to every
// `addEventListener(..., { signal })` the pass adds. Keyed on any object: a
// widget's container element, or `document` for page-level listeners no morph
// ever replaces.
export function wiring(key) {
  // Aborted BEFORE the replacement exists, so a re-wire cannot briefly have two
  // live wirings racing on one key.
  wirings.get(key)?.abort();
  const pass = new AbortController();
  wirings.set(key, pass);
  return pass.signal;
}

// Ensure exactly one `selector` child of `parent`, built by `make()`. Returns
// the element it appended.
//
// The duplicate-append guard: without it a boot that creates and appends an
// element adds another copy on every re-run, since the morph left the previous
// one in place.
export function only(parent, selector, make) {
  for (const existing of parent.querySelectorAll(selector)) existing.remove();
  const made = make();
  parent.append(made);
  return made;
}

// Register `fn` to run after each morph.
//
// `??=` rather than an assignment: load order between rheo's live client and
// this module is not something either end can assume, so whichever arrives
// first creates the array.
export function rehydrate(fn) {
  (globalThis.__rheoRehydrate ??= []).push(fn);
}

// THE GLOBAL, PUBLISHED IN SOURCE MODE TOO. `vite.config.js` builds an IIFE
// named `RheoRehydrate`, so a release carries this object; a project consuming
// `src/lib.js` through a repo- or path-backed namespace gets ES modules, and
// this assignment is what gives it the same surface. The surface is a property
// of the package rather than of how it was installed.
//
// `??=` so the IIFE's own assignment wins where both run, and guarded on
// `typeof document` rather than on `window`, because node imports this module
// with a document and no window — reading `window` here would throw there on an
// access every real page satisfies for free.
if (typeof document !== "undefined") {
  globalThis.RheoRehydrate ??= { wiring, only, rehydrate };
}
