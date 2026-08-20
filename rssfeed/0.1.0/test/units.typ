// Unit fixture for the entry model, feed config, and `resolve-entries` in
// `/src/lib.typ`. No runner and no JS: `assert`/`assert.eq` fail the compile
// with a line number, and a passing compile is the green light.
//
// Run with `just test` from `rssfeed/0.1.0`.
//
// SCOPE: this bead lands data modelling only — no concrete source, no XML
// serialization, no `.marrow.typ` — so this fixture covers exactly that:
// `feed(...)`'s validation and defaults, and `resolve-entries`'s normalise
// -> sort -> dedupe -> limit pipeline, including the skip rule for entries
// with neither `published` nor `updated`.
//
// PANICS ARE NOT ASSERTABLE in Typst, so the invalid-input paths are only
// documented here, not exercised:
//   - `feed(...)` panics on: empty/missing `title`; empty/missing
//     `base-url`; a `base-url` with no scheme (e.g. "example.com"); an empty
//     `sources`; a non-function `sources` entry; a `content` other than
//     "html"/"xhtml"/none; a `path` that is not a non-empty string; an
//     `author` that is not a non-empty string; a `subtitle` that is neither a
//     string nor none; a `limit` that is not a positive integer or none
//     (`limit: 0` used to empty the feed silently, `limit: -1` to drop its
//     oldest entry).
//   - the ONE non-empty-title rule (`_expect-title`) panics wherever a title
//     arrives from outside the package — a source's entry, an
//     `<rssfeed:item>` beacon read by `items()`, or an `item(...)` call — when
//     that title is neither a string nor content, or flattens to "". All
//     three sites share the checker, so the rule cannot differ between them.
//   - `resolve-entries` (via `_normalize-entry`) panics on: a non-dictionary
//     entry from a source; an entry with
//     neither `url` nor `page`; a `categories` that is not an array, or an
//     array holding a non-string (`categories: "note"` used to emit one
//     `<category>` per LETTER, silently); a `published` or `updated` that is
//     neither a datetime nor none — a STRING date especially, since the
//     retired `rheo-feed-updated` variable this package's readme migrates
//     from took one, and an unchecked string used to die inside `_rfc3339`
//     instead.
//   - `resolve-entries` panics when a source's return value is not an array.
//   - `items()` panics (at query time) on a `<rssfeed:item>` (or custom
//     `label-name`) beacon whose value is not a dictionary. Its beacon
//     `title` is checked by the shared rule above.
//   - `_mint-plan` panics when two feeds in its input share the same `path`.
//
// `_mint-plan` itself IS testable here, unlike `emit`/`.marrow.typ`: it
// returns plain `(path, data)` pairs rather than minting with `#asset(...)`
// — see its own doc comment in `/src/lib.typ` — so it needs no bundle target
// and nothing calling it here ever gets shown/laid out. `emit(...)` calls
// `#asset(...)` directly and so is only exercisable under a real rheo build
// (this fixture compiles to `--format pdf`, where `asset` bails if shown).

#import "/src/lib.typ": _clean-page, _mint-plan, _plain-text, atom, feed, item, items, resolve-entries, spine

// ---- _clean-page — no double slash whichever way a source spells `page` ---
#assert.eq(_clean-page("two.html"), "two.html")
#assert.eq(_clean-page("/two.html"), "two.html")
#assert.eq(_clean-page("./two.html"), "two.html")

