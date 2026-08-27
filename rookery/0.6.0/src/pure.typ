// rookery — the PURE half: functions of their arguments and nothing else.
//
// What belongs here: a helper whose whole answer comes from what it is handed
// — a string, a content tree, an array. NO `state`, no `context`, no `query`,
// no `sys.inputs`, no target detection, no page handle, no prefix, no theme,
// no registry, no bibliography. Nothing in this file reads document state.
//
// What does NOT belong here: everything that does. Those helpers stay in
// `lib.typ`, whose ORDERING IS LOAD-BEARING — a `#let` closure captures the
// scope visible AT DEFINITION time — which is precisely the constraint this
// file's contents do not participate in.
//
// `lib.typ` re-exports every name here (`#import "pure.typ": *`), so the
// underscore-private ones stay importable from `"@rheo/rookery:0.6.0"` by
// name — `test/units.typ` imports twelve of them that way, and `.marrow.typ`
// imports seventeen of `lib.typ`'s own internals on the same footing.
//
// Order still matters WITHIN this file, for the same definition-time-capture
// reason: `_INLINE-FUNCS` -> `_is-inline` -> `_blocks` -> `_truncate`,
// `_join` -> `_body-text` -> `_body-plain`, and `IK`/`WK` above both footnote
// walkers.
//
// `_std-footnotes`'s `footnote` is TYPST'S BUILT-IN, deliberately: rookery
// defines its own `#footnote` far down in `lib.typ` and nothing here shadows
// the name. Do not import rookery's `footnote` into this file.

// Normalise a name (string or Typst label) to its bare string form, with no
// prefix. Strips a leading "prefix:" when present, so the bare form
// ("etal", <etal>) and the full id ("idea:etal", <idea:etal> — the same id
// `@idea:etal` resolves) name the same note either way: whichever is closer
// to hand — a fresh name to pin, or a full id copied from elsewhere — just
// works. Shared by `#idea` (pinning an explicit id), `#window` (looking one
// up), and `#hyperlink` (linking to one). Defined before the registry below
// because `hyperlink` needs both and must come before `_flatten`, which
// installs it as a `show ref:` rule.
#let _norm(name) = {
  let s = if type(name) == label { str(name) } else { name }
  let i = s.position(":")
  if i == none { s } else { s.slice(i + 1) }
}

// ---- _norm-tags — every accepted `tags:` form, as ONE dictionary -----------
//
// The tag store is a DICTIONARY as of 0.5.0: keys are tag names, values are
// arbitrary Typst values, and a plain tag is one whose value is `none`. This is
// what lets a tag carry metadata — `(depends-on: ("a", "b"))` — instead of only
// naming itself, and it is the primitive `@rheo/rookery-todos` and
// `@rheo/rookery-dates` build on.
//
// Four author-facing forms all land here and all normalize to that one shape,
// so nothing downstream has to ask which was written:
//
//   none            -> (:)
//   "draft"         -> (draft: none)
//   ("a", "b")      -> (a: none, b: none)
//   (a: 1, b: none) -> unchanged
//
// `("a", "b")` and `(a: none, b: none)` are therefore THE SAME registry record,
// which matters at `idea.typ`'s duplicate-id check: two pins of one id written
// in different forms must not read as a collision.
//
// Defined above BOTH its callers — `_tag-pred` just below and `_dedup-tag`
// further down — because a `#let` closure captures the scope visible AT
// DEFINITION time, so a helper defined after a caller is invisible to it.
#let _norm-tags(v) = {
  if v == none {
    (:)
  } else if type(v) == str {
    ((v): none)
  } else if type(v) == dictionary {
    v
  } else {
    v.fold((:), (d, t) => { d.insert(t, none); d })
  }
}

