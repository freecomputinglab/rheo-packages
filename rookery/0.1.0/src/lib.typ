// rookery — atomic, interlinked, transcludable notes ("ideas") for Typst (Zettelkasten-style).
//
// A note exists only where the author writes `#idea("name")[...]` — there is
// no document show rule and no "every heading is a note" behaviour. Notes are
// flat: there is no kind/type taxonomy, only a free-form set of labels an
// author attaches to a note. `#note`/`#todo` are pure sugar over that same
// labels array (see below), not a taxonomy of their own. Note ids are flat
// Typst labels (`<note:name>`), not handle-prefixed, so a note can move
// between files without breaking inbound links.
//
// This package takes no `ctx` argument and installs no template: under plain
// `typst compile` one root file `#include`s the notes and everything works.
// Under rheo (https://rheo.ohrg.org) it feature-detects `sys.inputs` and the
// `rheo-handle` page state to upgrade cross-page links automatically.
//
// NO `#preview`/tooltip integration: rheo's package asset auto-detection only
// scans a project's own `.typ` files for package imports, not the packages
// those files' packages import in turn — so a `#preview` composing
// `@rheo/tooltip` from inside THIS package would need every consuming project
// to import `@rheo/tooltip` directly too, just to get its JS auto-injected.
// That leaky requirement (REJECTED 2026-08-14) is worse than not having the
// feature; `#link`/`#view` cover referencing a note without it.

// ---- Target detection — the only rheo-specific read ------------------------
//
// `std.target()` reports EPUB as "html"; rheo's own context distinguishes
// them. Use `std.target()` rather than a bare `target()`: rheo injects its
// `target()` polyfill into each vertebra's scope, not into package scope.
//
// REQUIRES `--features html`: `std.target` is gated by that compiler feature,
// not by output format — it is absent from `dictionary(std)` under a plain
// `typst compile` with no `--features html`, even when compiling to PDF. This
// package accepts that constraint rather than working around it: every
// invocation, including a plain paged build with no rheo, needs the flag.
// Document this as a hard requirement (readme bead).
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: none)

#let _target() = {
  let c = _rheo-ctx()
  if c != none and "target" in c { c.target } else { std.target() }
}

// ---- Note page URLs -------------------------------------------------------
//
// `.marrow.typ` mints one standalone page per note (see that file). Links
// here must agree with what it mints, so BOTH sides build the path with
// `_note-file` — never spell it out twice.
//
// The extension is literally "html" even under EPUB, where rheo-context's
// `ext` is "xhtml": `.marrow.typ` passes `document()` a literal path, so the
// minted file is `.html` whatever the format. Matching that literal is what
// keeps the href resolvable.
#let _note-file(id) = "notes/" + id.trim("note:", at: start) + ".html"

// Depth-relative href from the CURRENT page to a note's standalone page, or
// `none` when no such page exists to link to:
//   - plain `typst compile` with no rheo — nothing mints per-note pages;
//   - rheo with no `ext` in its context — the combined PDF target, where
//     `.marrow.typ` is skipped outright.
// Both fall back to a `#link(label(id))` at the call site, which still lands
// on the note's anchor wherever it was written.
//
// Mirrors rheo's own cross-vertebra link rule (crates/core/src/typ/rheo.typ):
// the current page's handle comes from `state("rheo-handle")`, published per
// #document by the bundle source, and each `:` level costs one `../`. This is
// why `.marrow.typ` mints via `rheo-document` with an explicit handle — a
// bare `document()` inherits the previous page's handle and every href
// computed on a minted page comes out at the wrong depth.
#let _note-href(id) = {
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return none }
  let handle = state("rheo-handle").get()
  if type(handle) != str { return none }
  let depth = handle.split(":").len() - 1
  let prefix = if depth == 0 { "" } else { range(depth).map(x => "../").join() }
  prefix + _note-file(id)
}

// A small, self-contained arrow link to a note's own page (falling back to
// its label anchor) — used instead of wrapping a whole transcluded body in
// one outer <a>, which breaks the moment that body contains its own link
// (see `#view`'s HTML/EPUB branch, and the folded row's revealed body).
#let _goto-link(id) = {
  let href = _note-href(id)
  if href == none { link(label(id))[→] } else { link(href)[→] }
}

