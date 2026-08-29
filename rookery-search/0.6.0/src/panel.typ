// `#panel` — a filter-and-sort widget over a `tag-index` projection.
//
// WHY IT IS HERE AND NOT IN CORE. @rheo/rookery ships no JavaScript at all, and
// this repo's CLAUDE.md records that as deliberate: "search is only worth having
// with JavaScript, and rookery is the one package here that ships none", which is
// why search was split out in the first place. A panel is the same case, and this
// package already has the vite build, the fuzzy scorer and an import of rookery.
//
// WHAT IT REPLACES. One fuzzy subsequence scorer was being written three times
// across two packages and a consuming site — `src/score.js` here,
// `todo-search.js` in @rheo/rookery-todos, and a site's own hand-rolled copy
// whose comment said outright that it was "Ported from `todo-search.js`" — with
// three near-identical Typst halves above them, each existing because
// `#todos-search` renders its pill row internally with no hook to add a facet to.
// A panel closes both gaps: facets are DECLARED, and a derived value reaches a
// facet through a projection.
//
//   #let INDEX = tag-index((sort: (family: "sort-"), state: (from: ..)))
//   #panel(
//     rows: ideas(tags: "submission", index: INDEX),
//     facets: ("sort", "state"),
//     sort: "deadline",
//     visible: 5,
//     render: r => [#r.label],
//   )
//
// NO JSON ISLAND, and this is a rule rather than an implementation detail. Every
// faceted or searched field rides as a `data-<field>` attribute on the row
// carrying it, so the payload and the markup cannot disagree — and with no
// JavaScript the rendering is a complete readable list rather than an empty
// container waiting to be filled. The projection's scalar guarantee is exactly
// what makes that generic instead of hand-written per widget.
//
// PANELS TAKE AN INDEX, THEY NEVER BUILD ONE. A page builds one projection and
// passes the projected rows to everything on it. A self-building panel would put
// back the per-view walk of the value store that `tag-index` exists to remove.

#import "base.typ": *

// The scalar rule, policed HERE rather than at the accessor. `ideas(values: true)`
// may legitimately carry arbitrary values for Typst-side rendering — a datetime to
// format, content to place — and this is the boundary where such a value would
// otherwise be stringified into an HTML attribute and read back as nonsense.
#let _attr(field, value) = {
  if value == none { return "" }
  assert(
    type(value) in (str, int, float, bool),
    message: "@rheo/rookery-search: panel field `"
      + field
      + "` holds "
      + repr(type(value))
      + ", which cannot become an HTML attribute. A faceted or sorted field must be "
      + "a scalar — project it through `tag-index(..)` first, and note that "
      + "`ideas(values: true)`'s `tags-dict` is for Typst-side rendering only.",
  )
  if type(value) == bool { if value { "true" } else { "false" } } else { str(value) }
}

// One pill per value ANY LISTED ROW ACTUALLY HAS, never per value the vocabulary
// permits: a pill for a value nothing carries is a filter that could only ever
// return nothing. Values are sorted so the pill row is stable across builds —
// `ideas()` is ordered by id, but the set of values a facet takes is not.
#let _facet-values(rows, field) = {
  rows
    .map(r => r.at(field, default: none))
    .filter(v => v != none and v != "")
    .map(v => _attr(field, v))
    .dedup()
    .sorted()
}

