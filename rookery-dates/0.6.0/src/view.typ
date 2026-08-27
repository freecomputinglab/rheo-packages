// `#log-view` — a note's dated log as a vertical rail.
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

#let _fmt-day(d) = d.display("[day padding:none] [month repr:short] [year]")
#let _fmt-time(d) = d.display("[hour]:[minute]")

// A CONTEXT FUNCTION, because it branches on `target()` — the same shape every
// view in the rookery family takes, and the reason it returns content rather than
// data a caller could assert on directly.
#let log-view(entry, tags, today: none, ladder: none) = context {
  // `timeline` rather than `log-of`, so rookery's own `created` leads the rail:
  // the record starts when the note was written and the log is what happened to
  // it since. One store per fact, one view over both.
  let events = timeline(entry, tags)
  if events.len() == 0 { return }

  let now = _today(today)
  let past = events.filter(e => _stamp-of(e.on) <= _stamp-of(now))
  let booked = events.filter(e => _stamp-of(e.on) > _stamp-of(now))

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
      ladder.transit.slice(r + 1).filter(n => n not in reached)
    }
  }

  // SAME-DAY EVENTS SHOW THEIR TIMES rather than repeating a date. This is the
  // case the component was designed against: a todo activated at 15:00 and closed
  // at 16:00 on one day renders two identical dates and a rule between them
  // otherwise, saying nothing. Decided per event by looking at its NEIGHBOURS, so
  // a lone timed event still reads as a date.
  let dated = past + booked
  let shares-day(i) = {
    let d = dated.at(i).on
    if not _has-time(d) { return false }
    let day = d.display("[year][month][day]")
    let others = dated.enumerate().filter(p => p.at(0) != i).map(p => p.at(1).on)
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
          let when = if shares-day(i) { _fmt-day(e.on) + " " + _fmt-time(e.on) } else { _fmt-day(e.on) }
          [#when — #e.stage.replace("-", " ")]
        })
        + expected.map(n => [— #n.replace("-", " ") (expected)]),
    )
  }

  // `timed` is decided by the CALLER, from the event's index, rather than looked
  // up in here from its date — two events could share a timestamp, and a lookup by
  // value would then answer for whichever came first.
  let row(cls, stage, when, timed: false) = html.elem(
    "li",
    attrs: (class: "date-log-event " + cls),
    {
      html.elem("span", attrs: (class: "date-log-stage"), stage.replace("-", " "))
      if when == none {
        html.elem("span", attrs: (class: "date-log-when"), [—])
      } else {
        html.elem(
          "time",
          attrs: (class: "date-log-when", datetime: when.display("[year]-[month]-[day]")),
          if timed { _fmt-day(when) + " " + _fmt-time(when) } else { _fmt-day(when) },
        )
      }
    },
  )

  html.elem("ol", attrs: (class: "date-log"), {
    for (i, e) in past.enumerate() { row("date-log-past", e.stage, e.on, timed: shares-day(i)) }
    // ONLY WHERE BOTH SIDES EXIST. A rail whose every event is past needs no line
    // saying where now is — it would be a divider at the bottom, marking nothing.
    if past.len() > 0 and booked.len() > 0 {
      html.elem("li", attrs: (class: "date-log-today"), html.elem(
        "span",
        attrs: (class: "date-log-today-label"),
        "today",
      ))
    }
    for (i, e) in booked.enumerate() {
      row("date-log-future", e.stage, e.on, timed: shares-day(past.len() + i))
    }
    for n in expected { row("date-log-expected", n, none) }
  })
}
