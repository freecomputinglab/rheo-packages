// Mints every feed registered via `configure(...)` (path (a) in lib.typ's own
// header comment) as an Atom asset, plus one shared `.rheo/head.html`
// autodiscovery fragment. Reachable purely by importing the package — no
// rheo.toml entry, no project file needed — because rheo inlines a package's
// `.marrow.typ` verbatim at the bundle root (see typst_manifest.rs in rheo
// core). Skipped automatically for the combined PDF target, which rejects
// `document()`/`asset()` outright — no target check of our own needed here.
//
// Reach the package's own code by package spec, never a relative import:
// this text is spliced into rheo's synthesized bundle root, so a relative
// path would resolve against the PROJECT root, not this file's own
// directory.
//
// A project that imports this package and never calls `configure` gets a
// COMPLETE no-op here: `_feeds` defaults to `()`, `_mint-plan` (lib.typ)
// returns `()` for an empty list, and the loop below then mints nothing at
// all — no XML, no `.rheo/head.html`.
//
// `#context` is required for two independent reasons that both land in the
// same block: `state(...).final()` always needs context to read, and
// `_mint-plan` itself needs context whenever a configured feed's `sources`
// includes `spine()`/`items()` (both call `query()`). One block satisfies
// both — the same shape rookery's own `.marrow.typ` uses for its own
// `_registry.final()` read.
//
// Minting itself is one shared loop, not duplicated logic: `_mint-plan`
// returns what to write rather than minting with `#asset(...)` itself,
// because `asset` is only a bound name at bundle root (this text, or a
// project's own bundle-root marrow calling `emit(...)`) — lib.typ is
// ordinary package code and cannot assume it. See `_mint-plan`'s own doc
// comment in lib.typ for the full reasoning; `emit(...)` (lib.typ's
// direct-call entry point, path (b)) shares this exact loop.
#import "@rheo/rssfeed:0.1.0": _feeds, _mint-plan

#context {
  for m in _mint-plan(_feeds.final()) {
    asset(m.path, m.data)
  }
}
