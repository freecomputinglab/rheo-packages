#import "@rheo/feeds:0.1.0": feed, configure, spine
#import "@rheo/rookery:0.3.0": ideas

// A project-level @rheo/feeds SOURCE built on rookery's `ideas(tags:)` — with NO
// import coupling between the two packages. A source is just a plain
// function `cfg => (entries)` (see @rheo/feeds's src/lib.typ, "source — a
// plain function, not a registry"); `ideas()` is called HERE, by the
// PROJECT, not by @rheo/feeds itself. @rheo/feeds never imports rookery, and
// rookery never imports it — this whole feed is one project-authored
// function that both happen to compose with.
//
// Field names below come from rookery's `ideas()` doc comment (`src/lib.typ`,
// "#ideas — every registered note, as data"): `page` is the note's minted
// page, site-root-relative, or `none` when nothing is minted (plain `typst
// compile`, or the combined PDF target); `text` is the title as a plain
// string; `minted`/`updated` are `datetime` or `none`; `tags` is the
// author's own tag list. The filter drops anything the entry model
// could not otherwise date or link — same skip rule `resolve-entries` itself
// applies, just checked earlier so an unminted/undated note never becomes a
// candidate row at all.
//
// WRAPPED IN PARENS, deliberately: without them, the chained `.filter(...)`/
// `.map(...)` on their own lines fall outside the `#let`'s single hash-code
// expression and back into markup — MEASURED, they rendered as a literal
// paragraph of code text on this page, and `from-ideas` silently returned
// `ideas()`'s raw rows (whose `title` is CONTENT, not a string), which is
// what tripped the "entry is missing a non-empty `title`" assert. The
// parens keep the whole chain inside one expression regardless of line
// breaks.
#let from-ideas(tags: none, match: "any") = cfg => (
  ideas(tags: tags, match: match)
    .filter(e => e.page != none and e.updated != none)
    .map(e => (
      id: e.id,
      title: e.text,
      page: e.page,
      updated: e.updated,
      published: e.minted,
      categories: e.tags,
    ))
)

// ONE configure(...) call, registering BOTH feeds. Different `title` AND
// `author` per feed — proof both are per-feed, not document-global.
#configure(feeds: (
  feed(
    path: "feed.xml",
    title: "Rssfeed Demo — Posts",
    base-url: "https://demo.example.org",
    author: "The Editors",
    // Restricted to the three dated posts under posts/, by the spine
    // entry's own handle — depth-independent: posts/deep/three.typ's handle
    // is "posts:deep:three", still caught by the same prefix check as
    // posts/one.typ's "posts:one".
    sources: (spine(filter: e => e.handle.starts-with("posts:")),),
  ),
  feed(
    path: "notes.xml",
    title: "Rssfeed Demo — Notes",
    base-url: "https://demo.example.org",
    author: "The Rookery",
    sources: (from-ideas(tags: "note"),),
  ),
))

= Rssfeed demo

Two Atom feeds come out of this one small site, built from disjoint
subsets of it:

- `feed.xml` — the three dated posts under `posts/`, selected by filtering
  the spine on each vertebra's handle.
- `notes.xml` — the notes tagged `note` on the notes page, sourced from
  `@rheo/rookery`'s `ideas(tags:)` primitive rather than @rheo/feeds's own
  `<feeds:item>` beacon protocol.
