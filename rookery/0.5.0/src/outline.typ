// `#ideas-outline` — a table of contents for the ideas on THIS page, or across
// the whole rookery, and the data pass behind it.
//
// Also holds the page-level link map it shares with the minted pages' footer:
// both answer "which pages mention this note", from opposite ends.

#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *
#import "hyperlink.typ": *
#import "links.typ": *
#import "idea.typ": *

// ---- Page-level links ------------------------------------------------------
//
// `handle -> (note ids that page links to DIRECTLY)`, for the page half of the
// backlinks list. Directly means at depth 0: not inside an `#idea`, and not
// inside a `#window`'s transcluded body (see `_edge`).
//
// This is the one thing in the package that cannot come from the registry.
// The registry holds notes, and a link in a page's own prose belongs to no
// note — so the page itself has to be asked.
//
// ASKED AS A CONTENT QUESTION, and BEACONED, rather than swept out of the
// document with `query`. This used to be one bundle-wide
// `query(metadata|link|ref)` walked in document order with a depth counter, and
// that shape is what put a rookery site over Typst's five-iteration relayout cap.
// The sweep's result builds the backlink list on every page `.marrow.typ` mints,
// and those minted pages replay note bodies — so they emit `link`, `ref` and
// `metadata` elements that the same sweep then sees. The query fed the pages it
// queried, and each round of that costs one iteration of a budget capped at
// `MAX_ITERS = 5` (typst-library/src/introspection/convergence.rs).
//
// MEASURED on an 82-note site, warning counts with ANSI stripped: 4 with the
// sweep, 2 with it stubbed out entirely. Past the cap `state("rheo-handle")`
// reads stop converging, and a note's page-relative href degenerates to ONE
// value shared by every page it is replayed onto — which is how 72 links came
// out `../ideas/<slug>.html` from the site root and 404'd. A converging site
// does not have that problem: verified on a small rookery site, where the same
// stored body yielded `ideas/m.html` at depth 0 and `../ideas/m.html` at depth 1,
// both correct, from unmodified code.
//
// So each vertebra now scans its OWN content — `_page-outbound` below, a plain
// content walk with no introspection at all — and publishes the answer as one
// labelled `metadata` beacon, exactly the shape rheo uses for its own per-vertebra
// metadata. `_page-links` reads `query(<rookery-page-links>)`, a selector a
// minted page never contributes to, so the loop is closed: the input no longer
// grows when marrow mints. `#show: rookery` is what emits it (see `template.typ`),
// which is also what scopes it to vertebrae — a minted page applies the project's
// `idea-page-template`, not `rookery()`, so it publishes nothing here.
//
// Four shapes count, the same four `_outbound` counts inside a note:
//
//   #link(label("idea:etal"))   a `link` element whose dest is a label
//   @idea:etal                   a `ref` element
//   #window("etal")               the `rookery-window` marker `#window` emits
//   #hyperlink("etal")[...]       the `rookery-link` marker `#hyperlink` emits
//
// `#hyperlink` needs its own marker, like `#window`, because its `link-to:
// "page"` default resolves to a plain href STRING (not a label) whenever a
// page is minted — invisible to the `f == link and type(el.dest) == label`
// check below. `link-to: "anchor"` would have stayed a label link and been
// caught by that check anyway, but the marker covers both modes uniformly
// rather than depending on which one was passed. `#hyperlink` used AS the
// `show ref:` rule needs no marker of its own: it renders a `ref` element,
// already the second shape above.
//
// A `ref` also renders INTO a link, so it can be seen twice; the result is a
// set per page, so seeing it twice costs nothing.
// WHY A CONTENT WALK AND NOT A DEPTH COUNTER. The sweep this replaces got
// "not inside an idea or window" from the `rookery-edge` open/close markers
// `_bracket` emits, counted in document order. A content walk gets the same
// answer structurally, by simply not descending: an `#idea` IS a
// `figure(kind: IK)` in the body it was written into, and a `#window` announces
// itself with a `rookery-window` marker before its own `figure(kind: WK)` exists
// (that figure is built inside a `context`, so at content-walk time there is
// nothing else of it to find — the same fact `_cite-scan` in `bib.typ` is built
// around, and the reason it scans for the marker too).
//
// A page-level `#window` therefore both COUNTS as a page link and STOPS the walk,
// which is right on both counts: the page links to those notes, and whatever the
// transcluded bodies link to belongs to them, not to this page.
#let _page-outbound(node) = {
  let out = ()
  if type(node) != content { return out }
  let f = node.func()
  if f == link { return if type(node.dest) == label { (str(node.dest),) } else { () } }
  if f == ref { return (str(node.target),) }
  if f == metadata {
    let v = node.value
    if type(v) != dictionary { return out }
    if "rookery-window" in v { return v.rookery-window }
    if "rookery-link" in v { return (v.rookery-link,) }
    return out
  }
  // A note's own links belong to the note. Stop here.
  if f == figure and node.at("kind", default: none) in (IK, WK) { return out }
  if node.has("children") { for k in node.children { out += _page-outbound(k) } }
  else if node.has("body") { out += _page-outbound(node.body) }
  else if node.has("child") { out += _page-outbound(node.child) }
  out
}

