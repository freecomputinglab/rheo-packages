// @rheo/rssfeed
//
// Atom 1.0 feed generation for Rheo projects, in pure Typst. This package
// replaces the Rust feed generator that was removed from rheo core — feed
// generation moves from the engine into a package, same as other
// project-shaped concerns already do.
//
// Two ways this package is used, once its full API lands:
//
//   (a) Configured from a vertebra via a `configure(...)` call that a
//       project's `.marrow.typ` mints for it — the common case, where the
//       feed's sources and metadata are declared once and threaded through
//       automatically. `configure` appends onto a document-wide `state`
//       (below), the same channel rookery's own `.marrow.typ` reads through
//       (`rg -n 'state("rheo-ideas"' rookery/0.3.0/src/lib.typ`), because a
//       vertebra cannot otherwise reach the bundle root a marrow's text is
//       spliced into.
//
//   (b) Called directly from a project's own `.marrow.typ`, for projects
//       that want to assemble the feed's inputs themselves rather than go
//       through a minted `configure(...)`. That path reads `resolve-entries`
//       and `atom(...)` directly — it needs the `state` in (a) not at all.
//
// This file now carries: the DATA MODEL (`feed(...)` builds and validates a
// feed config; `resolve-entries` runs a config's sources and normalises
// their output into the finished, ordered entry list); the built-in sources
// (`spine`, `items`, and the `item(...)` beacon helper); `configure`/the
// `state` wiring path (a) above; and `atom(...)`, the Atom 1.0 XML
// serializer. Path (a)'s other half is this package's own `.marrow.typ`,
// which reads `_feeds` and mints what `_mint-plan` returns; `emit(...)`
// below is path (b)'s entry point onto the same plan.
//
// MOSTLY rheo-free: `feed(...)`, `resolve-entries`, and `atom(...)` read no
// `sys.inputs` and work identically under plain `typst compile` with no
// rheo present — see `test/units.typ`. The built-in sources `spine`/`items`
// are the exception (Pattern B feature-detection — see their own doc
// comments): they read `sys.inputs`/`query()` when rheo is present and fall
// back to empty output when it is not.

// ---- entry — one syndicated page -------------------------------------------
//
// The shape `resolve-entries` normalises every source's output into:
//
//   id:         str        stable, globally unique; defaults to `url`
//   title:      str        REQUIRED
//   url:        str        absolute; if absent, built as `base-url + "/" +
//                           page` (see `_clean-page`)
//   page:       str        optional: plugin-output-relative path whose
//                           compiled HTML becomes <content> (a later bead)
//   select:     str        optional: region selector passed through to rheo
//                           (e.g. "main", ".rheo-feed-content")
//   published:  datetime   optional
//   updated:    datetime   REQUIRED by Atom (RFC 4287 §4.2.15); see the skip
//                           rule in `_normalize-entry`
//   summary:    str        optional
//   categories: (str,)     optional, defaults to `()`
//   author:     str        optional; falls back to the feed's own `author`
//
// A SOURCE need not fill every key — only `title` is mandatory on the way in;
// everything else is filled or defaulted by `_normalize-entry` below.

// ---- source — a plain function, not a registry --------------------------
//
// A source is a FUNCTION taking the resolved feed config dict (the same
// dict `feed(...)` returns) and returning an array of entries — nothing
// more. There is no source registry and no descriptor dict: a built-in
// source (`spine`, `items`) takes its own arguments and RETURNS that
// function, so it reads as an ordinary call at the call site:
//
//   #feed(sources: (spine(filter: e => e.handle.starts-with("posts:")),), ...)
//
// and a user-written source is any function of the same shape — nothing
// package-specific about it:
//
//   #let my-source(cfg) = ((title: "Hello", url: cfg.base-url + "/hi"),)
//
// This is why `sources` inside a `feed` config, and therefore inside the
// `configure` state below, holds live function VALUES rather than data:
// MEASURED (typst 0.15, `--features html`) that a Typst `state` can hold a
// function, that it survives `.final()`, and that the result is still
// callable — the same fact rookery's own `_idea-page-template` state relies
// on (see that package's `src/lib.typ`, "WHY A STATE HOLDING A FUNCTION").
// So the descriptor-dict fallback this bead's tracker sketched is NOT
// needed: a config's `sources` array is simply carried through, functions
// and all.

// ---- field validators — one message shape, every field ---------------------
//
// These exist so that EVERY field error names `@rheo/rssfeed` and the offending
// field, per the rule stated in the `feed` section immediately below. Without
// them an unchecked field does not fail here at all: it fails much later, deep
// inside the XML serializer, with a raw Typst error (`type integer has no
// method 'replace'` from `_esc-text`, `type string has no method 'display'`
// from `_rfc3339`) that names neither this package nor the field the author
// actually got wrong.
//
// Each returns its argument, so a call site reads as an annotation on the value
// rather than a statement before it:
//
//   path: _expect-str(path, "path"),
#let _expect-str(v, field) = {
  assert(
    type(v) == str and v.len() > 0,
    message: "@rheo/rssfeed: `" + field + "` must be a non-empty string — got "
      + repr(v),
  )
  v
}

