// bib.typ — bibliography: the per-idea References block, the sweep block
// that claims a prose citation written BEFORE an idea, and the trailing-
// prose block that claims one written after the LAST idea/window on the
// page (lib.typ:757 `_refs-block`, :783 `_sweep-block`, :2743 the trailing
// block inside `rookery`).
//
// `_bib` is document-wide state (lib.typ:309), like `_prefix`/`_theme`, so
// this file assumes whatever includes it has already applied
// `#show: rookery.with(bibliography: arguments(bytes(read("refs.bib")), ..))`
// — see root.typ and paged.typ, both of which `#include` this file. The
// PAGED target is the one that matters most here: a citation with no
// bibliography anywhere is a HARD ERROR there (`label <key> does not exist
// in the document`, lib.typ:1564), so paged.typ including this file is what
// actually proves the combined-PDF path doesn't regress into that error.
#import "../../src/lib.typ": idea

// A citation in ordinary page prose, BEFORE an idea — unclaimed until the
// next idea's own UNCONDITIONAL sweep block claims it, so it doesn't leak
// into that idea's own References list.
Some prose citing Beta directly: @beta2021.

#idea("cited", title: [Cited])[
  This note cites Gamma @gamma2019 in its own body, producing its own
  References block.
]

// Trailing prose citation — AFTER the last idea/window on the page, with
// nothing following to claim it. Claimed by the document-wide trailing
// block `#show: rookery` emits only when something is actually left.
A trailing citation with nothing after it: @beta2021.
