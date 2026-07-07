// rheo-justify: optimal (Knuth-Plass-style) line breaking.
//
// This module is the pure line-breaking core. It knows nothing about the DOM
// or @chenglou/pretext: it operates on measured segment widths and returns the
// chosen break points. The runtime layer (lib.ts) is responsible for turning a
// pretext prepared handle into the SegmentStream this module consumes, and for
// encoding the result back onto the DOM. Keeping the algorithm free of any
// pretext/DOM dependency is what makes it unit-testable without a browser.
//
// Cost model: minimize the sum, over every justified line, of the squared (or
// cubed) deviation of the actual inter-word space from the natural space width.
// A line is infeasible (infinite cost) if justifying it would push the word
// space below `minSpaceFrac` or above `maxSpaceFrac` of the natural space. A
// break taken at a hyphenation point adds `hyphenPenalty` to the cost. The last
// line of the paragraph is set ragged (never stretched), so it is only
// infeasible if its natural content overflows the target width.
//
// See issue rheo-packages-fcm.

/** How adjacent segments are joined. */
export type Join =
  | "space" // a normal, stretchable inter-word space
  | "hyphen" // an optional break; contributes a hyphen glyph iff a line ends here
  | "none"; // glued: the two segments never break apart (e.g. within a word)

export interface SegmentStream {
  /** Natural width of each unbreakable segment, in px, in reading order. */
  segmentWidths: number[];
  /**
   * How each adjacent pair of segments is joined. Length must be
   * `segmentWidths.length - 1`; `joins[k]` describes the join between segment
   * `k` and segment `k + 1`.
   */
  joins: Join[];
  /** Natural width of one normal inter-word space, in px. */
  spaceWidth: number;
  /** Width of the hyphen glyph inserted when a line ends at a `hyphen` join. */
  hyphenWidth: number;
}

export interface JustifyConfig {
  /** Minimum word space as a fraction of the natural space width (e.g. 0.9). */
  minSpaceFrac: number;
  /** Maximum word space as a fraction of the natural space width (e.g. 1.5). */
  maxSpaceFrac: number;
  /** Extra cost charged when a line ends on a hyphenation break. */
  hyphenPenalty: number;
  /** Power the space deviation is raised to. 2 = squared (default), 3 = cubed. */
  costExponent?: number;
}

/** A single laid-out line: the inclusive segment range it covers. */
export interface Line {
  /** Index of the first segment on the line. */
  start: number;
  /** Index of the last segment on the line (inclusive). */
  end: number;
  /** Actual width of one inter-word space on this line, in px. */
  spaceWidth: number;
  /** True if this line ends at a hyphenation break (a hyphen glyph is added). */
  hyphenated: boolean;
}

export interface BreakResult {
  lines: Line[];
  /**
   * Indices into `joins` at which a line break was taken (i.e. the join after
   * the last segment of each non-final line). Useful for encoding to the DOM.
   */
  breakJoins: number[];
  /** Indices into `joins` (of kind `hyphen`) where a hyphen was materialized. */
  hyphenBreaks: number[];
  /** Total cost of the chosen layout. `Infinity` implies no feasible layout. */
  cost: number;
  /** True if the result came from the greedy fallback rather than the optimum. */
  fallback: boolean;
}

const DEFAULT_EXPONENT = 2;

/**
 * Build a SegmentStream from a plain list of word widths, joining every word
 * with a normal space. Convenience for the common all-space case (and tests).
 */
export function wordsToStream(
  wordWidths: number[],
  spaceWidth: number,
  hyphenWidth = 0,
): SegmentStream {
  return {
    segmentWidths: wordWidths.slice(),
    joins: wordWidths.slice(1).map((): Join => "space"),
    spaceWidth,
    hyphenWidth,
  };
}

interface LineMetrics {
  /** Natural width of the line's boxes plus any trailing hyphen glyph. */
  boxWidth: number;
  /** Number of stretchable spaces inside the line. */
  spaces: number;
  /** True if the line ends at a hyphen join. */
  hyphenated: boolean;
}

/**
 * Measure a candidate line covering segments [start, end] (inclusive). `atEnd`
 * is the join taken immediately after `end`, or `null` if `end` is the last
 * segment of the paragraph. Returns null if the range spans a `none` join at
 * its boundary (i.e. the break would split a glued unit) — such breaks are
 * illegal.
 */
function measureLine(
  s: SegmentStream,
  start: number,
  end: number,
  atEnd: Join | null,
): LineMetrics | null {
  // A break may only be taken after `end` at a `space` or `hyphen` join (or at
  // the paragraph end). Breaking at a `none` join would split a glued unit.
  if (atEnd === "none") return null;

  let boxWidth = 0;
  let spaces = 0;
  for (let i = start; i <= end; i++) {
    boxWidth += s.segmentWidths[i];
    if (i < end) {
      // Interior join between i and i+1.
      const join = s.joins[i];
      if (join === "space") spaces++;
      // `none` and interior `hyphen` add no width (hyphens only show at a break).
    }
  }
  const hyphenated = atEnd === "hyphen";
  if (hyphenated) boxWidth += s.hyphenWidth;
  return { boxWidth, spaces, hyphenated };
}