#let _expect-str-or-none(v, field) = {
  assert(
    v == none or type(v) == str,
    message: "@rheo/rssfeed: `" + field + "` must be a string or none — got "
      + repr(v),
  )
  v
}

#let _expect-positive-int-or-none(v, field) = {
  assert(
    v == none or (type(v) == int and v > 0),
    message: "@rheo/rssfeed: `" + field + "` must be a positive integer or "
      + "none — got " + repr(v),
  )
  v
}

// ---- feed — the top-level config -------------------------------------------
//
// Every panic below names `@rheo/rssfeed` and the offending field: a package
// error must be self-identifying, since it surfaces in a project author's
// build log, not this package's own.
#let feed(
  path: "feed.xml",
  title: none,
  base-url: none,
  sources: (),
  author: "Rheo",
  subtitle: none,
  content: "html",
  limit: none,
) = {
  assert(
    type(title) == str and title.len() > 0,
    message: "@rheo/rssfeed: feed's `title` must be a non-empty string.",
  )
  assert(
    type(base-url) == str and base-url.len() > 0,
    message: "@rheo/rssfeed: feed's `base-url` must be a non-empty string.",
  )
  // Absolute means "starts with a scheme" — `http://`, `https://`, or
  // anything shaped like one (RFC 3986's scheme grammar: a letter, then
  // letters/digits/`+`/`.`/`-`). Anchored at the START of the string, not
  // merely present, so "see http://x" (a title, not a base-url) still fails.
  assert(
    base-url.match(regex("^[a-zA-Z][a-zA-Z0-9+.\-]*://")) != none,
    message: "@rheo/rssfeed: feed's `base-url` must be absolute (start with "
      + "a scheme, e.g. \"https://\") — got " + repr(base-url),
  )
  assert(
    type(sources) == array and sources.len() > 0,
    message: "@rheo/rssfeed: feed needs at least one source in `sources`.",
  )
  for s in sources {
    assert(
      type(s) == function,
      message: "@rheo/rssfeed: every entry in `sources` must be a function "
        + "(cfg) -> (entry, ..) — got " + repr(type(s)),
    )
  }
  assert(
    content == "html" or content == "xhtml" or content == none,
    message: "@rheo/rssfeed: feed's `content` must be \"html\", \"xhtml\", "
      + "or none — got " + repr(content),
  )

  // The four fields below are validated HERE, in the returned dict, rather than
  // as separate asserts above: each is checked exactly where it is stored, and
  // nothing else in this function needs their values. `title`, `base-url`,
  // `sources` and `content` keep their own asserts up top instead — each
  // carries field-specific wording (the scheme regex, the "at least one
  // source" count, the enumerated `content` values) that the generic helpers
  // would flatten away.
  (
    path: _expect-str(path, "path"),
    title: title,
    // Trimmed here, ONCE, so every downstream consumer (`_normalize-entry`,
    // the later XML emitter) can join with a bare "/" and never worry about
    // a double slash from an author-supplied trailing one.
    base-url: base-url.trim("/", at: end),
    sources: sources,
    author: _expect-str(author, "author"),
    subtitle: _expect-str-or-none(subtitle, "subtitle"),
    content: content,
    limit: _expect-positive-int-or-none(limit, "limit"),
  )
}

// ---- resolve-entries — run the sources, normalise, order, dedupe, limit ---

// Strip a single leading "./" or "/" from a source-supplied `page`, so
// `cfg.base-url + "/" + page` never doubles the slash: `base-url` already
// lost its own trailing one in `feed(...)` above, and a caller writing
// `page: "/posts/x.html"` or `page: "./posts/x.html"` (both natural ways to
// spell a "plugin-output-relative path") must not be punished for it.
#let _clean-page(page) = {
  if page.starts-with("./") {
    page.slice(2)
  } else if page.starts-with("/") {
    page.slice(1)
  } else {
    page
  }
}

// ---- _plain-text — flatten CONTENT (or pass a string through unchanged) ---
//
// Needed because a `title` can arrive as CONTENT rather than a plain string:
// `spine()`'s own beacon-sourced title (below) always is, and a hand-written
// source that forwards Typst's own `document.title` gets content too —
// MEASURED (typst 0.15.1, this package's own probe against rheo's
// `<rheo-meta:*>` beacon) that even `#set document(title: "Plain Str")`
// queries back as content `[Plain Str]`, and a bracket title with markup
// (`[Bracket #emph[Title]]`) as a `sequence` of `text`/`space`/`emph`
// children. There is no built-in content-to-string conversion in Typst, so
// this is a hand-rolled flattener.
//
// MEASURED shapes (typst 0.15.1, via `c.func()`/`c.has(..)`) drove every
// branch below:
//   - a `text` leaf has a `text` FIELD (`c.text`) holding the plain string.
//   - `sequence` (what a paragraph of mixed markup becomes) has a `children`
//     FIELD — an array of content, recursed into and joined with NO
//     separator: the space between two words is already its own `space`
//     child, not something the join needs to insert.
//   - `emph`/`strong` (and any similarly-shaped single-child wrapper) have a
//     `body` FIELD holding that one child — recursed into.
//   - `space`/`parbreak`/`linebreak` carry none of the three fields above
//     (`.has(..)` is false for all of `text`/`children`/`body`) and each
//     becomes a single " " — a title's flattened text has no need to
//     distinguish a paragraph break from a plain space. `space`, unlike
//     `parbreak`/`linebreak`, has no bindable global name in Typst — MEASURED
//     "unknown variable: space" — so its element function is instead
//     captured once, below, off a throwaway one-space content value.
//   - anything else unrecognised flattens to "" rather than erroring — a
//     title's content shape is not this function's place to validate; an
//     empty-after-flattening result is caught by the CALLER's own non-empty
//     check instead (`_normalize-entry`, immediately below).
//
// The recursive helper is a nested `#let` (Typst allows recursion in a `#let`
// binding, top-level or nested) so only the trimmed, flattening entry point
// is exported from this scope.
#let _space-func = [ ].func()
#let _plain-text(c) = {
  let go(c) = if c == none {
    ""
  } else if type(c) == str {
    c
  } else if c.has("text") {
    c.text
  } else if c.has("children") {
    c.children.map(go).join("")
  } else if c.has("body") {
    go(c.body)
  } else if c.func() in (_space-func, parbreak, linebreak) {
    " "
  } else {
    ""
  }
  go(c).trim()
}

