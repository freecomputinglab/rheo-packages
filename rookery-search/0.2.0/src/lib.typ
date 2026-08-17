// @rheo/rookery-search — fuzzy search over a rookery.
//
// Reads the corpus through `@rheo/rookery`'s public primitives and never
// touches its internals: `ideas()` for the notes, `note-href()` for links.
// Nothing here RENDERS a note's body — the modal's preview pane fetches the
// note's own minted page at runtime instead (see `search-modal` below), so
// this package's build cost is one pass over the registry per page rather
// than one full body render per note per page.
//
// Two layers, and the split matters:
//   - `search-ideas(query)` is pure Typst and works under plain
//     `typst compile` — build a static list of matches with no JavaScript.
//   - `search-index()` and `search-bar()` are RHEO ONLY. The bar's script is
//     injected by rheo from this manifest's `js_scripts`, and the index links
//     to minted note pages, which only rheo produces.
//
// BUILT, unlike `@rheo/rookery`: `typst.toml` points at `dist/`, and `dist/`
// comes from `just build` (vite copies this file and the CSS across and
// bundles `src/rookery-search.js` into `dist/lib.js`). Editing `src/` does
// NOT take effect until you rebuild — the one ergonomic cost of shipping JS.
#import "@rheo/rookery:0.2.0": ideas, note-href

// ---- Target detection — a deliberate copy of rookery's ---------------------
//
// The originals are `_rheo-ctx` and `_target` in `rookery/0.2.0/src/lib.typ`,
// where they are underscore-private. They are copied rather than exported and
// imported: six lines of `sys.inputs` read, against making rookery widen its
// public surface with something no author would ever call. `sys.inputs` is
// readable from any package's scope, so the copy behaves identically.
//
// `std.target()` reports EPUB as "html"; rheo's own context distinguishes
// them. `std.target()` rather than a bare `target()`, because rheo injects its
// `target()` polyfill into each vertebra's scope, not into package scope — and
// that read REQUIRES `--features html`, which every build of a project using
// this package therefore needs.
//
// Keep in step with rookery's. If that pair changes, this one changes too.
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: none)

#let _target() = {
  let c = _rheo-ctx()
  if c != none and "target" in c { c.target } else { std.target() }
}

// Lowercase, and `-`/`_` read as a space. Applied to the HAYSTACK AND THE
// QUERY, which is what makes an id findable by how a person types it: the note
// `flat-ids` matches "flat ids", and the exact string "flat-ids" still matches
// too, because both sides collapse to the same thing. Folding only the
// haystack would have broken the second case — the query's literal `-` would
// find no `-` left to match.
//
// Deliberately NOT accent-folding: MEASURED, "cafe" does not match "Café", and
// fixing that means Unicode normalisation the JavaScript port would have to
// reproduce exactly. Recorded as a known limitation in the readme instead.
#let _fold(s) = lower(s).replace("-", " ").replace("_", " ")

// Subsequence fuzzy match: `none` when `query`'s characters do not all appear
// in `hay` in order, otherwise an integer score, higher is better. An empty
// query matches everything at score 0.
//
// The score is: 1 point per matched character, 3 instead when it sits
// immediately after the previous match (a contiguous run beats a scatter);
// +10 for a prefix match, else +5 for a substring match anywhere; up to +5 for
// matching near the start; and up to +10 for the haystack being close in
// length to the query.
//
// That last term is load-bearing, not a flourish. MEASURED without it, the
// query "window" scored `windows` and `window-depth` identically at 31 — both
// are prefix matches of six contiguous characters — and the tie broke by id, so
// the near-exact match sorted BELOW the longer one. With it they are 40 and 35.
// Nothing else in the formula rewards matching a large FRACTION of the hay.
//
// Integer arithmetic throughout, deliberately: `src/rookery-search.js`
// reimplements this rule for the live bar, and integers compare exactly across
// the two languages where floats would not. `just parity` diffs them.
#let fuzzy-score(hay, query) = {
  let h = _fold(hay)
  let q = _fold(query)
  if q == "" { return 0 }
  let hc = h.clusters()
  let qc = q.clusters()
  let i = 0
  let first = none
  let prev = none
  let points = 0
  for ch in qc {
    let found = none
    let j = i
    while j < hc.len() {
      if hc.at(j) == ch { found = j; break }
      j += 1
    }
    if found == none { return none }
    if first == none { first = found }
    points += if prev != none and found == prev + 1 { 3 } else { 1 }
    prev = found
    i = found + 1
  }
  if h.starts-with(q) { points += 10 } else if h.contains(q) { points += 5 }
  points += calc.max(0, 5 - first)
  points += calc.max(0, 10 - (hc.len() - qc.len()))
  points
}

