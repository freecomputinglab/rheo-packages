// tags.typ — #note/#todo (pure sugar over `tags`, lib.typ:1591-1592),
// `#tags-of` (lib.typ:1609), and `#window(tags: .., match: "all")`
// (`match:` defaults to "any", already exercised by the second `#window`
// call below).
#import "../../src/lib.typ": note, todo, tags-of, window

#note("n-plain")[A plain sugar note — `#note` prepends the "note" tag.]
#todo("t-plain")[A plain sugar todo — `#todo` prepends the "todo" tag.]
#todo("t-both", tags: ("phd",))[
  A todo ALSO tagged phd — reads `("todo", "phd")` per `_dedup-tag`, todo
  first because `#todo` prepends its own tag ahead of the caller's.
]
#note("n-both", tags: ("phd",))[A note ALSO tagged phd, no todo.]

#context [
  n-plain is tagged: #repr(tags-of("n-plain")) \
  t-both is tagged: #repr(tags-of("t-both")) \
  a note that doesn't exist is tagged: #repr(tags-of("nope"))
]

// `tags:`/`match: "all"` — only a note carrying BOTH "todo" AND "phd":
// t-both, not t-plain (todo only) or n-both (phd only, no todo).
#window(tags: ("todo", "phd"), match: "all")

// `match: "any"` (the default) — todo OR phd, so three of the four above.
#window(tags: ("todo", "phd"))
