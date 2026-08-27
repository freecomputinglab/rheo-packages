// `#ideas` — every registered note as plain data, which is the supported way to
// build anything this package does not: an index page, a feed, a graph.
//
// `@rheo/rookery-search` is written entirely against this and `#note-href`.

#import "base.typ": *
#import "state.typ": *
#import "urls.typ": *
#import "hyperlink.typ": *
#import "links.typ": *
#import "idea.typ": *
#import "transclusion.typ": *

// ---- #ideas — every registered note, as data ------------------------------
//
//   #context ideas()                 // -> ((id: "idea:etal", name: "etal", ..), ..)
//   #context ideas(tags: "phd")      // only the notes tagged phd
//   #context ideas(tags: ("phd", "draft"), match: "all")  // both tags
//
// The whole rookery as a plain ARRAY of dictionaries, ordered by id so a build
// is reproducible. This is the primitive other packages and custom site code
// are written against — `@rheo/rookery-search` ranks it, a site can render it
// as an index, a feed can walk it — and it is deliberately a snapshot of
// STABLE fields rather than the internal record:
//
//   (id:      "idea:etal",     // the full id, prefix included
//    name:    "etal",          // the id with the prefix stripped
//    title:   [Et al.],        // the title as CONTENT, or none
//    text:    "Et al.",        // the same title as plain text, "" if none
//    tags:    ("note", "draft"), // as the author gave them, () if untagged
//    body:    "Et al. is ...", // the note's body as plain text, "" if empty
//    href:    "ideas/etal.html", // depth-relative, or none — see `note-href`
//    page:    "ideas/etal.html", // site-root-relative, or none — see `note-path`
//    minted:  datetime or none,
//    updated: datetime or none)
//
// `tags` is the note's tag NAMES, every key including the valued ones, and
// TAGS ARE UNORDERED as of 0.5.0: key order is unspecified and nothing may
// depend on it. A consumer wanting a stable sequence sorts them itself.
// The VALUES are not here — `tag-data()` below hands over the whole store.
//
// `#tags-of(name)` exposes ONE note's tags too, and still does. This field is
// the bulk form and the cheap one: `tags-of` resolves `_registry.final()` once
// PER NOTE, where `ideas()` resolves it once for the whole pass — and
// `@rheo/rookery-search`'s `#search-index` runs on every page of a site, so the
// difference is one state resolution per note per page against one per page.
//
// NOT exposed IN BULK: `raw`, `body`-as-CONTENT and `links`. `body` above is
// a plain STRING derived from `raw` — matchable and excerptable, but not
// renderable, so returning it in an array of every note in the rookery does
// not make a consumer a second transclusion engine the way handing out every
// note's content here would; `links` is backlink plumbing that `.marrow.typ`
// already owns. Add fields here when a consumer genuinely needs them — this
// list is a contract other packages depend on, so removing one is a breaking
// change.
//
// A SINGLE note's body-as-content IS available, on request: `#idea-body(name)`
// below renders one note at a time, the same rendering `#window` gives it —
// links, styling, footnotes, citations — for a consumer that wants to show
// the actual note rather than describe it. The distinction is bulk vs.
// one-at-a-time: `#ideas()` handing out `title` (content) for the WHOLE
// rookery would already be the transclusion-engine problem above if it
// contained the full body instead of a heading; asking for one note's body
// by name is what `#window` has always let an author do explicitly, and
// `#idea-body` is that same permission, minus the chrome.
//
// `tags:`/`match:` narrow the corpus to the notes carrying a tag, and are the
// SAME pair `#window` takes, with the same meanings, through the same shared
// `_tag-pred`: `tags` is `none`, one string or an array; `match` is "any" (the
// default) or "all". They exist because the workaround does not scale and does
// not reach far enough — `ideas().filter(e => "phd" in tags-of(e.name))` works
// and is VERIFIED, but it costs one `_registry.final()` read per row, and
// `#search-bar` builds its index internally with no hook for a caller's filter
// at all.
//
// Filtered BEFORE the `.map`, so a note that is dropped never pays for its
// `_body-plain`/`_note-href`/`_plain` conversions. That is the whole reason the
// parameter is here rather than left to a caller's own `.filter`.
//
// Must be called INSIDE a `#context` block (it reads `_registry.final()`); it
// is not itself a context function, because a context function can only return
// content and the whole point here is to return data.
#let ideas(tags: none, match: "any") = {
  _assert-tags(tags, "#ideas'")
  _assert-match(match, "#ideas'")
  let reg = _registry.final()
  let keep = _tag-pred(tags, match)
  reg
    .pairs()
    .sorted(key: p => p.at(0))
    .filter(p => keep == none or keep(p.at(1).at("tags", default: (:))))
    .map(p => {
      let (id, rec) = p
      (
        id: id,
        name: _norm(id),
        title: rec.at("title", default: none),
        text: _plain(rec.at("title", default: none)),
        // TAG NAMES ONLY, as a flat array of every key — valued tags included.
        // The VALUES are deliberately kept off this row, and that is load-
        // bearing rather than tidiness: `@rheo/rookery-search` puts this field
        // straight into a JSON index (`corpus.typ`, `row.tags`) and calls
        // `.map` on it (`rank.typ`). A dictionary breaks both, and a value can
        // be a datetime or content — MEASURED, `json.encode` of content does
        // not error, it silently emits a structural blob and bloats every page.
        // Keeping values off the row makes that failure impossible rather than
        // merely unlikely. Reach for `tag-data()` below when you want them.
        tags: rec.at("tags", default: (:)).keys(),
        body: _body-plain(rec.at("raw", default: none)),
        href: _note-href(id),
        page: _note-path(id),
        minted: rec.at("minted", default: none),
        updated: rec.at("updated", default: none),
      )
    })
}

