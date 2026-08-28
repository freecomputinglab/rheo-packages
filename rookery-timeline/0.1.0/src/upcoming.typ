// `#upcoming` — the log as a dated list ACROSS MANY NOTES.
//
// THE SECOND VIEW IN THIS PACKAGE, and the sibling of `#timeline-view` rather than
// a variant of it. That one draws ONE note's log as a rail; this draws ONE ROW PER
// NOTE, ordered by what is coming next. `view.typ`'s own header rejects an "inline
// sparkline (a different component, for a table of many notes)" — this is that
// different component, written rather than folded into the rail.
//
// WHAT MAKES IT BELONG HERE rather than in a consuming project: every question it
// asks is a question about a log. Which entry dates a row, whether that date has
// arrived, what has happened so far — all of it is `read.typ` and `when.typ`, and a
// project rewriting this view rewrites those readers' semantics by hand. The
// project this was extracted from had TWO copies of it (one over submissions, one
// over todos), which is the usual sign.
//
// TWO THINGS IT DELIBERATELY DOES NOT DO:
//
//   NO LADDER. It cannot say whether a note is finished, because `accepted` ends a
//   conference submission and is the middle of a journal's — the same reason
//   `when.typ` keeps `is-settled` out of itself. A caller that wants settled rows
//   gone passes `filter:`.
//
//   NO RENDER HOOK, and so THREE FIXED COLUMNS: when, name, current stage. A
//   caller needing a fourth column (a submission's host school, a path to a
//   manuscript) is asking about ITS OWN data model, which this package cannot see,
//   and should keep its own view for that. Fixed columns are what make one call on
//   two unrelated corpora look like one table.
//
// THIS FILE READS THE NOTE REGISTRY, through rookery's `ideas()`. That makes it the
// second exception to `lib.typ`'s "every function is a function of its arguments",
// and a bigger one than `#timeline-view` (which only emits HTML). It is not a new
// pattern in the family: `@rheo/rookery-todos`' own views import `ideas` from
// rookery for exactly this.

#import "fragment.typ": *
#import "read.typ": *
#import "when.typ": *

// The rookery spec is the one the sibling modules use — `lib.typ` names it twice
// and nothing else here imports rookery at all. Keep the three in step: a spec
// naming a version the cache cannot resolve fails with a bare "package not found"
// that says nothing about which file asked for it.
#import "@rheo/rookery:0.6.0": ideas

// ---- when-of — which entry dates a row -------------------------------------
//
// PURE, and separate from the view for that reason: the view returns content and
// branches on `target()`, so nothing about it can be asserted on directly, while
// this is the whole of the policy and `test/units.typ` pins it.
//
// `stage:` is the caller's answer to "which entry queues this row", because the log
// is a DICTIONARY OF NAMED DATES and only the caller knows which name it is waiting
// on. A job application is queued by its `deadline`; a call whose dates are not out
// yet is queued by the `scheduled` date it is expected to post on; a conference is
// queued by whichever it has. So: one name, or an array of names in PRIORITY ORDER.
//
// THE LADDER, in order, and the second rung is the one worth stating:
//
//   1. the first of `stage:` the log carries -> that date, `firm: true`
//   2. else the next entry dated AFTER `today:` (`next-of`) -> `firm: false`
//   3. else nothing -> `(none, none, false)`, and the view sorts it last
//
// Rung 2 is the row with no deadline that nonetheless has something BOOKED — an
// interview, a promised decision. It has a real place in the queue and dropping it
// would hide the one thing about it that is imminent. `firm` marks it as answering
// the question from a different entry than the caller asked about; the stylesheet
// greys it, and it is a presentation fact rather than a claim about the date.
#let when-of(tags, stage: DEADLINE-STAGE, today: none) = {
  let names = if type(stage) == str { (stage,) } else { stage }
  for name in names {
    let d = stage-date(tags, name)
    if d != none { return (date: d, stage: name, firm: true) }
  }
  let nxt = next-of(tags, today: today)
  if nxt != none { return (date: nxt.timestamp, stage: nxt.stage, firm: false) }
  (date: none, stage: none, firm: false)
}