// ---- _tag-pred — the shared tag filter -----------------------------------
//
// `tags` is `none`, a single string, an array of strings, or a dictionary —
// the same four forms `#idea` takes; `match` is "any" (the default) or "all".
// Returns a predicate over a note's own tag DICTIONARY, or `none` when there is
// nothing to filter by. An EMPTY `tags` is no filter at all rather than a
// filter matching nothing — asking for none of the tags is not the same as
// asking for a tag no note has.
//
// `filter` is a caller's OWN predicate over the same tag dict, ANDed with the
// `tags`/`match` one — both must hold, never either. NAMED and defaulting to
// `none` so the callers with no use for it (`#window`, `ideas()`) keep their
// arity; `#ideas-outline` is the one that offers it, because `tags:`/`match:`
// can say "any of these" and "all of these" and nothing else. It cannot say
// `phd` but NOT `draft`, nor `(phd AND draft) OR todo`. Keyword parameters for
// those would be a filter language grown one special case at a time —
// `exclude:`, then `any-of:`/`all-of:`, then nested-array groups — and a Typst
// function value already IS that language, in the caller's hands.
//
// The predicate sees the TAG DICTIONARY and nothing else: no title, no id, no
// depth. Those are not tag filtering, and handing over a whole outline entry
// would make the entry's shape a public contract this package then has to keep.
//
// THE DICT, not an array of names, as of 0.5.0 — that is what lets a project
// filter on a tag's VALUE rather than only on its presence:
//
//   filter: t => t.at("priority", default: 4) <= 1
//
// BREAKING for a 0.4.1 predicate written against the array. `t => "phd" in t`
// keeps working unchanged (MEASURED: `in` tests dictionary KEYS), but
// `t.map(..)`, `t.any(..)`, `t.all(..)` and `t.at(0)` do not — a dictionary has
// no `.any`/`.all` at all, and its `.at` takes a key, not an index.
//
// Still `none` when neither is set, and that matters — it is what lets
// `_prune-outline` skip its walk entirely for an unfiltered outline. Do not
// replace it with an always-true closure.
//
// Defined HERE, above every caller, rather than beside the first one to want
// it: a `#let` closure captures the scope visible AT DEFINITION time, so a
// helper defined further down is invisible to `#window`. `_blocks` carries the
// same note for the same reason. `#ideas-outline`'s tag filter reuses this —
// do not define a second copy next to it.
#let _tag-pred(tags, match, filter: none) = {
  let by-tags = if tags == none { none } else {
    // `.keys()`, and it is load-bearing rather than cosmetic. `_assert-tags`
    // now also accepts a dictionary, so `#window(tags: (draft: none))` reaches
    // here with `want` a dict — and MEASURED, a typst dictionary has no `.any`
    // and no `.all`, so the two branches below would hard-error with
    // "type dictionary has no method any". `_norm-tags` folds str, array and
    // dict onto one shape and `.keys()` takes the names off it.
    let want = _norm-tags(tags).keys()
    if want.len() == 0 { none } else if match == "all" {
      t => want.all(x => x in t)
    } else {
      t => want.any(x => x in t)
    }
  }
  if by-tags == none and filter == none { none } else if filter == none {
    by-tags
  } else if by-tags == none {
    filter
  } else {
    t => by-tags(t) and filter(t)
  }
}

// ONE `../` per `:` level of the CURRENT page's handle, mirroring rheo's own
// cross-vertebra link rule. Shared by `_note-href` and `_page-href` so a note
// href and a page href cannot disagree about depth.
#let _rel-prefix(handle) = {
  let depth = handle.split(":").len() - 1
  if depth == 0 { "" } else { range(depth).map(x => "../").join() }
}

// Every bibliography key cited in this content, in document order.
//
// Walks for BOTH `ref` and `cite`: `@key` markup is a `ref` element until
// realization and becomes a `cite` only then, so a walk looking for `cite`
// alone finds nothing — MEASURED, it returned `()` for a body full of `@key`
// citations. `#cite(<key>)` written explicitly is already a `cite`.
//
// Intersecting with `_bib-keys()` is what makes this correct rather than merely
// plausible: `@idea:etal` and a reference to a heading are `ref` elements too,
// and only the ones naming a bibliography key are citations.
#let _cite-walk(node) = {
  let out = ()
  if type(node) != content { return out }
  if node.func() == ref { return (str(node.target),) }
  if node.func() == cite { return (str(node.key),) }
  if node.has("children") { for k in node.children { out += _cite-walk(k) } }
  else if node.has("body") { out += _cite-walk(node.body) }
  else if node.has("child") { out += _cite-walk(node.child) }
  out
}

