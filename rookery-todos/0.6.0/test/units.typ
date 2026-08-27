// Unit fixture for @rheo/rookery-todos' pure helpers. Run with `just test`
// from `rookery-todos/0.6.0`. No runner: an `assert` that fails fails the
// compile with a line number, and a passing compile is the green light.

#import "/src/lib.typ": *
// rookery-timeline is NOT re-exported by this package's lib, deliberately — a
// consumer imports it itself. The fixture does the same, for the derivations
// `TODO-LADDER` exists to feed.
#import "@rheo/rookery-timeline:0.1.0": entries, is-settled, next-stage, rung

#let d(y, m, dd) = datetime(year: y, month: m, day: dd)

// ---- todo-tags — the three surfaces ---------------------------------------

// Every todo carries the base key, and nothing else by default.
#assert.eq(todo-tags().keys(), ("todo",))

// FLAT keys encode their value in the key, so they stay filterable by
// `#window(tags:)` and by rookery-search's `tags:todo-p1`.
#assert.eq(todo-tags(priority: 1).keys(), ("todo", "todo-p1"))
#assert.eq(todo-tags(priority: 0).keys(), ("todo", "todo-p0"))
#assert.eq(todo-tags(kind: "bug").keys(), ("todo", "todo-bug"))
#assert.eq(todo-tags(status: "in-progress").keys(), ("todo", "todo-in-progress"))
// Flat means the value is `none`, which is what makes it render as a pill.
#assert.eq(todo-tags(priority: 1).at("todo-p1"), none)

// VALUED keys carry data and render no pill, but their KEY is still present,
// so `#window(tags: "todo-deps")` still finds them.
#assert.eq(todo-tags(deps: ("a", "b")).at("todo-deps"), ("a", "b"))
#assert.eq(todo-tags(metadata: (estimate: 30)).at("todo-metadata"), (estimate: 30))

// `closed` on `todo-tags` is a BOOL, and it is DERIVED: `#todo` passes
// `CLOSED-STAGE in log`, never a date. The date lives in the log alone. There is
// no `closed:` argument on `#todo` any more — a close is `log: (closed: d)`.
#assert.eq(todo-tags(closed: true).at("todo-closed"), none)
#assert.eq(todo-tags(closed: true).keys(), ("todo", "todo-closed"))
// `closed: false` emits NO KEY. A key valued `false` would read as closed to
// every consumer that tests for the key, including rookery's own tag filter.
#assert.eq(todo-tags(closed: false).keys(), ("todo",))


// EMPTY MEANS ABSENT for the valued keys — no meaningless class, no key that
// reads as "has dependencies, namely none".
#assert.eq(todo-tags(deps: ()).keys(), ("todo",))
#assert.eq(todo-tags(metadata: (:)).keys(), ("todo",))

// Deps are normalized through the injected normalizer, so a full id and a bare
// name land on the same string.
#assert.eq(
  todo-tags(deps: ("idea:a", "b"), norm: n => n.split(":").last()).at("todo-deps"),
  ("a", "b"),
)

// LABELS ARE PLAIN, UNNAMESPACED rookery tags — not a parameter of ours.
#assert.eq(todo-tags(tags: ("phd", "urgent")).keys(), ("todo", "phd", "urgent"))

// The caller's own tags merge LAST and win outright on a collision, with no
// deep merge. MEASURED: typst dictionary `+` is right-wins.
#assert.eq(todo-tags(priority: 1, tags: ("todo-p1": "mine")).at("todo-p1"), "mine")
#assert.eq(todo-tags(deps: ("a",), tags: ("todo-deps": ("z",))).at("todo-deps"), ("z",))

// ---- readers — decode, never store twice ----------------------------------
#assert.eq(is-todo(todo-tags()), true)
#assert.eq(is-todo((phd: none)), false)

#assert.eq(priority-of(todo-tags(priority: 3)), 3)
#assert.eq(priority-of(todo-tags()), none)
#assert.eq(type-of(todo-tags(kind: "feature")), "feature")
#assert.eq(type-of(todo-tags()), none)

#assert.eq(deps-of(todo-tags(deps: ("a",))), ("a",))
#assert.eq(deps-of(todo-tags()), ())
#assert.eq(metadata-of(todo-tags()), (:))