// A DATE AS A ZERO-PADDED STRING, which is what makes it a free sort key: fixed
// width, so string order is date order. `zzzzzzzz` puts every undated row after
// every dated one without a second comparison.
//
// NOT `_stamp` from `when.typ`, which is private and carries a time component this
// does not want: two events on one day should keep their authored order (which is
// the note name here), not be split by a clock the log may not even carry.
#let _key(d) = if d == none { "zzzzzzzz" } else { d.display("[year][month][day]") }

// The ISO form, for the `datetime` ATTRIBUTE only — zero-padded, and deliberately
// not the form the row shows. A machine reads the attribute; a person reads
// `_fmt-day`.
#let _iso(d) = d.display("[year]-[month]-[day]")

// What to call a note in a row: its authored title where it has one, and rookery's
// own `label` otherwise — which is never empty (the title flattened, else the
// body's first 60 characters, else the note's name). Rendering `label` when there
// IS a title would lose the title's typography, so this is not `label` everywhere.
#let _name-of(r) = if r.title == none { r.label } else { r.title }

// A stage as a word: `first-interview` reads `first interview`. The hyphen is a
// naming convention in a ladder, not something a reader should have to see.
#let _words(s) = s.replace("-", " ")

// ---- #upcoming --------------------------------------------------------------
//
// `tags:`/`match:`/`filter:` are rookery's OWN selection vocabulary, passed
// straight through — `ideas()` asserts on the first two, and `filter:` is a
// predicate over the tag dictionary exactly as `#ideas-outline` and
// `#todos-list` take one. One idiom for selecting notes, not a second.
//
// `from:`/`within:` bound the WINDOW, and they bound it from opposite ends: `from`
// drops what is too old to matter, `within` drops what is too far off to act on.
// Neither drops an UNDATED row, which has no date to fail either test — a note
// being watched with nothing announced yet is precisely what a queue should still
// show.
//
// SORTED ASCENDING, oldest first, which puts a date already behind you at the TOP
// rather than the bottom. An overdue row is the most urgent thing on the list.
#let upcoming(
  tags: none,
  match: "any",
  filter: none,
  stage: DEADLINE-STAGE,
  today: none,
  from: none,
  within: none,
  limit: none,
  title: none,
  empty: [Nothing upcoming.],
) = context {
  assert(
    within == none or (type(within) == int and within >= 0),
    message: "@rheo/rookery-timeline: #upcoming's `within` must be none or a "
      + "non-negative integer number of days — got "
      + repr(within),
  )
  assert(
    from == none or type(from) == datetime,
    message: "@rheo/rookery-timeline: #upcoming's `from` must be none or a datetime — got " + repr(from),
  )
  assert(
    filter == none or type(filter) == function,
    message: "@rheo/rookery-timeline: #upcoming's `filter` must be none or a function "
      + "taking the note's tag dictionary — got "
      + repr(filter),
  )

  // `values: true` is not optional: it is what adds `tags-dict`, and the log lives
  // in there. Without it every row would read as having no dates at all.
  let rows = ideas(tags: tags, match: match, values: true)
  if filter != none { rows = rows.filter(r => filter(r.tags-dict)) }

  let rows = rows.map(r => {
    let w = when-of(r.tags-dict, stage: stage, today: today)
    (
      ..r,
      when: w.date,
      firm: w.firm,
      key: _key(w.date),
      // WHAT HAS HAPPENED, not what is coming: the last entry dated on or before
      // the reference date. A note nothing has happened to yet has none, and draws
      // no badge rather than an empty one.
      at: stage-of(r.tags-dict, today: today),
    )
  })

  // Both bounds compare on the same zero-padded key the sort uses, so there is one
  // notion of "this date is before that one" in this file rather than two.
  let rows = rows.filter(r => {
    if r.when == none { return true }
    if from != none and r.key < _key(from) { return false }
    if within != none and r.key > _key(_today(today) + duration(days: within)) { return false }
    true
  })

  let rows = rows.sorted(key: r => (r.key, r.name))
  if limit != none { rows = rows.slice(0, calc.min(limit, rows.len())) }

  // PAGED FIRST. A PDF or EPUB page has no anchor to click and no grid to align, so
  // the same rows render as an ordinary Typst list — the same fallback every view in
  // this family makes. `align(start)` is load-bearing: this content can sit inside a
  // Typst `figure`, which CENTRES its body, and the rail's own paged branch was
  // written the same way for the same reason.
  if target() != "html" {
    return align(start, {
      if title != none {
        strong(title)
        linebreak()
      }
      if rows.len() == 0 {
        text(gray, emph(empty))
      } else {
        list(
          ..rows.map(r => {
            if r.when != none {
              [#_fmt-day(r.when)#if not r.firm { [ (booked)] } — ]
            }
            _name-of(r)
            if r.at != none { [ #text(gray, "(" + _words(r.at) + ")")] }
          }),
        )
      }
    })
  }

  if rows.len() == 0 {
    return html.elem("p", attrs: (class: "upcoming-empty"), empty)
  }

  html.elem("div", attrs: (class: "upcoming"), {
    // A `<div>`, NOT AN `<hN>`, and that is the point of it: this labels the list
    // sitting under it and must claim no place in the page's outline, where it would
    // outrank the real headings around it.
    if title != none {
      html.elem("div", attrs: (class: "upcoming-title"), title)
    }
    html.elem(
      "ul",
      attrs: (class: "upcoming-list"),
      rows
        .map(r => html.elem(
          "li",
          // The note's own tags ride on the row as `idea-tag-<tag>` classes, the
          // same convention rookery's outline rows and @rheo/rookery-todos' list
          // rows both follow — so a project theming a tag on a card has already
          // themed it here.
          attrs: (class: (("upcoming-row",) + r.tags-dict.keys().map(k => "idea-tag-" + k)).join(" ")),
          {
            html.elem(
              "span",
              // `soft` SAYS SOMETHING ABOUT A DATE, so an undated row does not wear
              // it: the class means "this date came from an entry other than the one
              // you queued by", and a row rendering `—` has no such claim to make.
              // Caught by the fixture, which read every undated row as soft.
              attrs: (
                class: if r.when == none or r.firm { "upcoming-when" } else { "upcoming-when soft" },
              ),
              if r.when == none { [—] } else {
                html.elem("time", attrs: (datetime: _iso(r.when)), _fmt-day(r.when))
              },
            )
            if r.href == none {
              html.elem("span", attrs: (class: "upcoming-name"), _name-of(r))
            } else {
              html.elem("a", attrs: (class: "upcoming-name", href: r.href), _name-of(r))
            }
            // TWO CLASSES ON THE BADGE, and the second is what carries a project's
            // colours: `idea-tag-<stage>` is the class rookery's generated
            // `@layer rookery-tags` rules publish `--idea-tag-bg`/`--idea-tag-color`/
            // `--idea-tag-line` on, so a themed stage colours itself with no code
            // here. `idea-tag` marks it as one of that family for a project's own
            // rules. A stage name that is not usable as a class is rejected by
            // rookery when the tag is authored, so nothing is validated again here.
            //
            // NOT WRAPPED IN `.idea-tab`, which would inherit rookery's own pill
            // rule directly: that element draws a stub of rule through its
            // `::before`, which inside a table row renders as a stray dash. The
            // stylesheet copies the SHAPE instead, the same way
            // @rheo/rookery-search's own chips do.
            if r.at != none {
              html.elem(
                "span",
                attrs: (class: "upcoming-stage idea-tag idea-tag-" + r.at),
                _words(r.at),
              )
            }
          },
        ))
        .join(),
    )
  })
}