// Full-text AND match over a note's body: `none` unless every whitespace-split
// term in `query` appears somewhere in `body`, otherwise an integer score,
// higher is better. Deliberately NOT `fuzzy-score` — that is a subsequence
// matcher, good over a 40-character id but useless over a 2000-character body,
// where its length term (line 97) clamps to 0 for nearly everything and the
// surviving score is noise.
//
// AND across terms — every term must appear — is what keeps a multi-word
// query from behaving like an OR and dragging in the whole corpus.
//
// +6 for the whole query appearing as one contiguous phrase; +2 per term for
// simply being present; up to +3 per term for appearing early, in coarse
// 200-CLUSTER buckets. Clusters, not bytes: `str.position` returns a byte
// offset and JavaScript's `indexOf` returns a UTF-16 offset, and those
// disagree the moment a body contains a non-ASCII character — counting
// clusters is the one measure both languages can produce identically, the
// same reason `fuzzy-score` already works in `.clusters()`.
//
// Integer arithmetic throughout, same reason as `fuzzy-score` (line 69):
// `src/rookery-search.js` ports this rule for the live bar and `just parity`
// diffs the two number for number.
#let body-score(body, query) = {
  let h = _fold(body)
  let q = _fold(query)
  if q.trim() == "" { return none }
  let terms = q.split(" ").filter(t => t != "")
  if terms.len() == 0 { return none }
  for term in terms {
    if not h.contains(term) { return none }
  }
  let points = 0
  if h.contains(q) { points += 6 }
  for term in terms {
    points += 2
    let i = h.position(term)
    let cl = h.slice(0, i).clusters().len()
    points += calc.max(0, 3 - int(cl / 200))
  }
  points
}

// ---- #search-ideas — fuzzy lookup over a rookery's ids, titles and bodies -
//
//   #context search-ideas("flt")   // -> ((id: "idea:flat-ids", .., score: 47, kind: "name"), ..)
//
// Returns a plain ARRAY of dictionaries — every field `@rheo/rookery`'s
// `ideas()` provides (id, name, title, text, body, href, minted, updated)
// plus `score` and `kind` — so a caller renders it however it likes. Pure
// Typst: no rheo needed, though `href` is `none` without it (nothing mints
// note pages), in which case a caller links with `#link(label(id))` instead.
//
// TWO TIERS, not one blended number. `kind: "name"` rows — matched on id or
// title, via `fuzzy-score`, taking the better of the two — always sort above
// every `kind: "body"` row — matched only on body text, via `body-score`. A
// body match and a title match are not the same KIND of evidence, and a
// reader looking for a note by name must never have it pushed below some
// other note that happens to mention the word six times; tiering says that
// plainly, where a weighted sum would only approximate it and need constant
// retuning. `kind` is what the modal's preview pane uses to decide whether to
// show a snippet. Tags are not searched at all; that is a deliberate deferral
// (rookery's records do not carry them yet — see bead
// rheo-packages-rookery-labels-dpq).
//
// TWO SORTED PASSES CONCATENATED, not one sort on a compound key: Typst's
// `.sorted(key:)` wants a comparable key and an array key is not reliably one
// here. Each tier is filtered out, sorted by score descending, and the two are
// joined — `limit:` is applied to the concatenation, not per tier. Ties stay
// in id order either way, because `ideas()` returns id-ordered rows and
// Typst's sort is stable — that guarantee must survive within each tier.
//
// Must be called INSIDE a `#context` block — `ideas()` reads a `state`'s
// `.final()`. It is not itself a context function, because a context function
// can only return content and the whole point here is to return data.
#let search-ideas(query, limit: none) = {
  assert(
    type(query) == str,
    message: "@rheo/rookery-search: #search-ideas' `query` must be a string — "
      + "got " + repr(query),
  )
  assert(
    limit == none or (type(limit) == int and limit >= 0),
    message: "@rheo/rookery-search: #search-ideas' `limit` must be none or a "
      + "non-negative integer — got " + repr(limit),
  )
  let name-hits = ()
  let body-hits = ()
  for e in ideas() {
    let s-name = fuzzy-score(e.name, query)
    let s-text = if e.text == "" { none } else { fuzzy-score(e.text, query) }
    let name-score = if s-name == none {
      s-text
    } else if s-text == none { s-name } else { calc.max(s-name, s-text) }
    if name-score != none {
      name-hits.push((..e, score: name-score, kind: "name"))
      continue
    }
    let body-score-val = body-score(e.at("body", default: ""), query)
    if body-score-val != none {
      body-hits.push((..e, score: body-score-val, kind: "body"))
    }
  }
  name-hits = name-hits.sorted(key: e => -1 * e.score)
  body-hits = body-hits.sorted(key: e => -1 * e.score)
  let out = name-hits + body-hits
  if limit == none { out } else { out.slice(0, calc.min(limit, out.len())) }
}

