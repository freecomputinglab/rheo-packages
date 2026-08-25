// Unit fixture for the pure, state-free helpers in `/src/lib.typ`.
//
// Every case below pins a MEASURED defect recorded in that file's own comments,
// named in the comment above the assertion. This is a regression suite: a case
// is here because the behaviour was once wrong, not to describe the API.
//
// Run it with `just test` from `rookery/0.5.0`. There is no runner and no JS:
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
  _bib, _bib-keys, _blocks, _body-plain, _body-text, _cite-scan, _dedup-tag,
  _is-inline, _join, _nest-outline, _norm, _norm-tags, _note-file, _outbound,
  _own-cited-keys, _plain, _resolve-tags-color, _sort-ids, _tag-pred, _truncate,
  footnote, idea, note-href, note-path, window,
)

// ---- _norm — bare name, full id, label, and a name with its own colon ------
// `_norm` splits on the FIRST colon only, so an id whose name contains one
// survives intact.
#assert.eq(_norm("etal"), "etal")
#assert.eq(_norm("idea:etal"), "etal")
#assert.eq(_norm(<idea:etal>), "etal")
#assert.eq(_norm("idea:a:b"), "a:b")

// ---- _norm-tags — four author-facing forms, one dictionary -----------------
// `("a", "b")` and `(a: none, b: none)` must be the SAME record, or two pins of
// one id written in different forms read as a duplicate-id collision.
#assert.eq(_norm-tags(none), (:))
#assert.eq(_norm-tags("a"), (a: none))
#assert.eq(_norm-tags(("a", "b")), (a: none, b: none))
#assert.eq(_norm-tags((a: 1)), (a: 1))
#assert.eq(_norm-tags(()), (:))
// Insertion order survives the fold. MEASURED: typst dictionaries iterate in
// insertion order, so `.keys()` here is authored order, not sorted order.
#assert.eq(_norm-tags(("zeta", "alpha")).keys(), ("zeta", "alpha"))

// ---- _dedup-tag — `#todo("x", tags: ("todo",))` must not double the tag ----
// A duplicate here reaches the heading as a duplicated `idea-tag-todo` class.
#assert.eq(_dedup-tag("todo", ("todo",)), (todo: none))
#assert.eq(_dedup-tag("todo", ()), (todo: none))
#assert.eq(_dedup-tag("note", ("draft",)), (note: none, draft: none))
#assert.eq(_dedup-tag("note", ("draft", "note")), (draft: none, note: none))
// The tag is PREPENDED, which is visible in key order.
#assert.eq(_dedup-tag("note", ("draft",)).keys(), ("note", "draft"))
// A caller's own value for the tag WINS OUTRIGHT over the factory default —
// no deep merge. This is the mechanism by which `#todo("x", tags: (todo: ..))`
// sets a value for the wrapper's own tag, and it is why the "already a key"
// guard must run before the merge: dict `+` is right-wins (MEASURED), so an
// unconditional merge would clobber the caller's value with the default.
#assert.eq(_dedup-tag("todo", (todo: (p: 1))), (todo: (p: 1)))
#assert.eq(_dedup-tag("todo", (todo: (p: 1)), value: "default"), (todo: (p: 1)))
// `value:` applies only when the caller did not name the tag at all.
#assert.eq(_dedup-tag("flag", ("draft",), value: "yes"), (flag: "yes", draft: none))
// A bare string `tags:` is normalized, so `tag in tags` is a KEY test and never
// a substring test — `_dedup-tag("raft", "draft")` must not think it is present.
#assert.eq(_dedup-tag("raft", "draft"), (raft: none, draft: none))

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

// ---- _blocks — an inline run is ONE block, and keeps its spaces (akb) -------
// MEASURED DEFECT: children here are `text space raw space text`, and dropping
// every `space` made a truncating slice rejoin the runs as "layers,because".
// The whole paragraph is one block now, so `limit:` cannot land inside it, and
// the spaces survive either way.
#let _inline-raw = [Some text #raw("x") and more text here.]
#assert.eq(_blocks(_inline-raw).len(), 1)
#assert.eq(_body-plain(_blocks(_inline-raw).first()), "Some text x and more text here.")
// A block-level sibling still starts its own block, and the `space` before it
// is still dropped — that gap is drawn by margins, not content. Children:
// `space heading space text space`, and note there is NO `parbreak` between a
// heading and the paragraph after it, so the split cannot come from one.
#let _heading-then-text = [
  = Head
  Body text.
]
#assert.eq(_blocks(_heading-then-text).len(), 2)
// `#idea`'s own marker is `metadata`: invisible, and it used to take a whole
// block — and therefore a whole `limit` slot — to itself.
#assert.eq(_blocks([A#metadata((k: 1))B]).len(), 1)
// `raw`/`quote`/`equation` name both their forms, so they are asked, not looked
// up: the block form is a block, the inline form joins the run.
#assert(_is-inline(raw("x")))
#assert(not _is-inline(raw("x", block: true)))
#assert(_is-inline(quote[q]))
#assert(not _is-inline(quote(block: true)[q]))
#assert(_is-inline($x$))
#assert(not _is-inline($ x $))
// An unrecognised element is a block, so it keeps the pre-list behaviour.
#assert(not _is-inline(table(columns: 1, [a])))
#assert(not _is-inline(figure([a])))