// ---- _plain-text — flatten CONTENT titles (the metadata beacon's own
// shape, and any hand-written source forwarding `document.title`) to plain
// strings, passing a plain string straight through. See `/src/lib.typ`'s
// own doc comment on `_plain-text` for the MEASURED content shapes this
// covers `c.text`/`c.children`/`c.body`/space-like leaves.
#assert.eq(_plain-text(none), "")
// A plain string passes through unchanged — no content involved at all.
#assert.eq(_plain-text("Plain Str"), "Plain Str")
// A single-word bracket title is one `text` leaf — the `c.text` field path.
#assert.eq(_plain-text([Word]), "Word")
// A multi-word bracket title with markup is a `sequence` of
// `text`/`space`/`emph` children — the `c.children` recursion path, and
// `emph`'s own `c.body` recursion nested inside it. This is the exact
// fixture the bead itself names.
#assert.eq(_plain-text([Two, #emph[emphatically]]), "Two, emphatically")
// A run of markup with an explicit paragraph break — `parbreak` is one of
// the space-like leaves that flattens to a single " ".
#assert.eq(_plain-text([Para one

Para two]), "Para one Para two")
// An apostrophe or quote typed inside markup is its OWN `smartquote` element,
// not part of the surrounding `text` node, and it carries only a `double`
// field. Before it had a branch of its own it fell to the final `else` and
// flattened to "" — DELETING the character: a real title authored as
// `[Mladen Dolar: What's in a Name?]` came out as "Whats in a Name?".
#assert.eq(_plain-text([It's a test]), "It's a test")
#assert.eq(_plain-text([She said #emph[hello] to "everyone"]), "She said hello to \"everyone\"")
// A title that is CONTENT but carries no text at all (just a space)
// flattens to "" once trimmed — this is what `_normalize-entry`'s own
// non-empty check relies on to still catch an effectively-empty title.
#assert.eq(_plain-text([ ]), "")

// `feed(...)` requires at least one source (panics otherwise — see the top
// comment), so every config below needs one even where its entries do not
// matter to the assertion at hand.
#let _empty-source(cfg) = ()

// ---- feed — defaults, and the trailing-slash trim on `base-url` -----------
// Two configs, two different `path`s — proves `feed(...)` is not a singleton
// and each call is independent.
#let feed1 = feed(
  path: "feed1.xml",
  title: "Feed One",
  // Trailing slash: `feed(...)` must trim it so `resolve-entries` never
  // joins a page onto a double slash.
  base-url: "https://example.com/",
  sources: (_empty-source,),
)
#let feed2 = feed(
  path: "feed2.xml",
  title: "Feed Two",
  base-url: "https://example.org",
  sources: (_empty-source,),
)
#assert.eq(feed1.path, "feed1.xml")
#assert.eq(feed2.path, "feed2.xml")
#assert.eq(feed1.base-url, "https://example.com")
// Untouched when there was nothing to trim.
#assert.eq(feed2.base-url, "https://example.org")
// Defaults: `author` "Rheo", `content` "html", `subtitle`/`limit` none.
#assert.eq(feed1.author, "Rheo")
#assert.eq(feed1.content, "html")
#assert.eq(feed1.subtitle, none)
#assert.eq(feed1.limit, none)

// The four fields validated in `feed(...)`'s returned dict pass VALID values
// through untouched — the validators annotate, they never rewrite. (Their
// invalid values panic, and a panic is not assertable here; see the top
// comment.)
#let feed-opts = feed(
  path: "opts.xml",
  title: "Opts Feed",
  base-url: "https://example.com",
  sources: (_empty-source,),
  author: "Someone",
  subtitle: "A subtitle",
  limit: 5,
)
#assert.eq(feed-opts.path, "opts.xml")
#assert.eq(feed-opts.author, "Someone")
#assert.eq(feed-opts.subtitle, "A subtitle")
#assert.eq(feed-opts.limit, 5)

