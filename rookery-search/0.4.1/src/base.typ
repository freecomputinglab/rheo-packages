// Whether we are compiling under rheo and to what, the theme rookery
// publishes, and the argument validators several public functions share.
//
// EVERY OTHER MODULE IMPORTS THIS ONE and it imports nothing, which is what
// keeps the module graph a DAG.


// ---- Target detection — a deliberate copy of rookery's ---------------------
//
// The originals are `_rheo-ctx` and `_target` in `rookery/0.4.0/src/lib.typ`,
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

// ---- The rookery theme — inherited, not copied ----------------------------
//
// This package's stylesheet reads rookery's own custom properties before its
// literals — `var(--rookery-search-border, var(--idea-border-color, ...))` and
// friends — so a site that themes its notes tints the search UI to match with no
// second configuration. That used to require this package to carry its own copy
// of rookery's theme table and inject it as an inline `style` on `#search-bar`'s
// span and `#search-modal`'s dialog, because neither has a `.idea-*` ancestor to
// inherit from and rookery only emitted the properties on its own containers.
//
// Rookery now ALSO publishes the configured theme once per page as a
// document-scope `<style>:root { --idea-*: ...; }</style>` rule (see the banner
// above `_THEME-KEYS`/`_theme`/`_themed` in `rookery/0.4.0/src/lib.typ`). Custom
// properties inherit down the WHOLE DOM from `:root`, so `#search-bar` and
// `#search-modal` see the theme for free with no private copy of the table and
// no state-key contract to keep in step. MEASURED 2026-08-18: `getComputedStyle`
// on both elements resolves `--idea-border-color` correctly via that inheritance
// alone, with no inline style of their own.

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

// ---- Argument validators shared by more than one public function ----------
//
// `tags`, `match` and `body-search` are checked identically by several of this
// package's public functions, each of which used to carry its own six-line
// `assert` and its own copy of the message. MEASURED at 0.4.0: 18 assert blocks
// in this file, `tags` written out four times and `match` four.
//
// `where` is the caller's own name as it already appears in the message, so the
// text a reader sees is byte for byte what it was — possessive included, since
// `#search-ideas'` and `#search-index's` are both correct for their nouns.
//
// A DELIBERATE COPY of `@rheo/rookery`'s three, not an import of them, for the
// same reason `_target` above is a copy: these say `@rheo/rookery-search:` and
// belong to this package's messages. Importing an internal of another package to
// save nine lines would couple the two on something neither documents.
//
// `limit` and `class` are NOT here. They are checked by `#search-bar` and
// `#search-modal`, which are being folded onto one shared core in their own
// bead — deduplicating them here would only move the same lines twice. And
// `#search-ideas`' `limit` is a different check anyway: it accepts 0, the UI's
// does not.
#let _assert-tags(v, where) = assert(
  v == none
    or type(v) == str
    or (type(v) == array and v.all(t => type(t) == str)),
  message: "@rheo/rookery-search: " + where + " `tags` must be none, a "
    + "string, or an array of strings — got " + repr(v),
)

#let _assert-match(v, where) = assert(
  v == "any" or v == "all",
  message: "@rheo/rookery-search: " + where + " `match` must be \"any\" or "
    + "\"all\" — got " + repr(v),
)

#let _assert-bool(v, name, where) = assert(
  type(v) == bool,
  message: "@rheo/rookery-search: " + where + " `" + name + "` must be a "
    + "boolean — got " + repr(v),
)
