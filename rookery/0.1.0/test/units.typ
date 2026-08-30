// Unit fixture for the pure, state-free helpers in `/src/lib.typ`.
//
// Every case below pins a MEASURED defect recorded in that file's own comments,
// named in the comment above the assertion. This is a regression suite: a case
// is here because the behaviour was once wrong, not to describe the API.
//
// Run it with `just test` from `rookery/0.6.0`. There is no runner and no JS:
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
  _derived-title, _own-cited-keys, _plain, _resolve-excluded, _resolve-tags-color, _sort-ids,
  _project, _split-tag-list, _tag-pred, _truncate, footnote, idea, note-href, note-path,
  tag-index, window,
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

// A dictionary `tags:` argument must work on the QUERY side too, now that
// `_assert-tags` accepts one: MEASURED, a typst dictionary has no `.any`/`.all`,
// so `_tag-pred` normalizes `want` to keys or hard-errors.
#assert.eq(_tag-pred((draft: none), "any")((draft: none, phd: 1)), true)
#assert.eq(_tag-pred((draft: none), "any")((phd: 1)), false)
#assert.eq(_tag-pred("draft", "any")((draft: none)), true)
#assert.eq(_tag-pred(("a", "b"), "all")((a: none, b: 2, c: none)), true)
#assert.eq(_tag-pred(("a", "b"), "all")((a: none,)), false)
// An empty dict is no filter at all, same as an empty array.
#assert.eq(_tag-pred((:), "any"), none)
// `in` tests KEYS, so a VALUED tag is presence-filterable by name.
#assert.eq(_tag-pred("priority", "any")((priority: 1)), true)

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
  "idea:a": (created: datetime(year: 2026, month: 1, day: 2)),
  "idea:b": (created: datetime(year: 2026, month: 3, day: 4)),
  "idea:c": (created: datetime(year: 2026, month: 1, day: 2)),
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

// ---- _split-tag-list — one `--input` value as tag names --------------------
// A `sys.inputs` value is ALWAYS a string, so a LIST of tags arrives as one
// string. Commas and whitespace in any mixture, because a caller should not
// have to know which spelling this package parses.
#assert.eq(_split-tag-list("a, b  c"), ("a", "b", "c"))
#assert.eq(_split-tag-list("a,b,c"), ("a", "b", "c"))
#assert.eq(_split-tag-list("solo"), ("solo",))
// `none` is an ABSENT key, and the empty string is an empty value — both mean
// "no tags", never one tag whose name is the empty string. Such a tag is one no
// note can carry while every note could be tested against it.
#assert.eq(_split-tag-list(none), ())
#assert.eq(_split-tag-list(""), ())
#assert.eq(_split-tag-list(" , "), ())
// A trailing comma and a doubled separator are harmless for the same reason.
#assert.eq(_split-tag-list("a,,b,"), ("a", "b"))

// ---- _resolve-excluded — declared UNION exclude MINUS include --------------
// With no `--input` given (which is how `just test` compiles this fixture), the
// result is the declared list and nothing else. `test/inputs.typ` is the
// fixture that exercises the two `sys.inputs` keys, because they cannot be set
// from here.
#assert.eq(_resolve-excluded(none), ())
#assert.eq(_resolve-excluded(()), ())
// The SAME four forms `#idea`'s `tags:` takes, since this routes through
// `_norm-tags` — so `exclude-tags: "private"` needs no array ceremony.
#assert.eq(_resolve-excluded("x"), ("x",))
#assert.eq(_resolve-excluded(("x", "y")), ("x", "y"))
#assert.eq(_resolve-excluded((x: none, y: none)), ("x", "y"))
// A VALUED tag excludes exactly as a plain one does: the names are the keys, and
// a tag carrying metadata is no less a tag (the rule `cls` in idea.typ follows).
#assert.eq(_resolve-excluded((x: (owner: "me"))), ("x",))
// Deduped, so a tag named twice is one tag.
#assert.eq(_resolve-excluded(("x", "x")), ("x",))

