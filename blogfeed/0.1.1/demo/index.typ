#import "@rheo/blogfeed:0.1.1": feed, filter-bar, tags-cell, post-tags

= blogfeed demo

The list below is derived from the spine: every `post-*.typ` sets a document
`date` and `keywords`, so it shows up here newest-first, tagged. This page sets
no date, so it drops out. Click a tag to filter.

#let tags = (
  (id: "typ", tooltip: "Typst"),
  (id: "read", tooltip: "Reading"),
)

#filter-bar(tags)

#feed(
  meta: e => tags-cell(post-tags(e)),
  data-tags: e => post-tags(e).join(" "),
)