// ---- #search-index — the corpus as a JSON island --------------------------
//
//   #search-index()                       // usually not called directly
//   #search-index(elem-id: "notes-index")  // a second, differently-keyed index
//   #search-index(body-chars: 400)         // a tighter cap on body size
//
// Emits `<script type="application/json" id="rookery-search-index">[...]</script>`,
// one row per note: `(id, name, text, body, href)`, where `text` is the
// plain-text title ("" when untitled), `body` is the plain-text body ("" when
// empty), and `href` is the depth-relative path to the note's minted page —
// computed against the page this call sits on, so an island in a site's
// shared chrome comes out right on a nested vertebra too.
//
// The field is `text`, not `title`, on purpose: same name, same meaning, same
// type as `search-ideas` returns. `title` there is CONTENT, which JSON cannot
// carry, and one name meaning two types across two surfaces is how a consumer
// gets it wrong.
//
// `body-chars` CAPS each note's body at that many CLUSTERS (never bytes, so
// the cap cannot split a character) before it goes into the JSON — `none`
// means no cap, ship the whole body. No ellipsis is appended in the DATA; the
// preview pane excerpts and adds its own. This matters because the island is
// INLINE IN EVERY PAGE, not fetched once: MEASURED for rookery.ohrg.org, its
// `content/*.typ` sources total ~31 KB across roughly 40 notes, so an
// uncapped index costs on the order of 20-25 KB of JSON on every page (it
// compresses well, being prose). The default of 1200 clusters per note keeps
// that bounded for a rookery with hundreds of notes; a note longer than the
// cap stays FINDABLE by its opening, and fully findable through the Typst-side
// `#search-ideas`, which never truncates.
//
// WHY NOT A SEPARATE FETCHED JSON FILE, which would keep pages small: rheo
// emits pages from typst, and there is no supported way for a package to emit
// a standalone asset file next to them. An inline island is what the package
// can actually produce, and it also works from `file://` with no fetch.
//
// `search-bar` emits this itself, so most projects never call it. Call it
// directly when building a custom UI, or when several bars share one index —
// see `search-bar`'s `index:` parameter.
//
// The rows are `search-ideas("")` — the empty query matching everything — with
// the fields JSON cannot carry dropped, and unmintable notes filtered out.
#let search-index(elem-id: "rookery-search-index", body-chars: 1200) = context {
  if _target() != "html" { return }
  assert(
    body-chars == none or (type(body-chars) == int and body-chars >= 0),
    message: "@rheo/rookery-search: #search-index's `body-chars` must be none "
      + "or a non-negative integer — got " + repr(body-chars),
  )
  let rows = search-ideas("")
    .filter(e => e.href != none)
    .map(e => (
      id: e.id,
      name: e.name,
      text: e.text,
      // `array.join()` on an EMPTY array returns `none`, not `""` (MEASURED)
      // — so a short body (or an empty one) that needs no truncation at all
      // is passed through directly rather than round-tripped through
      // `clusters().slice(..).join()`, which would crash on it.
      body: if body-chars == none or e.body.clusters().len() <= body-chars {
        e.body
      } else {
        e.body.clusters().slice(0, body-chars).join()
      },
      href: e.href,
    ))
  if rows.len() == 0 { return }
  html.elem(
    "script",
    attrs: (type: "application/json", id: elem-id),
    json.encode(rows, pretty: false),
  )
}

