// The two public faces over `transclusion.typ`: `#window`, which shows a note
// inside another page, and `#idea-body`, which hands back one note's body as
// content for a caller to place itself.

#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *
#import "bib.typ": *
#import "transclusion.typ": *
#import "hyperlink.typ": *
#import "links.typ": *
#import "idea.typ": *

// ---- #window — transclusion, array form, working limit --------------------
//
// `#window("etal")` transcludes the target note: its title, its permalink, and
// its stored (flattened) body, as one foldable block. `names` accepts a
// string, a label, or an array of either — bare (`"etal"`, `<etal>`) or full
// id (`"idea:etal"`, `<idea:etal>` — the same id `@idea:etal` resolves), see
// `_norm`. Reads the registry via `.final()`, not `.get()` — that is what
// lets a note defined in ANOTHER vertebra resolve, since the whole spine
// compiles as one Typst document.
//
// `tags:` selects notes instead of naming them, and COMBINES with the names
// rather than replacing them: the window shows the union of what was named and
// what carries the tags, with a note that is both appearing once, where it was
// named. `match:` is "any" (the default) or "all". Selection is always
// rookery-wide — the registry is the whole bundle's, so where the window sits
// makes no difference to what a tag pulls in. Either half may be omitted, but
// not both.
//
// `sort:` is `auto`, "date" or "lexicographic". `auto` keeps named ids in
// call-site order and appends the tag matches by id, so a window that names
// its notes and asks for no sort behaves exactly as it always has; naming a
// sort orders the whole selection instead. See `_sort-ids`.
//
// A `#window` is pure presentation: it never registers, never advances the
// counter, and never re-registers a nested `#idea`. That guarantee is
// delivered by `_flatten` (defined above, next to `IK`/`WK`), not by any
// suppression logic here.
//
// `depth:` is the transclusion budget (see `_window-depth` for the whole
// scale): `0` transcludes nothing and renders this window as a LINK to the
// note's page, `1` renders the note and collapses a `#window` written inside it
// to its bare permalink, `n` unfurls n-1 levels of those as real windows.
// `auto`, the default, takes the document-wide setting from
// `#show: rookery.with(window-depth: n)` — which itself defaults to 1, the
// one-level rendering every document already has. Per call site, because
// "unfurl the whole tree here", "show it" and "just point at it" are all
// reasonable on the same page: an index that shows one note in full wants
// depth, a backlinks list of forty does not, and a dense index may want no
// transclusion at all.
//
// Nesting counts WINDOWS only. A `#idea` written inside a transcluded note is
// always rebuilt in full whatever the budget (that is `_flatten`'s IK rule,
// and it cannot cycle — an idea's body is finite and literally contains its
// nested ones), so `depth` measures exactly the thing that can cycle.
//
// Rendering — `folded`, `show-date`, `limit:`, click budget: `_window-content`.
#let window(
  ..args,
  limit: none,
  folded: false,
  show-date: false,
  show-tags: false,
  depth: auto,
  tags: none,
  match: "any",
  sort: auto,
) = {
  assert(
    depth == auto or (type(depth) == int and depth >= 0),
    message: "@rheo/rookery: #window's `depth` must be auto or a non-negative "
      + "integer — `0` renders the note as a link to its own page, `1` (the "
      + "document default) renders it once and collapses any window inside it "
      + "to a permalink, `n` unfurls n-1 nested levels — got " + repr(depth),
  )
  // `>= 1`, not `>= 0`: a window showing nothing but an ellipsis truncates
  // nothing, so `limit: 0` reads as a mistake rather than a request.
  _assert-limit(limit, "#window's")
  _assert-tags(tags, "#window's")
  _assert-match(match, "#window's")
  assert(
    sort == auto or sort == "date" or sort == "lexicographic",
    message: "@rheo/rookery: #window's `sort` must be auto, \"date\" or "
      + "\"lexicographic\" — got " + repr(sort),
  )
  // Variadic, not a plain positional: a positional parameter cannot carry a
  // default in typst, and `#window(tags: "todo")` has to be callable with no
  // name at all. `#hyperlink` takes the same shape for the same reason.
  let pos = args.pos()
  assert(
    pos.len() <= 1,
    message: "@rheo/rookery: #window wants one name or one array of names — "
      + "#window((\"a\", \"b\")), not #window(\"a\", \"b\") — got "
      + str(pos.len()) + " positional arguments.",
  )
  assert(
    pos.len() == 1 or tags != none,
    message: "@rheo/rookery: #window needs something to show — name at least "
      + "one note, or pass `tags:` to select them by tag.",
  )
  let ids = if pos.len() == 0 { () } else {
    let names = pos.first()
    (if type(names) == array { names } else { (names,) }).map(_norm)
  }

  // A transclusion is a way of pointing at a note, so it has to show up in the
  // target's backlinks. `_outbound` walks a note's RAW body at registration,
  // where everything below is still an unevaluated `context` block with
  // nothing inspectable in it — so the names are announced up front, in an
  // invisible `metadata` element, where the walk can see them without
  // rendering anything.
  //
  // Bare names, not full ids: this runs outside `context`, so `_pfx()` is not
  // available here. `_outbound` re-adds the prefix, which it can.
  //
  // Only the NAMED ids can be announced. A tag selection is not known until
  // the registry is readable, which needs `context`, and by then this walk has
  // already happened — so tag-matched notes get no backlink from this window.
  // That asymmetry is documented in the readme; do not "fix" it by announcing
  // the tags instead, which would have `_outbound` read the registry while it
  // is still being built.
  // LABELLED, so `query()` can find it as well as the content walk.
  //
  // `_page-outbound` walks a vertebra's content at `#show: rookery` time to
  // build its backlink beacon, and that walk CANNOT ENTER A CONTEXT BLOCK — the
  // body does not exist until layout. So a `#window` emitted from inside one
  // announced itself to nobody, and every note it transcluded lost its backlink
  // from the page transcluding it. Not a corner case: any package that computes
  // which notes to window must do so inside a context, since reading the
  // registry needs one. MEASURED with `@rheo/rookery-todos`'s
  // `#todos-ready(windows: true)`, which produced no backlinks at all while a
  // hand-written window on the same page produced them.
  //
  // The label costs nothing here and lets `_page-links` pick these up by query
  // instead. THE MARKER STAYS OUTSIDE THE CONTEXT BLOCK BELOW, which is the
  // whole point: `_page-links` resolves which page it sits on with
  // `state("rheo-handle").at(el.location())`, the positional read
  // `_ideas-outline-data` already uses. Reading `.get()` from inside the
  // context instead was tried and REVERTED — it made a document with minted
  // pages fail to converge in five attempts, because the value observed
  // depended on where the surrounding layout had got to.
  [#metadata((rookery-window: ids)) <rookery-window-mark>]

  context {
  let reg = _registry.final()

  // Named ids first, in call-site order, and the only ones that can be wrong:
  // a tag scan reads the registry it filters, so it cannot name a missing note.
  //
  // EXCLUDED IS NOT MISSING. A note this build dropped for its tags (see
  // `_resolve-excluded`, base.typ) is deliberately absent, and a `#window` on it
  // renders NOTHING rather than failing the build — otherwise turning on an
  // exclusion breaks the public build wherever a surviving note or page links to
  // a removed one, which would make the feature unusable in the one scenario it
  // exists for. Filtered out of `named` here, so every consumer of that array
  // below (the sort, the tag merge, the rendering) simply never sees it.
  //
  // A TYPO STILL PANICS, message unchanged, and telling the two apart is the
  // entire reason `_excluded-ids` exists (state.typ). Dropping the panic
  // outright was the alternative and it is worse: a misspelt name would then
  // silently render nothing, which is the class of mistake this package fails
  // loudly on everywhere else.
  //
  // CANNOT BE RESCUED, and no later bead should try: the `@idea:x` MARKUP form
  // is a Typst `ref` to a label minted by the very `#idea` that got removed, so
  // it is a hard `label does not exist` error neither this package nor rheo can
  // intercept. An author whose notes may be excluded routes links to them
  // through `#window`, `#hyperlink` or `#note-href` — never through `@`.
  //
  // ALSO REJECTED: minting the hidden anchor and label for an excluded note so
  // `@`-refs keep resolving. That leaks the excluded note's id into the public
  // build's HTML, which for a `private` tag is precisely what the feature exists
  // to prevent.
  let gone = _excluded-ids.final()
  let named = ids.map(n => _pfx() + n).filter(id => {
    if id in reg { return true }
    if id in gone { return false }
    panic("@rheo/rookery: #window unknown note '" + id + "'")
  })

  // Tag matches minus anything already named — a note that is both shows once,
  // in the position the author named it.
  let tagged = if tags == none { () } else {
    let pred = _tag-pred(tags, match)
    if pred == none { () } else {
      reg
        .pairs()
        .filter(p => pred(p.at(1).at("tags", default: (:))))
        .map(p => p.at(0))
        .filter(id => id not in named)
        .sorted()
    }
  }

  // `auto` keeps the author's own order for what they named and appends the
  // tag matches; naming a sort orders the whole selection instead.
  let full-ids = if sort == auto { named + tagged } else {
    _sort-ids(named + tagged, reg, sort)
  }

  for id in full-ids {
    let rec = reg.at(id)

    // THIS CALL SITE'S OWN BUDGET, resolved once: `auto` takes the
    // document-wide setting. Both the depth-0 branch below and `windows-claim`
    // need the number rather than `auto`, and reading it twice invited them to
    // disagree.
    let d = if depth == auto { _window-depth.final() } else { depth }

    // The marker an ENCLOSING `_flatten` reads when this window turns out to
    // be nested inside a transcluded body. It carries the presentation
    // arguments as well as the id, so the collapse-or-expand decision up
    // there can rebuild this exact window rather than a default one. NOT
    // `depth`, though — the budget belongs to the scope doing the expanding,
    // not to the call site being expanded.
    //
    // The key is `rookery-window-id`, not `rookery-window`: that name is
    // taken by the announce marker above, and `_outbound`/`_page-links` both
    // test for it by exact key on any dictionary-valued metadata they walk.
    let marker = metadata((
      rookery-window-id: id,
      folded: folded,
      show-date: show-date,
      show-tags: show-tags,
      limit: limit,
    ))

    // DEPTH 0 — A LINK, NOT A TRANSCLUSION. The note's title, linked to the
    // note's own page, and nothing else: no summary row, no `<details>`, no
    // body, so there is no `_window-content` on this path at all.
    //
    // It wears the row shape a minted page already gives a PAGE it names —
    // `.idea-page-list`/`.idea-page-row`, built by `.marrow.typ`'s `page-list`
    // for Context and for the page half of Backlinks — rather than a third row
    // style of its own: "a pointer to somewhere you can read this" is the same
    // kind of thing here as it is there, and the stylesheet already draws it
    // (the same left rule and indent a window gets, no box).
    //
    // `_resolve-dest` for the href, the same resolution `_permalink` and
    // `#hyperlink` use, so this link cannot disagree with them about where a
    // note lives: the minted page where there is one, and the note's in-context
    // label where there is not (plain `typst compile`, the combined PDF).
    // A TITLELESS note has no title to link, so the permalink IS the row — the
    // same `[idea:x]` a depth-exhausted nested window collapses to.
    //
    // `limit:` and `folded:` are simply inert here, not an error: a link has no
    // body to truncate and nothing to fold. Both still ride on `marker`, so an
    // enclosing `_flatten` that DOES have budget rebuilds the full window with
    // them intact — the budget belongs to the scope doing the expanding, and
    // that is as true of `depth: 0` as of any other value.
    if d <= 0 {
      let shape = _window-link(id, rec)
      _bracket(figure(kind: WK, supplement: none, [#marker#shape]), WK)
      continue
    }

    let body = _body-at(rec, depth: depth)
    let shown = _truncate(body, limit)

    // Bracketed: the body being shown belongs to the note it came from, so
    // its links must not read as links from whatever page is showing it.
    _bracket(
      figure(kind: WK, supplement: none, [
        #marker#_window-content(id, rec, shown, folded, show-date, show-tags, windows-claim: d > 1)
      ]),
      WK,
    )
  }
  }
}

// ---- #idea-body — one note's body, as CONTENT ------------------------------
//
//   #context idea-body("etal")                 // -> content, or a panic
//   #context idea-body("etal", limit: 3)        // first three blocks
//
// The note's body as the REAL Typst-rendered thing — links, styling,
// footnotes, citations — not the plain string `#ideas()`'s `body` field
// gives out. For a consumer that wants to show the actual note rather than
// tell about it, the way `@rheo/rookery-search`'s preview pane does: a
// `body` string can be matched and excerpted, and that is exactly what it is
// for, but a code block inside it reads as bare, unstyled source text with
// no separation from the prose around it — MEASURED as "Typst markup peeking
// through" the moment a note quotes any code at all. Rendering the real
// content fixes that at the root: the browser gets an actual `<pre><code>`,
// not a paragraph that happens to contain one.
//
// NOT `#window`, despite doing almost the same rendering underneath. Two
// differences, both load-bearing:
//
//   1. `#window` ANNOUNCES the note it shows, up front, via the same
//      `metadata((rookery-window: ids))` marker `_outbound` reads at
//      REGISTRATION time to build the backlinks graph — a note shown in a
//      `#window` counts as a link TO it from wherever the window sits. That
//      is correct for a window written into a note's own prose, and
//      catastrophic for a call site meant to run once per note on EVERY
//      page, as a search preview does: every page on the site would end up
//      "linking" to every note in the whole rookery. `idea-body` skips the
//      announcement entirely — it renders, and nothing more.
//   2. `#window` draws chrome: a summary line (title, permalink, date) and a
//      `<details>` disclosure. `idea-body` is body only, always fully shown
//      — a caller wanting a title has it already, from whatever listed the
//      note in the first place (`#ideas()`'s `text` field, here).
//
// STILL `_bracket`ed, the same edges `#window` draws, for the same reason
// `#window` needs them: `_page-links` walks a page's own outbound links by
// COUNTING BRACKET DEPTH (see `_edge`), and unbracketed content here would
// make every link inside every previewed note look like a link the page
// itself wrote — corrupting the page-backlinks half of `.marrow.typ`'s
// Backlinks section for every page that calls this.
//
// Wrapped in `.idea-window`/`.idea-window-body` — the same classes
// `#window` wraps its own body in — so it inherits every rule rookery.css
// already writes for prose inside a window: link colours, raw/code styling,
// list and footnote layout. A consumer never has to restyle any of that
// itself. `_themed` carries the document's theme along as an inline style,
// the same way every other container this package emits does, since a
// caller's own container (rookery-search's hidden preview templates, say)
// has no `.idea-*` ancestor to inherit the custom properties from.
//
// `limit:` truncates by BLOCK — a paragraph, a list — the same unit
// `#window`'s own `limit:` uses, because that is the unit that can be cut
// without leaving half a sentence. `none` (the default) shows the whole
// body.
//
// `depth` is the same transclusion budget `#window` takes (see
// `_window-depth`); `1` (the default) renders the body with any nested
// `#window` collapsed to its permalink rather than unfurled, which keeps a
// preview's own size bounded regardless of how deep the note it is showing
// nests. PINNED rather than `auto` for that reason, and `1` rather than `0`
// because this function's job is to render a body: `@rheo/rookery-search`'s
// preview pane calls it without passing `depth` at all, and a default of 0
// would turn every search preview into a link. (`depth: 0` here renders the
// body all the same — there is no chrome and no link shape to fall back to,
// which is `#window`'s job; it simply asks for no unfurling, as `1` does.)
//
// HTML/EPUB only, like `#window`'s own chrome — its only realistic consumer
// is a web preview, and `html.elem` is what builds the `.idea-window`
// wrapping. On a paged target the body still renders, just without that
// wrapping, so a stray direct call does not hard-error.
//
// Must be called INSIDE a `#context` block — it reads `_registry.final()`.
#let idea-body(name, depth: 1, limit: none) = context {
  // Both asserts are copied verbatim from `#window`, which takes the same two
  // parameters with the same meaning — the messages have to agree, or one call
  // site teaches a rule the other contradicts. `>= 1` on `limit` for the reason
  // stated there.
  assert(
    depth == auto or (type(depth) == int and depth >= 0),
    message: "@rheo/rookery: #idea-body's `depth` must be auto or a "
      + "non-negative integer — got " + repr(depth),
  )
  _assert-limit(limit, "#idea-body's")
  let id = _pfx() + _norm(name)
  let reg = _registry.final()
  if id not in reg {
    // EXCLUDED IS NOT MISSING — the same distinction `#window` above draws, for
    // the same reason and through the same state. An excluded note renders as
    // nothing; a typo still panics with the message unchanged.
    if id in _excluded-ids.final() { return [] }
    panic("@rheo/rookery: #idea-body unknown note '" + id + "'")
  }
  let rec = reg.at(id)
  let body = _body-at(rec, depth: depth)
  let shown = _truncate(body, limit)
  let inner = _footnoted(shown) + _refs-block(_own-cited-keys(shown, windows-claim: depth > 1))
  if _target() == "html" or _target() == "epub" {
    // `idea-window-plain`: this render has no chrome by design (no summary,
    // no disclosure), so it should not carry `.idea-window`'s BOX either —
    // the border, padding and hover tint that make sense around an actual
    // on-page `#window`, not around a body a caller is embedding inside a
    // box of its own. See rookery.css for why this needs a second class
    // rather than a downstream override.
    _bracket(
      html.elem(
        "div",
        attrs: _themed((class: "idea-window idea-window-plain")),
        html.elem("div", attrs: (class: "idea-window-body"), inner),
      ),
      WK,
    )
  } else {
    _bracket(align(start, block(inner)), WK)
  }
}
