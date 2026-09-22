// Three levels, with the default `separator: heading`. TWO rungs are drawn and
// the third is FLATTENED into the second rather than dropped — a reader cannot
// jump to an entry that is not listed. The `===` rows below must appear, as
// subsection rows, numbered as siblings of the `==` they follow.
#set document(title: "Nested demo")
#import "@rheo/contents-panel:0.1.1": contents

#show: contents

= First

Filler under the first top-level section, long enough that the section
occupies a band of the page rather than a line of it.

== One point one

Filler beneath a second-level heading.

=== One point one point one

A THIRD-level heading. With the earlier behaviour, which kept only the two
shallowest depths a page used, this row vanished from the box with no error
anywhere — the section was unreachable from the contents and nothing said so.

=== One point one point two

A second third-level heading, so the flattening is visible as a run rather
than as a single row that could be a coincidence.

== One point two

Back up to the second level, which must reset the numbering beneath it.

= Second

A second top-level section, so the top rung advances and everything below it
starts again.

== Two point one

Filler beneath it.

=== Two point one point one

And a third level under the second top-level section.
