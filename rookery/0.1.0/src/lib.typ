// rookery — atomic, interlinked, transcludable notes ("ideas") for Typst (Zettelkasten-style).
//
// A note exists only where the author writes `#idea("name")[...]` — there is
// no document show rule and no "every heading is a note" behaviour. Notes are
// flat: there is no kind/type taxonomy, only a free-form set of labels an
// author attaches to a note. `#note`/`#todo` are pure sugar over that same
// labels array (see below), not a taxonomy of their own. Note ids are flat
// Typst labels (`<idea:name>`), not handle-prefixed, so a note can move
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

// ---- Label prefix — configurable, document-wide ---------------------------
//
// A note's id is `<prefix>:<name>`, `idea:` by default; `#show: rookery` (at
// the bottom of this file) changes it.
//
// The prefix is document-wide STATE rather than a parameter on `#idea`,
// because four separate places have to agree on it — `#idea` (minting the
// label), `#view` (looking one up), `_note-file` (deriving a minted page's
// slug from an id) and `.marrow.typ` (minting those pages) — and only
// `#idea`'s call site could ever pass an argument. One wrong reader and the
// id it builds simply does not exist.
//
// Read with `.final()`, NOT `.get()`. `#show: rookery` is applied per FILE
// (imports are per-file), so under rheo a spine sets the same prefix once per
// vertebra; a vertebra that forgot the template would, under `.get()`, mint
// `idea:` ids in the middle of an otherwise `note:` document, and a `#view`
// reaching across that boundary would panic on an id that was never
// registered. `.final()` collapses the whole document to ONE prefix (last
// writer wins), so every reader agrees no matter which file it sits in.
//
// EVERY caller of `_pfx` is therefore inside a `context` block already —
// `#idea`'s deferred body, `#view`, `_note-href` via `#idea`/`#view`/
// `ref-rule`, and `.marrow.typ`'s own `#context`.
#let _prefix = state("rheo-idea-prefix", "idea")
#let _pfx() = _prefix.final() + ":"

// ---- Theme — configurable the same way ------------------------------------
//
// Every colour the package will set for you, as one dictionary. `#show:
// rookery` publishes it; `rookery.css` holds the DEFAULTS and this state holds
// only the overrides, so an unconfigured document emits nothing extra at all.
//
// Delivered as INLINE CSS CUSTOM PROPERTIES on the elements that root a
// rookery subtree — `.idea-box`, `.idea-view`, and a minted page's `<h1>` —
// whence they inherit to the permalink, the date, and anything nested. That is
// the only mechanism available: this package emits no `<style>` element and
// the template wraps `doc` in nothing, so there is no ancestor to hang a
// `:root` variable on, and emitting a `<style>` per vertebra would duplicate
// it once per output page and is dubious inside an EPUB's body besides.
//
// It degrades cleanly in both directions: the DEFAULT lives in the `var()`
// call in the stylesheet, not here, so a reader that does not understand
// custom properties still gets the default look; and a container that somehow
// carries no property inherits from whichever ancestor does.
//
// Same `.final()` reasoning as `_prefix` above: one theme for the whole
// document, so a note and a view of it cannot disagree about their colours.
//
// Each key maps to exactly one custom property, and `rookery.css` reads each
// through `var(--x, <default>)`. Adding a knob means adding a line here and a
// `var()` there — nothing else.
// The two that carry the look are `link-color` and `fold-color`, and the
// contrast between them is the point: BOTH are hover backgrounds, so they
// compare like with like, and the lighter one belongs to the fold (a block
// that only opens and closes) while the stronger one belongs to every link
// (which actually goes somewhere). Forester makes the same split with one blue
// at two alphas; rookery defaults to two hues, a light blue and a purple, so
// the difference survives being read quickly.
#let _THEME-KEYS = (
  "link-color": "--idea-link-color",
  "fold-color": "--idea-fold-color",
  "id-color": "--idea-id-color",
  "date-color": "--idea-date-color",
)
#let _theme = state("rheo-idea-theme", (:))

// The `style` attribute value for the configured theme, or `none` when
// nothing is configured (in which case no attribute is emitted at all).
#let _theme-style() = {
  let t = _theme.final()
  let decls = _THEME-KEYS
    .pairs()
    .filter(((key, prop)) => t.at(key, default: none) != none)
    .map(((key, prop)) => prop + ": " + t.at(key))
  if decls.len() == 0 { none } else { decls.join("; ") }
}

// Add that style to an attrs dictionary, or leave it untouched. Every
// container this package emits goes through here, so none can drift.
#let _themed(attrs) = {
  let s = _theme-style()
  if s == none { attrs } else { attrs + (style: s) }
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
#let _note-file(id) = "notes/" + id.trim(_pfx(), at: start) + ".html"

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

