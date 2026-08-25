// @rheo/feeds
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

// ---- modal — re-exported, the one part of this package that emits markup ---
//
// Kept in its own file because it shares nothing with feed generation: no
// validator, no entry model, no serializer. Re-exported here so a project
// imports it from the package entrypoint like everything else. It emits
// NOTHING unless called — see the banner in `modal.typ` for why that matters,
// and for why this package still ships no `[tool.rheo.html]` bundle.
#import "modal.typ": atom-icon, feeds-modal, mail-icon

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
//
// ADDING A FIELD means touching three places, not one: this table,
// `_normalize-entry`'s returned dictionary, and `item(...)`'s pair list (which
// decides what a `<feeds:item>` beacon carries). The readme's entry table is
// a fourth, user-facing copy.

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
// These exist so that EVERY field error names `@rheo/feeds` and the offending
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
    message: "@rheo/feeds: `" + field + "` must be a non-empty string — got "
      + repr(v),
  )
  v
}

#let _expect-str-or-none(v, field) = {
  assert(
    v == none or type(v) == str,
    message: "@rheo/feeds: `" + field + "` must be a string or none — got "
      + repr(v),
  )
  v
}

// "Absolute" means "starts with a scheme" — RFC 3986's scheme grammar: a
// letter, then letters/digits/`+`/`.`/`-`. Anchored at the START of the string,
// not merely present, so "see http://x" still fails. ONE binding, used by both
// `feed(...)`'s `base-url` assert and `_expect-abs-url` below, so the two
// cannot drift into two spellings of the same rule.
#let _abs-url-re = regex("^[a-zA-Z][a-zA-Z0-9+.\-]*://")

#let _expect-abs-url(v, field) = {
  let s = _expect-str(v, field)
  assert(
    s.match(_abs-url-re) != none,
    message: "@rheo/feeds: `" + field + "` must be an absolute URL (start "
      + "with a scheme, e.g. \"https://\") — got " + repr(s)
      + ". A page-relative path belongs in `page`, which is joined onto the "
      + "feed's `base-url` for you.",
  )
  s
}

// The message names the FIX, not just the fault. Typst loops a string
// character by character, so `categories: "note"` is not a type error at all:
// it silently emits one `<category>` per letter (MEASURED — four of them,
// `term="n"`, `term="o"`, `term="t"`, `term="e"`). Writing the bare string
// instead of a one-element array looks correct to the author, so the error has
// to say what to write instead.
#let _expect-strs(v, field) = {
  assert(
    type(v) == array,
    message: "@rheo/feeds: `" + field + "` must be an array of strings — got "
      + repr(v) + ". A single value must still be a one-element array, e.g. "
      + "`categories: (\"note\",)`.",
  )
  for s in v {
    assert(
      type(s) == str,
      message: "@rheo/feeds: every value in `" + field + "` must be a string "
        + "— got " + repr(s),
    )
  }
  v
}

// The migration hint in this message is load-bearing. This package's own
// readme maps the retired `#let rheo-feed-updated = "..."` variable — a STRING
// — onto these fields, so a string arriving here is the single likeliest
// migration slip. Unchecked, it survived the skip rule and died much later
// inside `_rfc3339` as `type string has no method 'display'`, naming neither
// this package nor the field.
#let _expect-datetime-or-none(v, field) = {
  assert(
    v == none or type(v) == datetime,
    message: "@rheo/feeds: `" + field + "` must be a datetime or none — got "
      + repr(v) + ". Write `datetime(year: .., month: .., day: ..)`, not a "
      + "string: the retired `rheo-feed-updated` variable took a string, this "
      + "field does not.",
  )
  v
}

#let _expect-positive-int-or-none(v, field) = {
  assert(
    v == none or (type(v) == int and v > 0),
    message: "@rheo/feeds: `" + field + "` must be a positive integer or "
      + "none — got " + repr(v),
  )
  v
}

// Strip a single leading "./" or "/" from an output-relative path, so
// `cfg.base-url + "/" + <path>` never doubles the slash: `base-url` loses its
// own trailing one in `feed(...)` below, and a caller writing
// `page: "/posts/x.html"` or `page: "./posts/x.html"` (both natural ways to
// spell a "plugin-output-relative path") must not be punished for it.
//
// Used for BOTH an entry's `page` and a feed's own `path` — the same hazard in
// two places. Keeps its name: `page` is still what it reads like at the call
// site that matters most, and `test/units.typ` imports it under this name.
//
// Defined ABOVE `feed(...)`, which calls it: MEASURED (typst 0.15.1) that a
// Typst closure captures its DEFINITION scope, so a `#let` appearing later in
// the module is `unknown variable` from inside a function body defined earlier.
#let _clean-page(page) = {
  if page.starts-with("./") {
    page.slice(2)
  } else if page.starts-with("/") {
    page.slice(1)
  } else {
    page
  }
}