// ---- resolve-entries — normalise, the skip rule, order, id/url fill -------
//
// Four hand-written entries from one stub source:
//   "one"   — dated (published AND updated), explicit url
//   "two"   — dated (published AND updated), url built from a leading-slash
//             `page` (exercises `_clean-page` through the real pipeline)
//   "three" — PUBLISHED ONLY — must get `updated` filled from it
//   "four"  — NO DATES AT ALL — must be DROPPED by the skip rule
#let _stub-dated(cfg) = (
  (
    title: "Entry One",
    url: "https://example.com/one",
    published: datetime(year: 2026, month: 1, day: 10),
    updated: datetime(year: 2026, month: 1, day: 12),
  ),
  (
    title: "Entry Two",
    page: "/two.html",
    published: datetime(year: 2026, month: 3, day: 5),
    updated: datetime(year: 2026, month: 3, day: 6),
  ),
  (
    title: "Entry Three",
    url: "https://example.com/three",
    published: datetime(year: 2026, month: 2, day: 1),
  ),
  (
    title: "Entry Four",
    url: "https://example.com/four",
  ),
)

#let cfg-dated = feed(
  path: "dated.xml",
  title: "Dated Feed",
  base-url: "https://example.com",
  sources: (_stub-dated,),
)
#let dated = resolve-entries(cfg-dated)

// The undated entry ("Entry Four") is gone: 3 kept, not 4.
#assert.eq(dated.len(), 3)
// Newest-first: Two (Mar 5) > Three (Feb 1) > One (Jan 10).
#assert.eq(dated.map(e => e.title), ("Entry Two", "Entry Three", "Entry One"))
// `url` built from `page`, with the leading slash stripped — no double slash.
#assert.eq(dated.at(0).url, "https://example.com/two.html")
// `id` defaults to the (possibly built) `url` when a source gives none.
#assert.eq(dated.at(0).id, "https://example.com/two.html")
#assert.eq(dated.at(2).id, "https://example.com/one")
// "Entry Three" had only `published`; `updated` must be filled from it.
#assert.eq(dated.at(1).published, datetime(year: 2026, month: 2, day: 1))
#assert.eq(dated.at(1).updated, datetime(year: 2026, month: 2, day: 1))

// `limit: 2` keeps the 2 most recent, post-sort.
#let cfg-limited = feed(
  path: "limited.xml",
  title: "Limited Feed",
  base-url: "https://example.com",
  sources: (_stub-dated,),
  limit: 2,
)
#assert.eq(
  resolve-entries(cfg-limited).map(e => e.title),
  ("Entry Two", "Entry Three"),
)

// ---- categories — a real array survives; a bare string is rejected --------
//
// The rejection itself is not assertable (see the top comment), so this pins
// the POSITIVE half: an array of two strings arrives intact and serializes to
// exactly two `<category>` elements — the count a bare `categories: "note"`
// used to get wrong silently, emitting one per letter instead.
#let _stub-cats(cfg) = (
  (
    title: "Tagged",
    url: "https://example.com/tagged",
    updated: datetime(year: 2026, month: 1, day: 1),
    categories: ("a", "b"),
  ),
)
#let cfg-cats = feed(
  path: "cats.xml",
  title: "Cats Feed",
  base-url: "https://example.com",
  sources: (_stub-cats,),
)
#assert.eq(resolve-entries(cfg-cats).first().categories, ("a", "b"))
#assert.eq(atom(cfg-cats).matches("<category").len(), 2)

// ---- resolve-entries — dedupe by id keeps the FIRST occurrence ------------
//
// Sorting happens BEFORE deduping, so "first occurrence" of a repeated id is
// whichever copy sorted newest — here, "Dup New".
#let _stub-dup(cfg) = (
  (
    id: "dup",
    title: "Dup Old",
    url: cfg.base-url + "/dup-old",
    updated: datetime(year: 2026, month: 1, day: 1),
  ),
  (
    id: "dup",
    title: "Dup New",
    url: cfg.base-url + "/dup-new",
    updated: datetime(year: 2026, month: 6, day: 1),
  ),
)
#let cfg-dup = feed(
  path: "dup.xml",
  title: "Dup Feed",
  base-url: "https://example.org",
  sources: (_stub-dup,),
)
#let dup = resolve-entries(cfg-dup)
#assert.eq(dup.len(), 1)
#assert.eq(dup.first().title, "Dup New")

