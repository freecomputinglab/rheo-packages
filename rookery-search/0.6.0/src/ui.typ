// The two public search surfaces — the embeddable `#search-bar` and the overlay
// `#search-modal` — and the core they share.
//
// RHEO ONLY, both: they mint an island and DOM that `src/rookery-search.js`
// wires up in the browser, and neither has anything to do under plain
// `typst compile`.

#import "base.typ": *
#import "corpus.typ": *

// ---- #search-bar — the embeddable search UI. RHEO ONLY --------------------
//
//   #search-bar()
//   #search-bar(placeholder: "Find a note", limit: 12, class: "topbar-search")
//   #search-bar(index: false)   // a SECOND bar on a page that already has one
//   #search-bar(body-terms: 24)  // a tighter term budget per note in the island
//   #search-bar(body-search: false) // ids and titles only, no body text
//   #search-bar(tags: "phd")        // a bar over only the notes tagged phd
//
// Emits the JSON island (via `search-index`, `body-terms:`, `df-ceiling:`,
// `body-search:`, `tags:` and `match:` forwarded to it UNCHANGED — this function
// asserts none of them, `#search-index` owns their validation), an `<input>`, and
// an empty
// results container; `src/rookery-search.js`, injected by rheo from the
// manifest's `js_scripts`, wires them together.
//
// `tags:` SCOPES THE BAR by scoping its island, which is why it belongs here
// rather than in the script: the corpus is chosen in Typst, and the browser
// searches whatever it was handed. Two differently-scoped bars on one page are
// therefore two islands — give each its own `elem-id:` and leave `index: true`
// on both, where two bars over the SAME corpus want one island and
// `index: false` on the second.
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
  body-terms: 48,
  df-ceiling: 40,
  body-search: true,
  tags: none,
  match: "any",
) = context {
  if _target() != "html" or _rheo-ctx() == none { return }
  _search-ui-common(
    "#search-bar's",
    limit,
    class,
    index,
    elem-id,
    body-terms,
    df-ceiling,
    body-search,
    tags,
    match,
  )
  html.elem(
    "span",
    // No inline theme style needed: it inherits rookery's `--idea-*` properties
    // from the document-scope `:root` rule. See the theme block near the top of
    // this file.
    attrs: (
      class: _search-class("rookery-search", class),
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
//   #search-modal(tags: "phd")      // only the notes tagged phd
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
// `elem-id:`/`body-terms:`/`df-ceiling:`/`body-search:`/`tags:`/`match:`
// `#search-bar` already takes, all forwarded unchanged and all asserted by
// `#search-index`), then the trigger button (unless `trigger: false`), then the
// dialog.
// That is ALL it emits — see below on where the preview pane's content comes
// from.
//
// `tags:`/`match:` scope the island exactly as they do for `#search-bar`, so a
// site-wide modal can be restricted to one tag's notes. A modal sitting in a
// site's shared header is the case where that costs least to say and most to
// get wrong: the scope is settled once, in Typst, on every page it renders on.
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
// a build straight off disk gets the JSON island's `body` field instead of the
// rich rendering — which since 0.3.0 is that note's compressed KEYWORD ROW, not
// a prose excerpt, because the field is compressed precisely on the grounds that
// the pane no longer renders it as prose (see `#search-index`). Rich previews
// need http (`rheo watch`, or any served copy). Serve the build, or accept the
// keyword row. Note that `body-search: false` removes that field, so the two
// together mean no preview at all on `file://`; over http the fetched page is
// unaffected.
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
  body-terms: 48,
  df-ceiling: 40,
  body-search: true,
  tags: none,
  match: "any",
) = context {
  if _target() != "html" or _rheo-ctx() == none { return }
  _search-ui-common(
    "#search-modal's",
    limit,
    class,
    index,
    elem-id,
    body-terms,
    df-ceiling,
    body-search,
    tags,
    match,
  )
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
    // No inline theme style needed here either: this element is emitted wherever
    // the author calls `#search-modal` — in practice a site's header — and now
    // inherits rookery's `--idea-*` properties from the document-scope `:root`
    // rule rather than from a DOM parent. See the theme block near the top of
    // this file.
    attrs: (
      class: _search-class("rookery-search-modal", class),
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