// ---- feed — the top-level config -------------------------------------------
//
// Every panic below names `@rheo/feeds` and the offending field: a package
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
  format: "atom",
) = {
  assert(
    type(title) == str and title.len() > 0,
    message: "@rheo/feeds: feed's `title` must be a non-empty string.",
  )
  assert(
    type(base-url) == str and base-url.len() > 0,
    message: "@rheo/feeds: feed's `base-url` must be a non-empty string.",
  )
  // Absolute means "starts with a scheme" — see `_abs-url-re` above, which an
  // entry's own `url` is held to as well.
  assert(
    base-url.match(_abs-url-re) != none,
    message: "@rheo/feeds: feed's `base-url` must be absolute (start with "
      + "a scheme, e.g. \"https://\") — got " + repr(base-url),
  )
  assert(
    type(sources) == array and sources.len() > 0,
    message: "@rheo/feeds: feed needs at least one source in `sources`.",
  )
  for s in sources {
    assert(
      type(s) == function,
      message: "@rheo/feeds: every entry in `sources` must be a function "
        + "(cfg) -> (entry, ..) — got " + repr(type(s)),
    )
  }
  assert(
    content == "html" or content == "xhtml" or content == none,
    message: "@rheo/feeds: feed's `content` must be \"html\", \"xhtml\", "
      + "or none — got " + repr(content),
  )
  assert(
    format == "atom" or format == "rss" or format == "json",
    message: "@rheo/feeds: feed's `format` must be \"atom\", \"rss\" or "
      + "\"json\" — got " + repr(format),
  )
  // Two cross-field rules, both asserts rather than silent coercions: a
  // setting this package quietly ignored would be exactly the failure mode
  // its own dropped-summary bug was.
  assert(
    content != "xhtml" or format == "atom",
    message: "@rheo/feeds: `content: \"xhtml\"` is Atom-only (it is Atom's "
      + "own `type=\"xhtml\"` content model) — got format " + repr(format)
      + ". RSS carries HTML in `<description>`/`<content:encoded>`, and JSON "
      + "Feed carries none yet; use `content: \"html\"` or none.",
  )
  assert(
    format != "json" or content == none,
    message: "@rheo/feeds: `format: \"json\"` requires `content: none` — got "
      + repr(content) + ". JSON Feed content needs a JSON-safe "
      + "`<rheo-content>` encoding that rheo does not have yet, so entries "
      + "carry their `summary` only.",
  )

  // The four fields below are validated HERE, in the returned dict, rather than
  // as separate asserts above: each is checked exactly where it is stored, and
  // nothing else in this function needs their values. `title`, `base-url`,
  // `sources` and `content` keep their own asserts up top instead — each
  // carries field-specific wording (the scheme regex, the "at least one
  // source" count, the enumerated `content` values) that the generic helpers
  // would flatten away.
  (
    // Normalized through the same helper an entry's `page` uses, so a feed
    // written as `path: "/feed.xml"` cannot produce `base-url + "//" + path`
    // in its `<id>`, its `rel="self"` link and its autodiscovery `<link>` —
    // and so the collision check below, which compares paths as plain
    // strings, sees "feed.xml" and "./feed.xml" as the one output file they
    // really are.
    path: _clean-page(_expect-str(path, "path")),
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
    format: format,
  )
}

// ---- resolve-entries — run the sources, normalise, order, dedupe, limit ---

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
//   - `smartquote` — what Typst's smartquote show rule splits an apostrophe or
//     quote character typed inside markup into — carries ONLY a `double`
//     field, so it matches none of the three field branches above and used to
//     fall to the final `else` and contribute "". That DELETED the character
//     rather than mis-encoding it: MEASURED against real content, a title
//     authored as `[Mladen Dolar: What's in a Name?]` flattened to "Mladen
//     Dolar: Whats in a Name?". It is mapped to the ASCII `'`/`"` here rather
//     than the curly forms: the element records only whether the quote was
//     double, not which language's glyph the show rule chose, and neither
//     ASCII quote needs XML escaping in element text (`_esc-text` escapes only
//     `&`/`<`/`>`, which is correct) nor in an attribute (`_esc-attr` turns `"`
//     into `&quot;`).
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
  } else if c.func() == smartquote {
    if c.double { "\"" } else { "'" }
  } else if c.func() in (_space-func, parbreak, linebreak) {
    " "
  } else {
    ""
  }
  go(c).trim()
}

// ---- _expect-title — the ONE non-empty-title rule --------------------------
//
// Every place a title arrives from outside this package shares this checker, so
// the rule cannot differ by entry point. It used to: `_normalize-entry`
// accepted `str` OR `content` (the documented entry model), while `items()` and
// `item(...)` accepted `str` only — so a beacon carrying a CONTENT title, the
// exact shape `spine()` itself produces and what any package forwarding
// Typst's own `document.title` yields, was rejected outright, with a message
// claiming the title was "missing" while printing a dictionary that visibly
// had one.
//
// Returns the FLATTENED string, so no caller re-flattens. `what` is a
// caller-supplied phrase ("an entry", "a <feeds:item> beacon", "item(...)")
// spliced into both messages, so each site keeps its own wording.
#let _expect-title(v, what) = {
  assert(
    type(v) == str or type(v) == content,
    message: "@rheo/feeds: " + what + "'s `title` must be a non-empty string "
      + "or content — got " + repr(type(v)),
  )
  let t = _plain-text(v)
  assert(
    t.len() > 0,
    message: "@rheo/feeds: " + what + " is missing a non-empty `title` — got "
      + repr(v),
  )
  t
}