// One source-supplied entry, normalised — or `none` when the entry must be
// DROPPED (see the skip rule below). `cfg` is the resolved feed config, for
// `base-url`/`author` fallbacks.
#let _normalize-entry(e, cfg) = {
  assert(
    type(e) == dictionary,
    message: "@rheo/rssfeed: a source returned a non-dictionary entry — got "
      + repr(type(e)),
  )
  // A source's `title` may be a plain string OR content: Typst's own
  // `document.title` is ALWAYS content even when authored as a plain string
  // (MEASURED — see `_plain-text` above), and `spine()`'s beacon-sourced
  // title (below) is content too. Flattened through `_plain-text` before the
  // non-empty check so either shape is accepted from ANY source, not just
  // rssfeed's own built-in ones.
  let raw-title = e.at("title", default: none)
  assert(
    type(raw-title) == str or type(raw-title) == content,
    message: "@rheo/rssfeed: an entry's `title` must be a non-empty string "
      + "or content — got " + repr(type(raw-title)),
  )
  let title = _plain-text(raw-title)
  assert(
    title.len() > 0,
    message: "@rheo/rssfeed: an entry is missing a non-empty `title`.",
  )

  let published = e.at("published", default: none)
  let updated = e.at("updated", default: none)

  // THE SKIP RULE. Atom requires <updated> per entry (RFC 4287 §4.2.15).
  // rheo's old Rust generator fell back to the compiled output file's mtime
  // when an entry carried no date of its own — impossible here, since
  // nothing in Typst can stat a file. So an entry with NEITHER `updated` NOR
  // `published` is DROPPED outright rather than dated some other way. This
  // is a deliberate, PERMANENT difference from the retired Rust feed, not a
  // gap to close later: there is no substitute signal to fall back to from
  // pure Typst, and inventing one (build time, `datetime.today()`, ...)
  // would make every entry's date equally wrong instead of just missing.
  if published == none and updated == none {
    return none
  }
  // An entry with only `published` gets `updated` filled from it — Atom
  // still gets the field it requires, and "last updated" degrading to "first
  // published" is the only sane default when nothing else was ever said.
  if updated == none {
    updated = published
  }

  let url = e.at("url", default: none)
  if url == none {
    let page = e.at("page", default: none)
    assert(
      page != none,
      message: "@rheo/rssfeed: entry '" + title + "' has neither `url` nor "
        + "`page` — cannot build a URL.",
    )
    url = cfg.base-url + "/" + _clean-page(page)
  }

  (
    id: e.at("id", default: url),
    title: title,
    url: url,
    page: e.at("page", default: none),
    select: e.at("select", default: none),
    published: published,
    updated: updated,
    summary: e.at("summary", default: none),
    categories: e.at("categories", default: ()),
    author: e.at("author", default: cfg.author),
  )
}

// Sort key: `published`, falling back to `updated`. By the time an entry
// reaches this function it has already survived the skip rule above, so at
// least one of the two is always a `datetime` — never both `none`. MEASURED
// (typst 0.15): `datetime` supports `<`/`<=` directly, so no conversion to a
// comparable tuple is needed.
#let _sort-key(e) = if e.published != none { e.published } else { e.updated }

// Run every source in `cfg.sources` against `cfg`, normalise the combined
// output, and return the finished entry list: newest-first, deduped by
// `id`, and cut to `cfg.limit` when one is set.
//
// Order of operations matters and is fixed: normalise (and drop undated)
// THEN sort THEN dedupe THEN limit. Deduping after sorting is what makes
// "keep the first occurrence" mean "keep the newest one" when the same `id`
// is produced by two sources (or twice by one) with different dates.
#let resolve-entries(cfg) = {
  let raw = ()
  for src in cfg.sources {
    let out = src(cfg)
    assert(
      type(out) == array,
      message: "@rheo/rssfeed: a source must return an array of entries — "
        + "got " + repr(type(out)),
    )
    raw += out
  }

  let normalized = raw.map(e => _normalize-entry(e, cfg)).filter(e => e != none)

  // `.sorted` is ascending; `.rev()` turns it into newest-first. Typst has no
  // descending-sort argument, and negating a `datetime` is not a thing.
  let ordered = normalized.sorted(key: e => _sort-key(e)).rev()

  let seen-ids = ()
  let deduped = ()
  for e in ordered {
    if e.id not in seen-ids {
      seen-ids += (e.id,)
      deduped += (e,)
    }
  }

  if cfg.limit != none {
    deduped = deduped.slice(0, calc.min(cfg.limit, deduped.len()))
  }

  deduped
}

