// The corpus, the dependency graph over it, and the checks that keep it a DAG.
//
// Nothing here renders. `views.typ` is the rendering half; this file is the
// data and the validation, so a project can build its own views on the same
// footing the shipped ones stand on.

#import "@rheo/rookery:0.5.0": ideas, tag-data
#import "@rheo/rookery-dates:0.5.0": is-scheduled-now, scheduled-of
#import "tags.typ": *

// ---- todos() — every todo in the rookery, joined with its tag values ------
//
//   #context todos()
//
// One row per note carrying the `todo` key, each carrying rookery's own row
// fields (id, name, title, text, href, page, minted, updated) plus this
// package's decoded attributes and the raw tag dictionary.
//
// TWO BULK READS, NOT N SMALL ONES, and that is deliberate. `ideas()` resolves
// the registry once for the whole corpus and `tag-data()` does the same for the
// tag store; joining them on `id` costs nothing. Reaching for `tags-of` or
// `tag-value` per row instead would pay one registry resolution PER NOTE — a
// cost rookery's own `data.typ` documents explicitly against `tags-of`.
//
// Must be called INSIDE a `#context` block: `ideas()` and `tag-data()` both
// read `.final()`. Like them, it is not itself a context function, because a
// context function may only return content and the whole point is to return
// data.
#let todos() = {
  let store = tag-data()
  ideas()
    .map(e => {
      let tags = store.at(e.id, default: (:))
      (
        ..e,
        tags-dict: tags,
        priority: priority-of(tags),
        kind: type-of(tags),
        status: status-of(tags),
        closed: is-closed(tags),
        closed-on: closed-on(tags),
        deps: deps-of(tags),
        metadata: metadata-of(tags),
      )
    })
    .filter(t => is-todo(t.tags-dict))
}

// ---- todo-graph() — adjacency over `todo-deps` ----------------------------
//
// Returns `(nodes: (name -> row), edges: ((from, to), ..), unresolved: ((from,
// dep), ..))`, where an edge runs FROM a todo TO something it depends on.
//
// Keyed by `name` — the id with rookery's prefix stripped — because that is
// what an author writes in `deps: ("fetch",)` and what rookery's `_norm` maps
// every accepted form onto. Deps were already normalized at write time
// (`todo-tags`), so no id arithmetic happens here: matching is a dictionary
// lookup against the rows `todos()` returned. Do NOT rebuild ids with rookery's
// `_pfx()` — it is contextual state, and the rows already carry both forms.
//
// A DANGLING DEP IS NOT AN ERROR. It is collected into `unresolved` and left
// for a view to render as such. This follows the precedent rookery sets with
// `tags-of`, where an unknown id answers emptily rather than panicking: a
// caller asking about dependencies is describing a graph, not dereferencing a
// pointer, and a description that dies on the first typo is useless.
#let todo-graph(rows: none) = {
  let rows = if rows == none { todos() } else { rows }
  let nodes = rows.map(t => (t.name, t)).to-dict()
  let edges = ()
  let unresolved = ()
  for t in rows {
    for d in t.deps {
      if d in nodes { edges.push((t.name, d)) } else { unresolved.push((t.name, d)) }
    }
  }
  (nodes: nodes, edges: edges, unresolved: unresolved)
}

// ---- cycle detection ------------------------------------------------------
//
// A depth-first walk colouring each node white/grey/black. A grey node reached
// again is a back edge, i.e. a cycle, and the grey stack at that moment IS the
// cycle path — which is what makes the error message name the actual loop
// rather than merely assert one exists.
//
// Iterative rather than recursive: Typst has a recursion depth limit and a
// rookery is not bounded in size, so a deep chain must not be the thing that
// breaks first.
//
// Returns the cycle as an array of names (first name repeated at the end), or
// `()` when the graph is acyclic.
#let find-cycle(graph) = {
  let adj = (:)
  for name in graph.nodes.keys() { adj.insert(name, ()) }
  for e in graph.edges { adj.insert(e.at(0), adj.at(e.at(0)) + (e.at(1),)) }

  let colour = (:)
  for name in adj.keys() { colour.insert(name, "white") }

  for root in adj.keys() {
    if colour.at(root) != "white" { continue }
    // Each frame is (node, index of the next child to visit).
    let stack = ((root, 0),)
    colour.insert(root, "grey")
    while stack.len() > 0 {
      let (node, i) = stack.last()
      let kids = adj.at(node)
      if i >= kids.len() {
        colour.insert(node, "black")
        let _ = stack.pop()
        continue
      }
      stack.at(stack.len() - 1) = (node, i + 1)
      let kid = kids.at(i)
      let c = colour.at(kid, default: "white")
      if c == "grey" {
        // Back edge. The cycle is the grey stack from `kid` onward, closed by
        // `kid` again.
        let path = stack.map(f => f.at(0))
        let start = path.position(n => n == kid)
        return path.slice(start) + (kid,)
      }
      if c == "white" {
        colour.insert(kid, "grey")
        stack.push((kid, 0))
      }
    }
  }
  ()
}

