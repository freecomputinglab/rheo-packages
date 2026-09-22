// `breakpoint: none` — the package emits NO width-keyed CSS and the project
// owns the responsive behaviour in its own stylesheet. This page exists to
// hold that path down: nothing may be hoisted into its `<head>`, where every
// other page in this demo carries a breakpoint rule and a `reserve` padding
// rule.
#set document(title: "No breakpoint")
#import "@rheo/contents-panel:0.1.0": contents

#show: contents.with(breakpoint: none)

= Owning the breakpoint

A project with its own width-keyed rules for the panel's column would
otherwise state the same width twice — once as `breakpoint:` here and once in
its stylesheet — with nothing keeping the two in step, because a breakpoint
cannot be a custom property.

== What is not emitted

Four things: the rule that drops the panel into the flow, the one that hides
the hat, the one that shortens the list, and the `reserve` padding. All four
are width-keyed, so none of them can stand without a width to key them to.

== What still is

Everything that is not width-keyed: the panel itself, its anchors, its rows
and their ids, and the stylesheet the package ships.