// Prepends `tag`, unless the caller already passed it — `#todo("x", tags:
// ("todo",))` must yield `(todo: none)`, not the tag twice, or the heading gets
// a duplicated CSS class. Defined before the `tagged-idea` factory that calls
// it: a `#let` closure captures the scope visible AT DEFINITION time, so a
// forward reference to a not-yet-defined name fails at call time.
//
// `tags` is normalized here, not left to `#idea`'s own coercion: a wrapper
// calls this BEFORE `tags` ever reaches `#idea`, so a bare `tags: "draft"`
// would otherwise hit `tag in tags` as a SUBSTRING test rather than a key test.
//
// THE ORDER OF THE TWO BRANCHES IS LOAD-BEARING. MEASURED: dictionary `+`
// merges with the RIGHT side winning on a key collision, so an unconditional
// `((tag): value) + tags` would clobber a caller's own value for this tag with
// the default. The "already a key" guard therefore comes FIRST, and that guard
// is exactly the mechanism by which a caller supplies a value for the wrapper's
// own tag: `#todo("x", tags: (todo: (state: "open")))` keeps `(state: "open")`.
// A caller's value wins OUTRIGHT — there is no deep merge.
//
// `value:` is the default a factory binds for the tag it prepends (see
// `tagged-idea`). It only applies when the caller did not name the tag at all.
#let _dedup-tag(tag, tags, value: none) = {
  let tags = _norm-tags(tags)
  if tag in tags { tags } else { ((tag): value) + tags }
}

// ---- _sort-ids — a total order over a window's selected ids ---------------
//
// "lexicographic" is by full id, the same order `ideas()` publishes. "date" is
// newest `minted` first, undated notes last, ties broken by ASCENDING id.
//
// Built by grouping rather than by sorting twice: typst does not document
// `array.sorted` as stable, so a sort-by-id-then-sort-by-date pipeline cannot
// be relied on to keep the id order within a date. Dates are compared as
// zero-padded `[year][month][day]` strings, which sidesteps the question of
// how `datetime` orders as a sort key at all.
#let _sort-ids(ids, reg, sort) = {
  let by-id = ids.sorted()
  if sort != "date" { return by-id }
  let stamp-of(id) = {
    let m = reg.at(id).at("minted", default: none)
    if m == none { none } else { m.display("[year][month][day]") }
  }
  let dated = by-id.filter(id => stamp-of(id) != none)
  let undated = by-id.filter(id => stamp-of(id) == none)
  let ordered = ()
  // `dated` is already in ascending-id order and `filter` preserves it, so
  // each date's group comes out id-ascending inside a date-descending walk.
  for s in dated.map(stamp-of).dedup().sorted().rev() {
    ordered += dated.filter(id => stamp-of(id) == s)
  }
  ordered + undated
}

// Rebuilds a nested list from the flat `(depth, title, loc)` sequence above
// — a standard depth-tagged-list-to-tree pass. `wrap` builds ONE level's
// list container (`html.elem("ul", ..., ..)` or Typst's own `list`); `item`
// wraps one entry's own content plus its (possibly none) nested sublist.
// Shared by both targets so the tree-walk itself cannot drift between them.
//
// `wrap` is called as `wrap(items, root)`, `root` being true for the OUTERMOST
// list only. The theme's custom properties have to go on that one and inherit
// down: an outline is page-level chrome, a sibling of the notes rather than a
// descendant of any of them, so unlike everything else this package emits it
// has no `.idea-box`/`.idea-window` ancestor to inherit from. Putting them on
// every level instead would re-declare the same values once per nesting depth.
#let _nest-outline(entries, wrap, item) = {
  let build(entries, root: false) = {
    let items = ()
    let i = 0
    while i < entries.len() {
      let base = entries.at(i).depth
      let children = ()
      let j = i + 1
      while j < entries.len() and entries.at(j).depth > base {
        children.push(entries.at(j))
        j += 1
      }
      let sub = if children.len() == 0 { none } else { build(children) }
      items.push(item(entries.at(i), sub))
      i = j
    }
    wrap(items, root)
  }
  build(entries, root: true)
}