// ---- spine — built-in source: one entry per spine vertebra ----------------
//
// Reproduces what rheo's retired Rust feed generator did by default: every
// vertebra in the spine is a candidate entry. This is the parity baseline
// other sources (`items`, below) sit alongside, not a replacement for them.
//
// PATTERN B (feature-detect, no assert, no panic without rheo — this
// package's own CLAUDE.md; existing example `blogfeed/0.1.1/src/lib.typ`):
// with no rheo present, `sys.inputs` carries no `rheo-context` at all, so
// this falls back to an empty spine and `spine()(cfg)` returns `()` rather
// than erroring — see `test/units.typ`. Do NOT add a package-level `#let
// rheo-context = ...` fallback binding: this package's CLAUDE.md records,
// with measurements, that any such binding clobbers rheo's real injection.
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: (spine-flat: ()))

// The value of the `#metadata((handle: .., title: .., date: .., ...))
// <rheo-meta:<handle>>` beacon rheo emits per vertebra (rheo's
// `feat/transclusion`, `crates/core/src/util/typst_source.rs`), or `(:)` when
// the vertebra emitted none (no rheo, or a vertebra rheo did not
// instrument). Queries the label directly rather than going through rheo's
// `rheo-metadata-all()` bundle-root helper: a Typst function captures its
// DEFINITION scope, and that helper's binding exists only in rheo's
// synthesized bundle root, so package code cannot see it — the label,
// unlike the helper, is reachable from any scope with context, since rheo
// compiles the whole bundle in one introspection pass.
//
// REQUIRES CONTEXT: `query` only works inside a `context` block. See
// `spine`'s own doc comment below for where that block lives in practice.
#let _meta(handle) = {
  let found = query(label("rheo-meta:" + handle))
  if found.len() == 0 { (:) } else { found.first().value }
}

// A beacon's `date` field as a `datetime`, or `none` for anything else.
// `#set document(date:)` defaults to `auto` when left unset, and a vertebra
// may also set it to `none` explicitly; either way there is no date to
// carry, so both collapse to the same `none` here.
#let _meta-date(meta) = {
  let d = meta.at("date", default: none)
  if type(d) == datetime { d } else { none }
}

// Built-in source: one entry per spine vertebra. `sys.inputs`'s
// `spine-flat` is a flat pre-order array of `(handle, path, title)` dicts
// (`title` a plain STRING). REQUIRES CONTEXT — this source's `cfg => (..)`
// function calls `query` (via `_meta`, above) whenever the spine is
// non-empty, so call it (typically via `resolve-entries`) from inside a
// `#context { .. }` block. The normal case is `.marrow.typ`, which already
// wraps its own read of `configure`'s state the same way.
//
// - `title` PREFERS the vertebra's metadata beacon over the spine entry's
//   own filename-derived `v.title`. `v.title` is computed from the file
//   PATH before compile (`crates/core/src/reticulate/spine.rs`'s
//   `spine_flat`); rheo core no longer pre-scans `#set document(title: ..)`
//   to override it there, so the AUTHORED title is reachable only
//   post-compile, through the beacon's own `title` field — which rheo's
//   `#document(.., title: [<v.title>])` wrapper
//   (`crates/core/src/util/typst_source.rs`'s `TypstStmt::Document`) seeds
//   with `v.title` itself, and a vertebra's own `#set document(title: ..)`,
//   if any, then overrides within that same document scope. Either way the
//   beacon's `title` is CONTENT (Typst's resolved `document.title` is
//   ALWAYS content, even for a title authored as a plain string —
//   MEASURED, see `_plain-text` above), hence flattening it through
//   `_plain-text` before comparing against "" below. Falling back to
//   `v.title` itself covers the one case with no beacon value to read at
//   all — `_meta` found no beacon (a vertebra rheo did not instrument) —
//   and is still the right value there, being the same filename-derived
//   string the wrapper itself would have seeded.
// - `page` is built from its `handle`, NOT its `path` — `path` is the
//   vertebra's SOURCE `.typ` path (`crates/core/src/reticulate/spine.rs`'s
//   `rel_path`, e.g. "content/posts/one.typ"), never the compiled output
//   `.marrow.typ`/`emit`'s `<rheo-content>` transclusion resolves against.
//   MEASURED (this package's own end-to-end verify): minting `page: v.path`
//   produced "`<rheo-content>` references unknown page 'content/index.typ'"
//   — the compiled bundle has no such output. The handle is the correct
//   source: a handle's `:` segments become `/` and the build's own `ext`
//   (from `sys.inputs.rheo-context.ext`, same field `typ/rheo.typ`'s
//   cross-vertebra link rule reads) is appended — exactly the mapping that
//   rule itself applies to a handle to build a page's href, and the same
//   convention rookery's `_note-page` relies on for its own
//   minted-path/handle pairing. No `url` — `_normalize-entry` builds one
//   from `base-url` + `page`.
// - `select`, when given, is passed through to every entry unchanged.
// - `date`, read from the vertebra's metadata beacon (i.e. its own `#set
//   document(date: ...)`), fills BOTH `published` and `updated` — matching
//   what the retired Rust generator effectively did (it carried only one
//   date per page). `keywords` (an array, possibly empty) becomes
//   `categories`.
// - An UNDATED vertebra therefore yields an entry with neither `published`
//   nor `updated`, which `resolve-entries`'s skip rule then DROPS. This is
//   INTENTIONAL, not a gap: it is how a cover page or index falls out of
//   the feed, replacing the retired `rheo-feed-exclude` variable users knew
//   by name — there is no separate exclude mechanism here.
// - `filter`, when given, is a predicate over the SPINE ENTRY (e.g. `e =>
//   e.handle.starts-with("posts:")`), run BEFORE the metadata lookup;
//   `none` (the default) includes every vertebra, matching the old default.
#let spine(filter: none, select: none) = cfg => {
  let ctx = _rheo-ctx()
  // Falls back to "html" only in the no-rheo case, where `entries` below is
  // always `()` anyway and `ext` is therefore never actually used.
  let ext = ctx.at("ext", default: "html")
  let entries = ctx.at("spine-flat", default: ())
  if filter != none {
    entries = entries.filter(filter)
  }
  entries.map(v => {
    let meta = _meta(v.handle)
    let date = _meta-date(meta)
    // The beacon's `title` wins when it flattens to something non-empty —
    // see this function's own doc comment above for why it, not `v.title`,
    // carries the AUTHORED title. `v.title` (the spine's filename-derived
    // fallback) is the ONLY thing left to fall back to when `meta` is `(:)`
    // — no beacon found at all for this handle.
    let beacon-title = _plain-text(meta.at("title", default: none))
    let title = if beacon-title.len() > 0 { beacon-title } else { v.title }
    (
      title: title,
      page: v.handle.replace(":", "/") + "." + ext,
      select: select,
      published: date,
      updated: date,
      categories: meta.at("keywords", default: ()),
    )
  })
}

