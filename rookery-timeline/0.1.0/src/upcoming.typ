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
#import "@rheo/rookery:0.6.0": idea-row, ideas

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

// THE ONE PLACE THE REFERENCE DATE IS DEMANDED, called by both views below so the
// message cannot drift into two versions of itself. See the note above
// `#upcoming-rows` for why these two functions refuse the document-date fallback
// every predicate in `when.typ` accepts.
#let _require-today(today) = assert(
  type(today) == datetime,
  message: "@rheo/rookery-timeline: #upcoming and #upcoming-rows need an explicit "
    + "`today:` datetime — e.g. `today: datetime(year: 2026, month: 8, day: 27)`. "
    + "Typst has no wall clock (`datetime.today()` returns 1980-01-01 under a "
    + "reproducible build), and unlike the predicates in `when.typ` these two views "
    + "do not fall back to the document's own date. Got "
    + repr(today),
)

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
// `name-from:` IS FOR A CORPUS WHERE THE DATED NOTE IS AN INSTANCE OF SOMETHING
// ELSE, which is the ordinary shape of a tracker: the durable note is the place —
// a conference series, a journal, a programme — and the dated note is one attempt at
// it, carrying a valued tag that points back. Such a note has no name of its own and
// should not be given one, because a title stored in two places drifts. So this takes
// the TAG KEY holding the pointer, and the row is named and linked by whatever it
// points at. Without it, a row is named by its own note, which is the right answer
// whenever the dated note IS the thing.
//
// A KEY, NOT A CALLBACK: there is no render hook here on purpose (see the header),
// and this stays on the declarative side of that line — the same register as
// `stage:`, which also names a key rather than computing anything.
//
// SORTED ASCENDING, oldest first, which puts a date already behind you at the TOP
// rather than the bottom. An overdue row is the most urgent thing on the list.
//
// ---- #upcoming-rows — the queue as DATA -------------------------------------
//
// SPLIT OUT AND PUBLIC, and not merely as tidiness: it is what lets a project put an
// upcoming queue INSIDE a filter widget —
// `#filter-panel(rows: upcoming-rows(..), when: r => r.when)` — without this package
// importing @rheo/rookery-search. It must not: rheo scans only a PROJECT's own
// imports, never a package's, so a timeline that wrapped search's panel would hand a
// project markup with neither that package's stylesheet nor its script, silently.
// Computing rows here and rendering them there costs no package edge, because the
// project names both packages itself.
//
// Every argument means exactly what it means on `#upcoming`, which is now this plus
// the rendering. Returns the row dictionaries: rookery's own `ideas()` fields, plus
// `shown` (what to call it), `link-to`, `when`, `firm`, `key` (the sort stamp) and
// `at` (the stage reached).
//
// ---- `today:` IS REQUIRED HERE, and only here --------------------------------
//
// The predicates in `when.typ` resolve a missing `today:` through `_today` — the
// explicit argument, else the document's own `#set document(date:)`, else a panic.
// THESE TWO VIEWS DO NOT. They assert on the argument itself and take no document
// date, which is a deliberate narrowing rather than an oversight.
//
// The reason is what a QUEUE claims. A predicate answers a question the caller
// asked; a queue asserts an ordering, a window and a set of stage badges, all of
// which read as facts about the reader's today. A document date the author set
// once and stopped thinking about would make every one of them silently wrong
// rather than visibly absent. So the reference date is named at the call site,
// where it can be seen.
#let upcoming-rows(
  tags: none,
  match: "any",
  filter: none,
  stage: DEADLINE-STAGE,
  name-from: none,
  today: none,
  from: none,
  within: none,
  limit: none,
) = {
  _require-today(today)
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

  // ONE PASS FOR THE WHOLE LOOKUP, not one per row: `ideas()` walks the registry, and
  // doing that inside the row map would walk it once per row. `values:` is left off —
  // a target is read for its name and its link, never its tags.
  let by-name = if name-from == none { (:) } else {
    ideas().map(r => (r.name, r)).to-dict()
  }

  let rows = rows.map(r => {
    let w = when-of(r.tags-dict, stage: stage, today: today)
    // WHERE THE ROW'S NAME COMES FROM. Without `name-from:` it is the dated note's
    // own. With it, the note this one POINTS AT — see the argument's own note above.
    // A pointer naming a note that is not there falls back silently to the dated
    // note: a missing target is an authoring gap in the corpus, and a view that
    // panicked over one typo would take a whole site down with it.
    let target = if name-from == none { none } else {
      let of = r.tags-dict.at(name-from, default: none)
      if type(of) == str { by-name.at(of, default: none) } else { none }
    }
    (
      ..r,
      shown: if target == none { _name-of(r) } else { _name-of(target) },
      link-to: if target == none { r.href } else { target.at("href", default: none) },
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
  rows
}

// ---- #upcoming — the queue as a LIST ----------------------------------------
//
// `#upcoming-rows` above plus the drawing, and nothing else: the signature and the
// output are what they were before the split.
#let upcoming(
  tags: none,
  match: "any",
  filter: none,
  stage: DEADLINE-STAGE,
  name-from: none,
  today: none,
  from: none,
  within: none,
  limit: none,
  title: none,
  empty: [Nothing upcoming.],
) = context {
  // ASSERTED HERE TOO, not only inside `#upcoming-rows`: this is the function a
  // caller named, and a failure surfacing from the row builder would point at a
  // function the caller has never heard of.
  _require-today(today)

  let rows = upcoming-rows(
    tags: tags,
    match: match,
    filter: filter,
    stage: stage,
    name-from: name-from,
    today: today,
    from: from,
    within: within,
    limit: limit,
  )

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
            r.shown
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
        .map(r => idea-row(
          // THE ROW IS `#idea-row`, from rookery core, and this file no longer draws
          // one. It used to emit its own `<li>` with its own `.upcoming-when` /
          // `.upcoming-name` / `.upcoming-stage` cells, and the stylesheet carried a
          // hand copy of the chip's shape — which its own comment admitted was copied
          // from @rheo/rookery-search's. One object, three copies, and this was one
          // of them.
          //
          // `extra:` keeps this package's own hook on the row, so a project that
          // wrote a `.upcoming-row` rule still reaches it, and so does the stylesheet
          // here.
          extra: ("upcoming-row",),
          // The note's own tags, which the row turns into `idea-tag-<tag>` classes —
          // the same convention rookery's outline rows follow, so a project theming a
          // tag on a card has already themed it here.
          tags: r.tags-dict.keys(),
          when: if r.when == none { none } else { _fmt-day(r.when) },
          iso: if r.when == none { none } else { _iso(r.when) },
          // WHAT `soft` MEANS: this date came from an entry other than the one you
          // queued by. The row itself drops the flag on an undated row, so the bug
          // this package's fixture once caught cannot come back through either side.
          soft: not r.firm,
          title: r.shown,
          href: r.link-to,
          // ONE BADGE, THE STAGE REACHED. `#idea-row` puts `idea-tag` and
          // `idea-tag-<stage>` on it, which is what a themed stage colours itself
          // through — see rookery's own generated `@layer rookery-tags`.
          badges: if r.at == none { () } else { ((text: _words(r.at), tag: r.at),) },
        ))
        .join(),
    )
  })
}
