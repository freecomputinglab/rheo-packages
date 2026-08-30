// excluded.typ — `exclude-tags:` on `#idea` and `#tagged-idea`
// (src/idea.typ's exclusion gate), the `_resolve-excluded` composition
// (src/base.typ), and `_excluded-ids` (src/state.typ).
//
// WHAT THIS ROOT ASSERTS, and it is asserted by grep from
// `demo/pure/Justfile`'s own recipe rather than by an `assert` in here: an
// excluded note must be ABSENT, not hidden. Neither its body text nor its id
// may appear anywhere in the output, and `#ideas()` must not see it — which is
// the one assertion that also covers the registry, and through it every minted
// page, the search index and the feeds beacon.
//
// COMPILED TWICE by that recipe, from this one file:
//
//   build/excluded.html        no `--input`  -> `private` notes dropped
//   build/excluded-dev.html    `--input rookery-include=private` -> kept
//
// That pair is the whole feature in one place, and this demo is the only test in
// the repo that can make it: `rheo compile` forwards no `--input` today (see
// `_resolve-excluded`'s banner), so `demo/rheo` cannot vary the env half at all.
#import "../../src/lib.typ": hyperlink, idea, idea-body, ideas, rookery, tagged-idea, window

#show: rookery

// THE PROJECT PATTERN, verbatim as the readme documents it — two bindings
// sharing one list. Binding only `idea` would leave `#note` hatching the very
// notes this asks to exclude, because `tagged-idea` calls the `idea` captured in
// PACKAGE scope. That is the trap the second line exists to close.
#let EX = ("private",)
#let idea = idea.with(exclude-tags: EX)
#let note = tagged-idea("note", exclude-tags: EX)

= Excluded notes

#idea("keeper")[KEEPBODY, and this note survives every build.]

// Dropped by the default build, restored by `--input rookery-include=private`.
#idea("gone", tags: ("private",))[DROPBODY]

// The same through a `tagged-idea` wrapper, which is the case a project gets
// wrong if `exclude-tags:` is bound on `idea` alone.
#note("gone2", tags: ("private",))[DROPBODY2]

// A VALUED tag excludes exactly as a plain one does — the names are the keys.
#idea("gone3", tags: (private: (owner: "me")))[DROPBODY3]

// LINKS TO AN EXCLUDED NOTE, which are what make the exclusion usable rather
// than merely correct. Each of these panicked `unknown note 'idea:gone'` before
// the degradation landed, so a public build failed wherever a surviving page
// pointed at a removed one. `#window` and `#idea-body` now render nothing;
// `#hyperlink` renders its body UNLINKED, because it sits inline in a sentence
// and deleting it would break the author's grammar.
//
// The `@idea:gone` MARKUP form is deliberately absent and always will be: it is
// a Typst `ref` to a label minted by the very `#idea` that got removed, so it is
// a hard `label does not exist` error this package cannot intercept.
#window("gone")

Prose pointing at #hyperlink("gone")[HLBODY] mid-sentence, which survives as
plain text with no link around it.

#context idea-body("gone")

// A surviving note windows fine alongside all that.
#window("keeper")

// A genuine TYPO still panics — the distinction `_excluded-ids` exists to draw.
// Not written live here, since it would fail this build by design; exercised by
// hand per the bead's VERIFY.

#context [count=#ideas().len()]
