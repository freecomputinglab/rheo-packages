// blogfeed — derive a blog index/feed from Rheo's spine.
//
// A "post" is any spine vertebra that declares a document `date`
// (`#set document(date: ...)`); pages without one — the index itself and other
// chrome — drop out. `posts()` returns the dated vertebrae newest-first.
// `feed(...)` renders them as a `<ul class="post-list">`, with pluggable title,
// link, and right-hand "meta" column (a date, tag pills, whatever). `filter-bar`
// adds the optional tag filter that the bundled JS wires up. rheo auto-injects
// this package's CSS/JS via its `typst.toml` `[tool.rheo.html]`.

// ---- HTML element helpers --------------------------------------------------
#let div(_class, ..body) = html.elem("div", attrs: (class: _class), ..body)
#let span(_class, ..body) = html.elem("span", attrs: (class: _class), ..body)
#let button(_class, _filter, _tooltip, ..body) = html.elem(
  "button",
  attrs: (class: _class, data-filter: _filter, data-tooltip: _tooltip),
  ..body,
)

// ---- Spine → posts ---------------------------------------------------------

/// The document `date` of a spine entry, or `none` if it declares none.
#let post-date(entry) = entry.metadata.at("date", default: none)

/// The document `keywords` of a spine entry (used as tags), or `()`.
#let post-tags(entry) = entry.metadata.at("keywords", default: ())

/// The rheo build context for the current compile — `(spine-flat: …, …)`. rheo
/// binds the `rheo-context()` function inside each vertebra's scope but not
/// inside imported packages; the same data is on `sys.inputs`, which is reachable
/// everywhere. Falls back to an empty spine when built without rheo.
#let rheo-context() = sys.inputs.at("rheo-context", default: (spine-flat: ()))

/// Every dated spine vertebra, newest first. Undated pages (the index, chrome)
/// are dropped.
#let posts() = {
  let dated = rheo-context().spine-flat.filter(entry => post-date(entry) != none)
  dated.sorted(key: post-date).rev()
}

// ---- Date formatting -------------------------------------------------------

/// Format a start/end datetime pair as a human range. Within one month it reads
/// "July 13–19, 2026" (en dash, no spaces); across a month boundary it reads
/// "June 29 – July 5, 2026" (spaced en dash).
#let date-range(start, end) = {
  let long(d) = d.display("[month repr:long] [day padding:none]")
  let day(d) = d.display("[day padding:none]")
  let range = if start.month() == end.month() {
    long(start) + "–" + day(end)
  } else {
    long(start) + " – " + long(end)
  }
  range + ", " + str(start.year())
}

/// The seven-day range beginning on `monday` — a weeknotes-style week.
#let week-range(monday) = date-range(monday, monday + duration(days: 6))

// ---- Meta cells (right-hand column content for a row) ----------------------

/// A muted date/label cell, e.g. `date-cell(week-range(post-date(e)))`.
#let date-cell(body) = span("post-date")[#body]

/// A row of tag pills — one `.tag-label.tag-<id>` per tag. Pairs with
/// `filter-bar`, whose buttons the JS uses to toggle these.
#let tags-cell(tags) = span("post-tags")[
  #for tag in tags { span("tag-label tag-" + tag)[#tag] }
]

// ---- Rendering -------------------------------------------------------------

/// The optional filter bar. `tags` is an array of `(id: "WiG", tooltip: "…")`.
/// Renders `.filter-btn`s that the bundled JS wires up to toggle `.post-item`
/// visibility by their `data-tags`. HTML target only.
#let filter-bar(tags) = context if target() == "html" {
  div("filter-container")[
    #for t in tags {
      button("filter-btn tag-" + t.id, t.id, t.at("tooltip", default: t.id))[#t.id]
    }
  ]
}

/// Render the feed as `<ul class="post-list">`. HTML target only — paged
/// formats (PDF/EPUB) get nothing, since the spine itself carries the posts
/// there.
///
/// - `entries`:   rows to render (default: `posts()`).
/// - `title`:     `entry => content` for the left column (default: the
///                document title, falling back to the file handle).
/// - `href`:      `entry => link target` (default: `<handle>.html`).
/// - `meta`:      `entry => content` for the right column, or `none`
///                (e.g. `date-cell(...)` or `tags-cell(...)`).
/// - `data-tags`: `entry => space-joined tag string` for the filter JS, or
///                `none` to omit the attribute.
#let feed(
  entries: none,
  title: entry => entry.at("title", default: entry.handle),
  href: entry => entry.handle + ".html",
  meta: none,
  data-tags: none,
) = context if target() == "html" {
  let rows = if entries == none { posts() } else { entries }
  html.elem("ul", attrs: (class: "post-list"))[
    #for e in rows {
      let li-attrs = (class: "post-item")
      if data-tags != none { li-attrs.insert("data-tags", data-tags(e)) }
      html.elem("li", attrs: li-attrs)[
        #html.elem("a", attrs: (href: href(e), class: "post-link"))[
          #span("post-title")[#title(e)]
          #if meta != none { meta(e) }
        ]
      ]
    }
  ]
}
