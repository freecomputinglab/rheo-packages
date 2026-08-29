// The rendered fixture for `#upcoming`, and A FILE OF ITS OWN rather than a ninth
// section of `view.typ`. The reason is mechanical: `#upcoming` reads the note
// REGISTRY, so its rows have to be real `#idea` notes and the file has to apply
// rookery's own show rule — and `#show: rookery` rewrites the whole document, which
// would perturb the eight rails `check.sh` counts by regex in `view.typ`'s output.
// Two fixtures, two built files, one `check.sh` reading both.
//
// SIX CASES, each one the design turns on:
//   1. order — soonest first, whatever order the notes were written in
//   2. a row with no deadline but something BOOKED — soft, and still in the queue
//   3. `from:` — a cutoff drops what is too old, and keeps an undated row
//   4. nothing selected — the empty line, not a bare empty list
//   5. `name-from:` — a dated note named by the durable note it points at
//   6. `countdown:` — the chip on the right, across both bands and both silences
//
// EVERY CALL IS TAG-SCOPED, because the registry is the whole document: the
// `name-from` notes below would otherwise join the first two lists and the assertions
// would be counting each other's fixtures.
#import "/src/lib.typ": *
#show: rookery

#let d(y, m, dd) = datetime(year: y, month: m, day: dd)
#let NOW = d(2026, 8, 27)

#idea("later", title: [Later], tags: ("queued",), deadline: d(2026, 10, 1))[Body.]
#idea("sooner", title: [Sooner], tags: ("queued",), deadline: d(2026, 9, 1))[Body.]
#idea("booked", title: [Booked], tags: ("queued",), timeline: (submitted: d(2026, 8, 1), "first-interview": d(2026, 9, 20)))[Body.]
#idea("watched", title: [Watched], tags: ("watch", "queued"))[Nothing announced yet.]

// `name-from:`'s case: the DURABLE note holds the title, and the dated note is one
// attempt at it, carrying a pointer and no name of its own — which is what every
// tracker looks like. The third one's pointer names nothing, and must still render.
#idea("venue-x", title: [A Real Venue])[The durable note.]
#idea("try-1", tags: ("attempt": "venue-x"), deadline: d(2026, 9, 3))[Sent the abstract.]
#idea("try-2", tags: ("attempt": "venue-x"), deadline: d(2026, 9, 4))[Sent a second one.]
#idea("try-lost", tags: ("attempt": "no-such-note"), deadline: d(2026, 9, 5))[Dangling pointer.]

// `countdown:`'s case, on a tag of its own so these seven do not join the lists
// above. One note per outcome the band table has, counted from NOW = 27.8.26:
// -7, 0, +1, +6, +12, +66, and no date at all.
#idea("overdue", title: [Overdue], tags: ("due",), deadline: d(2026, 8, 20))[Body.]
#idea("nowish", title: [Due today], tags: ("due",), deadline: NOW)[Body.]
#idea("morrow", title: [Tomorrow], tags: ("due",), deadline: d(2026, 8, 28))[Body.]
#idea("week", title: [This week], tags: ("due",), deadline: d(2026, 9, 2))[Body.]
#idea("fortnight", title: [Fortnight], tags: ("due",), deadline: d(2026, 9, 8))[Body.]
#idea("faroff", title: [Far off], tags: ("due",), deadline: d(2026, 11, 1))[Body.]
#idea("undated", title: [Undated], tags: ("due",))[Body.]

= 1. Every row, soonest first

#upcoming(tags: "queued", today: NOW, stage: (DEADLINE-STAGE, SCHEDULED-STAGE))

= 2. With a cutoff

#upcoming(tags: "queued", today: NOW, from: d(2026, 9, 15))

= 3. Nothing selected

#upcoming(tags: "no-note-carries-this", today: NOW)

= 4. Named from the note a tag points at

#upcoming(tags: "attempt", today: NOW, name-from: "attempt")

= 5. The countdown column

#upcoming(tags: "due", today: NOW, countdown: true)