// One source-supplied entry, normalised — or `none` when the entry must be
// DROPPED (see the skip rule below). `cfg` is the resolved feed config, for
// `base-url`/`author` fallbacks.
#let _normalize-entry(e, cfg) = {
  assert(
    type(e) == dictionary,
    message: "@rheo/feeds: a source returned a non-dictionary entry — got "
      + repr(type(e)),
  )
  // A source's `title` may be a plain string OR content: Typst's own
  // `document.title` is ALWAYS content even when authored as a plain string
  // (MEASURED — see `_plain-text` above), and `spine()`'s beacon-sourced
  // title (below) is content too. `_expect-title` flattens either shape, and
  // is the same checker `items()`/`item(...)` use, so a title accepted at one
  // entry point is accepted at all of them.
  let title = _expect-title(e.at("title", default: none), "an entry")

  // Validated at the READ, before the skip rule below tests them against
  // `none`, so the skip rule can never be reached with a non-datetime value.
  let published = _expect-datetime-or-none(
    e.at("published", default: none),
    "published",
  )
  let updated = _expect-datetime-or-none(e.at("updated", default: none), "updated")

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

  // A source-supplied `url` must be ABSOLUTE — a relative one used to sail
  // through into `<link href>` and `<id>` verbatim, which is broken in every
  // reader and reported by nothing. A url BUILT from `page` needs no such
  // check: `feed(...)` already proved `base-url` absolute, so the join cannot
  // produce a relative result and a second regex per entry would buy nothing.
  let page = _expect-str-or-none(e.at("page", default: none), "page")
  let url = e.at("url", default: none)
  if url == none {
    assert(
      page != none,
      message: "@rheo/feeds: entry '" + title + "' has neither `url` nor "
        + "`page` — cannot build a URL.",
    )
    url = cfg.base-url + "/" + _clean-page(page)
  } else {
    url = _expect-abs-url(url, "url")
  }

  (
    // An `id` need NOT be a URL — a source may set its own opaque id, and
    // rookery-sourced entries do exactly that ("idea:beta"). Only its type is
    // checked. The default is `url`, already validated just above.
    id: _expect-str(e.at("id", default: url), "id"),
    title: title,
    url: url,
    page: page,
    select: _expect-str-or-none(e.at("select", default: none), "select"),
    published: published,
    updated: updated,
    summary: _expect-str-or-none(e.at("summary", default: none), "summary"),
    categories: _expect-strs(e.at("categories", default: ()), "categories"),
    // An entry-level author reaches `_entry-elem` as a plain string and fails
    // the same way an unchecked feed-level one would; the default is
    // `cfg.author`, which `feed(...)` already validated.
    author: _expect-str(e.at("author", default: cfg.author), "author"),
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
// is produced by two sources (or twice by one) with different dates. Within
// ONE date the sort is stable in source order, so dedupe there keeps the copy
// its source listed FIRST.
#let resolve-entries(cfg) = {
  let raw = ()
  for src in cfg.sources {
    let out = src(cfg)
    assert(
      type(out) == array,
      message: "@rheo/feeds: a source must return an array of entries — "
        + "got " + repr(type(out)),
    )
    raw += out
  }

  let normalized = raw.map(e => _normalize-entry(e, cfg)).filter(e => e != none)

  // Newest first, with ties keeping their SOURCE order. `.sorted` is ascending
  // and stable, Typst has no descending-sort argument, and negating a
  // `datetime` is not a thing — so the list is reversed BEFORE the sort rather
  // than after. `.sorted().rev()` would reverse equal keys too, silently
  // flipping every entry that shares a date with another; `spine()` dates are
  // day-granular (one `#set document(date: ..)` per vertebra), so two posts on
  // one day is the common case, not the corner case.
  let ordered = normalized.rev().sorted(key: e => _sort-key(e)).rev()

  // A dictionary as a set, not an array: `id not in <array>` is a linear scan
  // per entry, and a feed sourced from `@rheo/rookery`'s `ideas()` is every
  // note in a rookery — several hundred on a real site, so the loop was doing
  // tens of thousands of string comparisons to dedupe a list that usually has
  // no duplicates at all. Every `id` is a non-empty string by now
  // (`_normalize-entry` defaults it from `url` and type-checks it), so it is a
  // valid dictionary key.
  let seen = (:)
  let deduped = ()
  for e in ordered {
    if e.id not in seen {
      seen.insert(e.id, true)
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

// ---- the rheo floor -------------------------------------------------------
//
// True when rheo is present but PREDATES the three surfaces this package is
// built on: the `<rheo-meta:HANDLE>` beacon, `<rheo-content>` transclusion and
// the `.rheo/` control-asset prefix. All three arrived together after v0.5.2.
//
// WHY A GUARD AT ALL, when `typst.toml` already declares `min_version`: nothing
// in rheo reads that key yet, so it is invisible to precisely the person who
// needs the message. And every one of the three surfaces fails SILENTLY on an
// older rheo rather than erroring — MEASURED against a real 0.5.2 build
// (`cargo build` at tag v0.5.2; released latest as of 2026-08-20):
//
//   - `rheo compile demo` exits 0. Not one warning about any of this.
//   - `_meta`'s `query(label("rheo-meta:" + h))` finds nothing, so every
//     `spine()` entry loses its date, `resolve-entries` drops all of them,
//     `atom()` returns `none`, and `_mint-plan` skips the feed — `feed.xml` is
//     simply never written.
//   - `.rheo/head.html` is written as an ORDINARY FILE into the output tree
//     (0.5.2 has no reserved-prefix handling and takes the leading-dot path
//     without complaint), so the autodiscovery `<link>` it carries reaches no
//     page's `<head>` and sits orphaned on disk instead.
//   - Worst: a `content:`-configured feed ships the literal string
//     `<content type="html"><rheo-content page="..." as="escaped"/></content>`
//     to real feed readers. Well-formed XML, garbage content, exit 0.
//
// That last one is why this is an assert and not a readme note. A rookery on
// too-old a rheo mints nothing and is visibly empty; a feed on too-old a rheo
// is a live syndication endpoint serving markup nobody can read.
//
// THE PROBE IS A POSITIVE SIGNAL, as of 0.1.1. rheo publishes `rheo-version`
// in `rheo-context`, so the guard asks the engine what it is rather than
// inferring its age from something it stopped emitting. MEASURED on rheo 0.6.0:
// `rheo-context` carries `("spine", "spine-flat", "rheo-version", "target",
// "ext", "reset-footnotes", "title-overrides")` and `rheo-version` reads
// `"0.6.0"`.
//
// WHAT THIS REPLACES, and why it had to go: 0.1.0 dated the engine by a
// REMOVAL — `spine-flat` entries carried a `metadata` key at v0.5.2
// (`crates/core/src/reticulate/spine.rs:989`) and carry only
// `handle`/`path`/`title` after it, so the key's PRESENCE meant "old". That was
// accepted knowingly and flagged at the time as brittle in one specific way: a
// future rheo re-adding a `metadata` key to those entries would make the guard
// misfire and refuse to build on a perfectly good engine. An absence cannot
// distinguish "new enough" from "changed in some unrelated way"; a version
// string can.
//
// PATTERN B IS PRESERVED BY CONSTRUCTION: with no rheo at all `sys.inputs`
// carries no `rheo-context` at all, so the raw read below is `none` and this
// returns `false` — `test/units.typ` under bare `typst compile` never trips
// it. Running without rheo stays a supported
// no-op; running under a rheo too old to honour the output is what this
// refuses.
//
// THE KNOWN HOLE FROM 0.1.0 IS GONE WITH THE OLD PROBE. That version needed one
// spine entry to inspect and so could not detect a 0.5.2 build with an empty
// spine; this one reads a top-level key and does not care how many vertebrae
// there are.
//
// A rheo OLDER than the version key publishes no `rheo-version`, which is
// exactly the case this returns `true` for — the absence of the key IS the
// old-engine signal now, and it is an absence rheo can never accidentally
// reintroduce, because publishing the key is the new behaviour rather than the
// old one.
// The decision, as a PURE FUNCTION of the raw `rheo-context` value — `none`
// where there is no rheo at all. Split out from the `sys.inputs` read below so
// it can be unit-tested: a below-floor rheo is otherwise untestable without
// keeping a v0.5.2 binary around, and the one case this guard exists for is the
// one that would go unexercised.
#let _too-old-ctx(raw) = raw != none and "rheo-version" not in raw

#let _rheo-too-old() = {
  // `sys.inputs` DIRECTLY, not `_rheo-ctx()`, and the difference matters: that
  // helper substitutes `(spine-flat: ())` when there is no rheo, which is a
  // dictionary like any other and cannot be told apart from a real context by
  // inspection. Only the raw absence distinguishes "no rheo at all" — a
  // supported no-op — from "a rheo that does not announce its version", which
  // is the engine this refuses.
  _too-old-ctx(sys.inputs.at("rheo-context", default: none))
}

// Applied at the two marrow entry points ONLY — `configure` and `emit` — and
// deliberately not in `spine()`/`items()`. A project that imports this package
// but configures no feed must stay a complete no-op even on an old rheo, which
// is what `verify/no-configure` asserts; gating the sources instead would break
// that row and would also fire from `test/units.typ`, where there is no rheo to
// be too old.
#let _assert-rheo-floor(who) = {
  assert(
    not _rheo-too-old(),
    message: "@rheo/feeds: needs rheo >= 0.6.0, but this rheo predates it. "
      + "The `<rheo-meta:>` beacon, `<rheo-content>` transclusion and `.rheo/` "
      + "control assets this package is built on do not exist here, and none of "
      + "them fails loudly: without this check `" + who + "` would SUCCEED and "
      + "then write no feed at all (or one carrying a literal `<rheo-content>` "
      + "placeholder). Upgrade rheo: https://rheo.ohrg.org",
  )
}

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

// ---- items — built-in source: entries from `<feeds:item>` beacons -------
//
// Lets ANY code, anywhere in the bundle, contribute a feed entry for
// something that is not a spine vertebra (an idea's page, a generated
// listing, whatever) with NO import coupling in either direction: this
// package never imports the contributor's package, and the contributor
// need not import `@rheo/feeds` either — though `item(...)` below makes
// that easy when it wants to.
//
// THE PROTOCOL: emit `#metadata((..)) <feeds:item>` (or a matching custom
// `label-name`) anywhere in the bundle, with the metadata value shaped as an
// entry per this file's entry model (see the top of this file), e.g.:
//
//   #metadata((
//     id: "idea:etal", title: "Et al.", page: "notes/etal.html",
//     published: datetime(..), updated: datetime(..), categories: ("note",),
//   )) <feeds:item>
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
// non-empty `title`, is a hard failure naming `@rheo/feeds`, the label,
// and what was found — a silently dropped malformed item is worse than a
// build failure.
#let items(filter: none, label-name: "feeds:item") = cfg => {
  let found = query(label(label-name))
  let out = ()
  for f in found {
    let v = f.value
    assert(
      type(v) == dictionary,
      message: "@rheo/feeds: a <" + label-name + "> beacon's value must "
        + "be a dictionary shaped as a feed entry — got "
        + repr(type(v)),
    )
    // Validation gate only — the flattened title is DISCARDED and the
    // author's ORIGINAL dict is what goes downstream, so `_normalize-entry`
    // still sees exactly what the beacon carried.
    let _ = _expect-title(
      v.at("title", default: none),
      "a <" + label-name + "> beacon",
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

// Author-facing half of the `<feeds:item>` protocol: emits a well-formed
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
  label-name: "feeds:item",
) = {
  // Flattened at the EMITTING end, deliberately: a beacon's value is data
  // crossing into another scope, and a plain string is what every reader of it
  // expects — including `items()`, which reads this dict back verbatim.
  let title = _expect-title(title, "item(...)")
  // One pair list rather than nine near-identical `if`s, so a new field means
  // one more pair. `categories` is in it too: an omitted (or explicitly empty)
  // array is left OUT of the beacon entirely, which is what this function's
  // doc comment above promises and what the hand-rolled version got wrong by
  // always inserting it. `_normalize-entry` supplies the same `()` default
  // downstream, so "omitted" and "empty" mean the same thing to the feed.
  let value = (title: title)
  for (k, v) in (
    ("url", url),
    ("page", page),
    ("select", select),
    ("published", published),
    ("updated", updated),
    ("summary", summary),
    ("author", author),
    ("id", id),
    ("categories", categories),
  ) {
    if v != none and v != () { value.insert(k, v) }
  }
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

// One text element, escaped. Every `<tag>text</tag>` in this file goes through
// here so no site can be added that forgets the escape — the failure that
// would produce is malformed XML no assertion necessarily catches. Attributes
// are deliberately NOT covered: they are built inline with their own quoting,
// and `_content-elem`'s omit-`select`-entirely rule depends on staying
// explicit about them.
#let _elem(name, text) = "<" + name + ">" + _esc-text(text) + "</" + name + ">"

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

// ---- timestamps — RFC 822, for RSS 2.0 ------------------------------------
//
// RSS 2.0 dates are RFC 822 with a four-digit year, not RFC 3339. MEASURED
// (typst 0.15.1) that no weekday/month name tables are needed:
// `datetime(year: 2026, month: 1, day: 5).display("[weekday repr:short],
// [day] [month repr:short] [year]")` == "Mon, 05 Jan 2026".
//
// "GMT" rather than "+0000": both are legal per RFC 822 and GMT is what real
// RSS feeds use. Every `datetime` here is treated as UTC, the same assumption
// `_rfc3339` above records — nothing in this package's data model carries a
// timezone.
//
// The date-only arm exists for the same MEASURED reason as `_rfc3339`'s: a
// `datetime` built from year/month/day alone has `.hour() == none` and
// hard-errors if `.display` is asked for an `[hour]` field.
#let _rfc822(d) = {
  let date-part = d.display("[weekday repr:short], [day] [month repr:short] [year]")
  if d.hour() == none {
    date-part + " 00:00:00 GMT"
  } else {
    date-part + " " + d.display("[hour]:[minute]:[second]") + " GMT"
  }
}

// ---- atom — serialize a resolved config + entries to an Atom 1.0 string ---
//
// The element set is a PARITY TARGET against the retired Rust generator
// (`atom_syndication`-backed, `rheo/crates/html/src/feed.rs`:
// `AtomFeed::serialize`/`AtomEntry::to_atom`) — not byte-identical output;
// whitespace is not chased.

// A feed's own absolute URL — its `<id>`, its `rel="self"` link, and the `href`
// of its autodiscovery `<link>` in `.rheo/head.html` are all this same string.
// One helper so the three can never disagree: `base-url` lost its trailing
// slash in `feed(...)` and `path` its leading one, so the bare "/" join is safe
// here and nowhere else has to know that.
#let _feed-url(cfg) = cfg.base-url + "/" + cfg.path

// Largest `updated` across `entries` — becomes the feed-level `<updated>`
// (RFC 4287 §4.2.15: "most recent instant in which the feed was modified").
// Never called with an empty array — `atom(...)` below returns `none`
// before reaching this when `entries` is empty.
#let _max-updated(entries) = entries.map(e => e.updated).sorted().last()

// This entry's `<summary>` and/or `<content>`, or `""` when it has neither.
//
// The two are INDEPENDENT, and that is the whole shape of this function: a
// summary is emitted whenever the entry supplies one, and a content element is
// emitted whenever the feed asks for content AND the entry names a page. An
// entry may therefore carry both, which Atom permits (RFC 4287 §4.1.2) and
// readers make use of — the summary for a list preview, the content for the
// full article. Summary used to be the ELSE branch of content, so an entry
// with both silently lost the summary it asked for.
//
// `page`'s value is the caller's `page` AS-IS (plugin-output-relative, e.g.
// "notes/etal.html") — `atom(...)` never resolves or rewrites it. `select`
// is OMITTED from the `<rheo-content>` placeholder entirely when the entry
// has none: ABSENT means rheo's own default cascade, not "select nothing",
// so it must never be emitted as `select=""`.
#let _content-elem(cfg, e) = {
  let parts = ()
  if e.summary != none {
    parts += ("<summary type=\"text\">" + _esc-text(e.summary) + "</summary>",)
  }
  if cfg.content != none and e.page != none {
    let select-attr = if e.select != none {
      " select=\"" + _esc-attr(e.select) + "\""
    } else { "" }
    let page-attr = "page=\"" + _esc-attr(e.page) + "\""
    parts += (if cfg.content == "html" {
      "<content type=\"html\"><rheo-content " + page-attr + select-attr + " as=\"escaped\"/></content>"
    } else {
      // "xhtml": the placeholder's own `as="raw"` is unescaped because the
      // wrapping `<div xmlns="...">` is itself the XHTML content model Atom
      // requires for `type="xhtml"` (RFC 4287 §4.1.3.3) — escaping again
      // here would double-escape what rheo splices in.
      "<content type=\"xhtml\"><div xmlns=\"http://www.w3.org/1999/xhtml\">" + "<rheo-content " + page-attr + select-attr + " as=\"raw\"/></div></content>"
    },)
  }
  // Still `""` when there is neither — `_entry-elem` tests for that.
  parts.join("")
}

// One `<entry>`. Order: id, title, published (when present), updated,
// author (only when it differs from the feed's own — otherwise the feed's
// `<author>` already covers it per RFC 4287 §4.1.2's inheritance), category
// per `e.categories`, the alternate link, then content/summary.
#let _entry-elem(cfg, e) = {
  let parts = (
    _elem("id", e.id),
    _elem("title", e.title),
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
    parts += ("<author>" + _elem("name", e.author) + "</author>",)
  }
  for cat in e.categories {
    parts += ("<category term=\"" + _esc-attr(cat) + "\"/>",)
  }
  parts += ("<link rel=\"alternate\" href=\"" + _esc-attr(e.url) + "\"/>",)
  // Summary and/or content — either, both, or neither. See `_content-elem`.
  let body = _content-elem(cfg, e)
  if body != "" {
    parts += (body,)
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
// A supplied list is NORMALISED like any source's output — same validation,
// same fallbacks, same skip rule — so a hand-built sparse entry is accepted
// and an undated one is dropped. `_normalize-entry` is idempotent on an
// already-normalised entry (every field it fills is present and every assert
// it runs already passed), so the common case of passing a prior
// `resolve-entries(cfg)` result is unchanged. Without this, a hand-built entry
// died on the first missing key it reached: `dictionary does not contain key
// "id"`.
//
// Feed `<id>` and the `rel="self"` link both use `cfg.base-url + "/" +
// cfg.path` — the generalised form of the retired generator's hardcoded
// `base-url + "/feed.xml"`, now following whatever `path` the config set.
//
// The feed-level `rel="alternate"` link is a DIFFERENT href: `base-url`
// itself, the site the feed describes, as distinct from `rel="self"`, the
// feed's own URL. Readers use it as the "visit site" affordance, and its
// absence is a warning from the W3C Feed Validator (RFC 4287 does not require
// it).
#let atom(cfg, entries: none) = {
  let entries = if entries == none {
    resolve-entries(cfg)
  } else {
    entries.map(e => _normalize-entry(e, cfg)).filter(e => e != none)
  }
  if entries.len() == 0 {
    return none
  }

  let feed-url = _feed-url(cfg)
  let head = (
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>",
    "<feed xmlns=\"http://www.w3.org/2005/Atom\">",
    _elem("id", feed-url),
    _elem("title", cfg.title),
  )
  let subtitle = if cfg.subtitle != none {
    (_elem("subtitle", cfg.subtitle),)
  } else { () }
  let rest = (
    "<updated>" + _rfc3339(_max-updated(entries)) + "</updated>",
    "<author>" + _elem("name", cfg.author) + "</author>",
    // The SITE, not the feed — a reader's "visit site" target. No `type=`: an
    // `alternate` link defaults to text/html (RFC 4287 §4.2.7.2), which is
    // what a site root is.
    "<link rel=\"alternate\" href=\"" + _esc-attr(cfg.base-url) + "\"/>",
    "<link rel=\"self\" href=\"" + _esc-attr(feed-url) + "\"/>",
  )
  let entry-strs = entries.map(e => _entry-elem(cfg, e))

  (head + subtitle + rest + entry-strs + ("</feed>",)).join("")
}

// ---- rss — serialize a resolved config + entries to an RSS 2.0 string -----
//
// Same signature and same three contracts as `atom(...)` above: `entries:
// none` means resolve them here (requiring context when a source does), a
// supplied list is normalised like any source's output, and zero entries
// returns `none` so `_mint-plan` skips the feed rather than minting an empty
// one.
//
// WHAT DOES NOT TRANSFER FROM ATOM, and why each is a mapping rather than an
// omission:
//
//   - ONE DATE PER ITEM. RSS has `pubDate` and no second slot, so Atom's
//     `published`/`updated` distinction collapses: `pubDate` takes
//     `published` when present, else `updated` — the same preference
//     `_sort-key` uses for ordering. The channel's `lastBuildDate` carries the
//     newest `updated` across the feed.
//   - `<dc:creator>`, NOT `<author>`. RSS 2.0's own `<author>` element must
//     contain an EMAIL ADDRESS; this package's `author` is a plain name
//     ("Rheo"), and a name in `<author>` produces a feed validators reject.
//     `<dc:creator>` is the conventional element for a name, hence the `dc`
//     namespace below. Emitted on EVERY item, because RSS has no
//     channel-to-item author inheritance — Atom's "omit when it matches the
//     feed's" rule (RFC 4287 §4.1.2) has no RSS equivalent.
//   - `<guid isPermaLink=..>`. A reader treats a permalink guid as a URL, so
//     the flag is `"true"` only when the id actually is one — tested with the
//     same `_abs-url-re` an entry's `url` is held to. A rookery-sourced id
//     like "idea:beta" is not a URL and must say so.
//   - `<description>` is REQUIRED at channel level, and the nearest config
//     field (`subtitle`) is optional, so it falls back to `cfg.title`.
//   - `content: "xhtml"` is Atom's own content model and means nothing here;
//     this treats it as `"html"`. The config-level guard lives in `feed(...)`.
#let _rss-item(cfg, e) = {
  let parts = (
    _elem("title", e.title),
    _elem("link", e.url),
  )
  let permalink = if e.id.match(_abs-url-re) != none { "true" } else { "false" }
  parts += (
    "<guid isPermaLink=\"" + permalink + "\">" + _esc-text(e.id) + "</guid>",
    "<pubDate>"
      + _rfc822(if e.published != none { e.published } else { e.updated })
      + "</pubDate>",
    _elem("dc:creator", e.author),
  )
  for cat in e.categories {
    parts += (_elem("category", cat),)
  }

  // RSS has ONE `<description>`, so summary and content compete for it. With
  // both, the summary wins the slot and the content goes in
  // `<content:encoded>` — what that namespace exists for, and the same
  // "summary is not swallowed by content" rule `_content-elem` follows for
  // Atom. `select` keeps its omit-entirely-when-absent rule: absent means
  // rheo's own default cascade, never `select=""`.
  let placeholder = if cfg.content != none and e.page != none {
    let select-attr = if e.select != none {
      " select=\"" + _esc-attr(e.select) + "\""
    } else { "" }
    // Parenthesised deliberately: inside a code block a continuation line
    // beginning with `+` is parsed as a unary plus on a new statement, not as
    // string concatenation — "cannot apply unary '+' to string".
    (
      "<rheo-content page=\"" + _esc-attr(e.page) + "\"" + select-attr
        + " as=\"escaped\"/>"
    )
  } else { none }

  if e.summary != none {
    parts += (_elem("description", e.summary),)
    if placeholder != none {
      parts += ("<content:encoded>" + placeholder + "</content:encoded>",)
    }
  } else if placeholder != none {
    parts += ("<description>" + placeholder + "</description>",)
  }

  "<item>" + parts.join("") + "</item>"
}