// ---- #idea — marker, note:<id> label, anchor, flattened registration ------
//
// `#idea[body]`, `#idea("name")[body]`, and `#idea(<name>)[body]` all work via
// an argument sink, since `#idea[body]` passes body as the first positional
// argument. An unnamed note steps a package-wide counter and takes the
// resulting sequence number as its id; a named note is pinned and does not
// perturb that counter. Either way the note gets: a `note:<id>` Typst label on
// a hidden referenceable anchor, an HTML heading (only when `title` is given)
// carrying that id and an `idea`/`idea-label-<tag>` class list, and a registry
// entry other beads (#view, ref-rule) read from.
#let _registry = state("rheo-ideas", (:))
#let IK = "rheo-idea" // marker for an idea
#let VK = "rheo-idea-view" // marker for a view; defined here (not next to
// `#view` below) because `_flatten` needs both marker kinds and must be
// defined before `#idea`, which calls it at registration time.

// Flatten a note's body ONCE, at registration, so `#view` is pure
// presentation (any number of views cost nothing) and cycles are safe (a
// self-view, or A-views-B/B-views-A, collapses one level instead of
// re-expanding forever). Without this, a transcluded body re-emits its
// embedded machinery live: a self-view fails with "maximum show rule depth
// exceeded", and a nested `#idea` inside a transcluded body re-runs its
// registration and counter step, inflating later ids.
//
// REFUTED APPROACH, do not reintroduce: a `state` depth counter around the
// expansion. Measured failing on typst 0.14.2 AND 0.15.1 — a self-view still
// fails identically, because typst hits its nesting cap before the state
// timeline converges.
//
// The `show` rules below are LOCALLY SCOPED to the content this function
// returns — Typst content carries its own style/show-rule modifications
// wherever it is later inserted, so a nested IK/VK marker anywhere inside
// `body` gets reduced when this returned content is finally rendered, no
// matter how many `#view`s later re-embed it.
//
// GOTCHA (measured): do NOT use `it.body.children.first()` to find the
// metadata child — the marker's body begins with a SPACE element whenever the
// markup block spans multiple lines, so `.first()` returns a `space` and
// fails with `space does not have field "value"`. Use
// `.children.find(c => c.func() == metadata)`.
#let _flatten(body) = {
  show figure.where(kind: IK): it => {
    let m = it.body.children.find(c => c.func() == metadata)
    m.value.body
  }
  show figure.where(kind: VK): it => {
    let m = it.body.children.find(c => c.func() == metadata)
    link(label(m.value), text(gray)[[view of #raw(m.value)]])
  }
  body
}

// Normalise a name (string or Typst label) to its bare string form, with no
// `note:` prefix. Shared by `#idea` (pinning an explicit id) and `#view`
// (looking one up).
#let _norm(name) = if type(name) == label { str(name) } else { name }

#let idea(level: 1, title: none, labels: (), minted: none, updated: none, ..args) = {
  let pos = args.pos()
  let (name, body) = if pos.len() == 1 {
    (none, pos.at(0))
  } else {
    (pos.at(0), pos.at(1))
  }
  let named = name != none
  let base = if named { _norm(name) } else { none }

  // The marker wraps the whole idea. Its body carries the RAW body as
  // metadata so a later _flatten can render a nested idea's content without
  // re-registering or re-counting it.
  figure(kind: IK, supplement: none, [
    #metadata((body: body))
    // counter.step() RETURNS CONTENT: emit it here, never inside a code block
    // whose value is used, or it silently turns the id into content.
    #if not named { counter("rheo-ideas-seq").step() }
    #context {
      let id = if named {
        "note:" + base
      } else {
        let n = counter("rheo-ideas-seq").get().first()
        "note:" + str(n)
      }

      // Resolution order, most specific first: explicit minted:/updated:
      // arguments, then the containing document's own
      // `#set document(date:)`, else no date. MEASURED: a document with no
      // date set yields `auto`, NOT `none` — must be tested for explicitly.
      // Resolved HERE, outside the state.update() closure below: anything
      // contextual fails inside that closure with "can only be used when
      // context is known", since it runs lazily at `.final()` time.
      let doc-date = {
        let d = document.date
        if d == auto { none } else { d }
      }
      let resolved-minted = if minted != none { minted } else { doc-date }
      let resolved-updated = if updated != none { updated } else { resolved-minted }

      // Store the FLATTENED body plus the title and resolved dates, so a
      // #view is pure presentation and any number of views cost nothing, and
      // ref-rule can render a note's title without re-deriving it. A
      // duplicate EXPLICIT id only errors if something observes the registry
      // (e.g. #view/ref-rule) — an identical re-insertion is a
      // re-emission, not a collision.
      let rec = (
        title: title,
        body: _flatten(body),
        minted: resolved-minted,
        updated: resolved-updated,
      )
      _registry.update(r => {
        if id in r and r.at(id) != rec {
          panic("rookery: duplicate note id " + id)
        }
        r.insert(id, rec)
        r
      })

      // Hidden referenceable anchor. VERIFIED: a locally scoped
      // `show ...: none` still hides it while leaving it referenceable, in-page
      // AND cross-page; it exports as <span id="loc-N">, and typst's own bundle
      // export turns a cross-vertebra #link(label(id)) into
      // ../<page>.html#loc-N.
      {
        show figure.where(kind: "rheo-idea-anchor"): none
        [#figure([], kind: "rheo-idea-anchor", supplement: none)#label(id)]
      }

      let ttl = if title == none { none } else { title }
      let cls = ("idea",) + labels.map(l => "idea-label-" + l)
      if _target() == "html" or _target() == "epub" {
        // The permalink is the ONLY way to discover an auto-generated id —
        // there is no `show heading` rule and no template to hook into, so
        // `#idea` appends it directly, always (even with no title), showing
        // the FULL `note:name` id so it is copy-pasteable straight into
        // `#view("...")`.
        //
        // It goes to the note's own standalone page when there is one, and
        // only falls back to the same-page `#id` fragment when there is not.
        // A fragment pointing at the very heading the reader just clicked is
        // a no-op; the minted page is what they actually want.
        let page-href = _note-href(id)
        let permalink = html.elem(
          "a",
          attrs: (
            class: "idea-label",
            href: if page-href == none { "#" + id } else { page-href },
            title: if page-href == none { "Link to this note" } else { "Open this note's page" },
          ),
          "[" + id + "]",
        )
        let header = html.elem("h" + str(level + 1), attrs: (id: id, class: cls.join(" ")),
                  (if ttl == none { [] } else { ttl }) + permalink)
        // Header and body wrap together in one card, HTML/EPUB only — no box
        // for a paged target. The box classes mirror `cls` (labels included)
        // so a label can style the whole card, not just the heading; the
        // heading's own class list (above) is untouched for existing
        // stylesheets.
        let box-cls = ("idea-box",) + labels.map(l => "idea-label-" + l)
        html.elem("div", attrs: (class: box-cls.join(" ")), header + body)
      } else {
        if ttl != none { heading(depth: level, ttl) }
        body
      }
    }
  ])
}

// ---- #note / #todo — sugar over labels, NOT a kind/type axis --------------
//
// Pure sugar: each PREPENDS its own tag to whatever `labels` the caller
// passed, so `#note("x")[...]` is exactly `#idea("x", labels: ("note",))[...]`
// — no new parameter on `#idea`, no recognised set of tags, no subclassing.
// Forwards every other argument (level, title, minted, updated) and the
// positional sink untouched, so `#note[body]`, `#note("name")[body]` and
// `#note(<name>)[body]` all work exactly as the `#idea` forms do.
//
// THE TRAP, do not reintroduce: `#let note = idea.with(labels: ("note",))`.
// An explicit `labels:` argument at the call site OVERRIDES a value bound by
// `.with()`, so `#note("x", labels: ("draft",))` would silently drop "note" —
// the tag the caller chose `#note` for in the first place.
//
// Prepends `tag`, unless the caller already passed it — `#todo("x", labels:
// ("todo",))` must yield `("todo",)`, not `("todo", "todo")`, or the heading
// gets a duplicated CSS class. Defined before `note`/`todo` below: a `#let`
// closure captures the scope visible AT DEFINITION time, so a forward
// reference to a not-yet-defined name fails at call time.
#let _dedup-label(tag, labels) = if tag in labels { labels } else { (tag,) + labels }
#let note(labels: (), ..args) = idea(labels: _dedup-label("note", labels), ..args)
#let todo(labels: (), ..args) = idea(labels: _dedup-label("todo", labels), ..args)

// ---- #view — transclusion, array form, working limit ----------------------
//
// `#view("etal")` renders the target note's stored (flattened) body inline,
// wrapped in a link back to the source note. `names` accepts a string, a
// label, or an array of either. Reads the registry via `.final()`, not
// `.get()` — that is what lets a note defined in ANOTHER vertebra resolve,
// since the whole spine compiles as one Typst document.
//
// A `#view` is pure presentation: it never registers, never advances the
// counter, and never re-registers a nested `#idea`. That guarantee is
// delivered by `_flatten` (defined above, next to `IK`/`VK`), not by any
// suppression logic here.

// Split a body into block-level chunks for `limit:` truncation. A naive
// `body.children.slice(0, limit)` is WRONG: whitespace (`space`/`parbreak`)
// children make it select nothing, and list items are bare `item` children
// with no wrapping `list` element, so a naive slice also cuts lists in half.
// This groups consecutive `item`s into one block and drops whitespace.
// Compares `repr(c.func())` against "space"/"parbreak" because there is no
// public element function to compare those against directly.
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
#let _blocks(body) = {
  let body = body
  while repr(body.func()) == "styled" { body = body.child }
  if not body.has("children") { return (body,) }
  let out = ()
  let prev-item = false
  for c in body.children {
    let f = repr(c.func())
    if f == "space" or f == "parbreak" { prev-item = false; continue }
    if f == "item" and prev-item {
      out.at(-1) = out.at(-1) + c
    } else {
      out.push(c)
      prev-item = f == "item"
    }
  }
  out
}

