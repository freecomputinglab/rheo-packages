// idea-body.typ — `#idea-body` (lib.typ:1985), the pure function underneath
// `@rheo/rookery-search`'s preview pane: no `ctx:`, nothing rheo-specific, so
// it belongs in this native-Typst demo like everything else here.
//
// "w-outer" (windows.typ), not "etal": `#idea-body`'s `name` resolves against
// whatever `prefix:` this DOCUMENT has configured (default "idea:" here), and
// "etal" only exists under root-prefix.typ's own `prefix: "note"` — a
// different compilation unit entirely (see that file's header for why
// prefix/theme get a second root). "w-outer" is a real note in THIS
// document, already kept four blocks long specifically so `limit:` has
// something to truncate (windows.typ:20) — reused here for the same reason.
#import "../../src/lib.typ": idea-body

#context [
  w-outer's body in full, all four blocks: #idea-body("w-outer")

  w-outer's body, truncated to its first two blocks: #idea-body("w-outer", limit: 2)
]