#let rss(cfg, entries: none) = {
  let entries = if entries == none {
    resolve-entries(cfg)
  } else {
    entries.map(e => _normalize-entry(e, cfg)).filter(e => e != none)
  }
  if entries.len() == 0 {
    return none
  }

  let feed-url = _feed-url(cfg)
  let head = (
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>",
    "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\""
      + " xmlns:content=\"http://purl.org/rss/1.0/modules/content/\""
      + " xmlns:dc=\"http://purl.org/dc/elements/1.1/\">",
    "<channel>",
    _elem("title", cfg.title),
    // The SITE, as Atom's own feed-level `rel="alternate"` is.
    _elem("link", cfg.base-url),
    _elem(
      "description",
      if cfg.subtitle != none { cfg.subtitle } else { cfg.title },
    ),
    // RSS 2.0 has no self-link of its own; borrowing Atom's is the universal
    // convention, and the reason for the `atom` namespace above.
    "<atom:link rel=\"self\" href=\"" + _esc-attr(feed-url)
      + "\" type=\"application/rss+xml\"/>",
    "<lastBuildDate>" + _rfc822(_max-updated(entries)) + "</lastBuildDate>",
  )
  let item-strs = entries.map(e => _rss-item(cfg, e))

  (head + item-strs + ("</channel>", "</rss>")).join("")
}

