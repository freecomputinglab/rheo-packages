// theme.typ — the "_pfx" story: idea registration, #window, `show ref:
// hyperlink` and #tags-of/#ideas-outline all reading the SAME non-default
// prefix root-prefix.typ configures ("note:", not "idea:") — four readers
// that must agree (lib.typ:169-170 `_prefix`/`_pfx`). Also exercises
// `theme:` and the granular colour parameters root-prefix.typ's
// `#show: rookery.with(..)` call sets — this file has nothing more to do
// for those beyond existing under that configuration; there is no
// programmatic way to assert a CSS custom property from a compile, so the
// coverage is "compiles under a non-default theme", same as `prefix`.
#import "../../src/lib.typ": idea, window, hyperlink, tags-of, ideas-outline

#idea("etal", title: [Et al.], tags: ("phd",), show-tags: true)[
  A note registered under the "note:" prefix, not "idea:" — its id is
  "note:etal", proving `#idea`'s registration read the configured prefix.
]

A plain reference: @note:etal — resolves under the custom prefix through
`show ref: hyperlink`, which `#show: rookery` already installed with no
extra rule needed here.

An explicit link: #hyperlink("etal")[see Et al.] — same prefix, same note,
reached without spelling the full "note:etal" id out.

A window of the same note: #window("etal")

#context [Et al.'s tags: #repr(tags-of("etal"))]

#ideas-outline(title: [Everything under "note:"], rookery-wide: true)
