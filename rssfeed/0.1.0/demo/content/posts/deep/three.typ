#set document(date: datetime(year: 2026, month: 3, day: 20))

= Post Three

Nested one directory deep (`posts/deep/three.typ`, handle
`posts:deep:three`), to prove `spine()`'s entry is built from the
vertebra's HANDLE, not its directory depth: this page reaches `feed.xml`
through the exact same `e.handle.starts-with("posts:")` filter as its two
top-level siblings.
