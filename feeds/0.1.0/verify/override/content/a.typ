// Fully overridden by content/index.typ's source composition (title AND
// both dates) — this page's own date below is deliberately never the value
// that ends up in feed.xml, proving the override wins over spine()'s own
// reading of `#set document(date: ..)`.
#set document(date: datetime(year: 2026, month: 3, day: 1))

= A

Overridden entry (row 12): its feed.xml entry gets a different `title` and
distinct, LATER `updated` than `published` (row 11).
