#set document(
  title: [Two, #emph[emphatically]],
  date: datetime(year: 2026, month: 2, day: 12),
)

= Post Two

The second post, still at the top level of `posts/`. Its authored title is
BRACKET CONTENT containing markup (`#emph[..]`), not a plain string — proving
`spine()`'s `_plain-text` flattener actually flattens markup, not just reads
a already-string field. The filename-derived fallback would have been "Two".