// ---- items — built-in source: entries from `<rssfeed:item>` beacons -------
//
// Lets ANY code, anywhere in the bundle, contribute a feed entry for
// something that is not a spine vertebra (an idea's page, a generated
// listing, whatever) with NO import coupling in either direction: this
// package never imports the contributor's package, and the contributor
// need not import `@rheo/rssfeed` either — though `item(...)` below makes
// that easy when it wants to.
//
// THE PROTOCOL: emit `#metadata((..)) <rssfeed:item>` (or a matching custom
// `label-name`) anywhere in the bundle, with the metadata value shaped as an
// entry per this file's entry model (see the top of this file), e.g.:
//
//   #metadata((
//     id: "idea:etal", title: "Et al.", page: "notes/etal.html",
//     published: datetime(..), updated: datetime(..), categories: ("note",),
//   )) <rssfeed:item>
//
// rheo compiles the whole bundle in ONE `typst::compile` pass with one
// introspection loop, so `query()` sees beacons from every vertebra, not
// just whichever one is calling it — the same fact `spine`'s `_meta`,
// above, relies on, and the same fact rookery's own cross-vertebra beacons
// rely on. `:` is legal in a Typst label (rookery relies on this too).
//
// REQUIRES CONTEXT (calls `query`) — call (typically via `resolve-entries`)
// from inside a `#context { .. }` block; the normal case is bundle root (a
// project's own `.marrow.typ`), the same place it already wraps its read of
// `configure`'s state.
//
// Each beacon's value is VALIDATED here, not left for `_normalize-entry` to
// discover later: a value that is not a dictionary, or a dictionary with no
// non-empty `title`, is a hard failure naming `@rheo/rssfeed`, the label,
// and what was found — a silently dropped malformed item is worse than a
// build failure.
#let items(filter: none, label-name: "rssfeed:item") = cfg => {
  let found = query(label(label-name))
  let out = ()
  for f in found {
    let v = f.value
    assert(
      type(v) == dictionary,
      message: "@rheo/rssfeed: a <" + label-name + "> beacon's value must "
        + "be a dictionary shaped as an rssfeed entry — got "
        + repr(type(v)),
    )
    assert(
      type(v.at("title", default: none)) == str and v.at("title").len() > 0,
      message: "@rheo/rssfeed: a <" + label-name + "> beacon is missing a "
        + "non-empty `title` — got " + repr(v),
    )
    out += (v,)
  }
  // `filter`, when given, is a predicate over the ITEM VALUE (the parsed
  // dict), e.g. `items(filter: it => "note" in it.at("categories", default:
  // ()))`. `none` (the default) includes every beacon found.
  if filter != none {
    out = out.filter(filter)
  }
  out
}