// ---- json-feed — serialize to a JSON Feed 1.1 string ----------------------
//
// Named `json-feed`, NOT `json`: a module-level `#let json = ..` would shadow
// Typst's built-in `json` module this function calls into.
//
// Same three contracts as `atom(...)`/`rss(...)`: `entries: none` resolves
// here, a supplied list is normalised, zero entries returns `none`.
//
// The whole serializer is "build a dictionary, encode it" — MEASURED (typst
// 0.15.1) that `json.encode(value)` returns a `str` and escapes correctly (for
// `(title: "He said \"hi\"")` the output contains `\"hi\"`), so there is no
// hand-rolled string escaping here at all.
//
// SUMMARY-ONLY, and that is a rheo-core gap rather than a choice. JSON Feed
// wants `content_html` per item, and `<rheo-content>` cannot produce it:
// MEASURED against a real rheo 0.6.0 build, its only encodings are `escaped`
// (XML entities for `&`/`<`/`>`) and `raw`, neither JSON-safe —
//
//   - with bare attribute quotes, so rheo's attribute regex matches, a
//     transcluded page carrying ANY html attribute breaks the JSON: the minted
//     file came out `{"content_html": "&lt;p&gt;.. &lt;a
//     href="https://example.com/x"&gt;..` and `json.load` failed with
//     `Expecting ',' delimiter: line 1 column 88`. `escaped` does not escape
//     `"`.
//   - with backslash-escaped attribute quotes, so the JSON stays valid, rheo's
//     attribute pattern (which wants `="`, not `=\"`) never matches and the
//     placeholder survives into the output verbatim, unresolved.
//
// So no `content_html` is emitted, and the `content: none` assert below makes
// an author acknowledge that rather than have a `content: "html"` setting
// silently ignored. Closing the gap needs a JSON-safe `Encoding` in rheo core
// (`crates/core/src/transclude.rs`) — bead `rheo-rheo-content-json-vxv` in the
// rheo repo.
//
// Absent values are OMITTED, never encoded as `null`: a null-littered feed
// reads as a bug, and JSON Feed's own spec talks in terms of members being
// present or absent.
#let _json-item(e) = {
  let it = (id: e.id, url: e.url, title: e.title)
  for (k, v) in (
    ("summary", e.summary),
    ("date_published", if e.published != none { _rfc3339(e.published) } else { none }),
    ("date_modified", if e.updated != none { _rfc3339(e.updated) } else { none }),
    ("tags", e.categories),
  ) {
    if v != none and v != () { it.insert(k, v) }
  }
  // `authors` (plural, array of objects) is the 1.1 spelling; the singular
  // `author` is deprecated 1.0.
  it.insert("authors", ((name: e.author),))
  it
}