// ---- tag-data — every note's tag store, in bulk ---------------------------
//
//   #context tag-data()   // -> ("idea:etal": (phd: none, priority: 1), ..)
//
// The whole tag dictionary of every registered note, keyed by full note id.
// This is the accessor a package builds on when it needs tag VALUES across the
// corpus — `@rheo/rookery-todos` reads its dependency edges out of it.
//
// BULK, and that is the point. `tags-of`/`tag-value` each resolve
// `_registry.final()` for ONE note, so walking N notes through them pays N
// registry reads; the same cost is already noted against `tags-of` further up.
// One `ideas()` plus one `tag-data()` covers the whole corpus, and the two join
// cleanly on `id`.
//
// Values are arbitrary Typst values — datetimes, arrays, content, anything a
// package put there. DO NOT serialize this wholesale into a page: that is
// exactly what `ideas().tags` publishing keys only is there to prevent.
//
// Must be called INSIDE a `#context` block (it reads `_registry.final()`); it
// is not itself a context function, because a context function can only return
// content and the whole point here is to return data.
#let tag-data() = {
  _registry
    .final()
    .pairs()
    .map(p => (p.at(0), p.at(1).at("tags", default: (:))))
    .to-dict()
}

// The 17 knobs `#show: rookery` accepts, checked before anything is published.
//
// Extracted from `rookery` below rather than inlined in it: the function was 158
// code lines, 13 of them asserts, and a reader asking what `#show: rookery`
// actually DOES had to scroll past the whole validation wall to reach the state
// updates that answer them. Nothing here is reusable — it exists once, for one
// caller — and that is fine: the split is for the reader, not for reuse.
//
// Every message is verbatim from where it was, including the ones that name no
// function (`prefix`, `ref-target`): these are the TEMPLATE's arguments, so
// there is no `#function's` to name.
#let _validate-config(
  prefix,
  window-depth,
  idea-page-template,
  theme,
  bibliography,
  ref-target,
  syndicate,
  index-page,
  invisible-tags,
) = {
  assert(
    type(prefix) == str and prefix != "" and not prefix.contains(":"),
    message: "@rheo/rookery: `prefix` must be a non-empty string containing no `:` "
      + "(the `:` between prefix and name is added for you) — got "
      + repr(prefix),
  )
  assert(
    type(window-depth) == int and window-depth >= 0,
    message: "@rheo/rookery: `window-depth` must be a non-negative integer — `0` "
      + "renders every #window as a link to the note's page, `1` (the default) "
      + "renders a windowed note once, `n` unfurls n-1 nested levels — got "
      + repr(window-depth),
  )
  assert(
    idea-page-template == none or type(idea-page-template) == function,
    message: "@rheo/rookery: `idea-page-template` must be a function taking "
      + "`(id: str, note: dictionary, doc)` — got " + repr(idea-page-template),
  )
  assert(
    type(theme) == dictionary,
    message: "@rheo/rookery: `theme` must be a dictionary of "
      + _THEME-KEYS.keys().join(", ") + ", tags-color" + " — got " + repr(theme),
  )
  assert(
    bibliography == none or type(bibliography) == arguments,
    message: "@rheo/rookery: `bibliography` must be an `arguments` value carrying "
      + "Typst's own #bibliography arguments, e.g. "
      + "`arguments(bytes(read(\"refs.bib\")), style: \"chicago-author-date\")` — got "
      + repr(bibliography),
  )
  // A PATH CANNOT WORK HERE, so say so rather than failing later with a
  // "file not found" naming a directory inside the package. Typst resolves a
  // path relative to the file the call appears in, and every call this package
  // makes is inside the package — see the note on `_bib`.
  if bibliography != none {
    let src = bibliography.pos().at(0, default: none)
    let sources = if type(src) == array { src } else { (src,) }
    for s in sources {
      assert(
        type(s) == bytes,
        message: "@rheo/rookery: `bibliography` sources must be `bytes`, not a path — "
          + "write `bytes(read(\"refs.bib\"))` so the path resolves against YOUR "
          + "file rather than against the package. Got " + repr(s),
      )
    }
  }
  assert(
    ref-target == "page" or ref-target == "anchor",
    message: "@rheo/rookery: `ref-target` must be \"page\" or \"anchor\" — got "
      + repr(ref-target),
  )
  assert(
    type(syndicate) == bool,
    message: "@rheo/rookery: `syndicate` must be a boolean — got " + repr(syndicate),
  )
  assert(
    type(index-page) == bool,
    message: "@rheo/rookery: `index-page` must be a boolean — got " + repr(index-page),
  )
  // THROUGH `_assert-tags`, the same helper every other tag-shaped argument in
  // this package uses, so `invisible-tags: "private"` needs no array ceremony and
  // a wrong type reads the same way here as it does on `#idea`'s own `tags:`.
  _assert-tags(invisible-tags, "`invisible-tags`")
}

