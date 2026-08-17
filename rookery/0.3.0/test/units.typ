// Unit fixture for the pure, state-free helpers in `/src/lib.typ`.
//
// Every case below pins a MEASURED defect recorded in that file's own comments,
// named in the comment above the assertion. This is a regression suite: a case
// is here because the behaviour was once wrong, not to describe the API.
//
// Run it with `just test` from `rookery/0.3.0`. There is no runner and no JS:
// `assert.eq` fails the compile with a line number, which is the whole harness.
// `--features html` is mandatory even though nothing here compiles to HTML —
// `std.target` is gated by the feature rather than the output format, and
// `/src/lib.typ` reads it at import time (see lib.typ:24-35).
//
// SCOPE: helpers that are pure functions of their arguments, plus the two that
// read one document-wide state (`_note-file` via `_pfx`, `_bib-keys` via
// `_bib`). Anything needing `query`/`context` convergence — `#idea`, `#window`,
// `_page-links`, `_ideas-outline-data` — is out of scope here and belongs to the
// demo-based beads.

#import "/src/lib.typ": (
  _bib, _bib-keys, _blocks, _body-plain, _body-text, _dedup-tag, _join,
  _nest-outline, _norm, _note-file, _plain, _sort-ids, _tag-pred,
)

// ---- _norm — bare name, full id, label, and a name with its own colon ------
// `_norm` splits on the FIRST colon only, so an id whose name contains one
// survives intact.
#assert.eq(_norm("etal"), "etal")
#assert.eq(_norm("idea:etal"), "etal")
#assert.eq(_norm(<idea:etal>), "etal")
#assert.eq(_norm("idea:a:b"), "a:b")

// ---- _dedup-tag — `#todo("x", tags: ("todo",))` must not double the tag ----
// A duplicate here reaches the heading as a duplicated `idea-tag-todo` class.
#assert.eq(_dedup-tag("todo", ("todo",)), ("todo",))
#assert.eq(_dedup-tag("todo", ()), ("todo",))
#assert.eq(_dedup-tag("note", ("draft",)), ("note", "draft"))
#assert.eq(_dedup-tag("note", ("draft", "note")), ("draft", "note"))

// ---- _join — `array.join()` returns none on an empty array -----------------
// The crash this pins: an empty-bodied note (`#idea("x")[]`) walked to a
// `sequence` with zero children, `.join()` gave `none`, and the caller's
// `.replace(...)` failed.
#assert.eq(_join(()), "")
#assert.eq(_join(("a", "b")), "ab")

// ---- _plain — a `raw` span must contribute its text, not a hole ------------
// MEASURED defect: "The  marker" (two spaces) where `raw` fell through to "".
#assert.eq(_plain(none), "")
#assert.eq(_plain("x"), "x")
#assert.eq(_plain([The #raw("marker") marker]), "The marker marker")

// ---- _body-text / _body-plain — block boundaries, and the empty body -------
// MEASURED defect: "raw code.A second paragraph" — a `parbreak` contributed
// nothing, gluing two blocks into one word.
#assert.eq(_body-plain([]), "")
#assert.eq(_body-plain([A.#parbreak()B.]), "A. B.")
#assert.eq(
  _body-plain[
    - one
    - two
  ],
  "one two",
)
// `metadata` contributes nothing: `#idea`'s own marker sits inside the body.
#assert.eq(_body-plain([A#metadata((k: 1))B]), "AB")

