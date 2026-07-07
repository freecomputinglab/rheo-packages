# @rheo/justify

Knuth-Plass optimal justification for Typst HTML output.

On the HTML target this package runs Knuth-Plass optimal line breaking in the
browser and encodes the chosen breaks back into the paragraph text, so the
browser's own line breaker reproduces the optimal layout — with fully
selectable, reflowable real text (no canvas painting, no absolute positioning).
On PDF/EPUB the document passes through untouched and Typst's native
justification applies.

## Usage

```typ
#import "@rheo/justify:0.1.0": template
#show: template
#set par(justify: true)

Your justified prose here...
```

`template` is **whole-document, default-on**: it installs a `show par` rule that
routes every justified paragraph through client-side Knuth-Plass. Paragraphs
that are not justified (`par(justify: false)`) are left alone.

## Honoring justification limits

Control the word-space elasticity with the standard Typst knobs — no custom API:

```typ
#set par(justify: true, justification-limits: (
  spacing: (min: 83% + 0pt, max: 150% + 0pt),
))
```

The template reads `par.justification-limits` via `context` and forwards the
`spacing` bounds to the client, which feeds them into the KP glue elasticity
(`minSpaceFrac` / `maxSpaceFrac`). When you leave `justification-limits` at the
Typst default, the package substitutes its own book-quality default
(`spacing 0.83 .. 1.5`).

**Honored in v1:** word spacing (`spacing`). **Deferred:** letter tracking
(`tracking`) — parsed but not yet applied; it would need CSS `letter-spacing`.

## Opting a block out

Wrap content in `no-justify` to leave it to the browser / Typst native flow:

```typ
#import "@rheo/justify:0.1.0": template, no-justify
#show: template

#no-justify[
  This block is not run through client-side justification.
]
```

## Caveats

- **HTML target only.** PDF and EPUB use Typst's native justification; the
  output is byte-identical to not importing the package.
- **Requires a named font.** Measurement is unsafe with `system-ui` (and other
  keyword families); blocks without a resolvable named family are left native.
- **Requires `Intl.Segmenter`** in the browser (a `@chenglou/pretext`
  requirement). Where it is absent, the paragraph falls back to plain browser
  rendering.
- **Text-only paragraphs in v1.** A paragraph containing inline markup (links,
  emphasis) is left to the browser; per-node encoding that preserves element
  boundaries is a documented follow-up.
- **No client-side hyphenation in v1.** Breaks are chosen at word boundaries;
  existing hard hyphens are held non-breaking. A hyphenation dictionary is a
  follow-up.
- **Graceful degradation.** With JavaScript disabled the browser renders the
  plain paragraph text as normal.
