// The theme: the keys a project may set, and their translation into CSS custom
// properties.
//
// Read by every element this package renders, through `_themed`, which is why
// this sits low in the module order — it depends on nothing but `base`.

#import "base.typ": *

// ---- Theme — configurable the same way ------------------------------------
//
// Every colour the package will set for you, as one dictionary. `#show:
// rookery` publishes it; `rookery.css` holds the DEFAULTS and this state holds
// only the overrides, so an unconfigured document emits nothing extra at all.
//
// Delivered as INLINE CSS CUSTOM PROPERTIES on the elements that root a
// rookery subtree — `.idea-box`, `.idea-window`, and a minted page's `<h1>` —
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
// document, so a note and a window of it cannot disagree about their colours.
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
//
// `border-color` (the `.idea-box`/`.idea-window` left rule) has no default of
// its own — `rookery.css` falls it back to `link-color` first, so a note's
// rule and its links read as one colour until a theme sets `border-color`
// apart from `link-color` deliberately.
//
// `pad` is the other length. It is the indent between a note's rule and its
// content — and, on a window, that window's right padding too, so the content sits
// the same distance from both edges. The tab's offset and the top rule's stub span
// exactly this distance in order to close the corner on the rule, so they read the
// same value and a retheme cannot leave a notch. Halved under 600px by the
// stylesheet's own media query, which overrides the one property rather than the
// four rules that depend on it.
//
// `rule-width` is the other odd one out: a LENGTH, not a colour, and it sets ONE
// thickness for every line that frames a note — the left rule on a card and a
// window, the tab that rules off the top of both, and `#ideas-outline`'s own rule
// and row markers. They are one system and they were four literals; a project
// that wants a heavier or lighter frame moves this and they all follow, including
// the corner arithmetic that has to know the rule's width to close on it. The
// separators above a footnotes, references or page-references block are NOT
// governed by it: those are apparatus rules, not the note's frame.
// CONSUMED BY @rheo/rookery-search, and not through an import. That package
// emits rookery's properties onto its own `#search-bar` span and `#search-modal`
// dialog, because neither has an `.idea-*` ancestor to inherit them from — a
// search UI lives in a site's header, not inside a note card. It reaches them by
// reading `state("rheo-idea-theme")` BY NAME (a Typst state is global per key)
// and by keeping its own copy of the table below, exactly as it keeps a copy of
// `_rheo-ctx`. So THREE things here are a cross-package contract, not private
// detail: the state's key string, the shape of the dictionary it holds (theme key
// -> already-stringified CSS value), and every property spelling in the table.
// Change any of them and change `rookery-search/0.4.0/src/lib.typ` in the same
// commit.
#let _THEME-KEYS = (
  "link-color": "--idea-link-color",
  "fold-color": "--idea-fold-color",
  "id-color": "--idea-id-color",
  "date-color": "--idea-date-color",
  "border-color": "--idea-border-color",
  "rule-width": "--idea-rule-width",
  "pad": "--idea-pad",
  "label-font": "--idea-label-font",
  "label-size": "--idea-label-size",
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

// Return `tags-color` as a block of GENERATED CSS RULES — one
// `.idea-tag-<tag>` rule per themed tag, publishing that tag's colours as the
// custom properties `rookery.css` already reads — or `none` when no tag is
// themed, mirroring `_theme-style()`'s `none` contract above so an unthemed
// document still emits nothing at all.
//
// RULES, NOT AN INLINE STYLE, and that is the whole point of the shape. These
// colours used to be an inline `style` attribute on the one pill
// `_permalink-tab` builds, which reached exactly that element and nothing else.
// Every OTHER surface a themed tag should colour already wears the same
// `idea-tag-<tag>` class — the note heading and the card (`idea.typ`), an
// outline row (`outline.typ`), and the chips `@rheo/rookery-search` builds IN
// THE BROWSER, long after Typst has run and therefore unreachable by any inline
// style Typst could ever write. One rule on the shared class reaches all of them
// at once, because `rookery.css`'s pill rule already resolves
// `var(--idea-tag-color, ..)` and `var(--idea-tag-bg, ..)`.
//
// ACCEPTED CONSEQUENCE: a themed pill is UNCOLOURED in EPUB output, which ships
// no stylesheet here, so those `var()`s fall back to their defaults. Paid
// deliberately for the gain an inline style made impossible — a project can now
// override a themed pill from its own stylesheet.
//
// `@layer rookery-tags` IS LOAD-BEARING, and not guessable from the output.
// This `<style>` sits in the document BODY, and UNLAYERED CSS beats LAYERED CSS
// regardless of source order — so WITHOUT the layer these generated rules would
// outrank a project's own `.idea-tag-draft { --idea-tag-bg: .. }` in its linked
// stylesheet, taking away the very override the shared class exists for.
// `rookery.css` is itself unlayered and unaffected either way: it only READS
// these properties, it never sets them.
//
// THREE PROPERTIES FROM TWO KEYS. `--idea-tag-line` is not in the `tags-color`
// vocabulary an author writes: it is derived here, and it colours the hairline
// MARKER on an outline row (`.idea-outline-row::before`, rookery.css). A 2px
// rule and a pill's text are different jobs, so reusing `--idea-tag-color` for
// both would leave the tick uncoloured for the documented shorthand — `draft:
// rgb("#3366ff")` means BACKGROUND-only. Hence: `text` when the entry has one,
// `background` otherwise. `_resolve-tags-color` rejects an entry with neither,
// so a themed tag always publishes a line colour.
//
// Reads the normalized `tags-color` dict (`_resolve-tags-color`, data.typ),
// where each tag maps to a dict with optional `background` and/or `text` keys,
// both already CSS-stringified (hex or passthrough) — and whose KEY is already
// validated as a usable CSS class, which is what makes interpolating it into a
// selector here safe.
#let _tags-color-rules() = {
  let tags-color = _theme.final().at("tags-color", default: (:))
  let rules = tags-color
    .pairs()
    .map(((tag, def)) => {
      let decls = ()
      if "background" in def { decls.push("--idea-tag-bg: " + def.at("background")) }
      if "text" in def { decls.push("--idea-tag-color: " + def.at("text")) }
      decls.push(
        "--idea-tag-line: "
          + if "text" in def { def.at("text") } else { def.at("background") },
      )
      ".idea-tag-" + tag + " { " + decls.join("; ") + " }"
    })
  if rules.len() == 0 { none } else { "@layer rookery-tags { " + rules.join(" ") + " }" }
}