// THE LOG ALONE decides. The flat marker is an index into it, not a second
// source: with one write path the two cannot disagree, so `is-closed` reads the
// log and a marker without an entry (which `#todo` cannot produce) is not closed.
#assert.eq(is-closed(entries(log: (closed: d(2026, 8, 1)))), true)
#assert.eq(is-closed(todo-tags()), false)
#assert.eq(is-closed(todo-tags(closed: true)), false)
#assert.eq(closed-on(entries(log: (closed: d(2026, 8, 1)))), d(2026, 8, 1))

// `status-of` — closed wins over a declared status, absent reads as open, and
// `blocked` never appears because it is derived from the graph, not declared.
#assert.eq(status-of(todo-tags()), "open")
#assert.eq(status-of(todo-tags(status: "draft")), "draft")
#assert.eq(status-of(todo-tags(closed: true) + entries(log: (closed: d(2026, 8, 1)))), "closed")
#assert.eq(status-of(todo-tags(status: "draft", closed: true) + entries(log: (closed: d(2026, 8, 1)))), "closed")

// ---- the graph, cycles, and derived state ---------------------------------
//
// Hand-built rows rather than a rookery registry: `todo-graph(rows: ..)` takes
// an injected corpus precisely so the graph logic can be tested without a
// document. The fields it reads are `name`, `deps`, `closed` and `tags-dict`.

#let row(name, deps: (), closed: false, tags: (:)) = (
  name: name,
  deps: deps,
  closed: closed,
  tags-dict: tags,
)

#let g(..rows) = todo-graph(rows: rows.pos())

// Edges run FROM a todo TO what it depends on.
#let simple = g(row("a"), row("b", deps: ("a",)))
#assert.eq(simple.edges, (("b", "a"),))
#assert.eq(simple.unresolved, ())
#assert.eq(simple.nodes.keys().sorted(), ("a", "b"))

// A DANGLING dep is collected, not fatal — a description of a graph that dies
// on the first typo is useless.
#let dangling = g(row("a", deps: ("nope",)))
#assert.eq(dangling.edges, ())
#assert.eq(dangling.unresolved, (("a", "nope"),))

// ---- find-cycle ------------------------------------------------------------
#assert.eq(find-cycle(simple), ())
// A three-node chain is still acyclic.
#assert.eq(find-cycle(g(row("a"), row("b", deps: ("a",)), row("c", deps: ("b",)))), ())
// A diamond is acyclic too — this is the case a naive visited-set walk calls a
// cycle, which is why the walk colours grey/black rather than just "seen".
#assert.eq(
  find-cycle(g(
    row("a"),
    row("b", deps: ("a",)),
    row("c", deps: ("a",)),
    row("d", deps: ("b", "c")),
  )),
  (),
)
// A two-node loop, and the path names the actual loop.
#let two = find-cycle(g(row("c", deps: ("d",)), row("d", deps: ("c",))))
#assert(two.len() == 3, message: "expected a 3-element cycle path, got " + repr(two))
#assert.eq(two.first(), two.last())
// A self-dependency is a cycle.
#assert.eq(find-cycle(g(row("s", deps: ("s",)))), ("s", "s"))

// ---- is-blocked / blockers-of ---------------------------------------------
#let chain = g(row("a"), row("b", deps: ("a",)))
#assert.eq(is-blocked(chain.nodes.at("b"), chain), true)
#assert.eq(is-blocked(chain.nodes.at("a"), chain), false)
#assert.eq(blockers-of(chain.nodes.at("b"), chain), ("a",))

// Closing the dependency unblocks the dependent.
#let done = g(row("a", closed: true), row("b", deps: ("a",)))
#assert.eq(is-blocked(done.nodes.at("b"), done), false)
#assert.eq(blockers-of(done.nodes.at("b"), done), ())

// An UNRESOLVED dep does not block: it names nothing, so it can never close,
// and treating it as a blocker would wedge a todo forever on a typo.
#let ghost = g(row("a", deps: ("nope",)))
#assert.eq(is-blocked(ghost.nodes.at("a"), ghost), false)

// ---- is-ready --------------------------------------------------------------
#let NOW = d(2026, 8, 25)
#assert.eq(is-ready(chain.nodes.at("a"), chain, today: NOW), true)
#assert.eq(is-ready(chain.nodes.at("b"), chain, today: NOW), false)
#assert.eq(is-ready(done.nodes.at("b"), done, today: NOW), true)
// A closed todo is never ready.
#assert.eq(is-ready(done.nodes.at("a"), done, today: NOW), false)