// ---- spine — no rheo present, so spine-flat is empty and there's no error -
//
// This fixture runs under plain `typst compile` with no rheo, so
// `sys.inputs` carries no `rheo-context` and `spine()`'s internal
// `_rheo-ctx()` falls back to an empty spine — `entries` is `()`, `.map`
// never runs its body, and the `query()` inside `_meta` is therefore never
// actually reached. Still wrapped in `#context`, both because that's the
// real calling convention (`spine()`'s doc comment: call via
// `resolve-entries` from inside `#context { .. }`) and because `assert`
// failures inside a `context` block still fail the compile — the mechanism
// this whole fixture relies on.
#let cfg-spine = feed(
  path: "spine.xml",
  title: "Spine Feed",
  base-url: "https://example.com",
  sources: (spine(),),
)
#context {
  assert.eq(resolve-entries(cfg-spine), ())
}

// Same, but exercising the argument-accepting shape (`filter`/`select`
// both given) — still `()` with no rheo, since `spine-flat` is empty before
// `filter` ever runs. Proves `spine(...)` itself doesn't choke on its own
// arguments; the `filter`/`select`/date-from-beacon LOGIC can only be
// exercised under a real rheo build (no way to fake `sys.inputs` here).
#let cfg-spine-args = feed(
  path: "spine2.xml",
  title: "Spine Feed 2",
  base-url: "https://example.com",
  sources: (spine(filter: e => true, select: "main"),),
)
#context {
  assert.eq(resolve-entries(cfg-spine-args), ())
}

// ---- items — beacons emitted by THIS document, read back in one pass -----
//
// `query()` sees any beacon in the SAME compile, even under plain `typst
// compile` with no rheo: one document is one introspection pass. This is
// the single-vertebra special case of the same fact rheo's own multi-
// vertebra bundle compile relies on for `spine`'s cross-vertebra
// `<rheo-meta:*>` beacons above. `item(...)` emits the beacons; `items()`
// reads them back — this also covers bead point "assert item(...)'s
// emitted beacon is picked up by items()".
#item(
  title: "Note A",
  page: "notes/a.html",
  updated: datetime(year: 2026, month: 5, day: 1),
  categories: ("note",),
)
#item(
  title: "Note B",
  page: "notes/b.html",
  updated: datetime(year: 2026, month: 5, day: 2),
  categories: ("log",),
)

#let cfg-items = feed(
  path: "items.xml",
  title: "Items Feed",
  base-url: "https://example.com",
  sources: (items(),),
)
#context {
  let all = resolve-entries(cfg-items)
  assert.eq(all.len(), 2)
  assert.eq(all.map(e => e.title).sorted(), ("Note A", "Note B"))
  // `page`/`url`, `author`, `id` were all omitted from the `item(...)`
  // calls above — proves `item(...)`'s sparse-dict emission lets
  // `_normalize-entry`'s own fallbacks (author from the feed, id from the
  // built url) still apply, rather than baking in explicit `none`s that
  // would shadow them.
  assert.eq(all.at(0).author, "Rheo")
  assert.eq(all.at(0).url, "https://example.com/notes/b.html")
  assert.eq(all.at(0).id, "https://example.com/notes/b.html")
}

