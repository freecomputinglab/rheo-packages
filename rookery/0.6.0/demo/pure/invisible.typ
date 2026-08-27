// invisible.typ — `#show: rookery.with(invisible-tags: ..)` (src/template.typ),
// `_visible-tags` (src/state.typ), and the seven sites it reaches: the pill
// funnel `_permalink-tab` (src/permalink.typ), the four `idea-tag-<tag>` class
// lists (src/idea.typ, src/transclusion.typ), `#ideas-outline`'s row classes
// (src/outline.typ) and the generated `tags-color` rules (src/theme.typ).
//
// WHAT THIS ROOT ASSERTS, by grep from `demo/pure/Justfile`'s recipe: the string
// `private` appears NOWHERE in the output — no pill, no class, no CSS rule —
// while `draft` on the very same note keeps its pill, its class and its themed
// rule. And `#tags-of` still reports BOTH, which is the half that makes an
// invisible tag usable as an `exclude-tags` key: presentation goes, filtering
// stays.
//
// The complement to `excluded.typ`, and the pair is the motivating case for both
// features: a `protected` tag keeps its pill because in a dev build it tells the
// author something, while a `private` tag is invisibilized so private notes are
// indistinguishable from protected ones everywhere.
#import "../../src/lib.typ": idea, ideas-outline, rookery, tags-of, window

#show: rookery.with(
  invisible-tags: ("private",),
  // BOTH tags are themed, and that is the point of theming the invisible one:
  // `_tags-color-rules` must emit a rule for `draft` and none for `private`. A
  // rule for an invisible tag would be dead CSS and — worse — the one place the
  // tag name still reached the output of a build that asked it to leave no trace.
  theme: (tags-color: (private: rgb("#ff0000"), draft: rgb("#0000ff"))),
)

= Invisible tags

// `show-tags: true` puts the flat tags in the hat as pills. `draft` must appear;
// `private` must not, on this card or anywhere else.
#idea("b", tags: ("private", "draft"), show-tags: true)[BODYTEXT]

// The same note transcluded: `_flatten`'s IK rule rebuilds the card and its
// class list, so an invisible tag must drop out there too or a windowed note
// names a tag its own card hides.
#window("b", show-tags: true)

// Outline rows carry the classes as well.
#ideas-outline()

// FILTERING IS UNTOUCHED, which is the whole boundary of this feature: both
// names come back from `#tags-of`, and `#window(tags: "private")` below still
// selects the note — that is what lets the same tag be an `exclude-tags` key.
//
// REPORTED AS A COUNT AND A BOOLEAN, never by printing the tag NAME, and that is
// deliberate rather than coy. The assertion this whole root exists to make is
// "the string `private` appears NOWHERE in the output" — a flat `grep -c private
// build/invisible.html` returning 0. Echoing the name here to prove filtering
// works would put the one occurrence back and turn a clean invariant into one
// with a documented exception, which is exactly the kind of assertion that rots.
#context [tagcount=#tags-of("b").len()]
// `1`/`0` rather than the bool: MEASURED, `#(expr)` yielding a boolean renders as
// an empty `<code>` element in HTML export, so `filterable=true` never appeared
// and the assertion silently proved nothing.
#context [filterable=#if "private" in tags-of("b") { 1 } else { 0 }]

#window(tags: "private", show-tags: true)
