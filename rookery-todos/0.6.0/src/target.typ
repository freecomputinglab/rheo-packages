// Whether we are compiling under rheo and to what.
//
// A DELIBERATE COPY of rookery's, not an import of it. The originals are
// `_rheo-ctx` and `_target` in `rookery/0.6.0/src/base.typ`, where they are
// underscore-private: six lines of `sys.inputs` read, against making rookery
// widen its public surface with something no author would ever call.
// `sys.inputs` is readable from any package's scope, so the copy behaves
// identically. `@rheo/rookery-search` carries the same copy for the same
// reason, and says so in its own `base.typ`.
//
// `std.target()` reports EPUB as "html"; rheo's own context distinguishes
// them. `std.target()` rather than a bare `target()`, because rheo injects its
// `target()` polyfill into each vertebra's scope, not into package scope — and
// that read REQUIRES `--features html`, which every build of a project using
// this package therefore needs.
//
// Keep in step with rookery's. If that pair changes, this one changes too.
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: none)

#let _target() = {
  let c = _rheo-ctx()
  if c != none and "target" in c { c.target } else { std.target() }
}

// Every view branches on this. HTML and EPUB get `html.elem` markup; anything
// else is a PAGED target, where `html.elem` contributes NOTHING — no error, no
// warning, just an empty view under its heading. That silence is the defect
// this module exists to end.
#let _is-markup() = _target() == "html" or _target() == "epub"