// ---- #search-bar — the embeddable search UI. RHEO ONLY --------------------
//
//   #search-bar()
//   #search-bar(placeholder: "Find a note", limit: 12, class: "topbar-search")
//   #search-bar(index: false)   // a SECOND bar on a page that already has one
//   #search-bar(body-chars: 400) // a tighter cap on the island's body text
//
// Emits the JSON island (via `search-index`, `body-chars:` forwarded to it
// unchanged), an `<input>`, and an empty results container;
// `src/rookery-search.js`, injected by rheo from the manifest's `js_scripts`,
// wires them together.
//
// PHRASING CONTENT ONLY — a `<span>` wrapper holding an `<input>` and a
// `<span role="listbox">`, never a `<div>`/`<ul>`/`<li>`. A `<div>` inside a
// paragraph is invalid HTML, which would rule out exactly the embeddings this
// is for: mid-sentence, in a heading, in a table cell. The span wrapper is
// `display: inline-block` by default and a project can make it anything.
//
// NO IDS IN THE MARKUP. Markup carrying a hardcoded id cannot be placed twice
// on a page. `rookery-search.js` assigns the listbox id at runtime and wires
// `aria-controls` to it. The one id on the page belongs to the ISLAND, and
// `data-rookery-search` carries its name so several bars can share one index —
// or point at different ones.
//
// EMITS NOTHING without rheo or on a non-HTML target: the script would not be
// there and the index would be empty, so a bar could only be a dead input.
// Silent no-op rather than an assert, matching how the rest of the stack
// degrades.
#let search-bar(
  placeholder: "Search notes",
  limit: 8,
  class: none,
  index: true,
  elem-id: "rookery-search-index",
  body-chars: 1200,
) = context {
  if _target() != "html" or _rheo-ctx() == none { return }
  assert(
    type(limit) == int and limit > 0,
    message: "@rheo/rookery-search: #search-bar's `limit` must be a positive "
      + "integer — got " + repr(limit),
  )
  assert(
    class == none or type(class) == str,
    message: "@rheo/rookery-search: #search-bar's `class` must be none or a "
      + "string — got " + repr(class),
  )
  if index { search-index(elem-id: elem-id, body-chars: body-chars) }
  html.elem(
    "span",
    attrs: (
      class: if class == none { "rookery-search" } else { "rookery-search " + class },
      "data-rookery-search": elem-id,
      "data-rookery-search-limit": str(limit),
      "data-rookery-search-open": "false",
    ),
    html.elem("input", attrs: (
      class: "rookery-search-input",
      type: "search",
      role: "combobox",
      placeholder: placeholder,
      autocomplete: "off",
      "aria-label": placeholder,
      "aria-expanded": "false",
      "aria-autocomplete": "list",
    ))
      + html.elem("span", attrs: (class: "rookery-search-results", role: "listbox"), []),
  )
}