// Author-facing half of the `<rssfeed:item>` protocol: emits a well-formed
// beacon so an author (or another package) can syndicate an arbitrary page
// without knowing the label name `items()` reads by default. Arguments
// mirror the entry model (see the top of this file) — everything but
// `title` is optional and, when omitted, simply absent from the emitted
// beacon's value so `_normalize-entry`'s own fallbacks (`author` from the
// feed, `id` from the built `url`, ...) still apply downstream, exactly as
// they would for a sparse dict handed straight to a plain source function.
//
// Pass a matching non-default `label-name` to both `item(...)` and the
// `items(label-name: ...)` reading it when using a custom label.
#let item(
  title: none,
  url: none,
  page: none,
  select: none,
  published: none,
  updated: none,
  summary: none,
  categories: (),
  author: none,
  id: none,
  label-name: "rssfeed:item",
) = {
  assert(
    type(title) == str and title.len() > 0,
    message: "@rheo/rssfeed: item(...) needs a non-empty `title`.",
  )
  let value = (title: title, categories: categories)
  if url != none { value.insert("url", url) }
  if page != none { value.insert("page", page) }
  if select != none { value.insert("select", select) }
  if published != none { value.insert("published", published) }
  if updated != none { value.insert("updated", updated) }
  if summary != none { value.insert("summary", summary) }
  if author != none { value.insert("author", author) }
  if id != none { value.insert("id", id) }
  [#metadata(value)#label(label-name)]
}

// ---- XML string escaping ---------------------------------------------------
//
// `&` MUST be escaped FIRST: escaping `<`/`>` before `&` would re-escape the
// `&amp;`/`&lt;`/`&gt;` those produce, double-escaping the source. Attribute
// values (always double-quoted in this file) additionally need `"` escaped;
// text content does not.
#let _esc-text(s) = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
#let _esc-attr(s) = _esc-text(s).replace("\"", "&quot;")

// ---- timestamps — RFC 3339 with an explicit "Z" offset --------------------
//
// Atom requires an offset on every timestamp (RFC 4287 §3.3); nothing in
// this package's data model carries a timezone, so every `datetime` here is
// treated as UTC and rendered with a literal "Z".
//
// MEASURED (typst 0.15.1): a `datetime` built with only `year`/`month`/`day`
// — exactly what `spine()`'s beacon dates and a bare authored date are — has
// `.hour()` == `none`, and calling `.display(...)` with an `[hour]` (or
// `[minute]`/`[second]`) field on it hard-errors "failed to format datetime
// (insufficient information)" rather than defaulting to midnight. So a
// date-only `datetime` is detected via `.hour()` and "T00:00:00Z" is
// spliced on by hand instead of asking `.display` to produce it.
#let _rfc3339(d) = {
  let date-part = d.display("[year]-[month]-[day]")
  if d.hour() == none {
    date-part + "T00:00:00Z"
  } else {
    date-part + "T" + d.display("[hour]:[minute]:[second]") + "Z"
  }
}

// ---- atom — serialize a resolved config + entries to an Atom 1.0 string ---
//
// The element set is a PARITY TARGET against the retired Rust generator
// (`atom_syndication`-backed, `rheo/crates/html/src/feed.rs`:
// `AtomFeed::serialize`/`AtomEntry::to_atom`) — not byte-identical output;
// whitespace is not chased.

// Largest `updated` across `entries` — becomes the feed-level `<updated>`
// (RFC 4287 §4.2.15: "most recent instant in which the feed was modified").
// Never called with an empty array — `atom(...)` below returns `none`
// before reaching this when `entries` is empty.
#let _max-updated(entries) = {
  let m = entries.first().updated
  for e in entries.slice(1) {
    if e.updated > m { m = e.updated }
  }
  m
}

// This entry's `<content>`/`<summary>`, or `""` when neither applies (feed
// `content: none`, or an entry with no `page`, and no `summary` either).
//
// `page`'s value is the caller's `page` AS-IS (plugin-output-relative, e.g.
// "notes/etal.html") — `atom(...)` never resolves or rewrites it. `select`
// is OMITTED from the `<rheo-content>` placeholder entirely when the entry
// has none: ABSENT means rheo's own default cascade, not "select nothing",
// so it must never be emitted as `select=""`.
#let _content-elem(cfg, e) = {
  if cfg.content == none or e.page == none {
    if e.summary != none {
      "<summary type=\"text\">" + _esc-text(e.summary) + "</summary>"
    } else {
      ""
    }
  } else {
    let select-attr = if e.select != none {
      " select=\"" + _esc-attr(e.select) + "\""
    } else { "" }
    let page-attr = "page=\"" + _esc-attr(e.page) + "\""
    if cfg.content == "html" {
      "<content type=\"html\"><rheo-content " + page-attr + select-attr + " as=\"escaped\"/></content>"
    } else {
      // "xhtml": the placeholder's own `as="raw"` is unescaped because the
      // wrapping `<div xmlns="...">` is itself the XHTML content model Atom
      // requires for `type="xhtml"` (RFC 4287 §4.1.3.3) — escaping again
      // here would double-escape what rheo splices in.
      "<content type=\"xhtml\"><div xmlns=\"http://www.w3.org/1999/xhtml\">" + "<rheo-content " + page-attr + select-attr + " as=\"raw\"/></div></content>"
    }
  }
}

