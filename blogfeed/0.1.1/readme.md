# @rheo/blogfeed

Derive a blog index/feed from a [Rheo](https://rheo.ohrg.org) spine, with an
optional client-side tag filter. Ships the Typst API, the post-list/filter CSS,
and the filtering JS — all auto-injected into the HTML target.

A "post" is any spine vertebra that declares a document `date`:

```typst
#set document(title: [My post], date: datetime(year: 2026, month: 5, day: 20))
```

Pages without a `date` (your index, other chrome) are ignored. `posts()` returns
the dated vertebrae newest-first; `feed()` renders them.

## Dated feed (e.g. weeknotes)

Each row shows a title and a date range on the right:

```typst
#import "@rheo/blogfeed:0.1.1": feed, post-date, week-range, date-cell

#feed(meta: e => date-cell(week-range(post-date(e))))
```

`week-range(monday)` formats the seven days from `monday` as
`July 13–19, 2026` (or `June 29 – July 5, 2026` across a month boundary). For an
arbitrary span use `date-range(start, end)`.

## Tagged feed with filtering (e.g. a research index)

Give each post `keywords`, then render a filter bar plus tag pills. The bundled
JS toggles posts by their `data-tags`, and colors each active filter (and its
matching tag pills) by click order — 1st clicked, 2nd clicked, etc., cycling
through 6 slots. Pass `colors:` to `filter-bar` to override that palette with
your own hex strings, in click-order:

```typst
#import "@rheo/blogfeed:0.1.1": feed, filter-bar, tags-cell, post-tags

#let tags = (
  (id: "WiG", tooltip: "Writing in general"),
  (id: "DiH", tooltip: "Dialectics in history"),
)

#context if target() == "html" {
  filter-bar(tags, colors: ("#1976d2", "#e63946"))
  feed(
    meta: e => tags-cell(post-tags(e)),
    data-tags: e => post-tags(e).join(" "),
  )
}
```

## API

| Symbol | Description |
| --- | --- |
| `posts()` | Dated spine vertebrae, newest-first. Call inside `context`. |
| `feed(entries:, title:, href:, meta:, data-tags:)` | Render `<ul class="post-list">`. HTML target only; all params are `entry => …` callbacks with sensible defaults. |
| `filter-bar(tags, colors:)` | Render the `.filter-btn` bar from `(id, tooltip)` records. `colors` optionally overrides the click-order palette with hex strings. |
| `tags-cell(tags)` / `date-cell(body)` | Right-hand meta cells (tag pills / muted label). |
| `post-date(entry)` / `post-tags(entry)` | Read an entry's `date` / `keywords`. |
| `week-range(monday)` / `date-range(start, end)` | Human date-range strings. |

Also exported: the small element helpers `div`, `span`, `button`.

## Styling

The stylesheet reads your site's `--text-color`, `--grey-color`,
`--dark-grey-color`, and `--primary-color` when present (falling back to neutral
defaults), and exposes `--blogfeed-*` variables for finer control. Override any
of them in your project's own stylesheet.

## Demo

```sh
cd demo && rheo compile . --html && open build/html/index.html
```
