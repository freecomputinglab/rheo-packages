// `#timeline-view` — a note's dated log as a vertical rail.
//
// THE ONE PLACE THIS PACKAGE EMITS HTML, and the reason it now ships a
// stylesheet at all. Everything else here is a function of its arguments; this
// draws something.
//
// WHAT IT SHOWS, and the shape was chosen against the alternatives rather than
// arrived at:
//
//   A DOT PER EVENT down a rule, FILLED for what has happened and HOLLOW for what
//   is booked, with a `today` divider between the two. That split is the main
//   thing a log knows and nothing else drew: entries may be future-dated by
//   design — a deadline has not arrived, an interview is booked before it is held
//   — so a view treating every entry alike throws the distinction away.
//
//   Real logs are SHORT. On the project this was built for, fourteen submissions
//   carry two events, seven carry one, one carries three; a todo's lifecycle
//   reaches three or four and a journal's revise-resubmit round could reach six.
//   So the rail has to look right at TWO events and must not need twenty.
//
// REJECTED, each for a stated reason: a horizontal track (crowds past four events
// and gives a long stage name nowhere to go), a definition list (says nothing
// about order, or about whether an entry has happened), an inline sparkline (a
// different component, for a table of many notes rather than one note's page), and
// durations of any kind — "126 days in flight", per-event gaps — because a
// computed interval resting on a stand-in date looks more precise than it is.

#import "fragment.typ": *
#import "read.typ": *
#import "when.typ": *
#import "ladder.typ": *

// Rendering a time is only legal where there is one. MEASURED on typst 0.15.1:
// `.display("[hour]")` on a date-only datetime panics with "failed to format
// datetime (insufficient information)", and `.hour()` on one is `none`.
#let _has-time(d) = d.hour() != none

// `_fmt-day` USED TO LIVE HERE and now comes in from `read.typ` with the rest of
// the readers, because `#upcoming` (`upcoming.typ`) draws a column of the same
// dates and a second copy of the format would be a second answer to "how does
// this package write a date". Its reasoning moved with it.
#let _fmt-time(d) = d.display("[hour]:[minute]")

