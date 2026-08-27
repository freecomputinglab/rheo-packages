// tags.typ — #tagged-idea (the factory `#note`/`#todo` are now built from,
// src/idea.typ),
// `#tags-of` (src/idea.typ), `#window(tags: .., match: "all")`
// (`match:` defaults to "any", already exercised by the second `#window`
// call below), and `show-tags:` — tags rendered as pills in the hat
// (`_permalink-tab`, lib.typ:550/1614), alongside `show-date:`.
#import "../../src/lib.typ": (
  idea, ideas-outline, tag-data, tag-value, tagged-idea, tags-of, window,
)

// `#note`/`#todo` are no longer package exports — `tagged-idea` is the
// factory, and these two lines are all a project needs to get them back.
#let note = tagged-idea("note")
#let todo = tagged-idea("todo")

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

// show-tags: true, alongside show-date: true — both a row of tag pills AND
// the date render in the same hat, in `_permalink-tab`'s fixed order (id,
// tags, date). Three tags so the row visibly wraps more than one pill.
#note(
  "n-hat",
  tags: ("draft", "phd", "review"),
  show-tags: true,
  show-date: true,
  created: datetime(year: 2025, month: 2, day: 1),
)[A note with tag pills AND a date in the same hat.]

// `updated:` distinct from `created:` — the hat shows `resolved-updated`, not
// `resolved-created` (lib.typ:1478-1492), so this hat reads 2026-03-15 despite
// having been created in 2024. Combined with show-tags: true since both are
// the same hat-rendering feature.
#idea(
  "n-updated",
  title: [Updated vs created],
  tags: ("phd",),
  created: datetime(year: 2024, month: 1, day: 1),
  updated: datetime(year: 2026, month: 3, day: 15),
  show-date: true,
  show-tags: true,
)[Minted 2024, updated 2026 — the hat shows 2026-03-15, not 2024-01-01.]

// #window(show-tags: true) — the pill row renders in a window's summary too,
// not just #idea's own card: `show-tags` threads into `_window-content` the
// same way `show-date` does (lib.typ:1904-1905).
#window("n-hat", show-tags: true)

// ---- 0.5.0: valued tags, the accessors, and a factory default -------------

// A VALUED tag. `priority: 1` is metadata a package reads, not a label a
// reader needs: both keys become `idea-tag-*` classes on the card and the
// heading, but only the FLAT one (`draft`, value `none`) renders a pill.
#idea(
  "valued",
  title: [A valued tag],
  tags: (draft: none, priority: 1),
  show-tags: true,
)[Carries `priority: 1` as tag metadata; only `draft` shows as a pill.]

// The three ways to read tags back. `tags-of` answers "what is this tagged"
// and hands over every key, valued ones included; `tag-value` fetches ONE
// value; `tag-data` hands over the whole store for every note at once, which
// is the accessor a package builds on — one registry read for the corpus
// rather than one per note.
#context [
  valued is tagged: #repr(tags-of("valued")) \
  its priority is: #repr(tag-value("valued", "priority")) \
  a key it lacks: #repr(tag-value("valued", "nope", default: 4)) \
  its whole store: #repr(tag-data().at("idea:valued"))
]

// `tagged-idea` can bind a DEFAULT VALUE for the tag it prepends, not just
// the tag. A caller naming that tag themselves wins outright — there is no
// deep merge between the factory's value and the caller's.
#let flagged = tagged-idea("flag", value: "yes")
#flagged("f-default")[Takes the factory's `flag: "yes"`.]
#flagged("f-override", tags: (flag: "no"))[Overrides it with `flag: "no"`.]
#context [
  f-default: #repr(tag-value("f-default", "flag")) \
  f-override: #repr(tag-value("f-override", "flag"))
]

// `filter:` receives the tag DICTIONARY as of 0.5.0, so an outline can select
// on a VALUE and not merely on a tag's presence.
#ideas-outline(title: [Priority 1 only], filter: t => t.at("priority", default: 9) <= 1)