// Panics naming the full cycle path when there is one. Every view in this
// package calls this before rendering.
//
// WHY IT CANNOT RUN AT THE `#todo` CALL SITE, which is what you might expect:
// `#todo("a", deps: ("b",))` is perfectly legal before `b` exists, and the
// graph only exists once the registry is final. There is no moment during
// authoring at which a cycle is visible. So the guarantee is assembled from two
// halves instead — every view checks, and `#todos-validate()` below lets a
// project that renders no view check anyway. Between them a cycle cannot
// survive a build.
#let assert-acyclic(graph) = {
  let cycle = find-cycle(graph)
  if cycle.len() > 0 {
    panic(
      "@rheo/rookery-todos: dependency cycle: " + cycle.join(" -> ")
        + ". Todos are networked purely through `deps:`, so this graph has no "
        + "order to render — break the loop by removing one of these edges.",
    )
  }
}

// ---- derived state — computed at render, never stored ---------------------
//
// `blocked`, `ready` and `stale` are questions about the graph and the calendar
// as they stand right now, not facts about a note. Tagging them would let them
// drift out of step with the deps and dates that define them, and nothing would
// report the drift.

// Blocked: at least one dependency exists and is not yet closed. An UNRESOLVED
// dep does not block — it names nothing, so it can never close, and treating it
// as a blocker would wedge a todo forever on a typo.
#let is-blocked(row, graph) = row.deps.any(d => {
  let dep = graph.nodes.at(d, default: none)
  dep != none and not dep.closed
})

// Which dependencies are blocking, for a view that wants to say why.
#let blockers-of(row, graph) = row.deps.filter(d => {
  let dep = graph.nodes.at(d, default: none)
  dep != none and not dep.closed
})

// Ready: open, unblocked, and not deferred past the reference date.
//
// THE DEFERRAL CLAUSE IS WHAT MAKES THIS br's `ready` RATHER THAN MERELY "not
// blocked". A todo scheduled for next week is not work you can pick up now.
// Deferral is read from @rheo/rookery-dates' `date-scheduled`, so scheduling
// stays one concept owned by one package rather than two that can disagree.
//
// A todo with NO `date-scheduled` is not deferred — absence of a plan is not a
// plan to wait, which is why this asks `scheduled-of(..) == none or ..` rather
// than `is-scheduled-now(..)` alone.
//
// `today:` is passed through to rookery-dates, which resolves it against the
// document date and panics if neither is available. NOTHING HERE CALLS
// `datetime.today()`: it returns 1980-01-01 under a reproducible build and does
// not error while doing it.
#let is-ready(row, graph, today: none) = {
  if row.closed { return false }
  if is-blocked(row, graph) { return false }
  let sched = scheduled-of(row.tags-dict)
  sched == none or is-scheduled-now(row.tags-dict, today: today)
}

// ---- #todos-validate() — fail the build on a broken graph -----------------
//
// Drop it at bundle root in a project that renders no todo view, so a cycle
// still cannot ship. Renders nothing.
//
// Also REPORTS what cannot be a warning. Typst gives package code no `warn()`,
// only `panic`, so the auto-id dependency smell — a dep naming an unpinned,
// sequence-numbered note, whose number shifts when a note is inserted earlier
// in the spine — has nowhere else to surface. `strict: true` turns it into an
// error for a project that wants the stricter rule; the default reports it in
// the compiled output rather than failing a build that has not actually broken.
#let todos-validate(strict: false) = context {
  let graph = todo-graph()
  assert-acyclic(graph)

  let numeric = ()
  for (name, row) in graph.nodes {
    for d in row.deps {
      // An auto id is rookery's counter value: digits and nothing else.
      if d.len() > 0 and d.clusters().all(c => c in ("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")) {
        numeric.push(name + " -> " + d)
      }
    }
  }

  let problems = ()
  if numeric.len() > 0 {
    problems.push(
      "depends on an auto-numbered note, whose id shifts when a note is "
        + "inserted earlier in the spine — pin it with `#todo(\"name\")`: "
        + numeric.join(", "),
    )
  }
  if graph.unresolved.len() > 0 {
    problems.push(
      "depends on a note that does not exist: "
        + graph.unresolved.map(p => p.at(0) + " -> " + p.at(1)).join(", "),
    )
  }

  if problems.len() == 0 { return }
  let msg = "@rheo/rookery-todos: " + problems.join("; ")
  if strict { panic(msg) } else {
    html.elem("div", attrs: (class: "todo-validate-report", hidden: "hidden"), msg)
  }
}
