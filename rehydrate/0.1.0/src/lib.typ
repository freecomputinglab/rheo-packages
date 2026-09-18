// `@rheo/rehydrate` is a JavaScript-only package. A package depends on it to
// get `dist/lib.js` (or `src/lib.js` in source mode) injected into the page and
// then calls `RheoRehydrate.*` from its own script — never from Typst.
//
// The emptiness is deliberate, not an oversight: there is no Typst API to
// expose. This file exists because `typst.toml` requires an entrypoint, and
// removing it would make the package unimportable.