// ---- _blocks — the styled unwrap, item grouping, whitespace ---------------
// MEASURED REGRESSION (v6y.7): every registry body goes through `_flatten`,
// which wraps it in a `show`-rule scope Typst represents as a `styled` node
// with no children. Without the unwrap `_blocks` returned one block for every
// body, silently disabling `limit:` truncation everywhere.
// Built in a CODE block, not markup: `[#show ..; body]` puts the `styled` node
// under a leading space inside a sequence, where `_blocks` never had a problem.
// `_flatten` wraps the whole body, so the `styled` node is the ROOT — which is
// the shape that broke, and the shape this reproduces.
#let _styled-two-blocks = {
  show emph: it => it
  [First.#parbreak()Second.]
}
#assert.eq(_blocks(_styled-two-blocks).len(), 2)
// Consecutive `item`s are ONE block, so `limit:` cannot cut a list in half.
// Children here are `space text space parbreak space item space item space`, so
// this holds only because a `space` between two items no longer clears the run:
// it is list punctuation, not a block boundary (bead rheo-packages-rtd.1).
#let _text-then-list = [
  Intro.
  #parbreak()
  - a
  - b
]
#assert.eq(_blocks(_text-then-list).len(), 2)
// A `parbreak` between two items DOES end the list — that is the one whitespace
// kind that still clears the run. Children: `space item parbreak item space`.
#let _list-parbreak-list = [
  - a

  - b
]
#assert.eq(_blocks(_list-parbreak-list).len(), 2)
// `+` and `/ term:` rows are `item` children too, so they group the same way.
#let _text-then-enum = [
  Intro.

  + one
  + two
]
#assert.eq(_blocks(_text-then-enum).len(), 2)
#let _text-then-terms = [
  Intro.

  / a: x
  / b: y
]
#assert.eq(_blocks(_text-then-terms).len(), 2)
// `space` and `parbreak` are separators, never blocks of their own.
#assert.eq(_blocks([A.#parbreak()#parbreak()B.]).len(), 2)
// A childless body is one block, itself.
#assert.eq(_blocks([A]).len(), 1)

// ---- _tag-pred — an EMPTY tags array is no filter, not match-nothing ------
#assert.eq(_tag-pred(none, "any"), none)
#assert.eq(_tag-pred((), "any"), none)
#assert(_tag-pred("phd", "any")(("phd", "draft")))
#assert(not _tag-pred("phd", "any")(("draft",)))
#assert(_tag-pred(("a", "b"), "any")(("b",)))
#assert(not _tag-pred(("a", "b"), "all")(("b",)))
#assert(_tag-pred(("a", "b"), "all")(("a", "b", "c")))

// ---- _sort-ids — date-descending, undated last, ties ASCENDING by id ------
// The tie rule is why the function groups by stamp instead of sorting twice.
#let _reg = (
  "idea:a": (minted: datetime(year: 2026, month: 1, day: 2)),
  "idea:b": (minted: datetime(year: 2026, month: 3, day: 4)),
  "idea:c": (minted: datetime(year: 2026, month: 1, day: 2)),
  "idea:d": (:),
)
#assert.eq(
  _sort-ids(("idea:d", "idea:c", "idea:b", "idea:a"), _reg, "date"),
  ("idea:b", "idea:a", "idea:c", "idea:d"),
)
#assert.eq(
  _sort-ids(("idea:b", "idea:d", "idea:a"), _reg, "lexicographic"),
  ("idea:a", "idea:b", "idea:d"),
)

// ---- _nest-outline — a level JUMP nests, it does not become a sibling -----
// The flat run is depth-tagged; a 1 -> 3 jump must still read as a child, which
// is what makes `_prune-outline`-style rebasing necessary rather than optional.
#assert.eq(
  _nest-outline(
    ((depth: 0, id: "a"), (depth: 1, id: "b"), (depth: 3, id: "c"), (depth: 0, id: "d")),
    (items, root) => items,
    (e, sub) => (id: e.id, sub: sub),
  ),
  (
    (id: "a", sub: ((id: "b", sub: ((id: "c", sub: none),)),)),
    (id: "d", sub: none),
  ),
)

// ---- _note-file — the path mirrors the `ideas:<slug>` handle --------------
// Reads `_pfx()`, hence the `context`. Only the DEFAULT prefix is exercised:
// `_pfx` resolves `_prefix.final()`, which is document-wide, so a fixture
// cannot hold two prefixes at once — an override belongs to a demo build.
#context {
  assert.eq(_note-file("idea:etal"), "ideas/etal.html")
  assert.eq(_note-file("etal"), "ideas/etal.html")
}

// ---- _bib-keys — BibTeX headers, and the Hayagriva-YAML fallback ----------
// A KEY-EXISTENCE CHECK, not a parser: format is detected from CONTENT, because
// `bytes` carry no filename. Both branches in one call, since `_bib` is
// document-wide and its first positional may be an ARRAY of sources.
#_bib.update(arguments((
  bytes("@article{smith2020,\n  title = {A Title},\n  author = {Smith},\n}\n"),
  bytes("jones2021:\n  type: article\n  title: Another Title\n"),
)))
#context {
  assert.eq(_bib-keys(), ("smith2020", "jones2021"))
}
