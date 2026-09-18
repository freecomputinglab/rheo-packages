# Spike: reading `par.justification-limits` via `context`

Findings for issue rheo-packages-4n3. Verified empirically against the
rheo-bundled Typst (0.15.0) by compiling probe `.typ` files to HTML with
`rheo compile <file> --html` and inspecting the emitted `repr(...)` output, and
against the `typst-library` 0.15.0 source in the cargo registry.

## 1. Does `context par.justification-limits` work? — YES

All of the relevant author set-rule values are readable inside a `#context`
block as fields on the element functions, and each resolves to the **effective**
set-rule value:

```typ
#set par(justification-limits: (spacing: (min: 90%, max: 150%)))
#set par(justify: true)
#set text(size: 12pt, lang: "en", hyphenate: true)
#context [ ... #repr(par.justification-limits) ... ]
```

produced:

| field                       | resolved value                                              |
| --------------------------- | ----------------------------------------------------------- |
| `par.justification-limits`  | `(spacing: (min: 90% + 0pt, max: 150% + 0pt), tracking: (min: 0pt, max: 0pt))` |
| `par.justify`               | `true`                                                      |
| `text.font`                 | `"libertinus serif"`                                        |
| `text.size`                 | `12pt`                                                      |
| `text.lang`                 | `"en"`                                                      |
| `text.hyphenate`            | `true`                                                      |

Note that setting only `spacing` left `tracking` at its default — confirming the
"retains previously set value / default" fold behaviour documented on the field.

## 2. Serialized shape of `par.justification-limits`

A dictionary with two entries, each a `{min, max}` dictionary:

```typ
(
  spacing:  (min: <relative length>, max: <relative length>),
  tracking: (min: <length>,          max: <length>),
)
```

- **`spacing`** min/max are **relative lengths** (`ratio + absolute`), relative
  to the normal space width. Their `repr` is `<pct>% + <len>pt`, e.g.
  `90% + 0pt`. In the source these are `Rel<Length>` (a `Ratio` plus a
  `Length`). The ratio part must be positive; the length part must be ≤ 0 for
  `min` and ≥ 0 for `max`.
- **`tracking`** min/max are plain **lengths** (`Length`, e.g. `0.01em` →
  resolved to `pt`), added between glyphs. No relative part.

JSON-serializable mapping for the runtime (`kp.ts` config): read the two ratios
and the absolute parts out of `spacing.min` / `spacing.max`, convert to
fractions of the measured space width. `tracking` maps to per-glyph letter-space
elasticity (not yet consumed by the word-level `kp.ts` core; reserve the field).

## 3. Defaults (the "unset" value)

`par.justification-limits` is **always present** — it is *not* `none`/disabled by
default (the issue's guess was wrong on this point). Compiling with nothing set
yields Typst's built-in defaults:

```
spacing:  (min: 66.67% + 0pt, max: 150% + 0pt)   // i.e. min = 2/3, max = 3/2
tracking: (min: 0pt, max: 0pt)                   // no letter-spacing adjustment
```

So word-space justification is bounded to `[2/3, 3/2]` of the natural space by
default, and character-level (tracking) justification is effectively **off**
(0pt/0pt) until the author widens the tracking bounds. `par.justify` itself is
`false` by default.

## 4. Typst version

- The `justification-limits` property (char-level justification, typst/typst
  PR #6161) is present in `typst-library` **0.14.2 and 0.15.0**.
- rheo pins Typst **0.15.0** (`rheo/Cargo.toml`, confirmed in `Cargo.lock`), so
  the bundled Typst **supports it**. Minimum usable version for our purposes:
  ≥ 0.14.

## 5. Fallback plan

**Not needed.** `context par.justification-limits` works in the bundled Typst,
so `lib.typ` can read the author's effective `{spacing, tracking}` bounds
directly and forward them to the client-side justifier via data attributes.
No package-level mirror parameter is required.

This unblocks the `lib.typ` template issue.