// Resolve a tags-color dictionary: each tag maps to either a colour/CSS-string
// (shorthand for background-only) or a dictionary with optional background/text keys.
// Returns a normalized dict with all colours converted to CSS hex strings.
#let _resolve-tags-color(tags-color) = {
  assert(
    type(tags-color) == dictionary,
    message: "@rheo/rookery: theme `tags-color` must be a dictionary — got "
      + repr(tags-color),
  )

  // Reusable colour converter: Typst color -> hex, string passthrough, else fail.
  let _css-color(key, value) = if type(value) == color {
    value.to-hex()
  } else if type(value) == str {
    value
  } else {
    assert(
      false,
      message: "@rheo/rookery: theme `tags-color` entry for \"" + key + "\" must be "
        + "a colour, a CSS colour string, or a dictionary with `background`/`text` keys — got "
        + repr(value),
    )
  }

  let resolved = (:)
  for (tag, value) in tags-color {
    // A THEMED TAG NAME IS A SELECTOR, which is why this is checked here and
    // not left to the free-form `tags:` array on `#idea`. A tag becomes the
    // class `idea-tag-<tag>` on the note, and a themed one ALSO becomes a
    // generated `.idea-tag-<tag>` rule (`_tags-color-rules`, theme.typ), so a
    // name carrying a space, a `.`, a `#`, a `:` or a leading digit either
    // breaks the stylesheet or matches the wrong elements. The sibling defect
    // one step upstream is already recorded in `_permalink-tab`
    // (permalink.typ): a tag with a space emits a broken two-class attribute,
    // `class="idea-tag idea-tag-my tag"`.
    //
    // REJECTED rather than escaped. Escaping an arbitrary name for a CSS
    // selector is a second, subtler spelling of every tag — the class attribute
    // would have to agree with it everywhere, including in a project's own
    // stylesheet, where the author writes the name by hand.
    //
    // An UNTHEMED tag is unconstrained, as before: this is about `tags-color`
    // KEYS, and a note may carry any string it likes as long as no colour is
    // asked for it by name.
    assert(
      tag.matches(regex("^[A-Za-z_][A-Za-z0-9_-]*$")).len() == 1,
      message: "@rheo/rookery: theme `tags-color` key \"" + tag + "\" is not usable "
        + "as a CSS class — a themed tag becomes the class `idea-tag-<tag>` and a "
        + "generated `.idea-tag-<tag>` rule, so it must start with a letter or an "
        + "underscore and carry only letters, digits, hyphens and underscores",
    )
    if type(value) == color or type(value) == str {
      // Shorthand: scalar colour/string -> background-only dict
      resolved.insert(tag, (background: _css-color(tag, value)))
    } else if type(value) == dictionary {
      // Dictionary form: validate and normalize
      let normalized = (:)
      for (key, val) in value {
        assert(
          key == "background" or key == "text",
          message: "@rheo/rookery: theme `tags-color` entry for \"" + tag + "\" has "
            + "unknown key `" + key + "` — valid keys are `background` and `text`",
        )
        normalized.insert(key, _css-color(tag + "." + key, val))
      }
      assert(
        normalized.len() > 0,
        message: "@rheo/rookery: theme `tags-color` entry for \"" + tag + "\" is an "
          + "empty dictionary — at least one of `background` or `text` must be present",
      )
      resolved.insert(tag, normalized)
    } else {
      assert(
        false,
        message: "@rheo/rookery: theme `tags-color` entry for \"" + tag + "\" must be "
          + "a colour, a CSS colour string, or a dictionary with `background`/`text` keys — got "
          + repr(value),
      )
    }
  }
  resolved
}

