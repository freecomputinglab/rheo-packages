// `#filter-panel` — a panel over the ideas carrying ONE tag, with a hand-named pill
// per tag.
//
// WHY IT IS NOT MORE ARGUMENTS ON `#panel`. That widget facets on PROJECTED FIELDS:
// `facets: ("status", "kind")` reads `r.at(field)` and mints one pill per value any row
// carries. This is the other shape — the rows are "every note tagged `todo`", the pills
// are a list of TAG NAMES the caller writes down, and the same tags come back as chips
// on the row. Neither half is expressible as a facet, and bending `#panel` into both
// would leave one function with two mutually exclusive halves.
//
// IT READS `ideas()` ITSELF, which departs from `panel.typ`'s own banner ("PANELS TAKE
// AN INDEX, THEY NEVER BUILD ONE"), and the departure is the point rather than an
// oversight. That rule exists to stop a per-view walk of the value store; the cost of
// keeping it here would be a wrapper in every consuming site, which is exactly what
// this export was asked for to delete — a site should import one name and call it. The
// walk is one `ideas()` per panel, and a caller that already has rows (because it built
// them from another package's projection) passes them through `rows:` and no walk
// happens at all.
//
// THE ROW IS `#idea-row`, from @rheo/rookery core. Nothing about the row's markup or
// the chip's shape is written here — that function exists so this file cannot be a
// fourth copy of it.

#import "base.typ": *
#import "@rheo/rookery:0.6.0": idea-row, ideas

// SHORT AND NUMERIC, matching @rheo/rookery-timeline's own `_fmt-day` exactly —
// `27.8.26`, unpadded — so a site running both packages' lists on one page does not
// show two spellings of the same kind of date. Written out here rather than imported,
// because this package has no edge to that one and must not grow one for a format
// string.
#let _fmt-day(d) = d.display("[day padding:none].[month padding:none].[year repr:last_two]")

// The ISO form for the `datetime` attribute — zero-padded, machine-facing, and
// deliberately not what the cell shows.
#let _iso(d) = d.display("[year]-[month]-[day]")

// A row's own tag NAMES, whatever shape rookery handed them in. `ideas()` gives
// `tags` as an array of names; `values: true` adds `tags-dict`, whose KEYS are the
// same names. Reading either means a caller can pass rows from either call.
#let _tags-of(r) = {
  let d = r.at("tags-dict", default: none)
  if d != none { return d.keys() }
  let t = r.at("tags", default: ())
  if type(t) == dictionary { t.keys() } else { t }
}

