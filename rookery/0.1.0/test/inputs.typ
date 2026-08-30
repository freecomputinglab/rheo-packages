// The half of `_resolve-excluded` that `test/units.typ` cannot reach: the two
// `sys.inputs` keys.
//
// A SECOND FIXTURE rather than more cases in `units.typ`, because `sys.inputs`
// is fixed for a whole compile — it is set by `--input` on the command line, so
// varying it means varying the invocation, which means a separate file. The
// `test` recipe in this package's `Justfile` compiles it with:
//
//   --input rookery-exclude=c --input rookery-include=a
//
// Same harness as `units.typ`: no runner, `assert.eq` fails the compile with a
// line number, `--features html` mandatory because `std.target` is gated by the
// feature rather than the output format and `/src/lib.typ` reads it at import
// time.

#import "/src/lib.typ": _input-tags, _resolve-excluded

// The keys as read, before any composition.
#assert.eq(_input-tags("rookery-exclude"), ("c",))
#assert.eq(_input-tags("rookery-include"), ("a",))
// An absent key is `()`, not an error — a project setting neither is the normal
// case and must not have to set them to empty strings.
#assert.eq(_input-tags("rookery-nope"), ())

// THE COMPOSITION, which is the whole point of the feature:
//
//   excluded = (declared UNION rookery-exclude) MINUS rookery-include
//
// `a` is declared but `rookery-include`d, so it survives the filter — this is
// the DEV build putting a `protected`/`private` note back. `c` is not declared
// at all but `rookery-exclude`d, so it is dropped — this is a build script
// carving a further subsection without touching the project source. `b` is
// declared and untouched by either key.
#assert.eq(_resolve-excluded(("a", "b")), ("b", "c"))
// `rookery-include` wins over `rookery-exclude` for the same tag, since the
// subtraction is applied last. A build asking for a tag back gets it back,
// whatever else asked for it to go.
#assert.eq(_resolve-excluded("a"), ("c",))
// Nothing declared: the env alone still excludes.
#assert.eq(_resolve-excluded(none), ("c",))
