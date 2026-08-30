// titles.typ — DERIVED LABELS (`_derived-title`, src/pure.typ; `note-label` in
// src/idea.typ, and `ideas().label` in src/data.typ).
//
// A note with no `title:` gets a naming LABEL from its body: the first 60
// characters as plain text, with `...` when there is more. It is used wherever the
// note is REFERRED TO — an outline entry, an index row, a minted page's `<title>`,
// a feed item, the text of a link — and deliberately NOT as the note's own
// heading, because the body is right there below it. Printing it there printed the
// text twice, which is the defect the title/label split fixed.
//
// Asserted by grep from this demo's own `Justfile` check recipe against
// `build/root.html`:
//
//   - the SHORT body's label appears verbatim in an `#ideas-outline` entry;
//   - the LONG one is cut to exactly 60 characters and ends in `...`;
//   - NO `.idea-title` span carries either — that is the no-duplication guard;
//   - an EMPTY body has no label at all, so that note stays out of the outline and
//     keeps the empty heading `h*.idea:empty` collapses.
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