#let json-feed(cfg, entries: none) = {
  assert(
    cfg.content == none,
    message: "@rheo/feeds: a JSON feed must be configured with `content: "
      + "none` — got " + repr(cfg.content) + ". JSON Feed content needs a "
      + "JSON-safe `<rheo-content>` encoding that rheo does not have yet, so "
      + "entries carry their `summary` only. Write `content: none` to "
      + "acknowledge a summary-only feed.",
  )
  let entries = if entries == none {
    resolve-entries(cfg)
  } else {
    entries.map(e => _normalize-entry(e, cfg)).filter(e => e != none)
  }
  if entries.len() == 0 {
    return none
  }

  let doc = (
    version: "https://jsonfeed.org/version/1.1",
    title: cfg.title,
    home_page_url: cfg.base-url,
    feed_url: _feed-url(cfg),
  )
  if cfg.subtitle != none { doc.insert("description", cfg.subtitle) }
  doc.insert("authors", ((name: cfg.author),))
  doc.insert("items", entries.map(_json-item))

  json.encode(doc)
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
// Shared by `configure`, `emit` and `_mint-plan` — the three places a caller
// hands over an array of feed configs. `who` is the caller's own name, spliced
// into both messages so each site reads as its own error.
//
// The per-item check is a SHAPE check, not a re-validation: `feed(...)` already
// checked every field, and all this has to catch is a dictionary that never
// went through it. Unchecked, such a dictionary died at the bundle root as
// `dictionary does not contain key "sources"` — no page, no line an author
// could act on.
#let _expect-feeds(feeds, who) = {
  assert(
    type(feeds) == array,
    message: "@rheo/feeds: " + who + "'s `feeds` must be an array of feed "
      + "configs, e.g. `" + who + "(feeds: (feed(..), feed(..)))`.",
  )
  for f in feeds {
    assert(
      type(f) == dictionary and "sources" in f and "path" in f,
      message: "@rheo/feeds: " + who + "'s `feeds` must hold configs built "
        + "by `feed(..)` — got " + repr(f) + ". Call `feed(title: .., "
        + "base-url: .., sources: (..))` and pass its return value.",
    )
  }
  feeds
}