// The beacon `#show: rookery` publishes, one per vertebra. Must be called from a
// `context`: it reads the prefix and this page's handle.
//
// A `rookery-window`/`rookery-link` marker carries a BARE name and a `link`/`ref`
// a full id, which is why the prefix is applied to the first two only — the same
// asymmetry the sweep had.
#let _page-links-beacon(doc) = {
  let pfx = _pfx()
  let handle = state("rheo-handle").get()
  if type(handle) != str { return }
  let targets = ()
  for t in _page-outbound(doc) {
    let full = if t.starts-with(pfx) { t } else { pfx + t }
    if full not in targets { targets.push(full) }
  }
  [#metadata((handle: handle, targets: targets)) <rookery-page-links>]
}

#let _page-links() = {
  let out = (:)
  for el in query(<rookery-page-links>) {
    let v = el.value
    if type(v) != dictionary { continue }
    let handle = v.at("handle", default: none)
    // Vertebrae only, as before. A project whose minted-page template applies
    // `#show: rookery` again would otherwise publish a beacon per minted page and
    // list those pages as backlinks to the notes they render.
    if type(handle) != str or not _is-vertebra(handle) { continue }
    let seen = out.at(handle, default: ())
    for t in v.at("targets", default: ()) {
      if t not in seen { seen.push(t) }
    }
    out.insert(handle, seen)
  }
  out
}