// ---- #search-modal — the overlay search UI. RHEO ONLY ---------------------
//
//   #search-modal()
//   #search-modal(placeholder: "Search ideas", limit: 30, trigger-label: "Search")
//   #search-modal(trigger: false)   // markup only; open it from your own button
//
// A telescope-style overlay: a trigger button for a site's topbar (a
// magnifier icon and a `Ctrl K` hint), and a `<dialog>` holding a two-pane
// listbox-plus-preview layout. `#search-bar` STAYS — it is the right thing
// for an inline or in-page bar, and both share `#search-index`; this is
// additive, not a replacement.
//
// A NATIVE `<dialog>` and `showModal()`, not a hand-rolled overlay div: focus
// trapping, page inertness behind it, `::backdrop` and Escape-to-close all
// come free and correct. It also renders in the TOP LAYER, which escapes
// every stacking context — load-bearing here because a sticky, z-indexed site
// header would otherwise trap a plain absolutely-positioned overlay under
// exactly the wrong things.
//
// Emits, in order: the JSON island (via `search-index`, same `index:`/
// `elem-id:`/`body-chars:` `#search-bar` already takes), then the trigger
// button (unless `trigger: false`), then the dialog. That is ALL it emits —
// see below on where the preview pane's content comes from.
//
// THE PREVIEW PANE'S RICH CONTENT IS FETCHED, NOT BUILT IN. The pane shows the
// selected note's real rendering — links, styling, footnotes, figures — and it
// gets it by `fetch`ing that note's own minted page (`ideas/<slug>.html`,
// which rookery's `.marrow.typ` already emits) when the reader selects the row,
// then caching it for the session. Nothing is rendered into this page.
//
// That is a build-cost decision, and a MEASURED one. This function sits in a
// site's header, so it runs on EVERY page; an earlier version emitted a hidden
// per-note container holding `#idea-body`'s rendering of every note, which is
// `notes × pages` renders per build — 57 × 69 ≈ 3,900 on weeknotes.ohrg.org,
// costing 14.6s against a 2.65s baseline and 312 MB of output (301 MB of it
// base64 images, since Typst's HTML export inlines every `#image`). Stripping
// the images cut the size to 33 MB but left the time at 14.6s, because the cost
// is PER CALL, not per byte: rendering the same bodies at `limit: 1`, near
// empty, still cost 10.3s. Truncation could not fix that; only not rendering
// N×M could. Fetching reuses pages rheo already emits, so the marginal build
// cost of a rich preview is now exactly zero.
//
// The trade, stated plainly: `fetch` does not work from `file://`, so opening
// a build straight off disk gets the plain-text excerpt the JSON island's
// `body` field already carries instead of the rich rendering. Rich previews
// need http (`rheo watch`, or any served copy). Serve the build, or accept the
// excerpt — a preview is an excerpt by construction either way.
//
// SAME ISLAND, SHARED BY NAME, NO IDS IN THE MARKUP — the rule `#search-bar`
// follows (see its comment above). The trigger's `data-rookery-search-modal`
// equals the dialog's `data-rookery-search`, so several triggers can drive
// one modal and nothing here needs an id of its own. A page should carry AT
// MOST ONE modal per island name; the script wires the first matching dialog.
//
// The `<kbd>` hint is `aria-hidden`: a screen reader should hear the button's
// `aria-label`, not the literal keys.
//
// EMITS NOTHING without rheo or on a non-HTML target, same reason and same
// silent no-op as `#search-bar`.
#let search-modal(
  placeholder: "Search notes",
  limit: 30,
  class: none,
  trigger: true,
  trigger-label: "Search",
  index: true,
  elem-id: "rookery-search-index",
  body-chars: 1200,
) = context {
  if _target() != "html" or _rheo-ctx() == none { return }
  assert(
    type(limit) == int and limit > 0,
    message: "@rheo/rookery-search: #search-modal's `limit` must be a positive "
      + "integer — got " + repr(limit),
  )
  assert(
    class == none or type(class) == str,
    message: "@rheo/rookery-search: #search-modal's `class` must be none or a "
      + "string — got " + repr(class),
  )
  if index { search-index(elem-id: elem-id, body-chars: body-chars) }
  if trigger {
    html.elem(
      "button",
      attrs: (
        class: "rookery-search-trigger",
        type: "button",
        "data-rookery-search-modal": elem-id,
        "aria-label": trigger-label,
      ),
      html.elem(
        "svg",
        attrs: (class: "rookery-search-icon", viewBox: "0 0 24 24", "aria-hidden": "true"),
        html.elem("path", attrs: (
          d: "M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3"
            + " 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49"
            + " 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z",
        )),
      )
        + html.elem("kbd", attrs: (class: "rookery-search-key", "aria-hidden": "true"), [Ctrl K]),
    )
  }
  html.elem(
    "dialog",
    attrs: (
      class: if class == none { "rookery-search-modal" } else { "rookery-search-modal " + class },
      "data-rookery-search": elem-id,
      "data-rookery-search-limit": str(limit),
    ),
    html.elem(
      "div",
      attrs: (class: "rookery-search-modal-inner"),
      html.elem("input", attrs: (
        class: "rookery-search-input",
        type: "search",
        role: "combobox",
        autocomplete: "off",
        "aria-autocomplete": "list",
        "aria-expanded": "false",
        placeholder: placeholder,
        "aria-label": placeholder,
      ))
        + html.elem(
          "div",
          attrs: (class: "rookery-search-panes"),
          html.elem("div", attrs: (class: "rookery-search-list", role: "listbox"), [])
            + html.elem("div", attrs: (class: "rookery-search-preview", "aria-live": "polite"), []),
        )
        + html.elem(
          "div",
          attrs: (class: "rookery-search-hint"),
          [↑↓ navigate · ↵ open · esc close],
        ),
    ),
  )
}
