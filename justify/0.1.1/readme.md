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
#import "@rheo/justify:0.1.1": template
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

**Honored in v1:** the word-space **stretch** bound (`spacing.max`). The
**shrink** bound (`spacing.min`) does not apply on the HTML target: within-line
gaps are encoded as non-breaking spaces, which the browser stretches under
`text-align: justify` but never shrinks below their natural width — so KP plans
lines that only ever stretch. **Deferred:** letter tracking (`tracking`) —
parsed but not yet applied; it would need CSS `letter-spacing`.

Because gaps cannot shrink, the usable elasticity is only `1 .. spacing.max`,
and most columns admit no layout inside so narrow a band. When none exists the
stretch bound is **raised in 10% steps until one does** — the resulting line is
looser than you asked for, but it is laid out exactly, which the alternative
(packing greedily and hoping) is not. A paragraph with a word wider than its
column is left ragged instead of justified.

## Hyphenation

The client hyphenates justified paragraphs so Knuth-Plass can break long words
at syllable boundaries — packing more text per line, so the column runs shorter
with tighter spacing. It honors the standard Typst knob:

```typ
#set text(hyphenate: true)    // force on
#set text(hyphenate: false)   // force off
#set text(hyphenate: auto)    // default: on when the paragraph is justified
```

Because the package only touches justified paragraphs, the default `auto`
hyphenates them — matching what Typst's native justification does for PDF/EPUB,
so the three targets stay consistent. Language is taken from `text.lang`.

**v1 covers English only** (`lang: "en"`). Other languages are justified without
hyphenation until their patterns are bundled. Words that already contain a
hyphen are left to break at that hyphen and are not split further.

## Opting a block out

Wrap content in `no-justify` to leave it to the browser / Typst native flow:

```typ
#import "@rheo/justify:0.1.1": template, no-justify
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
- **English hyphenation only in v1** (see above); other languages justify
  without word breaks.
- **Invisible characters in the encoded text.** Reproducing the chosen layout
  means writing no-break spaces, soft hyphens and word joiners into the
  paragraph, so copied text carries them. Word joiners fence off the in-word
  break opportunities the word model cannot see (em dash, en dash, slash): left
  alone, the browser takes one whenever a line comes out a hair too wide, and
  justifies the fragment it leaves behind across a single gap.
- **Graceful degradation.** With JavaScript disabled the browser renders the
  plain paragraph text as normal.