// ---- #ideas-outline — a table of contents for THIS page's own ideas -------
//
// Typst's own `#outline()` can't see ideas: it lists `heading` elements, and
// an idea only ever becomes one on the PAGED target (`heading(depth: level,
// ...)`, inside `#idea`'s `else` branch) — never on html/epub, where the
// title renders as a raw `html.elem("h" + ..., ...)`, a plain HTML tag with
// no Typst-level `heading` behind it at all. `#outline()` would therefore
// see every idea on PDF but NONE on the primary html/epub targets. Built
// instead off the same query-time machinery `_page-links` already uses (the
// `rookery-edge` open/close markers `_bracket` wraps every idea AND window
// in), so it works identically on every target.
//
// Nesting is the idea's LITERAL containment depth in the document (one
// `#idea` written inside another's body) — not the author-set `level:`
// (a heading-level knob authors are free to leave untouched regardless of
// nesting, and usually do; concepts.typ's own nested ideas never set it).
// Depth from real nesting means the outline is correct with zero ceremony,
// matching `#idea`'s own "hatch without ceremony" design.
//
// MEASURED, the reason this tracks TWO separate depths (`idea-depth`,
// `window-depth`) instead of one: a `show figure.where(kind: ...): ...`
// rule (which is all `_flatten`'s IK rule is) does NOT remove the original
// figure from `query()` — exactly like `show ref: hyperlink` leaves a `ref`
// still queryable as one (see `_page-links`'s own comment, "a ref also
// renders into a link, so it can be seen twice"). So a note windowed
// (possibly transitively, A-windows-B-windows-C) onto THIS page re-exposes
// every `figure(kind: IK)` its stored body ever contained, each a REAL
// match here, indistinguishable by `kind` alone from one actually hatched
// on this page. Confirmed by a two-page reproduction with mutual
// transclusion (rookery.ohrg.org's index.typ <-> concepts.typ, via
// `#window((<rookery>, <idea>), ...)`): without this check, ideas authored
// elsewhere surfaced nested under the WRONG local idea, several levels deep
// and wrongly attributed. A note is only ever counted at `window-depth ==
// 0`, i.e. not currently inside ANY `#window`'s content, cascaded through
// any number of levels — `idea-depth` (recorded before ITS OWN bracket
// opens) is then a clean count of real enclosing `#idea`s alone.
//
// Scoped to the CURRENT page (`origin`, in `_page-links` terms) unless
// `rookery-wide`: `query()` sees the whole spine (it compiles as one Typst
// document), so the `state("rheo-handle").at(...)` check below is the only
// thing that makes this a page's table of contents rather than the rookery's.
//
// ROOKERY-WIDE drops that check and keeps everything else — one tree of every
// idea in the spine, in spine order, nested by real containment exactly as
// the per-page form is. It substitutes a WEAKER check rather than none at
// all: only vertebrae count. `.marrow.typ` mints one page per note, each
// re-rendering that note's stored body, and a stored body's nested
// `figure(kind: IK)`s stay queryable through the show rule that rebuilds
// them (the same fact the `window-depth` check above turns on). The per-page
// form never had to care — a minted page's handle is `ideas:<slug>`, which
// simply is not `here` — so this hazard arrives with `rookery-wide`, and
// `handle not in spine` is the answer (the same predicate `_is-vertebra`
// applies for `_page-links`, spelled against the handle list this function
// already builds for ordering, so it costs one pass instead of one walk of
// `spine-flat` per entry). MEASURED on a three-vertebra spine: without it,
// `ideas:b-one` and `ideas:i-one` each re-exposed the nested idea in their
// own stored body, listing it a second time.
//
// That guard is gated on `multi-page` and must be: MEASURED on the combined
// PDF, where `.marrow.typ` is skipped outright, every vertebra's
// `state("rheo-handle")` is the empty string — a str, and not in the spine,
// so an ungated check swallowed the entire outline. Applying the guard only
// where the hazard exists is also why no exemption for `""` is needed.
//
// WHERE THERE IS ONLY ONE PAGE, the two forms agree and list the whole spine
// — which is the right answer, not a degradation: "this page's ideas" and
// "the rookery's ideas" are the same set when the output is one document.
// Both single-page targets reach it without a special case:
//
//   - the combined PDF, because every vertebra's handle is `""` and so is
//     equal to `here`;
//   - plain `typst compile` with no rheo, because nothing publishes
//     `state("rheo-handle")` at all, so `here` and every handle are `none`.
//
// The second used to be an early `return ()` on a non-str `here`, which made
// a standalone `#ideas-outline()` render its title over an empty list. Not
// worth keeping: the comparison below already gives the correct answer, and
// the two one-page targets now behave identically instead of one listing
// everything and the other nothing.
//
// Neither reorders (see `multi-page` below): a one-page target has one page
// order, its own, and the two forms would otherwise disagree about it on the
// very target where they list the same set.
//
// Untitled ideas (the bare `#idea[body]` form, auto-numbered) are omitted —
// nothing to label them with, and an outline entry is a heading text, not
// an id. Each entry links to `el.location()` directly, no href/label
// reconstruction: VERIFIED to resolve cross-page too under rheo's bundle
// export (`../<page>.html#loc-N`, the same shape `#link(label(id))` gets),
// so `rookery-wide` needs no second linking path.
#let _ideas-outline-data(rookery-wide: false) = {
  let here = state("rheo-handle").get()
  let c = _rheo-ctx()
  // Every vertebra's handle, IN SPINE ORDER — the order the author configured
  // (`[[spine.section]]` and the directory scan), not the order the files
  // happen to be named in. Empty without rheo, which is what "if it exists"
  // amounts to: nothing to order by, so document order stands.
  //
  // Doubles as the vertebra test below, replacing a call to `_is-vertebra`
  // (which walks `spine-flat` afresh per entry). Same predicate, one pass.
  let spine = if c == none { () } else {
    c.at("spine-flat", default: ()).map(v => v.at("handle", default: none))
  }
  // Is the output MULTI-PAGE? `ext` is present for html/epub and absent for
  // the combined PDF (and there is no context at all under plain `typst
  // compile`) — the same test `_note-href` uses. Two things hang off it, and
  // they are the same fact seen twice:
  //
  //   - `.marrow.typ` mints one page per note only here, so only here can a
  //     minted page re-expose a stored body's ideas (see the filter below);
  //   - only here does an ORDER OF PAGES exist for the spine — or for
  //     index-first — to mean anything. A combined PDF is one linear
  //     document; its outline should follow that document, and reordering it
  //     against the page sequence the reader is holding would be a lie.
  let multi-page = c != none and c.at("ext", default: none) != none
  let idea-depth = 0
  let window-depth = 0
  let out = ()
  for el in query(selector(metadata).or(selector(figure.where(kind: IK)))) {
    let f = el.func()
    if f == metadata {
      let v = el.value
      if type(v) != dictionary { continue }
      let edge = v.at("rookery-edge", default: none)
      let container = v.at("rookery-container", default: none)
      if edge == "open" and container == IK { idea-depth += 1 }
      if edge == "close" and container == IK { idea-depth -= 1 }
      if edge == "open" and container == WK { window-depth += 1 }
      if edge == "close" and container == WK { window-depth -= 1 }
      continue
    }
    // Inside a `#window`, at any cascade depth: an echo of a note stored
    // (and possibly authored) elsewhere, not this page's own structure.
    if window-depth > 0 { continue }
    let handle = state("rheo-handle").at(el.location())
    if rookery-wide {
      if multi-page and type(handle) == str and handle not in spine { continue }
    } else if handle != here {
      continue
    }
    let m = el.body.children.find(x => x.func() == metadata)
    if m == none { continue }
    let v = m.value
    if v.title == none { continue }
    // `tags` with a default, not `v.tags`: this metadata is read on the paged
    // and no-rheo paths too, and a default costs nothing where a missing key
    // would panic.
    out.push((
      depth: idea-depth,
      title: v.title,
      loc: el.location(),
      handle: handle,
      tags: v.at("tags", default: (:)),
    ))
  }

  // SPINE ORDER, explicitly. `query()` returns document order, and MEASURED
  // (typst 0.15.1, rheo 0.5.1) that already IS spine order today — verified
  // against a spine deliberately ordered AGAINST filename order with two
  // `[[spine.section]]`s, where `("aaa-first:gamma", "beta", "zzz-last:alpha")`
  // came out in exactly that sequence rather than alphabetically. So this
  // reorders nothing at present. It is here to make the guarantee the
  // OUTLINE's rather than one borrowed from how rheo happens to assemble its
  // bundle: an author who reorders the spine is entitled to have the index of
  // their rookery follow, and nothing else in this package would notice if
  // that coincidence ever ended.
  //
  // Bucketing, not `.sorted(key:)`: within one vertebra the entries must keep
  // document order EXACTLY, because that order is what carries the nesting
  // (`_nest-outline` reads a depth-tagged run, not a tree), and this does not
  // depend on Typst's sort being stable. Each vertebra's entries are already
  // contiguous — a vertebra's content is contiguous in the document, and
  // minted-page entries are filtered out above — so moving whole buckets
  // cannot split or merge a subtree.
  //
  // The trailing bucket catches a handle that is not a spine vertebra at all:
  // nothing reaches it today (the filter above drops those wherever minted
  // pages exist, and a `none`/`""` handle means a single-page target where
  // the whole list is one bucket anyway), but it keeps such entries in
  // document order at the end rather than dropping them.
  // INDEX FIRST. A rookery's `index.typ` is its front door — the page a
  // reader lands on — so an index of the whole rookery leads with it whatever
  // the spine says. rheo already does this for a NESTED directory, where
  // `index.typ` becomes that directory's landing page and therefore sorts
  // ahead of its siblings in the pre-order walk; at the ROOT it deliberately
  // does not ("Root-level index.typ is a normal leaf; only nested dirs treat
  // it as a landing page" — rheo's `reticulate/spine.rs`), so the root index
  // lands wherever the alphabet puts it. MEASURED on rookery.ohrg.org:
  // `("about", "concepts", "index", "install")`. Hoisting it here is what
  // makes the two cases read the same way — a landing page first, at every
  // level — rather than the root being the one place the front door turns up
  // in the middle.
  //
  // Exactly the handle `"index"`, not any handle ENDING in it: a nested
  // `sub:index` is already first within its own subtree by rheo's own rule,
  // and pulling it to the top of the rookery would tear it out of the section
  // it lands.
  let order = if "index" in spine { ("index",) + spine.filter(h => h != "index") } else { spine }

  if rookery-wide and multi-page and order.len() > 0 {
    let rank = (:)
    for (i, h) in order.enumerate() {
      if type(h) == str { rank.insert(h, i) }
    }
    let buckets = range(order.len() + 1).map(x => ())
    for e in out {
      let b = if type(e.handle) == str { rank.at(e.handle, default: order.len()) } else { order.len() }
      buckets.at(b) = buckets.at(b) + (e,)
    }
    out = buckets.flatten()
  }
  out
}

