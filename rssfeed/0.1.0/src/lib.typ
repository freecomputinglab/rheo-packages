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
//       (and, in a later bead, the XML emitter) directly — it needs the
//       `state` in (a) not at all.
//
// This bead lands the DATA MODEL only: `feed(...)` builds and validates a
// feed config, `resolve-entries` runs a config's sources and normalises their
// output into the finished, ordered entry list, and `configure`/the `state`
// wire path (a) above together. No concrete source (`spine`, `items`, ...)
// and no XML serialization live here — those are separate beads that build on
// this one.
//
// PURE DATA MODELLING: nothing here reads `sys.inputs` or any other
// rheo-injected context. Every function in this file works identically under
// plain `typst compile` with no rheo present at all — see `test/units.typ`.

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
// source (`spine`, `items`, ... — separate beads) is constructed with
// `.with(...)` so it is an ordinary function at the call site:
//
//   #rssfeed.feed(sources: (rssfeed.spine.with(root: "posts"),), ...)
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

  (
    path: path,
    title: title,
    // Trimmed here, ONCE, so every downstream consumer (`_normalize-entry`,
    // the later XML emitter) can join with a bare "/" and never worry about
    // a double slash from an author-supplied trailing one.
    base-url: base-url.trim("/", at: end),
    sources: sources,
    author: author,
    subtitle: subtitle,
    content: content,
    limit: limit,
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

// One source-supplied entry, normalised — or `none` when the entry must be
// DROPPED (see the skip rule below). `cfg` is the resolved feed config, for
// `base-url`/`author` fallbacks.
#let _normalize-entry(e, cfg) = {
  assert(
    type(e) == dictionary,
    message: "@rheo/rssfeed: a source returned a non-dictionary entry — got "
      + repr(type(e)),
  )
  let title = e.at("title", default: none)
  assert(
    type(title) == str and title.len() > 0,
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
// - `title` is the spine entry's own string `title`; `page` is its `path`.
//   No `url` — `_normalize-entry` builds one from `base-url` + `page`.
// - `select`, when given, is passed through to every entry unchanged.
// - `date`, read from the vertebra's metadata beacon (i.e. its own `#set
//   document(date: ...)`), fills BOTH `published` and `updated` — matching
//   what the retired Rust generator effectively did (it carried only one
//   date per page). `keywords` (an array, possibly empty) becomes
//   `categories`. The beacon's own `title` is CONTENT, not a string, so it
//   is deliberately ignored in favour of the spine entry's string `title`.
// - An UNDATED vertebra therefore yields an entry with neither `published`
//   nor `updated`, which `resolve-entries`'s skip rule then DROPS. This is
//   INTENTIONAL, not a gap: it is how a cover page or index falls out of
//   the feed, replacing the retired `rheo-feed-exclude` variable users knew
//   by name — there is no separate exclude mechanism here.
// - `filter`, when given, is a predicate over the SPINE ENTRY (e.g. `e =>
//   e.handle.starts-with("posts:")`), run BEFORE the metadata lookup;
//   `none` (the default) includes every vertebra, matching the old default.
#let spine(filter: none, select: none) = cfg => {
  let entries = _rheo-ctx().at("spine-flat", default: ())
  if filter != none {
    entries = entries.filter(filter)
  }
  entries.map(v => {
    let meta = _meta(v.handle)
    let date = _meta-date(meta)
    (
      title: v.title,
      page: v.path,
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

// ---- configure — the state-backed entry point (path (a) above) ------------
//
// `.marrow.typ` (a later bead, at this package's own root) reads every feed
// registered here via `.final()`, from the bundle root — the mirror of
// rookery's own `_registry` (`state("rheo-ideas", (:))`) feeding ITS
// `.marrow.typ` (`rg -n '_registry.final\(\)' rookery/0.3.0/.marrow.typ`).
// State is the only channel available: a vertebra cannot import a project's
// `.marrow.typ`, and `.marrow.typ`'s text is spliced into rheo's synthesized
// bundle root, so it cannot import back into any one vertebra either.
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