// ---- The permalink — the ONE navigational affordance ----------------------
//
// `[idea:etal]`, rendered beside a note's title (or alone, where there is no
// title) by BOTH `#idea` and `#view`. Shared so the two cannot drift: it is
// the same affordance meaning the same thing in both places — "this is the
// note's id, and it goes to the note's own page".
//
// Nothing else in this package is a link. A transcluded body is NOT wrapped
// in an anchor and no trailing arrow is appended (both were tried; see
// `#view`), so the reader's click budget is unambiguous: the permalink
// navigates, everything else folds.
//
// It goes to the note's standalone page when one is minted, and only falls
// back to the same-page `#id` fragment when there is not (plain `typst
// compile`, or the combined PDF). For `#idea`, that fragment points at the
// very heading the reader just clicked — a no-op — which is why the minted
// page is preferred whenever it exists.
// `href: auto` resolves the destination as described above. `.marrow.typ`
// passes an explicit one instead: on a note's OWN minted page the permalink
// must stay a same-page fragment rather than link the page to itself, and
// `_note-href` would happily compute the latter. Routing that case through
// here anyway is what keeps every permalink in the output identical — the
// hand-rolled copy this replaced had already drifted.
//
// Carries no theme properties of its own: it is always emitted inside a
// container that does (`.idea-box`, `.idea-view`, a minted page's `<h1>`), and
// custom properties inherit.
#let _permalink(id, href: auto) = {
  let dest = if href != auto { href } else {
    let page-href = _note-href(id)
    if page-href == none { "#" + id } else { page-href }
  }
  html.elem(
    "a",
    attrs: (
      class: "idea-label",
      href: dest,
      title: if dest.starts-with("#") { "Link to this note" } else { "Open this note's page" },
    ),
    "[" + id + "]",
  )
}

// Paged counterpart: no `html.elem`, and the fallback is the Typst label
// rather than an HTML fragment.
#let _permalink-paged(id) = {
  let href = _note-href(id)
  let dest = if href == none { label(id) } else { href }
  link(dest, text(gray, raw("[" + id + "]")))
}

// ---- #idea — marker, idea:<id> label, anchor, flattened registration -----
//
// `#idea[body]`, `#idea("name")[body]`, and `#idea(<name>)[body]` all work via
// an argument sink, since `#idea[body]` passes body as the first positional
// argument. An unnamed note steps a package-wide counter and takes the
// resulting sequence number as its id; a named note is pinned and does not
// perturb that counter. Either way the note gets: an `idea:<id>` Typst label on
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
  // A `#view` nested inside a transcluded body collapses to the SAME
  // permalink affordance the view's own summary would have carried — so the
  // one-link rule holds at every depth: the id navigates, nothing else does.
  // (It used to collapse to a `[view of idea:x]` link on the label anchor,
  // which was a second, differently-styled navigational form for the same
  // destination.) Wrapped in `context` for `_permalink`, which reads the page
  // handle and the prefix state.
  show figure.where(kind: VK): it => context {
    let m = it.body.children.find(c => c.func() == metadata)
    if _target() == "html" or _target() == "epub" {
      _permalink(m.value)
    } else {
      _permalink-paged(m.value)
    }
  }
  body
}