// One `<entry>`. Order: id, title, published (when present), updated,
// author (only when it differs from the feed's own — otherwise the feed's
// `<author>` already covers it per RFC 4287 §4.1.2's inheritance), category
// per `e.categories`, the alternate link, then content/summary.
#let _entry-elem(cfg, e) = {
  let parts = (
    "<id>" + _esc-text(e.id) + "</id>",
    "<title>" + _esc-text(e.title) + "</title>",
  )
  if e.published != none {
    // atom:published (RFC 4287 §4.2.9 — creation instant), DISTINCT from
    // atom:updated (§4.2.15 — last significant modification). A real defect
    // in the retired Rust generator: it never emitted `atom:published` at
    // all, mapping the authored date onto `updated` only. Readers
    // (NetNewsWire, Reeder, Feedbin, Miniflux) prefer `published` for
    // display/sort when present, so this is a genuine fix, not parity.
    //
    // `spine()` fills BOTH `published` and `updated` from the same beacon
    // date (see its own doc comment) — so a spine entry legitimately
    // carries the SAME instant in both elements below. That is correct and
    // expected, not a redundancy to suppress.
    parts += ("<published>" + _rfc3339(e.published) + "</published>",)
  }
  parts += ("<updated>" + _rfc3339(e.updated) + "</updated>",)
  if e.author != cfg.author {
    parts += ("<author><name>" + _esc-text(e.author) + "</name></author>",)
  }
  for cat in e.categories {
    parts += ("<category term=\"" + _esc-attr(cat) + "\"/>",)
  }
  parts += ("<link rel=\"alternate\" href=\"" + _esc-attr(e.url) + "\"/>",)
  let content = _content-elem(cfg, e)
  if content != "" {
    parts += (content,)
  }
  "<entry>" + parts.join("") + "</entry>"
}

// Serialize a resolved feed config + its entries into an Atom 1.0 (RFC 4287)
// XML string, ready to be minted with `#asset(...)` by a later bead — or
// `none` when there are no entries, mirroring the retired Rust generator's
// early return (`generate_feed`'s "Skip feed generation if no entries"):
// the caller (that later marrow bead) is expected to check for `none` and
// skip minting the asset entirely rather than mint an empty/invalid feed.
//
// `entries` defaults to `none`, meaning "resolve them here" via
// `resolve-entries(cfg)` — the convenience path for a caller with no need
// to inspect or adjust the list first. REQUIRES CONTEXT in that case ONLY
// when `cfg.sources` includes something that itself requires context
// (`spine()`, `items()` — see their own doc comments); call the no-`entries`
// form from inside `#context { .. }` in that case, same as `resolve-entries`
// itself would need.
//
// Passing `entries` explicitly (typically a caller's own prior
// `resolve-entries(cfg)` call, possibly inspected/filtered/adjusted first)
// never requires context here regardless of how that list was produced.
//
// Feed `<id>` and the `rel="self"` link both use `cfg.base-url + "/" +
// cfg.path` — the generalised form of the retired generator's hardcoded
// `base-url + "/feed.xml"`, now following whatever `path` the config set.
#let atom(cfg, entries: none) = {
  let entries = if entries == none { resolve-entries(cfg) } else { entries }
  if entries.len() == 0 {
    return none
  }

  let feed-url = cfg.base-url + "/" + cfg.path
  let head = (
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>",
    "<feed xmlns=\"http://www.w3.org/2005/Atom\">",
    "<id>" + _esc-text(feed-url) + "</id>",
    "<title>" + _esc-text(cfg.title) + "</title>",
  )
  let subtitle = if cfg.subtitle != none {
    ("<subtitle>" + _esc-text(cfg.subtitle) + "</subtitle>",)
  } else { () }
  let rest = (
    "<updated>" + _rfc3339(_max-updated(entries)) + "</updated>",
    "<author><name>" + _esc-text(cfg.author) + "</name></author>",
    "<link rel=\"self\" href=\"" + _esc-attr(feed-url) + "\"/>",
  )
  let entry-strs = entries.map(e => _entry-elem(cfg, e))

  (head + subtitle + rest + entry-strs + ("</feed>",)).join("")
}

// ---- CONSUMED BY .marrow.typ — a real API, with no other marker ------------
//
// `.marrow.typ` (this package's own, at the package root) imports `_feeds`
// and `_mint-plan` from here, both underscore-private. They are as
// load-bearing as `atom`/`resolve-entries` above and nothing else in this
// file says so. RENAMING OR RE-SIGNING EITHER MEANS CHANGING `.marrow.typ`
// IN THE SAME COMMIT — the same failure mode rookery's own matching banner
// records: a package's `.marrow.typ` that fails to read installs and
// compiles anyway, just silently minting nothing.
//
// ---- configure — the state-backed entry point (path (a) above) ------------
//
// `.marrow.typ` reads every feed registered here via `.final()`, from the
// bundle root — the mirror of rookery's own `_registry` (`state("rheo-ideas",
// (:))`) feeding ITS `.marrow.typ` (`rg -n '_registry.final\(\)'
// rookery/0.3.0/.marrow.typ`). State is the only channel available: a
// vertebra cannot import a project's `.marrow.typ`, and `.marrow.typ`'s text
// is spliced into rheo's synthesized bundle root, so it cannot import back
// into any one vertebra either.
//
// Holds an ARRAY of resolved `feed(...)` configs, appended to rather than
// replaced, because `configure` may in principle be called more than once
// even though the common case is exactly one call from exactly one
// vertebra. Each config carries its `sources` array of live FUNCTION
// values — safe per the MEASURED fact in the "source" section above: a
// Typst `state` holds a function through `.final()` and the result is still
// callable.
#let _feeds = state("rheo-rssfeed-feeds", ())

