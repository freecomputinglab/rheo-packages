// blogfeed — derive a blog index/feed from Rheo's spine.
//
// A "post" is any spine vertebra that declares a document `date`
// (`#set document(date: ...)`); pages without one — the index itself and other
// chrome — drop out. `posts()` returns the dated vertebrae newest-first.
// `blogfeed(...)` renders them as a `<ul class="post-list">`, with pluggable title,
// link, and right-hand "meta" column (a date, tag pills, whatever). `filter-bar`
// adds the optional tag filter that the bundled JS wires up. rheo auto-injects
// this package's CSS/JS via its `typst.toml` `[tool.rheo.html]`.

#import "core.typ": entries

// ---- HTML element helpers --------------------------------------------------
#let div(_class, ..body) = html.elem("div", attrs: (class: _class), ..body)
#let span(_class, ..body) = html.elem("span", attrs: (class: _class), ..body)
#let button(_class, _filter, _tooltip, ..body) = html.elem(
  "button",
  attrs: (class: _class, data-filter: _filter, data-tooltip: _tooltip),
  ..body,
)

// ---- Spine → posts ---------------------------------------------------------

/// The document `date` of a merged row (see `posts()`), or `none`.
#let post-date(entry) = entry.at("date", default: none)

/// The document `keywords` of a merged row (see `posts()`), used as tags, or
/// `()`.
#let post-tags(entry) = entry.at("keywords", default: ())

/// Every dated spine vertebra, newest first, as a spine entry merged with its
/// resolved document metadata. Undated pages (the index, chrome) are dropped.
///
/// Pattern A (this repo's `CLAUDE.md`): `ctx` is the ONLY way this can read
/// document metadata — a package's scope cannot see rheo's per-vertebra
/// injection, and `metadata-of` is a function so it cannot travel through
/// `sys.inputs`. Unlike `sitemap`'s own `ctx: none` guard, a feed rendering
/// nothing looks identical to a site with no posts, so this asserts instead of
/// silently returning `()`. Must be called inside `#context`.
#let posts(ctx: none) = {
  assert(
    type(ctx) == dictionary and "metadata-of" in ctx,
    message: "@rheo/sitemap: blogfeed needs the per-file `rheo-context` injected by "
      + "Rheo, for the document dates it sorts on. Call it as "
      + "`#blogfeed(ctx: rheo-context())` and compile the project with Rheo "
      + "(https://rheo.ohrg.org).",
  )
  let meta = ctx.metadata-of
  entries()
    .map(e => e + meta(e.handle))
    .filter(e => post-date(e) != none)
    .sorted(key: post-date)
    .rev()
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
#let date-cell(body) = span("sitemap-post-date")[#body]

/// A row of tag pills — one `.sitemap-tag-label.tag-<id>` per tag. Pairs with
/// `filter-bar`, whose buttons the JS uses to toggle these.
#let tags-cell(tags) = span("sitemap-post-tags")[
  #for tag in tags { span("sitemap-tag-label tag-" + tag)[#tag] }
]

// ---- Rendering -------------------------------------------------------------

/// The optional filter bar. `tags` is an array of `(id: "WiG", tooltip: "…")`.
/// Renders `.sitemap-filter-btn`s that the bundled JS wires up to toggle
/// `.sitemap-post-item` visibility by their `data-tags`. HTML target only.
///
/// `colors`: optional array of hex strings (e.g. `("#1976d2", "#e63946")`)
/// overriding the default click-order palette, in order — `colors.at(0)`
/// replaces the 1st-click color, `colors.at(1)` the 2nd, and so on. There
/// are 6 click-order slots in total; pass fewer than 6 to leave the rest at
/// their default color, more than 6 and the extras are unused.
#let filter-bar(tags, colors: none) = context if target() == "html" {
  if colors != none and colors.len() > 0 {
    let decls = colors
      .enumerate()
      .map(((i, c)) => "--blogfeed-order-" + str(i + 1) + ": " + c + ";")
      .join(" ")
    html.elem("style")[#(":root { " + decls + " }")]
  }
  div("sitemap-filter-container")[
    #for t in tags {
      button("sitemap-filter-btn tag-" + t.id, t.id, t.at("tooltip", default: t.id))[#t.id]
    }
  ]
}

/// Render the feed as `<ul class="sitemap-post-list">`. HTML target only — paged
/// formats (PDF/EPUB) get nothing, since the spine itself carries the posts
/// there.
///
/// - `ctx`:       the per-file `rheo-context()`, needed to build the default
///                `entries` (`posts(ctx: ctx)`) — see `posts()`. Not needed
///                when `entries` is passed explicitly.
/// - `entries`:   rows to render (default: `posts(ctx: ctx)`).
/// - `title`:     `entry => content` for the left column (default: the
///                document title, falling back to the file handle).
/// - `href`:      `entry => link target` override, or `none` (default) to let
///                rheo's own link rule resolve the entry's handle.
/// - `meta`:      `entry => content` for the right column, or `none`
///                (e.g. `date-cell(...)` or `tags-cell(...)`).
/// - `data-tags`: `entry => space-joined tag string` for the filter JS, or
///                `none` to omit the attribute.
#let blogfeed(
  ctx: none,
  entries: none,
  title: entry => entry.at("title", default: entry.handle),
  // `none` means: emit `#link(<handle>)` and let rheo's own `rheo-link-rule`
  // resolve it — format- and depth-correct, and validated against the spine.
  // Pass a closure to override with an explicit href string.
  href: none,
  meta: none,
  data-tags: none,
) = context if target() == "html" {
  let rows = if entries == none { posts(ctx: ctx) } else { entries }
  html.elem("ul", attrs: (class: "sitemap-post-list"))[
    #for e in rows {
      let li-attrs = (class: "sitemap-post-item")
      if data-tags != none { li-attrs.insert("data-tags", data-tags(e)) }
      let inner = [
        #span("sitemap-post-title")[#title(e)]
        #if meta != none { meta(e) }
      ]
      html.elem("li", attrs: li-attrs)[
        #span("sitemap-post-link")[
          #if href == none { link(label(e.handle), inner) } else {
            html.elem("a", attrs: (href: href(e)), inner)
          }
        ]
      ]
    }
  ]
}