#let filter-panel(
  // Only ideas carrying this tag become rows. `none` means every idea.
  tag: none,
  // Tag names, in order. Each becomes one pill AND, where a row carries it, one chip.
  // AUTHORED rather than derived, which is the difference from `#panel`'s facets.
  pills: (),
  // Pre-computed rows. When given, `tag:` is not consulted and no registry walk
  // happens — this is the composition hook: a caller can hand in rows built from
  // another package's projection (a log-derived queue, say) and pass a `when:` adapter
  // that reads whatever field that projection put the date in.
  rows: none,
  // THE DATE IS AN ADAPTER, not a field name, and it is what lets one panel answer two
  // questions. The default is rookery core's own `created` — when the note was written
  // — which is what an index of open work wants. A caller ordering by something derived
  // passes its own reader. Returns a `datetime` or `none`.
  when: r => r.at("created", default: none),
  // HOW A TAG READS, in a pill and in a chip. The default turns a hyphen into a space,
  // because a hyphen is a naming convention rather than something a reader should have
  // to see. A caller whose tags share a namespacing prefix strips it here:
  //
  //   tag-display: t => if t.starts-with("epic-") { t.slice(5) } else { t }
  //
  // DISPLAY ONLY, and that is the whole contract: the row's `idea-tag-<tag>` class,
  // the chip's own class and the pill's `data-panel-tag` all keep the REAL tag, so a
  // project's theme rules and this package's script are untouched by anything written
  // here. Two tags that display the same string produce two pills reading alike, which
  // the panel cannot detect and will not warn about — that is the caller's to avoid.
  //
  // NOT `label:`, which is what this argument was called for about an hour: `label` is
  // already a rookery ROW FIELD (a note's own name, read three lines below as
  // `r.at("label")`), so one word meant two things inside one function.
  tag-display: t => t.replace("-", " "),
  // HOW MANY ROWS SHOW BEFORE THE LIST SCROLLS, and `none` means IT DOES NOT: the
  // list flows down the page for as long as there are matching rows. Not a data cap
  // either way — every row is in the markup regardless, and the cap is only a height.
  //
  // A scroll box earns its place in a widget a reader opens to find one thing (the
  // panel's own ancestor is a search dropdown). It does not earn it in a page's main
  // list, where it cuts a row in half and hides the rest behind a gesture nothing
  // advertises — which is the same argument `#upcoming` makes for having no cap at all.
  visible: 8,
  placeholder: "Filter",
  noun: "ideas",
  empty: [Nothing here.],
  // The text input's haystack, per row. Defaults to label + name + body — searching the
  // BODY is what finds a note by a phrase inside it rather than by its title.
  haystack: none,
  // Override the whole row. The default is `#idea-row`; this exists for the caller with
  // a genuinely different row, not as the ordinary path.
  render: none,
) = context {
  let hay = if haystack != none { haystack } else {
    r => (
      r.at("label", default: ""),
      r.at("name", default: ""),
      r.at("body", default: ""),
    ).filter(s => s != "" and s != none).join(" ")
  }

  let rows = if rows != none { rows } else { ideas(tags: tag, values: true) }

  // NEWEST FIRST, UNDATED LAST, done as a PARTITION rather than by reversing a sorted
  // list. Reversing would put the undated rows — which sort last ascending — at the
  // TOP, where they read as the most recent thing on the page. Inverting the key would
  // work too; a partition says what it means in one line.
  let stamp = r => {
    let d = when(r)
    if d == none { none } else { d.display("[year][month][day]") }
  }
  let dated = rows.filter(r => stamp(r) != none).sorted(key: stamp).rev()
  let undated = rows.filter(r => stamp(r) == none)
  let rows = dated + undated

  // A PILL WITH NO ROWS IS A BUTTON THAT CAN ONLY EVER RETURN NOTHING, and unlike
  // `#panel`'s derived facet values this list is authored, so a typo or a tag nothing
  // carries yet would ship as dead chrome. Dropped, in the caller's own order.
  let carried = pills.filter(t => rows.any(r => _tags-of(r).contains(t)))

  let draw = if render != none { render } else {
    r => {
      let d = when(r)
      let mine = carried.filter(t => _tags-of(r).contains(t))
      idea-row(
        when: if d == none { none } else { _fmt-day(d) },
        iso: if d == none { none } else { _iso(d) },
        title: r.at("label", default: r.at("name", default: "")),
        href: r.at("href", default: none),
        tags: _tags-of(r),
        badges: mine.map(t => (text: tag-display(t), tag: t)),
        // The panel's own row hook, kept so the script and the stylesheet reach these
        // rows exactly as they reach `#panel`'s.
        extra: ("panel-row",),
        attrs: (
          "data-panel-text": lower(hay(r)),
          // SPACE-PADDED AT BOTH ENDS, which is not cosmetic: the script tests
          // `includes(" x ")`, and without the padding a tag that is another's prefix
          // would half-match.
          "data-panel-tags": " " + mine.join(" ") + " ",
        ),
      )
    }
  }

  // PAGED/EPUB: nothing to type into and no pill to press, so the rows render as an
  // ordinary list. `#idea-row` is HTML-only and panics if reached here, so this branch
  // builds its own — the same fallback every view in this family keeps.
  if target() != "html" {
    if rows.len() == 0 { return text(gray, emph(empty)) }
    return list(
      ..rows.map(r => {
        let d = when(r)
        if d != none { [#_fmt-day(d) — ] }
        r.at("label", default: r.at("name", default: ""))
      }),
    )
  }

  if rows.len() == 0 {
    return html.elem("p", attrs: (class: "panel-empty"), empty)
  }

  html.elem(
    "div",
    attrs: (
      // `panel-flow` IS THE UNCAPPED CASE, as a class rather than as an absent custom
      // property: CSS cannot test whether `--panel-rows` was set, so the stylesheet
      // needs something positive to hang "no max-height" on.
      class: if visible == none { "panel panel-flow" } else { "panel" },
      // `data-panel-mode` IS HOW ONE SCRIPT TELLS THE TWO PANELS APART. `#panel`'s
      // pills carry `data-panel-facet`/`data-panel-value` and filter on a row's
      // `data-<field>`; these carry `data-panel-tag` and intersect on
      // `data-panel-tags`.
      "data-panel-mode": "tags",
      // `false` until the script has wired itself. The stylesheet hides the input, the
      // pills and the scroll cap while it says so, which is how the widget degrades:
      // with no JavaScript the chrome that would do nothing never appears, and what is
      // left is an ordinary complete list.
      "data-panel-ready": "false",
      ..if visible == none { (:) } else { (style: "--panel-rows: " + str(visible)) },
    ),
    {
      html.elem(
        "input",
        attrs: (
          class: "panel-input",
          type: "search",
          placeholder: placeholder,
          "aria-label": placeholder,
          autocomplete: "off",
        ),
      )
      if carried.len() > 0 {
        html.elem(
          "div",
          attrs: (class: "panel-pills", role: "group", "aria-label": "Refine"),
          carried
            .map(t => html.elem(
              "button",
              attrs: (
                type: "button",
                class: "panel-pill",
                "data-panel-tag": t,
                "aria-pressed": "false",
              ),
              tag-display(t),
            ))
            .join(),
        )
      }
      html.elem(
        "p",
        attrs: (class: "panel-count", "aria-live": "polite"),
        str(rows.len()) + " " + noun,
      )
      html.elem("ul", attrs: (class: "panel-results"), rows.map(draw).join())
    },
  )
}
