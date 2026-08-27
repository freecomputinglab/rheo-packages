// titles.typ — DERIVED TITLES (`_derived-title`, src/pure.typ; `resolved-title`
// in src/idea.typ).
//
// A note with no `title:` takes the first 60 characters of its body as plain
// text, with `...` when there is more. Asserted by grep from this demo's own
// `Justfile` check recipe against `build/root.html`:
//
//   - the SHORT body appears verbatim as an `.idea-title` and ends in no ellipsis;
//   - the LONG body is cut to exactly 60 characters and ends in `...`;
//   - an EMPTY body derives nothing, so that note has no `.idea-title` at all —
//     the one case the package's `h*.idea:empty` CSS is still reached by;
//   - the derived title reaches `#ideas-outline` too, where an untitled note used
//     to be skipped outright.
#import "../../src/lib.typ": idea, ideas-outline

== Derived titles

// Under the limit: verbatim, no ellipsis. 46 characters.
#idea[DTSHORT and this body is well under the limit.]

// Over it: cut to 60 and given an ellipsis. The marker plus a run of `x` makes
// the cut point countable by eye and by grep.
#idea[DTLONG #("x" * 80)]

// Nothing to derive from, so this one stays untitled — and must NOT gain an empty
// title span.
#idea("dt-empty")[]

// The outline reads the same derived titles, which is the half no card can show.
#ideas-outline()
