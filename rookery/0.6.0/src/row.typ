// `#idea-row` — ONE ROW SHAPE for every list of notes.
//
// `when | title | badges` had been written five times across this repo and its first
// consumer, and the badge chip was specified in three stylesheets: this package's hat
// pill, `@rheo/rookery-search`'s own chips, and `@rheo/rookery-timeline`'s
// `.upcoming-stage` — whose comment says outright that it "copies the SHAPE instead,
// the same way @rheo/rookery-search's own chips do". One object, three hand copies.
// This is the object.
//
// WHY IT LIVES IN CORE. rookery-search and rookery-timeline both already import this
// package, so the row costs no new package edge; search could not host it, because
// rheo scans only a PROJECT's own imports and never a package's — a project reaching
// search's row THROUGH rookery-timeline would get the markup with neither that
// package's CSS nor its JS, which is a silent failure its own readme documents. Core
// also already owns everything the five copies reach for: `.idea-tag`, and the
// generated `@layer rookery-tags` rules that publish `--idea-tag-bg` /
// `--idea-tag-color` / `--idea-tag-line` per themed tag.
//
// NO JAVASCRIPT, and no breach of core's no-JS rule: a row is markup plus a class
// contract. Interaction stays in rookery-search.
//
// CELLS ARRIVE FORMATTED, which is the whole of the design. The row asks no questions
// about dates, stages or tags — a caller knows its own data model and fills the cells.
// That is what lets one row serve a log-derived queue (`#upcoming`), a
// `created`-ordered filter panel, and a hand-built table of submissions, none of which
// agree about what a date means.

// A row is HTML-ONLY, deliberately. A paged target has no grid to align and no anchor
// to click, and every view in this family already keeps a `target() != "html"` branch
// that builds its own `list(..)`. Reaching this function from one is a bug in the
// caller, so it says so rather than emitting `html.elem` into a PDF — where it would
// fail with a message about the element, not about the mistake.
#let _paged-panic = (
  "@rheo/rookery: #idea-row is HTML-only and was called on a paged target. "
    + "A view keeps its own `if target() != \"html\"` branch and renders `list(..)` "
    + "there; this row draws the grid the HTML branch needs."
)

// THE ROW'S CHILDREN, WITHOUT THE `<li>` AROUND THEM, and the split is forced by a
// caller rather than chosen for tidiness. @rheo/rookery-search ships TWO widgets that
// want this shape and disagree about who owns the list item: `#filter-panel` builds
// its own `<ul>` and uses `#idea-row` AS the `<li>`, while `#panel` wraps whatever its
// `render:` returns in an `<li class="panel-row" data-<field>=..>` of its own — so a
// `#panel` row rendered with `#idea-row` nests one `<li>` inside another.
//
// The alternative was a consumer re-emitting these four spans to drop the wrapper,
// which is the fifth hand copy this file's header exists to prevent. So: the shape
// lives here once, and the wrapper is the part a caller can decline.
//
// NO `tags`, `extra` OR `attrs` — those all describe the `<li>`, and a caller reaching
// for this function has its own.
#let idea-row-body(
  when: none,
  iso: none,
  soft: false,
  title: [],
  href: none,
  badges: (),
  cells: (),
) = {
  html.elem(
    "span",
    attrs: (class: if soft { "idea-row-when soft" } else { "idea-row-when" }),
    if when == none { [—] } else if iso == none { when } else {
      html.elem("time", attrs: (datetime: iso), when)
    },
  )
  if href == none {
    html.elem("span", attrs: (class: "idea-row-title"), title)
  } else {
    html.elem("a", attrs: (class: "idea-row-title", href: href), title)
  }
  // ONE SPAN PER `cells` ENTRY, between the title and the badges — a host
  // institution, a path to a manuscript, whatever a caller's own model has that
  // a reader scans DOWN for rather than reads inside the title. They are content,
  // not data: the row neither formats nor labels them.
  for c in cells {
    html.elem("span", attrs: (class: "idea-row-cell"), c)
  }
  // THE BADGE STRIP, and an empty one is omitted entirely rather than drawn
  // empty: a `<span>` with no children still takes a grid track, which on a
  // stacked narrow row costs a whole line.
  //
  // TWO CLASSES PER CHIP. `idea-tag` is the shape's hook; `idea-tag-<tag>` is the
  // same class this package puts on a card, a heading, an outline row and a hat
  // pill, and the class its generated `@layer rookery-tags` rules publish a
  // themed tag's colours on — so a badge colours itself with no code here.
  //
  // NOT WRAPPED IN `.idea-tab`, which carries the hat's own pill rule: that
  // element draws a stub of rule through its `::before`, which inside a row reads
  // as a stray dash. The stylesheet shares the SHAPE between the two selectors
  // instead.
  if badges.len() > 0 {
    html.elem(
      "span",
      attrs: (class: "idea-row-badges"),
      badges
        .map(b => html.elem(
          "span",
          attrs: (class: "idea-tag idea-tag-" + b.tag),
          b.text,
        ))
        .join(),
    )
  }
}

// `attrs:` EXISTS FOR THE FILTERING VIEWS, and it is the one hole in "the row asks no
// questions": @rheo/rookery-search's panels put their own `data-panel-*` attributes on
// the row a script reads back, and the alternative was that package re-emitting this
// markup so it could add two attributes — which is precisely the duplication this
// function exists to end. Merged UNDER the class attribute this function computes, so
// a caller cannot accidentally drop the row's own classes.
#let idea-row(
  when: none,
  iso: none,
  soft: false,
  title: [],
  href: none,
  badges: (),
  tags: (),
  extra: (),
  cells: (),
  attrs: (:),
) = context {
  assert(target() == "html", message: _paged-panic)

  // `soft` SAYS SOMETHING ABOUT A DATE, so a row with no date does not wear it: the
  // class means "this date answers a different question than the list asked" — a
  // booked event standing in for a deadline, an expected rung — and an em dash makes
  // no such claim. DROPPED SILENTLY rather than asserted, because it is a
  // presentational flag and a caller mapping over mixed rows will hand it in
  // uniformly; failing the build over a cosmetic redundancy would be the wrong
  // trade. The same bug was caught by @rheo/rookery-timeline's own fixture, which
  // read every undated row as soft.
  let soft = soft and when != none

  html.elem(
    "li",
    attrs: attrs
      + (
        class: (("idea-row",) + extra + tags.map(t => "idea-tag-" + t)).join(" "),
      ),
    idea-row-body(
      when: when,
      iso: iso,
      soft: soft,
      title: title,
      href: href,
      badges: badges,
      cells: cells,
    ),
  )
}