// A CONTENT title survives the whole round trip: `item(...)` flattens it at the
// emitting end, `items()` reads the beacon back, and the resolved entry carries
// the plain string. This is the shape that used to be rejected outright — the
// entry model accepted `str` or `content` while `items()`/`item(...)` accepted
// `str` only, so `spine()`'s own title shape could not reach a beacon.
//
// Emitted under its OWN `label-name`, for two reasons: it must not perturb the
// `<rssfeed:item>` counts asserted above, and the matching-custom-label
// contract (pass the same `label-name` to both `item(...)` and `items(...)`)
// otherwise has no coverage at all.
#item(
  title: [Item #emph[Content]],
  page: "notes/c.html",
  updated: datetime(year: 2026, month: 5, day: 3),
  label-name: "units:custom-item",
)
#let cfg-items-content = feed(
  path: "items-content.xml",
  title: "Items Feed Content",
  base-url: "https://example.com",
  sources: (items(label-name: "units:custom-item"),),
)
#context {
  let one = resolve-entries(cfg-items-content)
  assert.eq(one.len(), 1)
  assert.eq(one.first().title, "Item Content")
  assert.eq(one.first().url, "https://example.com/notes/c.html")
}

// `filter` over the parsed item VALUE keeps only the "note"-tagged beacon.
#let cfg-items-filtered = feed(
  path: "items-filtered.xml",
  title: "Items Feed Filtered",
  base-url: "https://example.com",
  sources: (items(filter: it => "note" in it.at("categories", default: ())),),
)
#context {
  let filtered = resolve-entries(cfg-items-filtered)
  assert.eq(filtered.len(), 1)
  assert.eq(filtered.first().title, "Note A")
}

// ---- atom — Atom 1.0 XML serialization (bead rheo-packages-serialize-yyv) -
//
// None of the stub sources below call `query()` (that's `spine()`/`items()`,
// already covered above) — so every `atom(cfg)` call here uses the default
// `entries: none` path with NO `#context` wrapper needed.

// ---- structural shape: XML decl, feed namespace, entry count --------------
#let _stub-atom-struct(cfg) = (
  (
    title: "Struct One",
    url: "https://example.com/struct-one",
    updated: datetime(year: 2026, month: 1, day: 1),
  ),
  (
    title: "Struct Two",
    url: "https://example.com/struct-two",
    updated: datetime(year: 2026, month: 1, day: 2),
  ),
)
#let cfg-atom-struct = feed(
  path: "struct.xml",
  title: "Struct Feed",
  base-url: "https://example.com",
  sources: (_stub-atom-struct,),
)
#let xml-struct = atom(cfg-atom-struct)
#assert(
  xml-struct.starts-with("<?xml version=\"1.0\" encoding=\"utf-8\"?>"),
  message: "atom(...) must start with the XML declaration",
)
#assert(
  xml-struct.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\">"),
  message: "atom(...) must declare the Atom namespace",
)
#assert.eq(xml-struct.matches("<entry>").len(), 2)

// ---- escaping: `&` first, then `<`/`>`, no double-escaping -----------------
#let _stub-atom-escape(cfg) = (
  (
    title: "Tom & Jerry <3",
    url: "https://example.com/tom-and-jerry",
    updated: datetime(year: 2026, month: 1, day: 1),
  ),
)
#let cfg-atom-escape = feed(
  path: "escape.xml",
  title: "Escape Feed",
  base-url: "https://example.com",
  sources: (_stub-atom-escape,),
)
#let xml-escape = atom(cfg-atom-escape)
#assert(
  xml-escape.contains("Tom &amp; Jerry &lt;3"),
  message: "title must be escaped & first, then <",
)
#assert(
  not xml-escape.contains("&amp;amp;"),
  message: "escaping & before </> must not double-escape the &",
)