// Deferral is what makes this br's `ready` and not merely "not blocked".
// Built through `entries(..)` rather than by hardcoding `the `scheduled` log stage`, which is
// what this fixture used to do — and exactly the drift the exported stage names
// exist to prevent. As of 0.6.0 there is no such key: it is a stage in the log.
#let deferred = g(row("x", tags: entries(scheduled: d(2026, 12, 1))))
#assert.eq(is-ready(deferred.nodes.at("x"), deferred, today: NOW), false)
#let arrived = g(row("x", tags: entries(scheduled: d(2026, 8, 1))))
#assert.eq(is-ready(arrived.nodes.at("x"), arrived, today: NOW), true)
// No schedule at all is not deferral — absence of a plan is not a plan to wait.
#assert.eq(is-ready(g(row("x")).nodes.at("x"), g(row("x")), today: NOW), true)

// ---- epic-of ---------------------------------------------------------------
#assert.eq(epic-of((todo: none, "epic-launch": none)), "launch")
#assert.eq(epic-of(todo-tags()), none)
#assert.eq(epic-of((todo: none, "epic-q3-push": none)), "q3-push")

// ---- graph-slice — what a view draws, closed included or not --------------
//
// The pure half of `#todo-graph-view(closed: ..)`, split out so the option is
// testable without a DOM or a rookery registry.

#let g-slice = todo-graph(rows: (
  row("done", closed: true),
  row("open-a", deps: ("done",)),
  row("open-b", deps: ("open-a",)),
))

// `closed: true` is the default and changes nothing: every row, every edge.
#assert.eq(graph-slice(g-slice).rows.len(), 3)
#assert.eq(graph-slice(g-slice).edges.len(), 2)
#assert.eq(graph-slice(g-slice, closed: true).edges, g-slice.edges)

// `closed: false` drops the closed row.
#assert.eq(graph-slice(g-slice, closed: false).rows.map(r => r.name), ("open-a", "open-b"))

// ...and with it, the edge POINTING AT it — a satisfied dependency whose box is
// no longer on the page — while the edge between two open rows survives.
#assert.eq(graph-slice(g-slice, closed: false).edges, (("open-b", "open-a"),))

// ---- ACTIVATED-STAGE — this package's own log vocabulary ------------------
// rookery-timeline reserves `scheduled`, `deadline` and `closed` and leaves the rest
// to its consumers; a status TRANSITION is this package's to name, which its own
// header says outright.
#assert.eq(ACTIVATED-STAGE, "activated")
// The flat status key and the log entry are not redundant: the key is what a tag
// query filters on, the entry is what says since when.
#assert.eq(
  status-of(todo-tags(status: "in-progress")),
  "in-progress",
)

// ---- updated-of over a todo's log — what todos-stale now reads ------------
// It used to read core's `updated`, which fell back to the DOCUMENT's date, so
// staleness measured document age on any project that did not hand-write one.
#assert.eq(
  updated-of((created: d(2026, 1, 1)), entries(log: (activated: d(2026, 7, 1)))),
  d(2026, 7, 1),
)
#assert.eq(updated-of((created: d(2026, 1, 1)), (:)), d(2026, 1, 1))

// ---- TODO-LADDER — rookery-timeline's derivations, over this vocabulary --------
// The point of "a structure over the log": nothing here reimplements settledness.
// The ladder is the words, and that package does the reasoning.
#let _T = d(2026, 9, 1)
#assert.eq(TODO-LADDER.terminal, ("closed",))
#assert.eq(TODO-LADDER.transit, ("scheduled", "activated"))
#assert.eq(
  is-settled(entries(log: (closed: d(2026, 8, 1))), ladder: TODO-LADDER, today: _T),
  true,
)
#assert.eq(
  is-settled(entries(log: (activated: d(2026, 8, 1))), ladder: TODO-LADDER, today: _T),
  false,
)
#assert.eq(
  next-stage(entries(log: (scheduled: d(2026, 8, 1))), ladder: TODO-LADDER, today: _T),
  "activated",
)
// `deadline` is deliberately NOT a rung, so a todo carrying one has not advanced.
#assert.eq(rung(entries(deadline: d(2026, 8, 1)), ladder: TODO-LADDER, today: _T), none)