// Normalise a name (string or Typst label) to its bare string form, with no
// prefix. Shared by `#idea` (pinning an explicit id) and `#view`
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
        _pfx() + base
      } else {
        let n = counter("rheo-ideas-seq").get().first()
        _pfx() + str(n)
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
        // the FULL `idea:name` id so it is copy-pasteable straight into
        // `#view("...")`. `#view` renders the identical affordance in its own
        // summary; both go through `_permalink`.
        let header = html.elem("h" + str(level + 1), attrs: (id: id, class: cls.join(" ")),
                  (if ttl == none { [] } else { ttl }) + _permalink(id))
        // Header and body wrap together in one card, HTML/EPUB only — no box
        // for a paged target. The box classes mirror `cls` (labels included)
        // so a label can style the whole card, not just the heading; the
        // heading's own class list (above) is untouched for existing
        // stylesheets.
        let box-cls = ("idea-box",) + labels.map(l => "idea-label-" + l)
        html.elem("div", attrs: _themed((class: box-cls.join(" "))), header + body)
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
// `#view("etal")` transcludes the target note: its title, its permalink, and
// its stored (flattened) body, as one foldable block. `names` accepts a
// string, a label, or an array of either. Reads the registry via `.final()`,
// not `.get()` — that is what lets a note defined in ANOTHER vertebra
// resolve, since the whole spine compiles as one Typst document.
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

// ONE rendering, whatever `folded` says. `folded` sets only the INITIAL
// disclosure state — `false` (the default) renders `<details open>`, `true`
// renders it closed. It is not a second layout: a folded view and an unfolded
// one are the same block, so a reader who opens one sees exactly what a
// `#view` beside it already shows. `limit:` is therefore meaningful in both
// (it truncates the body that folding hides) and the two are orthogonal.
//
// CLICK BUDGET (HTML/EPUB) — the whole point of this shape, modelled on
// Forester (www.forester-notes.org, whose `tree.xsl` renders every transcluded
// tree as a `<details>` whose `<summary>` holds the title and an
// `<a class="slug">[tfmt-0006]</a>`):
//
//   - clicking ANYWHERE in the summary — title, date, the whitespace between
//     them — folds or unfolds, and does nothing else;
//   - clicking the `[idea:etal]` permalink, and only that, opens the note's
//     own page.
//
// So the transcluded body is NOT a link and there is no trailing arrow. Both
// were tried and removed. An outer <a> around the body is invalid the moment
// that body contains its own link (MEASURED: browsers and typst's HTML export
// both truncate the outer anchor where the inner one starts and never resume
// it, so only "the first bit" stays clickable), and the arrow was a second
// navigational affordance competing with the permalink for the same click.
//
// The disclosure is native `<details>`/`<summary>`: this package ships no JS,
// and a `:target`/checkbox CSS hack would need a unique control id per view.
// An `<a>` INSIDE `<summary>` does not break the toggle — only an `<a>` around
// the whole summary does, which is what the earlier folded-row design got
// wrong. The permalink navigates on its own click; the summary keeps the rest.
#let view(names, limit: none, folded: false) = context {
  let reg = _registry.final()
  let ids = if type(names) == array { names } else { (names,) }

  for n in ids {
    let id = _pfx() + _norm(n)
    if id not in reg {
      panic("@rheo/rookery: #view unknown note '" + id + "'")
    }
    let rec = reg.at(id)

    let bs = _blocks(rec.body)
    let shown = if limit != none and bs.len() > limit {
      bs.slice(0, limit).join() + [#text(gray)[ ... ]]
    } else {
      rec.body
    }
    let date = if rec.minted != none { rec.minted.display("[year]-[month]-[day]") } else { none }

    if _target() == "html" or _target() == "epub" {
      // A titleless note contributes no title span at all, so the permalink
      // comes first in the summary — "at the top of the view", the id doing
      // double duty as the note's name. `#idea`'s own heading does the same.
      let title-span = if rec.title == none { [] } else {
        html.elem("span", attrs: (class: "idea-view-title"), rec.title)
      }
      let date-span = if date == none { [] } else {
        html.elem("span", attrs: (class: "idea-view-date"), date)
      }
      let summary = html.elem(
        "summary",
        attrs: (class: "idea-view-summary"),
        title-span + _permalink(id) + date-span,
      )
      // `open` is a BOOLEAN html attribute: present means open and there is no
      // value meaning closed, so the attrs dictionary itself has to differ
      // between the two states. `open: "false"` would read as open.
      let d-attrs = if folded { (class: "idea-view-details") } else {
        (class: "idea-view-details", open: "open")
      }
      let content = html.elem("div", attrs: _themed((class: "idea-view")),
        html.elem("details", attrs: d-attrs,
          summary + html.elem("div", attrs: (class: "idea-view-body"), shown)))
      figure(kind: VK, supplement: none, [#metadata(id)#content])
    } else {
      // No disclosure in a paged target — nothing to click, so a fold that
      // could not be opened would just hide the body: `folded` is ignored
      // here and the body always shows. The head still renders and the
      // permalink is still the only link, so both targets read the same.
      let head = {
        if rec.title != none { strong(rec.title); [ ] }
        _permalink-paged(id)
        if date != none { [ ]; text(gray, date) }
      }
      figure(kind: VK, supplement: none, [#metadata(id)#block[#head#parbreak()#shown]])
    }
  }
}

// ---- ref-rule — @idea:x renders the note, not a figure number -------------
//
// A note's label lives on a hidden anchor FIGURE, so a bare `@idea:etal`
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
// through untouched via the `else { it }` branch. Without the rule, `@idea:x`
// still compiles — it just shows a number; `#link(label("idea:x"))[text]`
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
    let linked = if href == none { link(it.target, shown) } else { link(href, shown) }
    // Wrapped so `@idea:other` is reachable from CSS and carries the theme.
    // A SPAN around Typst's own `link()`, not a hand-rolled `<a>`: the
    // label-fallback branch above has no href to hand-roll WITH, since only
    // Typst can resolve a label to the `#loc-N` it ends up at. And the wrapper
    // has to carry the theme itself — a reference sits in ordinary prose, with
    // no `.idea-box`/`.idea-view` ancestor to inherit from.
    if _target() == "html" or _target() == "epub" {
      html.elem("span", attrs: _themed((class: "idea-ref")), linked)
    } else {
      linked
    }
  } else {
    it
  }
}

// ---- #show: rookery — the setup, and the knobs ----------------------------
//
//   #import "@rheo/rookery:0.1.0": rookery, idea, view
//   #show: rookery.with(
//     prefix: "note",
//     theme: (link-color: rgb("#ffe08a"), fold-color: rgb("#fffbe8")),
//   )
//
// Does exactly three things, and deliberately nothing else:
//
//   1. publishes `prefix` (so `#idea("etal")` mints `<note:etal>`);
//   2. publishes the theme — every colour the package will set for you;
//   3. installs `show ref: ref-rule`, so `@note:etal` renders the note rather
//      than a bare figure number.
//
// It does NOT transform the document. It sets no page/text/heading style,
// wraps `doc` in no container, and emits nothing of its own — `#show:
// rookery` on a document with no notes in it is a no-op. The blast radius is
// exactly one element type: `ref`. Even there `ref-rule` passes every
// reference that is NOT a rookery note straight through untouched (its `else
// { it }` branch), so an ordinary `@fig:x` in the same document is unaffected.
//
// WHY NOT NARROWER — i.e. a rule scoped to `#idea` alone. The prefix cannot
// ride on a show rule over idea markers, because `#view` and `.marrow.typ`
// need the same value and neither is inside an idea. It has to be state (see
// `_prefix` at the top of this file), and a plain function CANNOT install the
// `ref` rule: a `show` inside a function body scopes to the content that body
// returns, not to the document that later inserts it. Hence a template — kept
// as thin as a template can be.
//
// THEME. `theme:` takes the whole set at once; the granular parameters named
// after each key take one at a time and WIN over `theme`, so the two compose:
//
//   #show: rookery.with(theme: DARK, link-color: rgb("#ff0"))
//
// reads as "the dark theme, but that one colour". Precedence, least specific
// first: `rookery.css`'s own default -> `theme:` -> the granular parameter.
// Anything left unset at every level stays a CSS default and is not emitted.
//
// Each value is a Typst colour or a raw CSS string. A colour is converted with
// `.to-hex()` HERE, once, rather than at every element: this is the only place
// that knows the value is destined for CSS. A string passes through untouched,
// which is what makes `rgba(…)`, `var(--accent)`, `transparent` and any other
// CSS-valid value available — Typst's colour type cannot express those.
//
// An unknown `theme:` key is an ERROR naming the valid ones, rather than a
// silently ignored typo: a misspelled colour that just does not apply is
// exactly the kind of thing an author would chase through their own
// stylesheet first.
//
// `refs: false` opts out of (3) alone, for an author who wants stock `@`
// behaviour or their own `show ref` rule. The `show` sits INSIDE the branch,
// wrapping `doc` there: a `show` in an `if` block's body scopes to that block,
// so hoisting it out of the branch would scope it to nothing at all.
//
// Defined last in this file because a `#let` closure captures the scope
// visible AT DEFINITION time — `ref-rule` must already exist.
#let rookery(
  prefix: "idea",
  theme: (:),
  link-color: none,
  fold-color: none,
  id-color: none,
  date-color: none,
  refs: true,
  doc,
) = {
  assert(
    type(prefix) == str and prefix != "" and not prefix.contains(":"),
    message: "@rheo/rookery: `prefix` must be a non-empty string containing no `:` "
      + "(the `:` between prefix and name is added for you) — got "
      + repr(prefix),
  )
  assert(
    type(theme) == dictionary,
    message: "@rheo/rookery: `theme` must be a dictionary of "
      + _THEME-KEYS.keys().join(", ") + " — got " + repr(theme),
  )

  // One converter for both sources, so `theme: (link-color: c)` and
  // `link-color: c` cannot disagree about what a value may be.
  let css(key, value) = {
    assert(
      type(value) == color or type(value) == str,
      message: "@rheo/rookery: theme `" + key + "` must be a colour or a CSS "
        + "colour string — got " + repr(value),
    )
    if type(value) == color { value.to-hex() } else { value }
  }

  let resolved = (:)
  for (key, value) in theme {
    assert(
      key in _THEME-KEYS,
      message: "@rheo/rookery: unknown theme key `" + key + "` — valid keys are "
        + _THEME-KEYS.keys().join(", "),
    )
    if value != none { resolved.insert(key, css(key, value)) }
  }
  // Granular arguments last: they override whatever `theme:` set.
  for (key, value) in (
    link-color: link-color,
    fold-color: fold-color,
    id-color: id-color,
    date-color: date-color,
  ) {
    if value != none { resolved.insert(key, css(key, value)) }
  }

  _prefix.update(prefix)
  _theme.update(resolved)
  if refs {
    show ref: ref-rule
    doc
  } else {
    doc
  }
}