// A CONTEXT FUNCTION, because it branches on `target()` — the same shape every
// view in the rookery family takes, and the reason it returns content rather than
// data a caller could assert on directly.
#let timeline-view(entry, tags, today: none, ladder: none) = context {
  // `timeline` rather than `timeline-of`, so rookery's own `created` leads the rail:
  // the record starts when the note was written and the log is what happened to
  // it since. One store per fact, one view over both.
  let events = timeline(entry, tags)
  if events.len() == 0 { return }

  let now = _today(today)

  // HAS THIS HAPPENED? Compared at the COARSER of the two precisions, which is not
  // a nicety — it is the difference between the rail being right and being useless
  // on the commonest call there is.
  //
  // `_stamp-of` treats a date-only value as the START of its day, which is correct
  // for ORDERING (a bare `deadline` precedes a timed event during that day). Used
  // here it is wrong: with a date-only `today:` — what almost every project passes,
  // since a site's reference date is a date — every timed event occurring today
  // would stamp LATER than the reference and read as booked. MEASURED: a todo
  // closed at 16:00 on the reference date showed as not yet closed.
  //
  // A bare reference date means the whole DAY. So both sides drop to day
  // granularity unless both carry a time, in which case the clock decides.
  let happened(e) = {
    if _has-time(e.timestamp) and _has-time(now) {
      _stamp-of(e.timestamp) <= _stamp-of(now)
    } else {
      _day-of(e.timestamp) <= _day-of(now)
    }
  }
  let past = events.filter(happened)
  let booked = events.filter(e => not happened(e))

  // The rungs a ladder says are still ahead — drawn undated, after everything
  // dated. WITHOUT a ladder this is empty and the view is a RECORD of what
  // happened; WITH one it is a PROGRESS indicator that also says what is
  // expected. One function, two registers, and a call site tells them apart by
  // whether it passes `ladder:`.
  //
  // An EXPECTATION, never a promise: nothing here knows a process will advance,
  // only what the ladder says would come next if it did. The class name says
  // `expected` and the stylesheet greys it for exactly that reason.
  let expected = if ladder == none { () } else {
    let reached = events.map(e => e.stage)
    let r = rung(tags, ladder: ladder, today: today)
    if r == none or r >= ladder.transit.len() { () } else {
      // THROUGH `rung-name`, so a family rung draws as `review` rather than
      // `review *`. And a family rung is dropped from what is "ahead" once ANY of
      // its occurrences has been reached: having done review-1, more reviews are
      // possible but no longer expected, and listing `review` as still-to-come
      // after two of them would be wrong.
      ladder
        .transit
        .slice(r + 1)
        .filter(p => not reached.any(st => _matches(p, st)))
        .map(rung-name)
    }
  }

  // SAME-DAY EVENTS SHOW THEIR TIMES rather than repeating a date. This is the
  // case the component was designed against: a todo activated at 15:00 and closed
  // at 16:00 on one day renders two identical dates and a rule between them
  // otherwise, saying nothing. Decided per event by looking at its NEIGHBOURS, so
  // a lone timed event still reads as a date.
  let dated = past + booked
  let shares-day(i) = {
    let d = dated.at(i).timestamp
    if not _has-time(d) { return false }
    let day = d.display("[year][month][day]")
    let others = dated.enumerate().filter(p => p.at(0) != i).map(p => p.at(1).timestamp)
    others.any(o => o.display("[year][month][day]") == day)
  }

  if target() != "html" {
    // PAGED/EPUB: no rail to draw, so the same events as an ordinary list — the
    // branch every view in this family takes.
    return list(
      ..dated
        .enumerate()
        .map(p => {
          let (i, e) = p
          let when = if shares-day(i) { _fmt-day(e.timestamp) + " " + _fmt-time(e.timestamp) } else { _fmt-day(e.timestamp) }
          // The note follows the stage here rather than taking its own line: a list
          // item on a paged target has no columns to place it in.
          [#when — #e.stage.replace("-", " ")#if "note" in e { [. #e.note] }]
        })
        + expected.map(n => [— #n.replace("-", " ") (expected)]),
    )
  }

  // `timed` is decided by the CALLER, from the event's index, rather than looked
  // up in here from its date — two events could share a timestamp, and a lookup by
  // value would then answer for whichever came first.
  // THE DATE COMES FIRST IN THE MARKUP, and that is not a style choice: the row is
  // a two-column grid with the rail's line between the columns, so the source
  // order has to match the column order or the date lands to the right of the line
  // it is meant to sit left of.
  let row(cls, stage, when, timed: false, note: none) = html.elem(
    "li",
    attrs: (class: "timeline-event " + cls),
    {
      if when == none {
        html.elem("span", attrs: (class: "timeline-when"), [—])
      } else {
        html.elem(
          "time",
          attrs: (class: "timeline-when", datetime: when.display("[year]-[month]-[day]")),
          if timed { _fmt-day(when) + " " + _fmt-time(when) } else { _fmt-day(when) },
        )
      }
      html.elem("span", attrs: (class: "timeline-stage"), stage.replace("-", " "))
      // THE NOTE, if this event has one: the prose that is about THIS event rather
      // than about the note as a whole. Inside the same `<li>`, not as a sibling
      // row, so the rail's dot stays aligned to the event the prose belongs to —
      // which is the entire point of an entry carrying it.
      // A `<div>`, NOT a `<p>`. MEASURED: a note spanning more than one paragraph
      // renders EMPTY inside a `<p>` — Typst's own paragraphs are block content, and
      // a `<p>` cannot legally contain them, so the whole element collapses. A note
      // is authored prose and the author chose its length, so the container has to
      // take whatever they wrote.
      if note != none {
        html.elem("div", attrs: (class: "timeline-note"), note)
      }
    },
  )

  // `.timeline` on the list, NOT `.timeline-log`: that is the tag KEY, and a class
  // named after the storage would be one more thing to keep in step. The stylesheet
  // and the documented class contract both say `.timeline`.
  html.elem("ol", attrs: (class: "timeline"), {
    // THE LAST PAST ROW IS THE CURRENT STAGE, and it gets a class of its own so the
    // stylesheet can say so — bold, against every other stage greyed. Computed here
    // rather than derived again in CSS, which cannot ask which row is last of a
    // class.
    for (i, e) in past.enumerate() {
      let cls = if i == past.len() - 1 { "timeline-past timeline-current" } else { "timeline-past" }
      row(cls, e.stage, e.timestamp, timed: shares-day(i), note: e.at("note", default: none))
    }
    // ONLY WHERE BOTH SIDES EXIST. A rail whose every event is past needs no line
    // saying where now is — it would be a divider at the bottom, marking nothing.
    if past.len() > 0 and booked.len() > 0 {
      html.elem("li", attrs: (class: "timeline-today"), html.elem(
        "span",
        attrs: (class: "timeline-today-label"),
        "today",
      ))
    }
    for (i, e) in booked.enumerate() {
      row(
        "timeline-future",
        e.stage,
        e.timestamp,
        timed: shares-day(past.len() + i),
        note: e.at("note", default: none),
      )
    }
    // NO NOTE ON AN EXPECTED RUNG. A rung that has not happened cannot have prose
    // about it, and the ladder supplies names only.
    for n in expected { row("timeline-expected", n, none) }
  })
}