// Plain text of a title, for `ideas()`. Typst has no built-in
// content-to-string, so this walks the usual constructors: anything carrying
// `.text` (a `text` element, and also `raw`), a space element standing for
// " ", a sequence's `.children`, and anything else with a `.body` (strong,
// emph, link, ...) recursed into. Unknown leaves contribute nothing rather
// than erroring — a title is matched on, not rendered from, here.
//
// The `.has("text")` branch is deliberately broader than `c.func() == text`:
// MEASURED, a title like [The `#window` marker] flattened to "The  marker"
// under the narrow test, because `raw` carries `.text` and has neither
// children nor a body — silently making that note unfindable by the word in
// its own title. A math equation still contributes nothing.
#let _plain(c) = {
  if c == none { "" } else if type(c) == str { c } else if type(c) != content {
    ""
  } else if c.has("text") { c.text } else if c.func() == [ ].func() {
    " "
  } else if c.has("children") { c.children.map(_plain).join() } else if c.has("body") {
    _plain(c.body)
  } else { "" }
}

// Plain text of a note's BODY, for `ideas()`. Every registry body has been
// through `_flatten` since v6y.7, wrapping it in a `show`-rule scope that
// Typst represents as a `styled` node hanging off `.child` — unwrap that
// first, the same way `_blocks` above does. Otherwise follows `_plain`'s
// branches (`.has("text")`, a space element, `.children`, `.body`), except a
// `parbreak` or `item` emits a boundary space so blocks and list entries
// don't glue together the way `_plain`'s title walker would let them
// (MEASURED: without this, "raw code.A second paragraph" loses its
// paragraph break). `metadata` and anything unrecognised contribute "".
//
// BUG FIX, MEASURED: `array.join()` on an EMPTY array returns `none`, not
// `""` — an idea with an empty body (`#idea("x")[]`) has a `sequence` node
// with zero children, and the naive `c.children.map(_body-text).join()`
// therefore returned `none` and crashed the caller's `.replace(...)`. Both
// join call sites below go through `_join`, which special-cases the empty
// array.
#let _join(arr) = if arr.len() == 0 { "" } else { arr.join() }

#let _body-text(c) = {
  if c == none { "" } else if type(c) == str { c } else if type(c) != content {
    ""
  } else {
    let c = c
    while repr(c.func()) == "styled" { c = c.child }
    let f = repr(c.func())
    if c == none { "" } else if c.func() == metadata { "" } else if f == "parbreak" {
      " "
    } else if f == "item" {
      let inner = if c.has("children") { _join(c.children.map(_body-text)) } else if c.has(
        "body",
      ) { _body-text(c.body) } else { "" }
      " " + inner + " "
    } else if c.has("text") { c.text } else if c.func() == [ ].func() { " " } else if c.has(
      "children",
    ) { _join(c.children.map(_body-text)) } else if c.has("body") { _body-text(c.body) } else { "" }
  }
}

// Collapses `_body-text`'s raw walk into one search-ready string: runs of
// whitespace (including the boundary spaces `_body-text` inserts) become a
// single space, and the ends are trimmed.
#let _body-plain(c) = _body-text(c).replace(regex("\s+"), " ").trim()

#let IK = "rheo-idea" // marker for an idea
#let WK = "rheo-idea-window" // marker for a window; defined here (not next to
// `#window` below) because `_flatten` needs both marker kinds and must be
// defined before `#idea`, which calls it at registration time.