// `title`/`depth` mirror Typst's own `outline()`
// (https://typst.app/docs/reference/model/outline/) so the two feel like
// one family: `title: auto` (the default) prints "Contents" — the same
// text Typst's own `#outline()` defaults to (MEASURED: `#outline()`'s
// title heading has `body: "Contents"` — there is no localization anywhere
// else in this package, so this doesn't attempt any either); `none` omits
// it entirely; any other content replaces it outright. Rendered as a real
// `heading`, `outlined: false` + `numbering: none` — the exact two
// properties MEASURED on Typst's own outline title — so it neither
// self-lists in a LATER `#outline()` targeting headings nor picks up the
// document's own heading numbering.
//
// `depth` (`none` or a positive integer) caps how many nesting LEVELS show,
// counting the same way Typst's own heading `level` does: top-level ideas
// are level 1. `_ideas-outline-data`'s `depth` field is 0-indexed (a
// top-level idea is `0`), so the comparison adds 1 to match.
//
// `rookery-wide: true` lists EVERY idea in the rookery instead of only this
// page's — one tree, in spine order, nested by the same real containment.
// The whole spine compiles as one Typst document, so this costs nothing
// extra: it is the per-page filter being lifted, not a second pass. `depth`
// composes with it, and caps containment levels either way — it does not
// mean "pages".
//
// Deliberately NOT grouped under per-page headings. An idea's id is flat and
// travels between files precisely so a reader never has to know which file
// holds it (see "Flat ids, and why" in the readme); an index that led with
// filenames would put that back. Entries link straight to the idea wherever
// it was written.
//
// `tags`/`match` are the same pair `#window` and `ideas()` take, through the
// same shared `_tag-pred`, and `filter` is a predicate of the caller's own over
// the same tag array, ANDed with them — see `_tag-pred` in `pure.typ` for why
// exclusion and an OR of ANDs are a function value here rather than four more
// keyword parameters. What differs is that an outline is a TREE, so a
// filter cannot be a `.filter()`: `_nest-outline` reads a FLAT depth-tagged run
// and assumes it is well formed, so a depth-1 entry left behind by a dropped
// depth-0 parent is silently read as a sibling of whatever came before. Hence
// `_prune-outline` below, which prunes AND PROMOTES.
#let _prune-outline(entries, pred) = {
  if pred == none { return entries }
  // `kept` holds the ORIGINAL depths of the entries that survived. Popping every
  // one whose depth is >= the current entry's leaves exactly the surviving
  // ANCESTORS on the stack, so `kept.len()` is the re-based depth: a matching
  // idea whose parent was filtered out lands at its nearest kept ancestor's
  // level rather than dangling at a depth with no parent above it.
  //
  // REJECTED: keeping unmatched ancestors as unlinked scaffolding, for context.
  // It puts notes in the index the filter said to exclude, and this package has
  // no styling for a row that is not a link.
  let kept = ()
  let out = ()
  for e in entries {
    while kept.len() > 0 and kept.last() >= e.depth { kept = kept.slice(0, kept.len() - 1) }
    if pred(e.tags) {
      out.push((..e, depth: kept.len()))
      kept.push(e.depth)
    }
  }
  out
}
#let ideas-outline(
  title: auto,
  depth: none,
  rookery-wide: false,
  tags: none,
  match: "any",
  filter: none,
) = context {
  assert(
    depth == none or (type(depth) == int and depth >= 1),
    message: "@rheo/rookery: #ideas-outline's `depth` must be none or a "
      + "positive integer — got " + repr(depth),
  )
  assert(
    type(rookery-wide) == bool,
    message: "@rheo/rookery: #ideas-outline's `rookery-wide` must be a boolean "
      + "— got " + repr(rookery-wide),
  )
  _assert-tags(tags, "#ideas-outline's")
  _assert-match(match, "#ideas-outline's")
  assert(
    filter == none or type(filter) == function,
    message: "@rheo/rookery: #ideas-outline's `filter` must be none or a "
      + "function taking the note's tag dictionary — got " + repr(filter),
  )
  let title-content = if title == auto { [Contents] } else { title }
  let entries = _ideas-outline-data(rookery-wide: rookery-wide)
  // Pruned BEFORE the `depth:` cap, and that order is the whole point: `depth`
  // then counts levels in the FILTERED tree, so `depth: 1` means "the top level
  // of what I asked for" rather than "whatever survived from the top level of
  // everything".
  let pred = _tag-pred(tags, match, filter: filter)
  entries = _prune-outline(entries, pred)
  if depth != none { entries = entries.filter(e => e.depth + 1 <= depth) }

  // On HTML an explicit `h4` carrying a class, the same shape (and the same
  // reason) as the Footnotes block's heading: a bare `heading()` compiled to
  // an unclassed `<h2>`, which took the host site's heading scale and made
  // "Contents" as loud as a section title — for a label on a list of links.
  // The class is what lets it be sized down, and there is nothing else on the
  // element to target.
  //
  // `idea-tab` ALONGSIDE IT, so this title is A HAT — the same object a note's
  // id sits on, a stub of rule out of the corner with the label on its end. The
  // tab treatment goes on the `<h4>` ITSELF rather than wrapping it, because
  // `.idea-tab` is emitted elsewhere as a `<span>` (`_permalink-tab`) and a
  // `<span>` may not contain an `<h4>`; the tab is only `display: flex` plus a
  // `::before`, so an element can wear it directly. It stays an `<h4>` — see
  // above for why the element matters and the stylesheet for how it is kept from
  // reading like one.
  //
  // `_themed`, AND IT IS NOT OPTIONAL HERE. The theme travels as inline custom
  // properties, which inherit DOWN the DOM, and this title is a SIBLING of the
  // `<ul>` rather than a descendant — the same reason `_nest-outline` themes the
  // outermost `<ul>` itself. MEASURED without it, on a project setting
  // `border-color: #ff0000, rule-width: 3px, label-font: Berkeley Mono`: the
  // list drew a 3px red rule while the hat above it drew a 2px last-resort
  // purple stub in the reader's plain monospace — a corner in two colours and
  // two widths. With it, both read `--idea-rule-width`/`--idea-border-color` and
  // the title reads `--idea-label-font`.
  //
  // The paged target keeps the real `heading()`: there it IS a document
  // structure, it belongs in the PDF outline, and nothing is styling it by
  // class.
  let title-heading = if title-content == none { none } else if (
    _target() == "html" or _target() == "epub"
  ) {
    html.elem("h4", attrs: _themed((class: "idea-outline-title idea-tab")), title-content)
  } else {
    heading(depth: 1, outlined: false, numbering: none, title-content)
  }
  // An empty UNFILTERED outline is an answer: the page said "here is the index
  // of this page's notes", there are none, and the heading is the sentence. An
  // empty FILTERED one is a promise the filter already ruled out — a page
  // carrying `#ideas-outline(title: [Todos], tags: "todo")` on every section
  // would render a "Todos" heading over emptiness on every section without one.
  // So the two cases differ on purpose, and `pred != none` is exactly "a filter
  // is active" — no separate flag, and no `hide-when-empty:` knob.
  //
  // `depth:` deliberately does NOT count as a filter here. It drops levels below
  // the first, so it cannot empty an outline that had anything in it at all.
  if entries.len() == 0 { return if pred == none { title-heading } else { none } }

  let list-content = if _target() == "html" or _target() == "epub" {
    _nest-outline(
      entries,
      (items, root) => html.elem(
        "ul",
        attrs: if root { _themed((class: "idea-outline")) } else { (class: "idea-outline") },
        items.join(),
      ),
      // The title in a span of its own, so the hairline marker and the row's
      // left rule can be positioned against the ROW while the link keeps the
      // hover treatment every other rookery link has.
      //
      // The note's tags go on the row as `idea-tag-<tag>` classes, built the
      // same way `#idea` builds them for the heading and for the card — one
      // convention, three emission sites, so a site styling a todo note in the
      // body can style the same note's row in the index. It is also the zero-API
      // half of tag filtering: with the classes here a site can grey, badge or
      // hide rows in its own CSS, with no Typst-side filter at all. The package
      // ships NO default rule for any of them — `#note`/`#todo` are sugar, not a
      // recognised set, and styling one here would invent an opinion.
      (e, sub) => html.elem(
        "li",
        attrs: (class: (("idea-outline-row",) + e.tags.keys().map(l => "idea-tag-" + l)).join(" ")),
        link(e.loc, e.title) + if sub == none { [] } else { sub },
      ),
    )
  } else {
    // No theme container and no marker styling on the paged target: `#idea`
    // renders as a plain `heading` there with no `.idea-box` rule to be in
    // line with, so an outline that grew rules and hairlines would be the
    // only thing on the page wearing them. Typst's own list, unchanged.
    _nest-outline(
      entries,
      (items, root) => list(..items),
      (e, sub) => list.item(link(e.loc, e.title) + if sub == none { [] } else { sub }),
    )
  }
  if title-heading == none { list-content } else { title-heading + list-content }
}


// Depth-relative href from the CURRENT page to another vertebra's page — the
// same arithmetic as `_note-href`, against a spine handle rather than a note
// id. rheo's own `show link:` rule would do this for a `#link(<handle>)`, but
// that rule lives in the document template and a marrow contribution is
// spliced in outside it, so the package computes its own.
#let _page-href(handle) = {
  let c = _rheo-ctx()
  if c == none { return none }
  let ext = c.at("ext", default: none)
  if ext == none { return none }
  let here = state("rheo-handle").get()
  if type(here) != str { return none }
  _rel-prefix(here) + handle.replace(":", "/") + "." + ext
}