// `folded: true` renders a compact index instead — one row per note, title
// left and a muted minted-date right, with the body collapsed behind it.
// `limit:` is meaningless for a row whose body starts hidden, so it is
// silently ignored when combined with `folded: true` (not a panic — the
// caller likely left `limit:` set from an unfolded call and flipped `folded`
// on).
//
// CLICK BUDGET (HTML/EPUB): the first click on a folded row UNFOLDS it, and
// only a click on the unfolded body navigates to the note's standalone page.
// That is a native `<details>`/`<summary>` disclosure — this package ships no
// JS, and a `:target`/checkbox CSS hack would need a unique control id per
// row and would fight the anchor. Consequently the ROW ITSELF MUST NOT BE A
// LINK: an `<a>` inside `<summary>` swallows the toggle click, which is
// exactly the behaviour this replaced.
#let view(names, limit: none, folded: false) = context {
  let reg = _registry.final()
  let ids = if type(names) == array { names } else { (names,) }

  if folded {
    // ONE list for the whole call, not one element per name (unlike the
    // unfolded branch below, which emits one figure per name).
    let rows = ids.map(n => {
      let id = "note:" + _norm(n)
      if id not in reg {
        panic("@rheo/rookery: #view unknown note '" + id + "'")
      }
      let rec = reg.at(id)
      // Same title fallback ref-rule uses: a titleless note gives a usable
      // row (its bare id) rather than a blank one.
      let ttl = if rec.title == none { raw(id) } else { rec.title }
      let date = if rec.minted != none { rec.minted.display("[year]-[month]-[day]") } else { none }
      (id: id, title: ttl, date: date, body: rec.body)
    })
    if _target() == "html" or _target() == "epub" {
      html.elem("ul", attrs: (class: "idea-folded-list"), rows.map(r => {
        let title-span = html.elem("span", attrs: (class: "idea-folded-title"), r.title)
        let date-span = if r.date != none { html.elem("span", attrs: (class: "idea-folded-date"), r.date) } else { [] }
        // <summary> is the fold control, so it carries no anchor (see the
        // CLICK BUDGET note above).
        let summary = html.elem("summary", attrs: (class: "idea-folded-link"), title-span + date-span)
        // The revealed body is the navigation target, and reuses `.idea-view`
        // so an unfolded row and a plain `#view` read and behave alike. Does
        // NOT wrap the body in an outer <a> (see `_goto-link` below) — a
        // trailing arrow link instead.
        let goto = _goto-link(r.id)
        let inner = html.elem("div", attrs: (class: "idea-view idea-folded-body"), r.body + [ ] + goto)
        html.elem("li", attrs: (class: "idea-folded-item"),
          html.elem("details", attrs: (class: "idea-folded-details"), summary + inner))
      }).join())
    } else {
      // No disclosure in a paged target — nothing to click, and a fold that
      // cannot be opened would just hide the body. One line per note.
      list(..rows.map(r => link(label(r.id), r.title)))
    }
  } else {
    for n in ids {
      let id = "note:" + _norm(n)
      if id not in reg {
        panic("@rheo/rookery: #view unknown note '" + id + "'")
      }
      let rec = reg.at(id).body
      let bs = _blocks(rec)
      let shown = if limit != none and bs.len() > limit {
        bs.slice(0, limit).join() + [#text(gray)[ ... ]]
      } else {
        rec
      }
      if _target() == "html" or _target() == "epub" {
        // Do NOT wrap `shown` in an outer <a> — HTML disallows nested
        // anchors, and a transcluded body commonly contains its OWN link
        // (another `#link`/`@ref`/`#view`). MEASURED: browsers (and typst's
        // HTML export) truncate the outer anchor right where the inner one
        // starts and never resume it afterward, so everything past the first
        // nested link silently stops being part of the outer link — "only
        // the first bit" is clickable. A small trailing arrow link (below)
        // sidesteps this entirely, regardless of what the body itself links
        // to.
        let content = html.elem("div", attrs: (class: "idea-view"), shown + [ ] + _goto-link(id))
        figure(kind: VK, supplement: none, [#metadata(id)#content])
      } else {
        // Paged output has no nested-anchor restriction (PDF link regions
        // can overlap), so the simple whole-block link is fine here.
        let href = _note-href(id)
        let linked = if href == none { link(label(id), block(shown)) } else { link(href, block(shown)) }
        figure(kind: VK, supplement: none, [#metadata(id)#linked])
      }
    }
  }
}

// ---- ref-rule — @note:x renders the note, not a figure number -------------
//
// A note's label lives on a hidden anchor FIGURE, so a bare `@note:etal`
// resolves to that figure and renders as a bare figure NUMBER by default —
// useless to a reader. This package installs no document template by design
// (the author just imports and calls `#idea`/`#view`), so there is nowhere to
// put a `show ref:` rule implicitly; it must be an exported rule the author
// opts into:
//
//   #import "@rheo/rookery:0.1.0": idea, view, ref-rule
//   #show ref: ref-rule
//
// References to anything else (an ordinary figure, a heading, ...) pass
// through untouched via the `else { it }` branch. Without the rule, `@note:x`
// still compiles — it just shows a number; `#link(label("note:x"))[text]`
// remains the primary terse-form-adjacent linking form.
//
// MEASURED CORRECTION to this bead's own sketch: it assumed the registry
// stored a dict with a `.title` field directly. It stores `(title:, body:)`
// now (added by this bead, since nothing previously persisted the title) —
// see `#idea`'s registration step. A note with no title (the common
// frictionless case) falls back to the bare id text, not a blank link.
#let ref-rule = it => context {
  let e = it.element
  if e != none and e.func() == figure and e.kind == "rheo-idea-anchor" {
    let id = str(it.target)
    let reg = _registry.final()
    let shown = if id in reg and reg.at(id).title != none {
      reg.at(id).title
    } else {
      raw(id)
    }
    // Same convention as #view/the permalink: go to the note's own page when
    // one is minted, falling back to the label anchor when not.
    let href = _note-href(id)
    if href == none { link(it.target, shown) } else { link(href, shown) }
  } else {
    it
  }
}