// ---- Footnotes — scoped to an idea, not to an output page -----------------
//
// Typst's own `#footnote` CANNOT be intercepted. Its body is collected by the
// HTML exporter through introspection, independently of show rules, so neither
// `show footnote: it => ...` nor `show footnote: none` removes the entry from
// the page's `<section role="doc-endnotes">` — MEASURED both ways on typst
// 0.15.1. So rookery exports its own `#footnote` (below), which shadows
// `std.footnote` at the author's import site and carries its body on an
// invisible marker this package places itself.
//
// The marker is `metadata` + a label, NOT a `figure`. A figure is block-level
// and forced `</p><p>` breaks around the reference, taking it out of its
// sentence — MEASURED. `metadata` renders nothing and sits inline.
//
// Defined HERE — after IK/WK, before `_flatten` — for the reason `_blocks`
// below is: a `#let` closure captures the scope visible AT DEFINITION time,
// and both `_flatten`'s IK rule and `#idea` itself need these.
#let FNK = <rkfn>

// Every footnote body in this content, in document order.
//
// STOPS at a nested IK or WK marker. A `#idea` written inside another's body
// owns its footnotes and renders its own block for them; a nested `#window`
// likewise. Without this the parent would list its children's footnotes as
// well as its own, and every one would appear twice on the page.
//
// Does NOT descend into a metadata VALUE — only into content children — which
// is what keeps the raw bodies that IK/WK markers carry as metadata payloads
// out of the walk.
#let _footnotes(node) = {
  let out = ()
  if type(node) != content { return out }
  if node.func() == metadata {
    if type(node.value) == dictionary and "rookery-fn" in node.value {
      return (node.value.rookery-fn,)
    }
    return out
  }
  if node.func() == figure and node.at("kind", default: none) in (IK, WK) { return out }
  if node.has("children") { for k in node.children { out += _footnotes(k) } }
  else if node.has("body") { out += _footnotes(node.body) }
  else if node.has("child") { out += _footnotes(node.child) }
  out
}

// Typst's OWN footnotes in a body — the ones this package cannot claim.
//
// `#footnote` above shadows `std.footnote` only at the author's IMPORT SITE, and
// Typst imports are per-file. A vertebra that writes `#footnote` without
// importing it from this package gets the builtin, and the build SUCCEEDS while
// putting the body somewhere else entirely: the page's endnote section,
// numbered page-wide, with no Footnotes block on the idea. MEASURED:
//
//     no import   idea-footnotes block=False   page endnotes=True
//     imported    idea-footnotes block=True    page endnotes=False
//
// `#idea` uses this to turn that silence into a build error. It cannot be fixed
// any other way — REFUTED, do not attempt: a rule installed by `#show: rookery`
// changes only how the marker renders, and the body is still collected into the
// endnote section behind it, because the HTML exporter gathers footnotes by
// introspection. MEASURED, the section was emitted and still contained the
// body. There is no way to rebind a builtin document-wide either; `#let` is
// file-scoped.
//
// Stops at a nested IK/WK marker for the same reason `_footnotes` does: a
// nested idea runs this check when IT registers, and should report its own
// violation rather than have its parent report it.
#let _std-footnotes(node) = {
  let out = ()
  if type(node) != content { return out }
  if node.func() == footnote { return (node,) }
  if node.func() == figure and node.at("kind", default: none) in (IK, WK) { return out }
  if node.has("children") { for k in node.children { out += _std-footnotes(k) } }
  else if node.has("body") { out += _std-footnotes(node.body) }
  else if node.has("child") { out += _std-footnotes(node.child) }
  out
}

