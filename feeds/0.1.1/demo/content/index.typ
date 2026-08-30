#import "@rheo/feeds:0.1.1": feed, configure, feeds-modal, mail-icon, spine

// ONE configure(...) call, registering the one feed this demo ships.
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
))

= Feeds demo

// The subscribe modal, the one part of this package that emits page markup.
// Called HERE and nowhere else in this demo — `posts/one.typ` deliberately
// does not call it, so `check.sh` can assert that a page which merely
// imports the package carries no modal markup, no `@layer feeds-modal` and
// no script. That negative is the whole promise of the feature: opt-in by
// call.
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

One Atom feed comes out of this small site:

- `feed.xml` — the three dated posts under `posts/`, selected by filtering
  the spine on each vertebra's handle.

// A SECOND feed used to live here too — `notes.xml`, sourced from
// `@rookery/core`'s (formerly `@rheo/rookery`'s) `ideas(tags:)` primitive
// rather than this package's own `<feeds:item>` beacon protocol, and the
// more interesting half of what this demo showed: a minted note page's
// FULL CONTENT transcluded into a feed entry via `content: "html"`. It was
// dropped when the rookery family moved to its own repository
// (`freecomputinglab/rookery`) and this repo stopped carrying a working
// copy of it. See this package's readme, "Sourcing from another package",
// for the worked example in prose, and revisit once a project here depends
// on `@rookery/core` again.