/**
 * Compute the cost of a single line, given its metrics and whether it is the
 * paragraph's final line. Returns Infinity if the line is infeasible.
 */
function lineCost(
  m: LineMetrics,
  targetWidth: number,
  s: SegmentStream,
  cfg: JustifyConfig,
  isLast: boolean,
): { cost: number; spaceWidth: number } {
  const exponent = cfg.costExponent ?? DEFAULT_EXPONENT;

  if (m.spaces === 0) {
    // A spaceless run has nothing to stretch or shrink.
    if (m.boxWidth - targetWidth > 1e-6) {
      return { cost: Infinity, spaceWidth: s.spaceWidth }; // overflows the column.
    }
    if (!isLast && targetWidth - m.boxWidth > 1e-6) {
      // A short spaceless line in the middle of a paragraph cannot be justified
      // (there is no gap to widen), so it is not a legal justified line. This is
      // what stops the optimizer from degenerating to one word per line.
      return { cost: Infinity, spaceWidth: s.spaceWidth };
    }
    // Fits exactly (or is the ragged last line); charge only any hyphen penalty.
    return {
      cost: m.hyphenated ? cfg.hyphenPenalty : 0,
      spaceWidth: s.spaceWidth,
    };
  }

  // Distribute the slack evenly across the line's spaces.
  const actualSpace = (targetWidth - m.boxWidth) / m.spaces;

  if (isLast) {
    // The last line is ragged: never stretched, never charged for short lines.
    // It is only infeasible if its natural content overflows the target.
    const natural = m.boxWidth + m.spaces * s.spaceWidth;
    if (natural - targetWidth > 1e-6) {
      return { cost: Infinity, spaceWidth: s.spaceWidth };
    }
    return {
      cost: m.hyphenated ? cfg.hyphenPenalty : 0,
      spaceWidth: s.spaceWidth,
    };
  }

  // Enforce the word-space bounds.
  if (
    actualSpace < cfg.minSpaceFrac * s.spaceWidth - 1e-9 ||
    actualSpace > cfg.maxSpaceFrac * s.spaceWidth + 1e-9
  ) {
    return { cost: Infinity, spaceWidth: actualSpace };
  }

  const deviation = Math.abs(actualSpace - s.spaceWidth);
  const cost =
    Math.pow(deviation, exponent) + (m.hyphenated ? cfg.hyphenPenalty : 0);
  return { cost, spaceWidth: actualSpace };
}

/** Legal break positions after a given segment index: `space`/`hyphen` joins. */
function isBreakable(join: Join): boolean {
  return join === "space" || join === "hyphen";
}

/**
 * Optimal line breaking via dynamic programming. Returns the break sequence
 * that minimizes total cost. Falls back to {@link greedyBreak} when no feasible
 * justified layout exists (e.g. a column so narrow no break sequence stays in
 * bounds, or an unbreakable word wider than the column).
 */
export function breakParagraph(
  s: SegmentStream,
  targetWidth: number,
  cfg: JustifyConfig,
): BreakResult {
  const n = s.segmentWidths.length;
  if (n === 0) {
    return { lines: [], breakJoins: [], hyphenBreaks: [], cost: 0, fallback: false };
  }
  if (s.joins.length !== n - 1) {
    throw new Error(
      `joins length ${s.joins.length} must equal segmentWidths length - 1 (${n - 1})`,
    );
  }

  // best[i] = min cost to lay out segments [i, n). choice[i] = the segment index
  // `end` of the first line starting at i (line covers [i, end]).
  const best = new Array<number>(n + 1).fill(Infinity);
  const choice = new Array<number>(n + 1).fill(-1);
  const chosenSpace = new Array<number>(n + 1).fill(0);
  const chosenHyphen = new Array<boolean>(n + 1).fill(false);
  best[n] = 0;

  for (let i = n - 1; i >= 0; i--) {
    for (let end = i; end < n; end++) {
      // A line covering [i, end] can only start if the join *before* it is a
      // legal break. That is enforced by the caller taking the break after the
      // previous line, so here we just guard the join *after* `end`.
      const atEnd: Join | null = end === n - 1 ? null : s.joins[end];
      if (atEnd !== null && !isBreakable(atEnd)) continue; // can't break here.

      const m = measureLine(s, i, end, atEnd);
      if (m === null) continue;

      const isLast = end === n - 1;
      const { cost, spaceWidth } = lineCost(m, targetWidth, s, cfg, isLast);
      if (!Number.isFinite(cost)) continue;

      const total = cost + best[end + 1];
      if (total < best[i]) {
        best[i] = total;
        choice[i] = end;
        chosenSpace[i] = spaceWidth;
        chosenHyphen[i] = m.hyphenated;
      }
    }
  }

  if (!Number.isFinite(best[0]) || choice[0] === -1) {
    return greedyBreak(s, targetWidth, cfg);
  }

  const lines: Line[] = [];
  const breakJoins: number[] = [];
  const hyphenBreaks: number[] = [];
  let i = 0;
  while (i < n) {
    const end = choice[i];
    lines.push({
      start: i,
      end,
      spaceWidth: chosenSpace[i],
      hyphenated: chosenHyphen[i],
    });
    if (end < n - 1) {
      breakJoins.push(end); // join index after segment `end`.
      if (chosenHyphen[i]) hyphenBreaks.push(end);
    }
    i = end + 1;
  }

  return { lines, breakJoins, hyphenBreaks, cost: best[0], fallback: false };
}