#let _feeds = state("rheo-feeds-feeds", ())

// Register one or more feeds for `.marrow.typ` to mint. Call ONCE from any
// vertebra:
//
//   #import "@rheo/feeds:0.1.1": feed, configure
//   #configure(feeds: (
//     feed(title: "My Site", base-url: "https://example.com", sources: (...)),
//   ))
//
// Projects using path (b) instead — calling `resolve-entries` (and, later,
// the XML emitter) directly from their own `.marrow.typ` — need this
// function not at all; the two entry points are independent.
#let configure(feeds: ()) = {
  _assert-rheo-floor("configure")
  _feeds.update(old => old + _expect-feeds(feeds, "configure"))
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
// Which serializer a config's `format` selects, and the autodiscovery `type=`
// that goes with it. Two helpers rather than one dispatch table because the
// mime type is needed without serializing (the `.rheo/head.html` link is built
// from the config alone).
#let _serialize(cfg, entries: none) = if cfg.format == "rss" {
  rss(cfg, entries: entries)
} else if cfg.format == "json" {
  json-feed(cfg, entries: entries)
} else {
  atom(cfg, entries: entries)
}

// `application/feed+json` is JSON Feed 1.1's registered type — not
// `application/json+feed`.
#let _feed-mime(cfg) = if cfg.format == "rss" {
  "application/rss+xml"
} else if cfg.format == "json" {
  "application/feed+json"
} else {
  "application/atom+xml"
}

