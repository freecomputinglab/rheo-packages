// Same template, same arguments as index.typ — and they MUST match. Prefix and
// theme are each one document-wide value (last writer wins), so two vertebrae
// asking for different themes get whichever the spine ends on, not one each.
// A vertebra that omitted the template entirely would still get `note:` ids
// and this theme; what it would lose is the `show ref:` rule.
#import "@rheo/rookery:0.1.0": rookery, view
#show: rookery.with(
  prefix: "note",
  theme: (
    link-color: "rgba(230, 140, 0, 0.16)",
    fold-color: "rgba(255, 190, 40, 0.07)",
    date-color: rgb("#a08a5a"),
  ),
)

= Guide intro

// `#show: rookery` installs ref-rule, so `@note:rookery` renders the note's
// title, linked, cross-page too. See demo/pure/b.typ for the same thing wired
// up by hand (`#show ref: ref-rule`), on the default `idea:` prefix.
Terse form, now that ref-rule is applied: @note:rookery

A transcluded view of the same note, cross-page:

#view("rookery")

A truncated view, `limit: 1`, dropping the second paragraph:

#view("multi", limit: 1)

Folded views — same block, just closed. Click a summary to open it; only the
`[note:...]` permalink leaves the page. `limit:` still applies to what an
opened one reveals:

#view(("rookery", "tagged", "n1"), folded: true)

#view("multi", limit: 1, folded: true)