// Split a body into block-level chunks for `limit:` truncation. A naive
// `body.children.slice(0, limit)` is WRONG: whitespace (`space`/`parbreak`)
// children make it select nothing, and list items are bare `item` children
// with no wrapping `list` element, so a naive slice also cuts lists in half.
// This groups consecutive `item`s into one block and drops whitespace.
// Compares `repr(c.func())` against "space"/"parbreak" because there is no
// public element function to compare those against directly.
//
// THE TWO WHITESPACE KINDS ARE NOT THE SAME BOUNDARY, and treating them as one
// is what stopped the item grouping ever firing. MEASURED (typst 0.15.1) — the
// children of `[Intro. #parbreak() - a - b]` are, in order:
//
//   space text space parbreak space item space item space
//
// Every markup list carries a `space` BETWEEN its items, so clearing
// `prev-item` on `space` cleared it before the next `item` was ever seen: each
// item became its own block and `#window("x", limit: 2)` on an intro plus a
// four-item list showed the intro and ONE bullet, the cut-a-list-in-half
// outcome the grouping exists to prevent. A `space` between two `item`s is list
// punctuation; a `parbreak` between them genuinely ends the list. So only
// `parbreak` resets the run. Both still emit no block of their own.
//
// `item` covers all three list kinds — `-`, `+` and `/ term:` items are all
// `item` children (measured), so one branch groups all three.
//
// MEASURED REGRESSION FIX: every registry body has been through `_flatten`
// since v6y.7, which wraps it in a `show`-rule scope — Typst represents that
// as a `styled` node with `.has("children") == false`, not the `sequence` it
// wraps. Without unwrapping, `_blocks` always fell into the single-block
// fallback below, silently disabling `limit:` truncation for every note.
// `styled` (like `space`/`parbreak`) has no public function value to compare
// against directly, hence `repr(...)`. A `styled` node exposes the wrapped
// content as `.child` — verified this stays a single layer even with two
// `show` rules in the scope (`_flatten` sets exactly two), but loop anyway
// in case that ever changes.
//
// Defined HERE, above `_flatten`, rather than beside `#window` where it is
// also used: `_flatten`'s WK rule applies `limit:` too when it expands a
// nested window, and a `#let` closure captures the scope visible AT
// DEFINITION time.
//
// A `space` between two INLINE siblings is not separator noise either, and
// dropping it is what made truncation rejoin two runs with nothing between
// them. MEASURED on rookery.ohrg.org content: "...three layers, because..."
// came out "...three layers,because..." once a `limit:` slice put a text run
// back against a `raw` span. Between BLOCK-level siblings the gap really is
// drawn by margins rather than content, so there the node must still go.
//
// So inline siblings ACCUMULATE into one block, keeping the `space` nodes
// between them, and only a block-level sibling starts a new one. That is also
// the fix for the count: a body that is one paragraph is now ONE block, so
// `limit: n` counts the blocks the name promises and can no longer cut a
// sentence in half. It is why neither `#idea-body` nor `#search-modal` could
// ship a default `limit:` before.
//
// Inline and block are told apart BY NAME, because typst exposes no predicate.
// MEASURED `repr(func())` values (typst 0.15.1) that decide the shape of the
// test: `raw`, `quote` and `equation` each name BOTH their inline and their
// block form, so those three are asked for their own `block` field instead; a
// `"..."` smartquote arrives as a `sequence`; `#text(gray)[x]` arrives as
// `styled`; `#idea`'s own marker arrives as `metadata`, invisible, and used to
// consume a whole `limit` slot on its own.
//
// UNKNOWN NAMES DEFAULT TO BLOCK, deliberately: an element missing from the
// list then behaves exactly as every element did before the list existed — its
// own block — so the worst a gap in it can do is leave one old dropped space
// in place. The other direction would merge two real blocks into one and make
// `limit:` show more than it was asked for.
#let _INLINE-FUNCS = (
  "text", "emph", "strong", "link", "footnote", "super", "sub", "strike",
  "underline", "overline", "highlight", "box", "h", "linebreak", "metadata",
  "sequence", "styled",
)
#let _is-inline(c) = {
  let f = repr(c.func())
  if f in ("raw", "quote", "equation") { return not c.at("block", default: false) }
  f in _INLINE-FUNCS
}
#let _blocks(body) = {
  let body = body
  while repr(body.func()) == "styled" { body = body.child }
  if not body.has("children") { return (body,) }
  let out = ()
  let prev-item = false
  let prev-inline = false
  // The `space` node seen since the last kept child, held back until we know
  // whether what follows it is inline (keep it) or block (drop it).
  let gap = none
  for c in body.children {
    let f = repr(c.func())
    if f == "space" { gap = c; continue }
    if f == "parbreak" { prev-item = false; prev-inline = false; gap = none; continue }
    if f == "item" {
      if prev-item { out.at(-1) = out.at(-1) + c } else { out.push(c) }
      prev-item = true
      prev-inline = false
      gap = none
      continue
    }
    let inline = _is-inline(c)
    if inline and prev-inline {
      let run = out.at(-1)
      if gap != none { run = run + gap }
      out.at(-1) = run + c
    } else {
      out.push(c)
    }
    prev-item = false
    prev-inline = inline
    gap = none
  }
  out
}

