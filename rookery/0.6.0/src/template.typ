// `#show: rookery` — the setup, its validation, and its theme resolution.
//
// Last, and importable by nothing here: it reads every other module, which is
// what a template does. A `#let` closure captures the scope visible at
// definition time, so this file existing at the end of the import order is what
// lets it see `hyperlink` for the `show ref:` rule.

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
#import "window.typ": *
#import "outline.typ": *
#import "data.typ": *

#import "data.typ": *
// ---- #show: rookery — the setup, and the knobs ----------------------------
//
//   #import "@rheo/rookery:0.6.0": rookery, idea, window
//   #show: rookery.with(
//     prefix: "note",
//     theme: (link-color: rgb("#ffe08a"), fold-color: rgb("#fffbe8")),
//   )
//
// Does exactly five things, and deliberately nothing else:
//
//   1. publishes `prefix` (so `#idea("etal")` mints `<note:etal>`);
//   2. publishes `window-depth`, the document-wide transclusion budget (see
//      `_window-depth` for the whole scale; `1`, the default, renders a
//      windowed note once and collapses a `#window` nested inside it to its
//      permalink, which is the behaviour every existing document already has,
//      while `0` transcludes nothing and renders every `#window` as a link to
//      the note's page). A `#window(..., depth: n)` overrides it per call
//      site;
//   3. publishes `idea-page-template`, the project's own chrome for the
//      standalone pages `.marrow.typ` mints (see `_idea-page-template`;
//      `none`, the default, mints them bare as before);
//   4. publishes the theme — every colour the package will set for you;
//   5. installs `show ref: hyperlink` (or `hyperlink.with(link-to:
//      "anchor")`, see `ref-target:` below), so `@note:etal` renders the
//      note rather than a bare figure number.
//
// It does NOT transform the document. It sets no page/text/heading style,
// wraps `doc` in no container, and emits nothing of its own — `#show:
// rookery` on a document with no notes in it is a no-op. The blast radius is
// exactly one element type: `ref`. Even there the installed rule passes every
// reference that is NOT a rookery note straight through untouched (its `else
// { it }` branch — see `#hyperlink` above), so an ordinary `@fig:x` in the
// same document is unaffected.
//
// WHY NOT NARROWER — i.e. a rule scoped to `#idea` alone. The prefix cannot
// ride on a show rule over idea markers, because `#window` and `.marrow.typ`
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
// `ref-target: "page"` (the default) installs plain `hyperlink`; `"anchor"`
// installs `hyperlink.with(link-to: "anchor")` instead, making every
// `@idea:etal` in the document behave like `#hyperlink("idea:etal", ...,
// link-to: "anchor")` rather than jumping to the note's minted page. Only
// meaningful alongside `refs: true`; ignored (with no error) when `refs:
// false`, since there is then no installed rule for it to configure — an
// author who set `refs: false` already opted into supplying their own
// `show ref` rule, anchor-targeted or not.
//
// Defined last in this file because a `#let` closure captures the scope
// visible AT DEFINITION time — `hyperlink` must already exist.
#let rookery(
  prefix: "idea",
  window-depth: 1,
  idea-page-template: none,
  bibliography: none,
  theme: (:),
  link-color: none,
  fold-color: none,
  id-color: none,
  date-color: none,
  border-color: none,
  rule-width: none,
  pad: none,
  label-font: none,
  label-size: none,
  refs: true,
  ref-target: "page",
  syndicate: false,
  index-page: true,
  doc,
) = {
  _validate-config(
    prefix,
    window-depth,
    idea-page-template,
    theme,
    bibliography,
    ref-target,
    syndicate,
    index-page,
  )
  let resolved = _resolve-theme(
    theme,
    link-color,
    fold-color,
    id-color,
    date-color,
    border-color,
    rule-width,
    pad,
    label-font,
    label-size,
  )


  _prefix.update(prefix)
  _window-depth.update(window-depth)
  // Default the style to author-date, and ONLY when the author passed none.
  //
  // WHY: citation numbering is document-wide and cannot be reset. `counter(
  // bibliography).update(0)` does nothing — CSL assigns the numbers, not a
  // Typst counter — so under a numeric style the third idea on a page reads
  // `[3]` and a standalone page can show its only reference as `[7]`. MEASURED.
  // An author-date style has no numbers and the problem does not arise. A
  // numeric style is still honoured without complaint: this is a default, not
  // a restriction.
  //
  // `_ => v`, never a bare value that happens to be callable — see
  // `_idea-page-template` for why `state.update` needs the wrapper.
  _bib.update(_ => if bibliography == none { none } else {
    let named = bibliography.named()
    if "style" not in named { named.insert("style", "chicago-author-date") }
    arguments(..bibliography.pos(), ..named)
  })
  // `_ => f`, not `f` — see `_idea-page-template`.
  _idea-page-template.update(_ => idea-page-template)
  _syndicate.update(syndicate)
  _index-page.update(index-page)
  _theme.update(resolved)
  // DOCUMENT-SCOPE theme publication, ADDITIVE to the per-container INLINE
  // styling `_themed` still applies everywhere it already did (see that
  // function and its callers) — this does not replace them, it gives
  // anything ELSE on the page a `:root` to inherit from. Custom properties
  // inherit DOWN the DOM, but only from an ancestor that carries them: before
  // this, that was ever only `.idea-box`/`.idea-window`/etc, so a sibling
  // element with no rookery ancestor (a `<dialog>` in a site's own header, a
  // search bar not nested inside a note) saw nothing. MEASURED bug this
  // fixes: `@rheo/rookery-search`'s `#search-modal` reading an empty string
  // for `--idea-border-color` and having to carry its own copy of the theme
  // table to cope (see the banner above `_THEME-KEYS`).
  //
  // EXACTLY ONCE PER OUTPUT PAGE: `#show: rookery` is applied PER FILE, and
  // under rheo one FILE is one VERTEBRA is one OUTPUT PAGE (the same fact
  // `_prefix`/`_bib`/`_theme` above are already document-wide state for) —
  // so one call to this function is one page, and this line runs exactly
  // once per call. `demo/rheo/content/lib.typ` is the shape every multi-page
  // project already uses: ONE shared `#show: rookery.with(..)` wrapper that
  // EVERY vertebra applies, so every page gets its own `<style>`, all of them
  // carrying the same document-wide `.final()` theme. A minted note page
  // (`.marrow.typ`) is a separate `#document` that never calls `rookery()`
  // again, so it is untouched by this — same as it always was.
  //
  // Reuses `_theme-style()` rather than re-deriving anything: it already
  // returns `none` for an unconfigured theme, so an unthemed project's
  // `<style>` count stays exactly zero, matching the promise inline theming
  // already keeps ("an unconfigured document emits nothing extra at all").
  //
  // TWO BLOCKS, ONE `<style>`. The `:root` block carries the document-wide
  // theme; the second is the per-tag `@layer rookery-tags` block that delivers
  // `theme: (tags-color: ..)` as generated `.idea-tag-<tag>` rules
  // (`_tags-color-rules`, theme.typ — read its banner for why a rule and why the
  // layer). They are independent: a project may configure either, both or
  // neither, and the element is emitted only when at least one has something to
  // say, so the zero-`<style>` promise above still holds for an unthemed
  // document.
  //
  // GATED to html/epub, exactly like every other `html.elem` call in this
  // file: `html.elem` renders nothing meaningful on the paged (PDF) target,
  // and unconditionally calling it there is what `demo/pure`'s two PDF roots
  // exist to catch.
  context {
    if _target() == "html" or _target() == "epub" {
      let root = _theme-style()
      let tags = _tags-color-rules()
      if root != none or tags != none {
        html.elem(
          "style",
          (if root != none { ":root { " + root + "; }" } else { "" })
            + (if tags != none { tags } else { "" }),
        )
      }
    }
  }
  // THE PAGE-LEVEL LINK BEACON, one per vertebra: which notes THIS page links to
  // in its own prose, for the page half of a minted page's backlink list. Read
  // `_page-links`'s banner in outline.typ for why this is beaconed rather than
  // swept out of the document with `query`, and for the 72 dead links the sweep
  // was ultimately responsible for.
  //
  // HERE, in the template, because this is the only place holding the whole page:
  // `doc` is the vertebra's entire content, and "what does this page link to
  // outside any note" is answerable from that content tree alone, with no
  // introspection. The same asymmetry the trailing-citations block below relies
  // on, for the same reason — an idea never sees the prose around it.
  //
  // EXACTLY ONCE PER OUTPUT PAGE, on the same grounds as the `<style>` block
  // above: `#show: rookery` is applied per FILE, and under rheo one file is one
  // vertebra is one output page. A minted note page never calls `rookery()` again
  // — it applies the project's `idea-page-template` — so it publishes no beacon,
  // and that is what keeps `query(<rookery-page-links>)` a selector marrow's own
  // output cannot grow.
  //
  // Not gated on target: the beacon renders nothing anywhere, and the paged build
  // answers the same question about the same page.
  context _page-links-beacon(doc)
  // The fallback for a rookery `#footnote` written OUTSIDE any idea: page-wide
  // numbering and a body in the page's own endnote section, exactly as Typst's
  // own footnote behaves. `#idea` installs a nested rule that wins over this
  // one inside a note — MEASURED.
  //
  // Installed unconditionally: `refs: false` is about the `show ref:` rule
  // only, and a document that opted out of reference rendering has not thereby
  // opted out of footnotes.
  show FNK: it => std.footnote(it.value.rookery-fn)
  if refs {
    show ref: if ref-target == "anchor" { hyperlink.with(link-to: "anchor") } else { hyperlink }
    doc
  } else {
    doc
  }
  // TRAILING PROSE CITATIONS. A citation in page prose before an idea is
  // claimed by that idea's sweep block, but one written after the LAST idea or
  // window on the page has nothing following it — and a citation no
  // bibliography claims is a hard error (`label <key> does not exist in the
  // document`), so this is required for the page to build at all, not polish.
  //
  // `_own-cited-keys(doc)` is exactly the right question here, and it is the
  // same one an idea asks about its own body: every `#idea` and `#window` on
  // the page is a claimant, so what survives the last of them is precisely the
  // trailing prose. Both always render at page level, hence the default
  // `windows-claim: true`.
  //
  // The template CAN ask this where `#idea` cannot: it receives the whole page
  // as `doc`, whereas an idea never sees the prose around it. That asymmetry is
  // why the sweep block before each idea has to be unconditional while this one
  // does not.
  //
  // Emitted only when something is actually left, so `#show: rookery` keeps its
  // promise to emit nothing of its own on a page with no notes — and on any
  // page with no configured bibliography, since `_own-cited-keys` is then empty.
  context {
    let own = _own-cited-keys(doc)
    if own.len() > 0 {
      if _target() == "html" or _target() == "epub" {
        html.elem("div", attrs: (class: "idea-page-refs"), _bib-call([References]))
      } else {
        _bib-call([References])
      }
    }
  }
}