#let panel(
  rows: (),
  // Projected field names to offer as pill groups, in the order given. Each
  // becomes one group of `aria-pressed` buttons.
  facets: (),
  // A projected field to order by, ascending. A date projected with
  // `stamp: true` is a zero-padded `[year][month][day]` string, so this is a
  // plain string sort in date order — see `tag-index`.
  sort: none,
  // Rows with no value for the sort field go LAST rather than first. A missing
  // date is not an early one, and an undated row floating to the top of a list
  // sorted by deadline reads as urgent when it is merely unset.
  descending: false,
  // How many rows are VISIBLE before the list scrolls. NOT a data cap: every row
  // stays in the markup. A consuming site had capped its list and hidden the
  // rest, and its own comment records why that was abandoned — it "made the box
  // a preview of the corpus rather than the corpus — you could not reach the
  // thirty-third place without narrowing the query enough to lift it into the
  // top five, and if you did not know its name you could not narrow at all".
  //
  // `none` MEANS IT DOES NOT SCROLL: the list flows down the page for as long as
  // there are matching rows. `#filter-panel` has taken this since it was written —
  // a scroll box earns its place in a widget a reader opens to find one thing, and
  // not in a page's main list, where it cuts a row in half and hides the rest behind
  // a gesture nothing advertises. This function was the odd one out, and `str(none)`
  // is what a caller trying it hit.
  visible: 8,
  // The haystack the text input filters on, per row. Defaults to the row's own
  // label, name and body — searching the BODY is what finds a note by a phrase
  // inside it rather than by its title.
  haystack: none,
  // How to draw one row. Content, free-form: this package renders the chrome and
  // the row's own markup is the site's business.
  render: r => [#r.at("label", default: r.at("name", default: ""))],
  // EXTRA CLASSES ON THE `<li>`, per row — an adapter, not a list, because the
  // classes worth adding are the row's own (`idea-tag-<tag>`) rather than the
  // panel's. Mirrors `#idea-row`'s `extra:`, and exists for the same reason
  // `#idea-row` has `attrs:`: without it a caller rendering the shared row shape
  // through `render:` cannot also wear `.idea-row`, which is the GRID
  // (`grid-template-columns: <gutter> 1fr auto auto`) and not decoration. This
  // package's own stylesheet already expects both shapes — see
  // `.panel-row:not(.idea-row)`. `#filter-panel` never needed this: it builds its
  // own `<ul>` and uses `#idea-row` AS the `<li>`.
  row-class: none,
  placeholder: "Filter",
  // Plural noun for the live count, e.g. "12 submissions".
  noun: "rows",
  empty: [Nothing here.],
) = {
  let hay = if haystack != none { haystack } else {
    r => (
      r.at("label", default: ""),
      r.at("name", default: ""),
      r.at("body", default: ""),
    ).filter(s => s != "" and s != none).join(" ")
  }

  let rows = if sort == none { rows } else {
    // `\u{ffff}` sorts after every ordinary character, which puts the unset rows
    // last in one comparison rather than needing a second partition. The same
    // string-key device the date stamps use, for the same reason.
    let key = r => {
      let v = r.at(sort, default: none)
      if v == none { "\u{ffff}" } else { _attr(sort, v) }
    }
    let s = rows.sorted(key: key)
    if descending { s.rev() } else { s }
  }

  // PAGED/EPUB: there is no input to type into and no pill to press, so the same
  // rows render as an ordinary list. Every view in this package takes this branch
  // for the same reason.
  if target() != "html" {
    if rows.len() == 0 { return text(gray, emph(empty)) }
    return list(..rows.map(render))
  }

  if rows.len() == 0 {
    return html.elem("p", attrs: (class: "panel-empty"), empty)
  }

  let pill(field, value) = html.elem(
    "button",
    attrs: (
      type: "button",
      class: "panel-pill",
      "data-panel-facet": field,
      "data-panel-value": value,
      "aria-pressed": "false",
    ),
    value.replace("-", " "),
  )

  html.elem(
    "div",
    attrs: (
      // `panel-flow` IS THE UNCAPPED CASE, as a class rather than as an absent custom
      // property: CSS cannot test whether `--panel-rows` was set, so the stylesheet
      // needs something positive to hang "no max-height" on. Same device, same class,
      // as `#filter-panel`.
      class: if visible == none { "panel panel-flow" } else { "panel" },
      // `false` until the script has wired itself up. The stylesheet hides the
      // input, the pills and the scroll cap while it says so, which is how the
      // widget degrades: with no JavaScript the chrome that would do nothing
      // never appears, and what is left is an ordinary complete list.
      "data-panel-ready": "false",
      // The visible height goes to CSS as a custom property rather than as a
      // rule, so the number lives once, here, in the call that sets it.
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
      if facets.len() > 0 {
        html.elem(
          "div",
          attrs: (class: "panel-pills", role: "group", "aria-label": "Refine"),
          facets
            .map(f => {
              let vals = _facet-values(rows, f)
              html.elem(
                "span",
                attrs: (class: "panel-pill-group", "data-panel-group": f),
                vals.map(v => pill(f, v)).join(),
              )
            })
            .join(),
        )
      }
      html.elem(
        "p",
        attrs: (class: "panel-count", "aria-live": "polite"),
        str(rows.len()) + " " + noun,
      )
      html.elem(
        "ul",
        attrs: (class: "panel-results"),
        rows
          .map(r => html.elem(
            "li",
            attrs: (
              (
                // `panel-row` FIRST and unconditionally: the script and the
                // stylesheet both hang off it, so a `row-class` adapter cannot
                // drop it by returning the wrong thing.
                class: (
                  ("panel-row",) + if row-class == none { () } else { row-class(r) }
                ).join(" "),
                "data-panel-text": lower(hay(r)),
              )
                // One `data-<field>` per faceted field, on the row carrying it.
                // No JSON island: the payload IS the markup.
                + facets.map(f => ("data-" + f, _attr(f, r.at(f, default: none)))).to-dict()
            ),
            render(r),
          ))
          .join(),
      )
    },
  )
}
