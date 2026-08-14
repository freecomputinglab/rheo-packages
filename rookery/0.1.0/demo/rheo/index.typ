#import "@rheo/rookery:0.1.0": view

= Ideas demo

A basic nav, since this package installs no template of its own — pair it
with `@rheo/sidebar` for real site navigation.

- #link("index.html")[Home]
- #link("notes.html")[Notes]
- #link("guide/intro.html")[Guide: Intro]

== A folded view of multiple notes

`#view(..., folded: true)` renders a compact index instead of transcluding
each note's body:

#view(("pinned", "tagged"), folded: true)