// ---- _truncate — the ONE `limit:` truncation, joined with a parbreak -------
#let _three-paras = [One.#parbreak()Two.#parbreak()Three.]
// `none` is not a truncation: the body comes back untouched, identity included,
// because the three call sites pass their own `limit:` straight through.
#assert(_truncate(_three-paras, none) == _three-paras)
// A limit at or above the block count is not one either.
#assert(_truncate(_three-paras, 3) == _three-paras)
#assert(_truncate(_three-paras, 9) == _three-paras)
// Below it: the kept blocks plus the ellipsis, and NOTHING dropped between them
// — the join re-inserts the `parbreak` `_blocks` discarded, which is what makes
// typst's HTML export emit one `<p>` per kept block instead of one run-on.
#assert.eq(_body-plain(_truncate(_three-paras, 2)), "One. Two. …")
#assert.eq(_blocks(_truncate(_three-paras, 2)).len(), 2)

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

// ---- note-href / note-path — none with no rheo context --------------------
// Neither was covered here before: this fixture compiles WITHOUT rheo (no
// `sys.inputs.rheo-context`), which is exactly the condition both must
// return `none` under, rather than a path to a page nothing minted.
#context {
  assert.eq(note-href("etal"), none)
  assert.eq(note-path("etal"), none)
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

// ---- _cite-scan / _outbound — a `#footnote`'s body is a metadata payload ---
// A `#footnote` stores its body inside `metadata((rookery-fn: body))`, and both
// walks used to stop dead at any metadata that was not a window marker. MEASURED
// before the fix: an idea whose only citation sat in a footnote rendered the
// author-date marker and no references block at all, and a `#window` written in
// a footnote registered no outbound link, so the windowed note lost that
// backlink. Both are the same missing descent.
//
// `_own-cited-keys` filters against `_bib-keys()`, so these run after the
// `_bib.update` above.
#context {
  let cited = [Prose #footnote[A note citing @smith2020.] and more prose.]
  assert.eq(_cite-scan(cited), ((kind: "cite", key: "smith2020"),))
  assert.eq(_own-cited-keys(cited), ("smith2020",))

  // Counted once. The payload is the only place the citation is seen: the
  // rendered footnote `_footnoted` appends is never scanned again.
  assert.eq(_cite-scan(cited).len(), 1)

  // A nested idea still claims its own. The outer body keeps the key from ITS
  // footnote and none from the inner one, which renders its own block.
  let nested = [
    Outer #idea("units-fn-inner")[Inner #footnote[cites @smith2020.]]
    tail #footnote[cites @jones2021.]
  ]
  assert.eq(_own-cited-keys(nested), ("jones2021",))

  assert.eq(_outbound([See #footnote[#window("etal")] here.]), ("idea:etal",))
}

// ---- _resolve-tags-color — dict validation and normalisation ------
// String shorthand -> background-only dict
#assert.eq(_resolve-tags-color((draft: rgb("#ff0000"))), (draft: (background: "#ff0000")))
// CSS colour string shorthand
#assert.eq(_resolve-tags-color((note: "#00ff00")), (note: (background: "#00ff00")))
// Dict form with both keys
#assert.eq(
  _resolve-tags-color((todo: (background: rgb("#0000ff"), text: rgb("#ffffff")))),
  (todo: (background: "#0000ff", text: "#ffffff")),
)
// Dict form, text only
#assert.eq(_resolve-tags-color((warn: (text: "#000"))), (warn: (text: "#000")))
// Dict form, background only (via dict)
#assert.eq(_resolve-tags-color((info: (background: rgb("#ffff00")))), (info: (background: "#ffff00")))
// Multiple tags
#assert.eq(
  _resolve-tags-color((
    draft: rgb("#ff0000"),
    note: (background: rgb("#00ff00"), text: "#ffffff"),
  )),
  (
    draft: (background: "#ff0000"),
    note: (background: "#00ff00", text: "#ffffff"),
  ),
)
// A KEY IS A SELECTOR, so the key is checked against the CSS-identifier shape a
// generated `.idea-tag-<tag>` rule needs. Hyphens and underscores are the two
// separators a real tag actually uses, and both are legal INSIDE a name; an
// underscore is legal as the first character too, a digit is not.
#assert.eq(
  _resolve-tags-color(("in-progress": rgb("#ff0000"))),
  ("in-progress": (background: "#ff0000")),
)
#assert.eq(_resolve-tags-color((my_tag: "#0f0")), (my_tag: (background: "#0f0")))
// NO NEGATIVE CASES HERE, and that is the harness rather than an oversight: a
// failed `assert` aborts the whole compile, and this fixture has no
// `#assert.fails` to catch one. A rejected key is exercised by hand instead —
// `tags-color: ("my tag": rgb("#f00"))` in demo/pure/root.typ fails the build
// with the message naming the key.
