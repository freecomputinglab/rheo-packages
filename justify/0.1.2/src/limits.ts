// rheo-justify: map Typst `par.justification-limits` into KP glue elasticity.
//
// The spike (rheo-packages-4n3) established that `context par.justification-limits`
// resolves to a dictionary of the shape:
//
//   (
//     spacing:  (min: <relative length>, max: <relative length>),  // rel. to space width
//     tracking: (min: <length>,          max: <length>),           // additive, per glyph
//   )
//
// with Typst's built-in defaults `spacing (2/3, 3/2)`, `tracking (0pt, 0pt)`.
//
// This module converts that (once lib.typ has forwarded it to the client) into
// the word-space bounds the kp.ts optimizer consumes (`minSpaceFrac` /
// `maxSpaceFrac`, fractions of the natural space width). See issue
// rheo-packages-m0w.
//
// TRACKING (letter-level justification) is intentionally NOT honored in v1: the
// space/no-break-space encoding in encode.ts controls word spacing only.
// Letter tracking would need CSS `letter-spacing` / `text-justify:
// inter-character` and is captured as a follow-up. `tracking` bounds are parsed
// and preserved on the resolved value but do not influence line breaking yet.

import type { JustifyConfig } from "./kp.ts";

/**
 * A relative length: a ratio (as a fraction, e.g. 0.9 for 90%) plus an absolute
 * length in points. Mirrors Typst's `Rel<Length>` (`90% + 0pt`).
 */
export interface RelLength {
  /** Ratio part, as a fraction (Typst `90%` -> 0.9). */
  ratio: number;
  /** Absolute part, in points (Typst `0.01em` is resolved to pt upstream). */
  length: number;
}

export interface Bounds<T> {
  min: T;
  max: T;
}

export interface JustificationLimits {
  /** Word-space bounds, relative to the natural space width. */
  spacing: Bounds<RelLength>;
  /** Letter-space bounds, in points. Parsed but not yet applied (v1). */
  tracking: Bounds<number>;
}

/**
 * Package default word-space bounds ("column 4" book-quality values from the
 * Andy Bell demo), used when the author sets no `justification-limits`. Slightly
 * tighter on the shrink side than Typst's own `2/3` default for a more even
 * book look.
 */
export const DEFAULT_LIMITS: JustificationLimits = {
  spacing: {
    min: { ratio: 0.83, length: 0 },
    max: { ratio: 1.5, length: 0 },
  },
  tracking: { min: 0, max: 0 },
};

/**
 * Parse a Typst relative-length repr such as `"90% + 0pt"`, `"66.67%"`,
 * `"150% + 0pt"`, or a plain length `"0pt"` into a {@link RelLength}. Accepts
 * the forms Typst's `repr()` emits for `Rel<Length>` and `Length`.
 */
export function parseRelLength(repr: string): RelLength {
  let ratio = 0;
  let length = 0;
  // Split on ` + ` / ` - ` while keeping signs.
  const normalized = repr.trim().replace(/\s*-\s*/g, " + -").replace(/\s*\+\s*/g, " + ");
  for (const rawTerm of normalized.split(" + ")) {
    const term = rawTerm.trim();
    if (term === "") continue;
    if (term.endsWith("%")) {
      ratio += parseFloat(term.slice(0, -1)) / 100;
    } else if (term.endsWith("pt")) {
      length += parseFloat(term.slice(0, -2));
    } else if (term.endsWith("em")) {
      // em cannot be resolved without the font size; caller should resolve to pt
      // upstream. Reject rather than silently mismeasure.
      throw new Error(`parseRelLength: unresolved em term "${term}" — resolve to pt first`);
    } else {
      throw new Error(`parseRelLength: unrecognized term "${term}" in "${repr}"`);
    }
  }
  return { ratio, length };
}

/** A partial limits value as it may arrive from the wire (any entry optional). */
export interface PartialLimits {
  spacing?: Partial<Bounds<RelLength>>;
  tracking?: Partial<Bounds<number>>;
}

/**
 * Resolve a possibly-partial limits value against the package default, matching
 * Typst's fold semantics: any entry the author did not set retains the default.
 * Pass `null`/`undefined` (author set nothing) to get the package default.
 */
export function resolveLimits(partial?: PartialLimits | null): JustificationLimits {
  return {
    spacing: {
      min: partial?.spacing?.min ?? DEFAULT_LIMITS.spacing.min,
      max: partial?.spacing?.max ?? DEFAULT_LIMITS.spacing.max,
    },
    tracking: {
      min: partial?.tracking?.min ?? DEFAULT_LIMITS.tracking.min,
      max: partial?.tracking?.max ?? DEFAULT_LIMITS.tracking.max,
    },
  };
}

/** Reduce a relative-length bound to a plain fraction of the space width. */
function toFraction(rel: RelLength, spaceWidth: number): number {
  if (rel.length !== 0 && !(spaceWidth > 0)) {
    throw new Error(
      "limits: a non-zero absolute space bound requires a positive spaceWidth",
    );
  }
  return rel.ratio + (rel.length !== 0 ? rel.length / spaceWidth : 0);
}

/**
 * Convert resolved limits into the word-space fraction bounds kp.ts consumes.
 * `spaceWidth` (px) is only needed when a bound carries a non-zero absolute
 * part; for the common ratio-only bounds it may be omitted.
 */
export function limitsToElasticity(
  limits: JustificationLimits,
  spaceWidth = 0,
): { minSpaceFrac: number; maxSpaceFrac: number } {
  return {
    minSpaceFrac: toFraction(limits.spacing.min, spaceWidth),
    maxSpaceFrac: toFraction(limits.spacing.max, spaceWidth),
  };
}

export interface ConfigOptions {
  /** Natural space width in px; required only if a bound has an absolute part. */
  spaceWidth?: number;
  /** Cost charged for a hyphenated line end. Default 100. */
  hyphenPenalty?: number;
  /** Deviation cost exponent passed through to kp.ts. */
  costExponent?: number;
}

/**
 * Build a full {@link JustifyConfig} for kp.ts from a (possibly partial) limits
 * value. Unset entries fall back to the package default (column-4 look).
 */
export function makeConfig(
  partial?: PartialLimits | null,
  opts: ConfigOptions = {},
): JustifyConfig {
  const limits = resolveLimits(partial);
  const { minSpaceFrac, maxSpaceFrac } = limitsToElasticity(
    limits,
    opts.spaceWidth ?? 0,
  );
  return {
    minSpaceFrac,
    maxSpaceFrac,
    hyphenPenalty: opts.hyphenPenalty ?? 100,
    costExponent: opts.costExponent,
  };
}