// The ONE `limit:` truncation — first `limit` blocks of a body, then a grey
// ellipsis — shared by `_flatten`'s WK expansion, `#window` and `#idea-body`.
// It lived as three verbatim copies, which is exactly the drift the rest of
// this file factors things out to prevent. Defined HERE, beside `_blocks`
// rather than beside `#window`, because a `#let` closure captures the scope
// visible AT DEFINITION time and `_flatten` (below) is one of the three
// callers. A `none` limit means no truncation; the callers assert away `0` and
// negatives before reaching this, so it validates nothing itself.
//
// Joined with `parbreak()`, not with nothing. `_blocks` drops the `parbreak`
// children that separated the blocks — right, because a block is not its
// separator — and putting them back is this join's job. MEASURED before it did:
// a two-block truncation rendered as
// `Only three layers, <code>because</code> derived.Second paragraph here. …`,
// one run of inline content with no space, no break, and no `<p>` wrappers at
// all, where the same note UNtruncated emits one `<p>` per paragraph. Typst's
// HTML export decides paragraphs by the `parbreak`s it finds, so restoring them
// restores the `<p>`s with them.
//
// No separator before the ellipsis, so it trails the last kept block rather
// than standing apart from it. MEASURED, and the two cases differ for a reason:
// after a paragraph it lands INSIDE that `<p>`, which reads as "this paragraph
// continues"; after a grouped list it comes out as its own `<p>` after the
// `</ul>`, because an ellipsis cannot sit inside a list. Both are right.
#let _truncate(body, limit) = {
  if limit == none { return body }
  let bs = _blocks(body)
  if bs.len() <= limit { return body }
  bs.slice(0, limit).join(parbreak()) + [#text(gray)[ ... ]]
}

// ---- Argument validators shared by more than one public function ----------
//
// `tags`, `match` and `limit` are checked identically by several functions, and
// before these existed each wrote its own six-line `assert` with its own copy of
// the message. MEASURED at 0.4.0: 32 assert blocks in `lib.typ`, `tags` written
// out four times, `match` three, `limit` twice.
//
// `where` is the caller's own name as it already appears in the message —
// "#idea", "#ideas'", "#window's" — so the text a reader sees is byte for byte
// what it was. Pass the possessive exactly as the original wrote it, apostrophe
// included: `#ideas'` and `#idea's` are both correct English for their nouns,
// and matching the old text matters more than regularising it.
//
// ONLY THE ONES WITH SEVERAL CALLERS live here. `depth` deliberately does NOT:
// `#window` and `#idea-body` accept `auto or int >= 0` while `#ideas-outline`
// accepts `none or int >= 1`, and `#window`'s message spends four lines
// explaining what each depth renders. Three different checks that happen to
// share a parameter name are not one check, and folding them would either lose
// that explanation or attach it to functions it does not describe.
#let _assert-tags(v, where) = assert(
  v == none
    or type(v) == str
    or type(v) == dictionary
    or (type(v) == array and v.all(t => type(t) == str)),
  message: "@rheo/rookery: " + where + " `tags` must be none, a string, an "
    + "array of strings, or a dictionary — got " + repr(v),
)

#let _assert-match(v, where) = assert(
  v == "any" or v == "all",
  message: "@rheo/rookery: " + where + " `match` must be \"any\" or \"all\" — got "
    + repr(v),
)

// The block-count form: `none` or a positive integer, shared by `#window` and
// `#idea-body`, which truncate the same way and say so the same way.
#let _assert-limit(v, where) = assert(
  v == none or (type(v) == int and v >= 1),
  message: "@rheo/rookery: " + where + " `limit` must be none or a positive "
    + "integer (the number of leading blocks to show) — got " + repr(v),
)
