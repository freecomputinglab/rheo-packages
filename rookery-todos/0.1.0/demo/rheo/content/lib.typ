// Shared setup for this demo, applied by every vertebra.
//
// `today` lives here as ONE literal because nothing in this stack may call
// `datetime.today()`: it returns 1980-01-01 under a reproducible build and does
// not error while doing it, so every view that needs a "now" takes it as an
// argument. Bump this line to age the demo.
#import "@rheo/rookery:0.1.0": rookery

#let TODAY = datetime(year: 2026, month: 8, day: 25)

#let demo(doc) = {
  show: rookery.with(theme: (tags-color: (
    "todo-p0": rgb("#cc3333"),
    "todo-closed": rgb("#888888"),
  )))
  doc
}
