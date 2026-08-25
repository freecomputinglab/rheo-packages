// Bead rheo-packages-parity-qrd, rows 2/11/12. See ../rheo.toml for the
// row-by-row summary; ../../run.sh (well, ../run.sh) for the assertions.
//
// This page itself is undated, so its own raw entry from `spine()` (page
// "index.html") has neither `published` nor `updated` and is dropped by
// `resolve-entries`'s skip rule before ever reaching the XML — it is not
// explicitly filtered out here, and does not need to be.
#import "@rheo/feeds:0.1.1": feed, configure, spine

// The composition this bead's readme entry documents verbatim (adjusted from
// the bead's own sketch to this project's actual page names): a plain
// function wrapping the built-in `spine()` source, `.map`-ing over its
// output to replace specific entries by `page` — the replacement for the
// retired `rheo-feed-title`/`rheo-feed-updated` per-vertebra variables, with
// no `#set document` involved and no feeds-side "current page" state.
#let with-overrides(s) = spine()(s).map(e => if e.page == "a.html" {
  e + (
    title: "Override",
    published: datetime(year: 2026, month: 1, day: 1),
    updated: datetime(year: 2026, month: 6, day: 1),
  )
} else if e.page == "b.html" {
  e + (published: none)
} else {
  e
})

#configure(feeds: (
  feed(
    path: "feed.xml",
    title: "Override Demo",
    base-url: "https://override.example.org",
    // `author` deliberately omitted — must default to "Rheo" (row 2).
    sources: (with-overrides,),
  ),
))

= Override Demo

Two pages, `a.typ` and `b.typ`, both syndicated through one composed source
that overrides specific fields of `spine()`'s own output by page name.
