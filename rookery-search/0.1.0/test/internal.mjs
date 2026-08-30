// Bridges the module-private helpers this suite unit-tests — `matchRanges`,
// `selection`, `extractNote`.
//
// It used to read `src/rookery-search.js` as TEXT, append a throwaway
// `export {...}` naming those three top-level `const`s, write that to a temp
// file and import it. That trick existed because the whole package was one flat
// module with no way to address a private binding from outside it.
//
// Since the split there is a better answer: each of the three lives in a module
// of its own and is exported there for exactly this reason. This file is now a
// plain re-export, and the temp-file dance is gone — along with its one real
// hazard, which the split would have tripped anyway: the temp copy landed in
// `os.tmpdir()`, where a relative `import "./text.js"` cannot resolve.
//
// They are deliberately NOT re-exported from `src/rookery-search.js`: the
// package's public surface is what that entrypoint exports, and a test's need to
// reach inside is not a reason to widen it.
export { matchRanges } from "../src/marks.js";
export { selection } from "../src/selection.js";
export { extractNote } from "../src/preview.js";
export { renderRow } from "../src/row.js";
export { passesTags } from "../src/panel.js";