#let _mint-plan(feeds) = {
  // The site that actually catches a bad config arriving through `configure`'s
  // state: `configure` only appends, and `.marrow.typ` reads the state back
  // much later, so its own check cannot see what a second caller put there.
  let feeds = _expect-feeds(feeds, "_mint-plan")
  for i in range(feeds.len()) {
    for j in range(i + 1, feeds.len()) {
      assert(
        feeds.at(i).path != feeds.at(j).path,
        message: "@rheo/feeds: two feeds both write to '" + feeds.at(i).path
          + "' (\"" + feeds.at(i).title + "\" and \"" + feeds.at(j).title
          + "\") — give each feed its own `path`.",
      )
    }
  }

  let minted = () // (path: str, data: str)
  // The CONFIGS that actually minted, not a projection of three of their
  // fields: everything the head fragment needs is already on the config, and
  // `_feed-url` is the same join `atom(...)` used for the feed's own `<id>`.
  let linked = ()
  for cfg in feeds {
    let data = _serialize(cfg)
    if data == none { continue }
    minted += ((path: cfg.path, data: data),)
    linked += (cfg,)
  }

  if linked.len() > 0 {
    let tags = linked
      .map(cfg => "<link rel=\"alternate\" type=\"" + _esc-attr(_feed-mime(cfg))
        + "\" href=\""
        + _esc-attr(_feed-url(cfg)) + "\" title=\"" + _esc-attr(cfg.title) + "\">")
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
//   #import "@rheo/feeds:0.1.1": feed, emit
//   #context { emit(feeds: (feed(...), feed(...))) }
#let emit(feeds: ()) = {
  _assert-rheo-floor("emit")
  for m in _mint-plan(_expect-feeds(feeds, "emit")) {
    asset(m.path, m.data)
  }
}
