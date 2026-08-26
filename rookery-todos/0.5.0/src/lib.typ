// @rheo/rookery-todos — todos, epics and a dependency DAG over rookery notes.
//
// A todo is an `@rheo/rookery` note carrying a `todo` tag, plus whatever else
// this package folds into its tag dictionary. Nothing new is stored anywhere:
// the registry rookery already keeps IS the todo database, and every view here
// is derived from it at build time.
//
// THE FRAMING THAT DECIDES WHAT IS HERE: `br` (the beads issue tracker) is a
// mutable SQLite database; this is a static build. So this package ports br's
// DERIVED VIEWS — ready, blocked, stale, graph, stats — and not its mutation
// surface. A status change here is an edit to a `.typ` file, which is the
// point rather than a shortcoming.
//
// THE ORDER OF THESE IMPORTS IS DEPENDENCY ORDER and it is load-bearing: a
// Typst `#let` closure captures the scope visible AT DEFINITION time, so a
// module can only use names from a module imported before it. A wrong order is
// an unknown-variable error, which is how this order was arrived at.

#import "target.typ": *
#import "tags.typ": *
#import "todo.typ": *
#import "graph.typ": *
#import "views.typ": *
#import "search.typ": *