// Register one or more feeds for `.marrow.typ` to mint. Call ONCE from any
// vertebra:
//
//   #import "@rheo/rssfeed:0.1.0": feed, configure
//   #configure(feeds: (
//     feed(title: "My Site", base-url: "https://example.com", sources: (...)),
//   ))
//
// Projects using path (b) instead — calling `resolve-entries` (and, later,
// the XML emitter) directly from their own `.marrow.typ` — need this
// function not at all; the two entry points are independent.
#let configure(feeds: ()) = {
  assert(
    type(feeds) == array,
    message: "@rheo/rssfeed: configure's `feeds` must be an array of feed "
      + "configs, e.g. `configure(feeds: (feed(...), feed(...)))`.",
  )
  _feeds.update(old => old + feeds)
}

// ---- _mint-plan — shared minting plan for BOTH marrow entry points --------
//
// Builds the list of `(path: str, data: str)` files to write for a set of
// resolved `feed(...)` configs: each feed's Atom XML (skipping a feed whose
// `atom(...)` came back `none` — zero entries), plus one trailing
// `.rheo/head.html` control asset carrying an autodiscovery `<link>` per
// MINTED feed (a zero-entry feed contributes no link either).
//
// Returns the plan rather than minting with `#asset(...)` itself: `asset` is
// only a bound name at bundle root (`.marrow.typ`'s own spliced text, or a
// project's own bundle-root marrow calling `emit(...)` below) — this file is
// ordinary package code, imported and compiled like any other module, so it
// cannot assume `asset` is reachable from here. Returning data instead keeps
// this helper a plain function of its input, testable from `test/units.typ`
// with no bundle at all, and gives BOTH `.marrow.typ` and `emit` exactly one
// `for m in plan { asset(m.path, m.data) }` loop to share rather than two
// copies of the same minting logic.
//
// Collisions are checked over the FULL `feeds` list, not just the feeds that
// end up minted: two feeds configured at the same `path` are a broken config
// regardless of which of them currently has entries, so this fails loud
// before ever calling `atom(...)`.
//
// REQUIRES CONTEXT whenever any feed's `sources` needs it (`spine()`,
// `items()`) — call from inside `#context { .. }`, exactly as `atom(...)`'s
// own no-`entries` form does.
#let _mint-plan(feeds) = {
  for i in range(feeds.len()) {
    for j in range(i + 1, feeds.len()) {
      assert(
        feeds.at(i).path != feeds.at(j).path,
        message: "@rheo/rssfeed: two feeds both write to '" + feeds.at(i).path
          + "' (\"" + feeds.at(i).title + "\" and \"" + feeds.at(j).title
          + "\") — give each feed its own `path`.",
      )
    }
  }

  let minted = () // (path: str, data: str)
  let links = () // (base-url: str, path: str, title: str) — minted feeds only
  for cfg in feeds {
    let xml = atom(cfg)
    if xml == none { continue }
    minted += ((path: cfg.path, data: xml),)
    links += ((base-url: cfg.base-url, path: cfg.path, title: cfg.title),)
  }

  if links.len() > 0 {
    let tags = links
      .map(l => "<link rel=\"alternate\" type=\"application/atom+xml\" href=\""
        + _esc-attr(l.base-url + "/" + l.path) + "\" title=\"" + _esc-attr(l.title) + "\">")
      .join("")
    minted += ((path: ".rheo/head.html", data: tags),)
  }

  minted
}

// ---- emit — direct-call entry point (path (b) above) -----------------------
//
// For a project that would rather write its OWN `.marrow.typ` than call
// `configure` from a vertebra: mints every feed in `feeds` (an array of
// `feed(...)` configs) plus the shared `.rheo/head.html` autodiscovery
// fragment, via `#asset(...)`. Shares `_mint-plan` with this package's own
// `.marrow.typ` — see that function's doc comment for why it returns a plan
// rather than minting directly. Path (a) (`configure`) and this path are
// independent; a project uses exactly one, never both.
//
// REQUIRES CONTEXT whenever any feed's `sources` needs it (`spine()`,
// `items()`) — call from inside `#context { .. }` in your own `.marrow.typ`,
// exactly as this package's own `.marrow.typ` does for `configure`'s feeds:
//
//   #import "@rheo/rssfeed:0.1.0": feed, emit
//   #context { emit(feeds: (feed(...), feed(...))) }
#let emit(feeds: ()) = {
  assert(
    type(feeds) == array,
    message: "@rheo/rssfeed: emit's `feeds` must be an array of feed "
      + "configs, e.g. `emit(feeds: (feed(...), feed(...)))`.",
  )
  for m in _mint-plan(feeds) {
    asset(m.path, m.data)
  }
}
