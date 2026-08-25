#set document(date: datetime(year: 2026, month: 3, day: 20))

= Post Three

Nested one directory deep (`posts/deep/three.typ`, handle
`posts:deep:three`), to prove `spine()`'s entry is built from the
vertebra's HANDLE, not its directory depth: this page reaches `feed.xml`
through the exact same `e.handle.starts-with("posts:")` filter as its two
top-level siblings.

A #link("./../two.html")[relative link to Post Two], written the way any page
links a sibling. It is here for the feed rather than for the page: transcluded
into `feed.xml`, a reader would resolve it against the READER's host and land
nowhere, unless the `<content>` carries an `xml:base`. `demo/check.sh` asserts
that the base on this entry is THIS page's own URL — one directory deep — and
not the site root, because that is the only base against which `./../two.html`
resolves correctly.
