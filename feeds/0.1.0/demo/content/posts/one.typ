#set document(
  title: "Custom Post Title",
  date: datetime(year: 2026, month: 1, day: 5),
)

= Post One

The first of three dated posts under `posts/`, syndicated into `feed.xml`
via `spine()`'s own reading of this page's `#set document(date: ..)` — and,
per bead rheo-packages-mxqa, its `#set document(title: ..)` too: a PLAIN
STRING title ("Custom Post Title") distinct from the filename-derived
fallback ("One") `spine()` used to be stuck with.