// The theme dictionary as CSS, from both the `theme:` dictionary and the
// granular arguments beside it.
//
// Extracted alongside `_validate-config` above and for the same reason. It
// returns the resolved dictionary rather than publishing it, so the state
// update stays in `rookery` with the seven others — publishing is the part of
// that function a reader wants to see in one place.
#let _resolve-theme(
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
) = {
  // One converter for both sources, so `theme: (link-color: c)` and
  // `link-color: c` cannot disagree about what a value may be.
  //
  // THREE KINDS OF VALUE, not two. Colours are the default and the majority;
  // `rule-width`/`pad`/`label-size` are LENGTHS; `label-font` is a FONT STACK,
  // which is neither — it is CSS text this package cannot validate and must
  // not mangle, so it is passed straight through. An array is accepted and
  // joined with `", "`, because a stack is what a font is and writing it as
  // `("Berkeley Mono", "monospace")` reads better than embedding the commas
  // in a string.
  //
  // The LENGTH branch: `repr` on a Typst length gives exactly the CSS it needs —
  // `2pt` -> "2pt", `0.15em` -> "0.15em" — so both spellings work and neither
  // needs a unit table here. A string passes through for the units Typst has no
  // literal for, `px` above all, which is what a hairline wants.
  let css(key, value) = if key == "label-font" {
    assert(
      type(value) == str or (type(value) == array and value.all(f => type(f) == str)),
      message: "@rheo/rookery: theme `label-font` must be a CSS font stack as a "
        + "string (\"Berkeley Mono, monospace\") or an array of family names "
        + "((\"Berkeley Mono\", \"monospace\")) — got " + repr(value),
    )
    if type(value) == array { value.join(", ") } else { value }
  } else if key in ("rule-width", "pad", "label-size") {
    // For `label-size` specifically, the STRING path is the primary one,
    // unlike `rule-width`/`pad` where a Typst length is more commonly used —
    // this key's whole point is staying in `rem` (see the readme), and Typst
    // has no `rem` literal, so `"0.8rem"` rather than a length is expected to
    // be the normal spelling here.
    assert(
      type(value) == length or type(value) == str,
      message: "@rheo/rookery: theme `" + key + "` must be a length (2pt, 0.15em) "
        + "or a CSS length string (\"3px\") — got " + repr(value),
    )
    if type(value) == length { repr(value) } else { value }
  } else {
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
      key in _THEME-KEYS or key == "tags-color",
      message: "@rheo/rookery: unknown theme key `" + key + "` — valid keys are "
        + _THEME-KEYS.keys().join(", ") + ", tags-color",
    )
    if key == "tags-color" {
      if value != none { resolved.insert("tags-color", _resolve-tags-color(value)) }
    } else if value != none {
      resolved.insert(key, css(key, value))
    }
  }
  // Granular arguments last: they override whatever `theme:` set.
  for (key, value) in (
    link-color: link-color,
    fold-color: fold-color,
    id-color: id-color,
    date-color: date-color,
    border-color: border-color,
    rule-width: rule-width,
    pad: pad,
    label-font: label-font,
    label-size: label-size,
  ) {
    if value != none { resolved.insert(key, css(key, value)) }
  }
  resolved
}