/**
 * Greedy first-fit line breaking: fill each line with as many segments as fit
 * within `targetWidth` at the natural space width, breaking at the last legal
 * join. Always completes — even for pathologically narrow columns — by placing
 * at least one segment per line. Used as the fallback when no feasible optimal
 * layout exists, and as a baseline in tests.
 */
export function greedyBreak(
  s: SegmentStream,
  targetWidth: number,
  cfg: JustifyConfig,
): BreakResult {
  const n = s.segmentWidths.length;
  const lines: Line[] = [];
  const breakJoins: number[] = [];
  const hyphenBreaks: number[] = [];

  let start = 0;
  while (start < n) {
    // Grow the line to the furthest segment that still fits, remembering the
    // last position at which a legal break was possible.
    let width = s.segmentWidths[start];
    let end = start;
    let spaces = 0;
    let lastBreak = -1; // furthest `end` with a legal break after it.

    // The start segment alone is always placed (guarantees progress).
    if (start === n - 1 || isBreakable(s.joins[start] ?? "none")) {
      lastBreak = start;
    }

    let cursor = start;
    while (cursor < n - 1) {
      const join = s.joins[cursor];
      const next = cursor + 1;
      const addedWidth =
        (join === "space" ? s.spaceWidth : 0) + s.segmentWidths[next];
      if (width + addedWidth > targetWidth && lastBreak >= start && lastBreak !== -1) {
        break; // overflow: stop and break at the last legal position.
      }
      width += addedWidth;
      if (join === "space") spaces++;
      cursor = next;
      end = cursor;
      if (isBreakable(join)) lastBreak = cursor;
    }

    // Prefer breaking at the last legal join; if none was found inside the run,
    // break right after `end` regardless (last resort, keeps layout progressing).
    const breakAt = lastBreak >= start ? lastBreak : end;
    // Recount spaces up to the chosen break point.
    let boxWidth = 0;
    let sp = 0;
    for (let k = start; k <= breakAt; k++) {
      boxWidth += s.segmentWidths[k];
      if (k < breakAt && s.joins[k] === "space") sp++;
    }
    const hyphenated = breakAt < n - 1 && s.joins[breakAt] === "hyphen";
    if (hyphenated) boxWidth += s.hyphenWidth;

    lines.push({
      start,
      end: breakAt,
      spaceWidth: s.spaceWidth, // greedy leaves natural spacing (ragged right).
      hyphenated,
    });
    if (breakAt < n - 1) {
      breakJoins.push(breakAt);
      if (hyphenated) hyphenBreaks.push(breakAt);
    }
    start = breakAt + 1;
  }

  return { lines, breakJoins, hyphenBreaks, cost: Infinity, fallback: true };
}

/**
 * Spacing variance of a layout: the mean squared deviation of each justified
 * line's actual space from the natural space width. The last line is excluded
 * (it is intentionally ragged). Lower is more uniform. Used by tests to show
 * the optimal layout beats greedy fill.
 */
export function spacingVariance(
  result: BreakResult,
  s: SegmentStream,
  targetWidth: number,
): number {
  const justified = result.lines.slice(0, -1); // exclude ragged last line.
  if (justified.length === 0) return 0;
  let sum = 0;
  for (const line of justified) {
    let boxWidth = 0;
    let spaces = 0;
    for (let k = line.start; k <= line.end; k++) {
      boxWidth += s.segmentWidths[k];
      if (k < line.end && s.joins[k] === "space") spaces++;
    }
    if (line.hyphenated) boxWidth += s.hyphenWidth;
    const actual = spaces > 0 ? (targetWidth - boxWidth) / spaces : s.spaceWidth;
    const dev = actual - s.spaceWidth;
    sum += dev * dev;
  }
  return sum / justified.length;
}
