// The rendered fixture for `#upcoming`, and A FILE OF ITS OWN rather than a ninth
// section of `view.typ`. The reason is mechanical: `#upcoming` reads the note
// REGISTRY, so its rows have to be real `#idea` notes and the file has to apply
// rookery's own show rule — and `#show: rookery` rewrites the whole document, which
// would perturb the eight rails `check.sh` counts by regex in `view.typ`'s output.
// Two fixtures, two built files, one `check.sh` reading both.
//
// FOUR CASES, each one the design turns on:
//   1. order — soonest first, whatever order the notes were written in
//   2. a row with no deadline but something BOOKED — soft, and still in the queue
//   3. `from:` — a cutoff drops what is too old, and keeps an undated row
//   4. nothing selected — the empty line, not a bare empty list
#import "/src/lib.typ": *
#show: rookery

#let d(y, m, dd) = datetime(year: y, month: m, day: dd)
#let NOW = d(2026, 8, 27)

#idea("later", title: [Later], deadline: d(2026, 10, 1))[Body.]
#idea("sooner", title: [Sooner], deadline: d(2026, 9, 1))[Body.]
#idea("booked", title: [Booked], timeline: (submitted: d(2026, 8, 1), "first-interview": d(2026, 9, 20)))[Body.]
#idea("watched", title: [Watched], tags: ("watch",))[Nothing announced yet.]

= 1. Every row, soonest first

#upcoming(today: NOW, stage: (DEADLINE-STAGE, SCHEDULED-STAGE))

= 2. With a cutoff

#upcoming(today: NOW, from: d(2026, 9, 15))

= 3. Nothing selected

#upcoming(tags: "no-note-carries-this", today: NOW)