// ---- published vs updated: distinct, and omitted when only `updated` ------
//
// This is the fix for the retired Rust generator's real defect (bead body):
// it never emitted `atom:published` at all. One entry carries both dates
// (distinct) so `<published>` must appear once with its OWN value, separate
// from `<updated>`; a second entry carries only `updated` so it must
// contribute NO `<published>` at all.
#let _stub-atom-pub(cfg) = (
  (
    title: "Has Both",
    url: "https://example.com/has-both",
    published: datetime(year: 2026, month: 1, day: 1),
    updated: datetime(year: 2026, month: 1, day: 15),
  ),
  (
    title: "Updated Only",
    url: "https://example.com/updated-only",
    updated: datetime(year: 2026, month: 1, day: 20),
  ),
)
#let cfg-atom-pub = feed(
  path: "pub.xml",
  title: "Pub Feed",
  base-url: "https://example.com",
  sources: (_stub-atom-pub,),
)
#let xml-pub = atom(cfg-atom-pub)
// Exactly one `<published>` in the whole document — only "Has Both" gets one.
#assert.eq(xml-pub.matches("<published>").len(), 1)
#assert(
  xml-pub.contains("<published>2026-01-01T00:00:00Z</published>"),
  message: "published must carry its own distinct RFC 3339 value",
)
#assert(
  xml-pub.contains("<updated>2026-01-15T00:00:00Z</updated>"),
  message: "updated must keep its own distinct value alongside published",
)

// ---- content: `<rheo-content>` placeholder, `select` present/absent -------
#let _stub-atom-select(cfg) = (
  (
    title: "With Select",
    page: "a.html",
    select: "main",
    updated: datetime(year: 2026, month: 1, day: 1),
  ),
)
#let cfg-atom-select = feed(
  path: "select.xml",
  title: "Select Feed",
  base-url: "https://example.com",
  sources: (_stub-atom-select,),
)
#let xml-select = atom(cfg-atom-select)
#assert(
  xml-select.contains(
    "<content type=\"html\"><rheo-content page=\"a.html\" select=\"main\" as=\"escaped\"/></content>",
  ),
  message: "select must appear on <rheo-content> when the entry has one",
)

#let _stub-atom-noselect(cfg) = (
  (
    title: "No Select",
    page: "a.html",
    updated: datetime(year: 2026, month: 1, day: 1),
  ),
)
#let cfg-atom-noselect = feed(
  path: "noselect.xml",
  title: "No Select Feed",
  base-url: "https://example.com",
  sources: (_stub-atom-noselect,),
)
#let xml-noselect = atom(cfg-atom-noselect)
#assert(
  xml-noselect.contains(
    "<content type=\"html\"><rheo-content page=\"a.html\" as=\"escaped\"/></content>",
  ),
  message: "select must be OMITTED entirely (not select=\"\") when the entry has none",
)
#assert(
  not xml-noselect.contains("select="),
  message: "absent select must not appear as an empty attribute either",
)

// ---- summary fallback: no `page` -> no `<content>`, `<summary>` instead ---
#let _stub-atom-summary(cfg) = (
  (
    title: "Summary Only",
    url: "https://example.com/summary-only",
    summary: "A short blurb.",
    updated: datetime(year: 2026, month: 1, day: 1),
  ),
)
#let cfg-atom-summary = feed(
  path: "summary.xml",
  title: "Summary Feed",
  base-url: "https://example.com",
  sources: (_stub-atom-summary,),
)
#let xml-summary = atom(cfg-atom-summary)
#assert(
  not xml-summary.contains("<content"),
  message: "an entry with no page must not get a <content> element",
)
#assert(
  xml-summary.contains("<summary type=\"text\">A short blurb.</summary>"),
  message: "an entry with no page but a summary must get <summary type=\"text\">",
)

// ---- no entries -> no feed at all ------------------------------------------
//
// Mirrors the retired Rust generator's early return ("Skip feed generation
// if no entries") — the later marrow bead is expected to check for `none`
// and skip minting the asset rather than mint an empty/invalid feed.
#let cfg-atom-empty = feed(
  path: "empty.xml",
  title: "Empty Feed",
  base-url: "https://example.com",
  sources: (_empty-source,),
)
#assert.eq(atom(cfg-atom-empty), none)

