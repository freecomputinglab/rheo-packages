// @rheo/rssfeed
//
// Atom 1.0 feed generation for Rheo projects, in pure Typst. This package
// replaces the Rust feed generator that was removed from rheo core — feed
// generation moves from the engine into a package, same as other
// project-shaped concerns already do.
//
// Two ways this package is used, once its API lands:
//
//   (a) Configured from a vertebra via a `configure(...)` call that a
//       project's `.marrow.typ` mints for it — the common case, where the
//       feed's sources and metadata are declared once and threaded through
//       automatically.
//
//   (b) Called directly from a project's own `.marrow.typ`, for projects
//       that want to assemble the feed's inputs themselves rather than go
//       through a minted `configure(...)`.
//
// No API yet: no `configure`, no `atom`, no entry model. This file is a
// stub — the surface above lands in follow-up work. It compiles as-is
// (a file of only comments is a valid Typst module).