// ---- _derived-title — a titleless note names itself by its body -------------
// An EMPTY body derives nothing and stays `none`: `#idea("x")[]` has no text to
// name itself with, and `""` would put an empty `.idea-title` span in the
// heading, defeating the `h*.idea:empty` rules that exist to collapse it.
#assert.eq(_derived-title([]), none)
#assert.eq(_derived-title(none), none)
// Under the limit: the body verbatim, no ellipsis.
#assert.eq(_derived-title([Short body.]), "Short body.")
// EXACTLY at the limit is not over it — an off-by-one here appends `...` to a
// title that was already complete.
#assert.eq(_derived-title([#("a" * 60)]), "a" * 60)
#assert.eq(_derived-title([#("a" * 61)]), "a" * 60 + "...")
// Whitespace collapses first (via `_body-plain`), so a multi-block body arrives
// as one clean line rather than carrying the source's own line breaks.
#assert.eq(_derived-title([A.#parbreak()B.]), "A. B.")
#assert.eq(
  _derived-title[
    - one
    - two
  ],
  "one two",
)
// NON-ASCII MUST NOT PANIC, and must count as CHARACTERS rather than bytes.
// `str.slice` takes byte offsets and hard-errors mid-character, which is why
// `_derived-title` slices `.clusters()`; each of these is >60 bytes and <=60
// clusters, so a byte-based slice would either panic or truncate early.
#assert.eq(_derived-title([héllo wörld]), "héllo wörld")
#assert.eq(_derived-title([#("é" * 40)]), "é" * 40)
#assert.eq(_derived-title([#("é" * 61)]), "é" * 60 + "...")
// The limit is a parameter for these tests only — `#idea` never passes one.
#assert.eq(_derived-title([abcdef], limit: 3), "abc...")

// ---- _plain / _body-text — a smart quote is its own element ----------------
// It used to contribute NOTHING, so every apostrophe and quotation mark vanished
// from a note's plain text and no search could match one. MEASURED on a real
// rookery: a note titled `Read Anil's 'Rumour is the exploit'` indexed as
// `"Read Anils Rumour is the exploit"`. ASCII rather than the curly glyph, because
// open-vs-close depends on position and the element carries only `double`.
#assert.eq(_plain([Anil's]), "Anil's")
#assert.eq(_plain([Read "this"]), "Read \"this\"")
#assert.eq(_plain([Read Anil's 'Rumour is the exploit']), "Read Anil's 'Rumour is the exploit'")
#assert.eq(_body-plain([He said "no" and Anil's reply]), "He said \"no\" and Anil's reply")
// Mixed with markup the walk already handled, so the new branch composes rather
// than short-circuiting the others.
#assert.eq(_body-plain([A #raw("x") isn't B]), "A x isn't B")

// ---- tag-index — a declared projection, flattened to SCALARS --------------
// The scalar rule is the contract, so it is tested by its refusals as much as by
// its results: a projected value must be safe to encode as JSON or as an HTML
// attribute, and the only thing that guarantees that is the assert.
#let _tags-a = (
  "cycle-26-27": none,
  "venue-postdoc": none,
  "date-deadline": datetime(year: 2026, month: 11, day: 1),
)
#let _spec = (
  cycle: (family: "cycle-"),
  kind: (family: "venue-", one-of: ("postdoc", "tenuretrack")),
  deadline: (key: "date-deadline", stamp: true),
)
#assert.eq(
  _project(tag-index(_spec), _tags-a),
  (cycle: "26-27", kind: "postdoc", deadline: "20261101"),
)
// A note carrying none of the tags projects `none` per field — an ABSENT fact,
// not a missing key, so a consumer reads `r.cycle == none` rather than probing.
#assert.eq(
  _project(tag-index(_spec), (:)),
  (cycle: none, kind: none, deadline: none),
)
// `one-of:` ORDERS the family, which is what makes two members of one family
// resolve deterministically — tags are unordered as of 0.5.0.
#assert.eq(
  _project(
    tag-index((kind: (family: "venue-", one-of: ("tenuretrack", "postdoc")))),
    ("venue-postdoc": none, "venue-tenuretrack": none),
  ),
  (kind: "tenuretrack"),
)
// `from:` — a COMPUTATION over the tag dictionary, the only way a value that
// cannot ride on a row (an array, a log) becomes filterable.
#assert.eq(
  _project(
    tag-index((n: (from: t => t.keys().len()))),
    _tags-a,
  ),
  (n: 3),
)
// A dateless field with `stamp: true` stays none rather than panicking: absence
// is not a type error.
#assert.eq(_project(tag-index((d: (key: "nope", stamp: true))), _tags-a), (d: none))
// `_project(none, ..)` is the no-index case and merges into nothing.
#assert.eq(_project(none, _tags-a), (:))