// ---- feed <id> and rel="self" link both use base-url + "/" + path ---------
//
// GENERALISED from the retired generator's hardcoded `base-url + "/feed.xml"`
// — proven here with a NON-default `path` so a config that renames the feed
// file is not silently pinned back to "feed.xml".
#let _stub-atom-path(cfg) = (
  (
    title: "Path Entry",
    url: "https://example.com/path-entry",
    updated: datetime(year: 2026, month: 1, day: 1),
  ),
)
#let cfg-atom-path = feed(
  path: "custom/atom.xml",
  title: "Path Feed",
  base-url: "https://example.com",
  sources: (_stub-atom-path,),
)
#let xml-path = atom(cfg-atom-path)
#assert(
  xml-path.contains("<id>https://example.com/custom/atom.xml</id>"),
  message: "feed <id> must be base-url + \"/\" + path, not a hardcoded feed.xml",
)
#assert(
  xml-path.contains(
    "<link rel=\"self\" href=\"https://example.com/custom/atom.xml\"/>",
  ),
  message: "rel=\"self\" href must match the same base-url + \"/\" + path",
)

// ---- _mint-plan — the shared marrow/emit minting plan ----------------------

// No feeds at all -> no plan, matching a project that imports the package
// but never calls `configure`/`emit`.
#assert.eq(_mint-plan(()), ())

// One feed with entries -> its XML plus a trailing `.rheo/head.html` link.
#let cfg-mint-one = feed(
  path: "one.xml",
  title: "One & Only",
  base-url: "https://example.com",
  sources: (_stub-atom-struct,),
)
#let plan-one = _mint-plan((cfg-mint-one,))
#assert.eq(plan-one.len(), 2)
#assert.eq(plan-one.at(0).path, "one.xml")
#assert(
  plan-one.at(0).data.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\">"),
  message: "the feed's own minted file must be its atom(...) output",
)
#assert.eq(plan-one.at(1).path, ".rheo/head.html")
#assert.eq(
  plan-one.at(1).data,
  "<link rel=\"alternate\" type=\"application/atom+xml\" href=\""
    + "https://example.com/one.xml\" title=\"One &amp; Only\">",
  // Title escaped (`&` -> `&amp;`) — proves the head fragment goes through
  // lib.typ's own `_esc-attr` rather than being spliced in raw.
)

// Two feeds, both with entries -> two minted files, ONE head.html carrying
// BOTH links in configured order.
#let cfg-mint-a = feed(
  path: "a.xml",
  title: "Feed A",
  base-url: "https://example.com",
  sources: (_stub-atom-struct,),
)
#let cfg-mint-b = feed(
  path: "b.xml",
  title: "Feed B",
  base-url: "https://example.org",
  sources: (_stub-atom-pub,),
)
#let plan-two = _mint-plan((cfg-mint-a, cfg-mint-b))
#assert.eq(plan-two.len(), 3)
#assert.eq(plan-two.map(m => m.path), ("a.xml", "b.xml", ".rheo/head.html"))
#assert(
  plan-two.at(2).data.contains(
    "<link rel=\"alternate\" type=\"application/atom+xml\" href=\"https://example.com/a.xml\" title=\"Feed A\">",
  ),
  message: "head.html must carry feed A's link",
)
#assert(
  plan-two.at(2).data.contains(
    "<link rel=\"alternate\" type=\"application/atom+xml\" href=\"https://example.org/b.xml\" title=\"Feed B\">",
  ),
  message: "head.html must carry feed B's link too — multiple feeds is the headline capability",
)

// A zero-entry feed among a real one is SKIPPED entirely — no minted XML
// file for it, and no autodiscovery link for it either.
#let cfg-mint-empty = feed(
  path: "empty-mint.xml",
  title: "Empty Mint Feed",
  base-url: "https://example.com",
  sources: (_empty-source,),
)
#let plan-mixed = _mint-plan((cfg-mint-one, cfg-mint-empty))
#assert.eq(plan-mixed.map(m => m.path), ("one.xml", ".rheo/head.html"))
#assert(
  not plan-mixed.at(1).data.contains("empty-mint"),
  message: "a zero-entry feed must not contribute a link either",
)
