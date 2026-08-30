// Compresses the rookery's corpus ONCE per build, at the bundle root.
//
// rheo inlines this file verbatim at the bundle root when a project imports
// `@rheo/rookery-search`, so it runs once for the whole build with the finished
// note registry in scope — the same place `@rheo/rookery`'s own `.marrow.typ`
// mints note pages from. Everything it publishes is read back through
// `_corpus-cache` by `#search-index`, which runs once per emitted page; see that
// state's comment in `src/lib.typ` for the measurements that make this worth
// having (~118ms per page against ~15ms for the island's own JSON, on a
// 200-note corpus).
//
// WITHOUT RHEO there is no bundle root, this file never runs, the state keeps
// its `(:)` default and `#search-index` compresses inline as it always did.
// Nothing here is required for correctness — it is a cache, and a miss is only
// slower, never different.
#import "@rheo/rookery-search:0.1.0": _compress-corpus, _corpus-cache, _corpus-key
#import "@rheo/rookery:0.1.0": ideas

#context {
  // `page`, not `href`: `#note-path` is the site-root-relative output path and
  // is defined exactly when a note has a minted page, which is the same
  // condition `#search-index`'s own `href != none` filter tests from a
  // vertebra. `href` is depth-relative and has no meaning at the bundle root,
  // where there is no current page to measure from.
  let rows = ideas().filter(e => e.page != none)
  if rows.len() > 0 {
    // The DEFAULTS only. A project calling `#search-index(body-terms: 64)` gets
    // a key miss and compresses inline — correct, just not cached. Publishing
    // every combination a project might ask for would mean reading the call
    // sites' arguments back out of a state the marrow itself feeds, and a state
    // that depends on a state fed from the pages it feeds is the one shape
    // Typst's convergence cannot be trusted to settle.
    let body-terms = 48
    let df-ceiling = 40
    let terms = _compress-corpus(
      rows.map(e => e.body),
      body-terms: body-terms,
      df-ceiling: df-ceiling,
    )
    let by-id = (:)
    for (i, e) in rows.enumerate() { by-id.insert(e.id, terms.at(i)) }
    _corpus-cache.update(c => {
      let c = c
      c.insert(_corpus-key(body-terms, df-ceiling), by-id)
      c
    })
  }
}
