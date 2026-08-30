#import "@rheo/feeds:0.1.0": feed, configure, feeds-modal, mail-icon, spine
#import "@rheo/rookery:0.1.0": ideas

// A project-level feeds SOURCE built on rookery's `ideas(tags:)` — with NO
// import coupling between the two packages. A source is just a plain
// function `cfg => (entries)` (see @rheo/feeds's src/lib.typ, "source — a
// plain function, not a registry"); `ideas()` is called HERE, by the
// PROJECT, not by @rheo/feeds itself. @rheo/feeds never imports rookery, and
// rookery never imports it — this whole feed is one project-authored
// function that both happen to compose with.
//
// Field names below come from rookery's `ideas()` doc comment (`src/lib.typ`,
// "#ideas — every registered note, as data"): `href` is the note's minted
// page, or `none` when nothing is minted (plain `typst compile`, or the
// combined PDF target); `text` is the title as a plain string;
// `created` is a `datetime` or `none`; `tags` is the author's own tag
// list. NOTE the two packages spell the same thing differently — rookery's
// row calls it `href`, the feeds entry model calls it `page` — which is the
// whole reason this function exists: reshaping one vocabulary into the other
// is the project's job, not either package's. Getting it wrong is not subtle,
// but it is not caught until build time: reading a key a row does not have is
// `dictionary does not contain key "page"`, thrown from inside
// `resolve-entries` where the source was called.
//
// The filter drops anything the entry model could not otherwise date or
// link — same skip rule `resolve-entries` itself applies, just checked earlier
// so an unminted/undated note never becomes a candidate row at all.
//
// WRAPPED IN PARENS, deliberately: without them, the chained `.filter(...)`/
// `.map(...)` on their own lines fall outside the `#let`'s single hash-code
// expression and back into markup — MEASURED, they rendered as a literal
// paragraph of code text on this page, and `from-ideas` silently returned
// `ideas()`'s raw rows (whose `title` is CONTENT, not a string), which is
// what tripped the "entry is missing a non-empty `title`" assert. The
// parens keep the whole chain inside one expression regardless of line
// breaks.
//
// `href` is DEPTH-RELATIVE, and this source is evaluated at bundle root where
// the ambient `state("rheo-handle")` is not the site root — MEASURED: the raw
// value came back as "../ideas/alpha.html", which the entry model then joined
// into "https://demo.example.org/../ideas/alpha.html". So the leading `../`
// run is stripped here to get the site-root-relative path `page` wants.
//
// This is project-side reshaping, which is the whole job of a source function,
// but it is worth knowing it is load-bearing rather than defensive: without it
// every note's feed URL is wrong, and nothing but a link-checker would say so.
#let root-relative(h) = {
  let out = h
  while out.starts-with("../") { out = out.slice(3) }
  out
}

#let from-ideas(tags: none, match: "any") = cfg => (
  ideas(tags: tags, match: match)
    .filter(e => e.href != none and e.created != none)
    .map(e => (
      id: e.id,
      title: e.text,
      // rookery calls it `href`; the feeds entry model calls it `page`.
      page: root-relative(e.href),
      updated: e.created,
      published: e.created,
      // rookery's `body` is the note as plain text. It becomes the entry's
      // `summary` because this feed cannot carry real content — see the
      // `content: none` note on the notes feed below.
      summary: e.body,
      categories: e.tags,
    ))
)

// ONE configure(...) call, registering BOTH feeds. Different `title` AND
// `author` per feed — proof both are per-feed, not document-global.
#configure(feeds: (
  feed(
    path: "feed.xml",
    title: "Feeds Demo — Posts",
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
    title: "Feeds Demo — Notes",
    base-url: "https://demo.example.org",
    author: "The Rookery",
    // `content: none` is REQUIRED here, and not a preference. A rookery note's
    // page is MINTED — it is an `#asset(..)`, not a compiled vertebra — and
    // `<rheo-content>` can only transclude compiled PAGES: rheo's own
    // transclusion pass builds its page map from the non-asset, `.html`
    // entries of the bundle (`crates/core/src/build.rs`, the
    // `assets.contains(&path_str) || !path_str.ends_with(".html")` filter).
    // MEASURED, before this line existed: `asset 'notes.xml': <rheo-content>
    // references unknown page '../ideas/alpha.html'; available output paths
    // include: index.html, notes.html, posts/...` — the five vertebrae and
    // none of the minted note pages.
    //
    // So these entries carry a `summary` (rookery's plain-text `body`, mapped
    // in `from-ideas` above) instead. Syndicating a minted page's full content
    // needs a rheo-core change, not a package or project one.
    content: none,
    sources: (from-ideas(tags: "note"),),
  ),
))

= Feeds demo

// The subscribe modal, the one part of this package that emits page markup.
// Called HERE and nowhere else in this demo — `notes.typ` deliberately does
// not call it, so `check.sh` can assert that a page which merely imports the
// package carries no modal markup, no `@layer feeds-modal` and no script.
// That negative is the whole promise of the feature: opt-in by call.
#feeds-modal(
  feed-desc: [Pull each new post into an #html.elem("a", attrs: (
    href: "https://aboutfeeds.com",
    target: "_blank",
    rel: "noopener",
  ))[RSS/Atom reader].],
  options: (
    (
      icon: mail-icon(),
      label: "Newsletter",
      href: "mailto:demo@example.org?subject=subscribe",
      desc: [Email us to subscribe.],
    ),
  ),
)

Two Atom feeds come out of this one small site, built from disjoint
subsets of it:

- `feed.xml` — the three dated posts under `posts/`, selected by filtering
  the spine on each vertebra's handle.
- `notes.xml` — the notes tagged `note` on the notes page, sourced from
  `@rheo/rookery`'s `ideas(tags:)` primitive rather than `@rheo/feeds`'s own
  `<feeds:item>` beacon protocol.
