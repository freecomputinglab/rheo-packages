// Partially overridden by content/index.typ's source composition: only
// `published` is stripped (set to `none`), leaving `title` and `updated` as
// spine() itself reported from this page's own `#set document(date: ..)`.
// Proves an entry with only `updated` emits no `<published>` at all (row 11).
#set document(date: datetime(year: 2026, month: 4, day: 15))

= B

Partially overridden entry (row 11): `published` is cleared, `updated`
survives from this page's own date.
