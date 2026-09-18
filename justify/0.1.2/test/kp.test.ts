// Tests for the Knuth-Plass line-breaking core. No external deps: run with
//   node --experimental-strip-types --test test/kp.test.ts
// (Node >= 22 strips the TS types; the built-in test runner + node:assert need
// nothing installed.)

import { test } from "node:test";
import assert from "node:assert/strict";

import {
  breakParagraph,
  greedyBreak,
  spacingVariance,
  wordsToStream,
  type JustifyConfig,
  type Join,
  type SegmentStream,
} from "../src/kp.ts";

const CONFIG: JustifyConfig = {
  minSpaceFrac: 0.6,
  maxSpaceFrac: 2.5,
  hyphenPenalty: 100,
};

test("optimal layout has lower spacing variance than greedy fill", () => {
  // 11 uniform words. Greedy first-fit packs 3 per line (a 4th overflows at the
  // natural space), leaving every justified line badly over-stretched. The
  // optimizer instead shrinks spaces to pack 4 per line, far closer to uniform.
  const words = new Array(11).fill(20);
  const stream = wordsToStream(words, /* spaceWidth */ 10);
  const target = 100;

  const optimal = breakParagraph(stream, target, CONFIG);
  const greedy = greedyBreak(stream, target, CONFIG);

  assert.equal(optimal.fallback, false, "optimal should find a feasible layout");
  assert.ok(Number.isFinite(optimal.cost), "optimal cost must be finite");

  const optVar = spacingVariance(optimal, stream, target);
  const grdVar = spacingVariance(greedy, stream, target);

  assert.ok(
    optVar < grdVar,
    `optimal variance (${optVar.toFixed(2)}) should beat greedy (${grdVar.toFixed(2)})`,
  );
});

test("every justified line respects the min/max word-space bounds", () => {
  const words = new Array(11).fill(20);
  const stream = wordsToStream(words, 10);
  const target = 100;

  const result = breakParagraph(stream, target, CONFIG);
  assert.equal(result.fallback, false);

  const min = CONFIG.minSpaceFrac * stream.spaceWidth;
  const max = CONFIG.maxSpaceFrac * stream.spaceWidth;

  // All lines except the ragged last one must sit within the bounds.
  const justified = result.lines.slice(0, -1);
  assert.ok(justified.length > 0, "expected at least one justified line");
  for (const line of justified) {
    // Single-word lines have no space to bound; skip them.
    if (line.end === line.start) continue;
    assert.ok(
      line.spaceWidth >= min - 1e-6 && line.spaceWidth <= max + 1e-6,
      `line ${line.start}-${line.end} space ${line.spaceWidth} outside [${min}, ${max}]`,
    );
  }
});

test("falls back to greedy on a pathologically narrow column without throwing", () => {
  const words = new Array(6).fill(20);
  const stream = wordsToStream(words, 10);
  const target = 5; // narrower than any single word: no feasible justified line.

  let result;
  assert.doesNotThrow(() => {
    result = breakParagraph(stream, target, CONFIG);
  });
  assert.equal(result!.fallback, true, "should have fallen back to greedy");
  // Fallback must still place every word (one per line here) and terminate.
  assert.equal(result!.lines.length, words.length);
  const covered = result!.lines.flatMap((l) => {
    const r: number[] = [];
    for (let k = l.start; k <= l.end; k++) r.push(k);
    return r;
  });
  assert.deepEqual(covered, [0, 1, 2, 3, 4, 5]);
});

test("break indices partition the segments contiguously", () => {
  const words = new Array(11).fill(20);
  const stream = wordsToStream(words, 10);
  const result = breakParagraph(stream, 100, CONFIG);

  // Lines must tile [0, n) with no gaps or overlaps.
  let expected = 0;
  for (const line of result.lines) {
    assert.equal(line.start, expected, "line start must follow previous line");
    expected = line.end + 1;
  }
  assert.equal(expected, stream.segmentWidths.length, "lines must cover all segments");

  // breakJoins are exactly the joins after each non-final line's last segment.
  const nonFinalEnds = result.lines.slice(0, -1).map((l) => l.end);
  assert.deepEqual(result.breakJoins, nonFinalEnds);
});

test("hyphen break is taken (and recorded) when it is the only feasible layout", () => {
  // The word [seg1|seg2] (glued only by a hyphen join) is wider than the column,
  // so it cannot sit whole on any line: the only feasible layouts break it at
  // the hyphen. Layout: [w0] [w1a]-[w1b] [w2].
  const stream: SegmentStream = {
    segmentWidths: [20, 40, 40, 20],
    joins: ["space", "hyphen", "space"],
    spaceWidth: 10,
    hyphenWidth: 4,
  };
  const target = 70; // w1a + w1b = 80 > 70, so the whole word never fits.

  const result = breakParagraph(stream, target, { ...CONFIG, hyphenPenalty: 1 });
  assert.equal(result.fallback, false, "a hyphenated layout is feasible");
  assert.deepEqual(result.hyphenBreaks, [1], "hyphen break at join index 1");
  assert.equal(result.lines[0].hyphenated, true);
  assert.equal(result.lines[0].end, 1);
});

test("hyphenPenalty flips the choice when both layouts are feasible", () => {
  // First line can be either 5 tightly-shrunk words ending on the whole word
  // (no hyphen, larger space deviation) or 4 words ending on a hyphenated split
  // (near-natural spacing). A low penalty prefers the tidier hyphenated line; a
  // huge penalty prefers the non-hyphenated one.
  const stream: SegmentStream = {
    segmentWidths: [20, 20, 20, 20, 20, 10],
    joins: ["space", "space", "space", "hyphen", "space"],
    spaceWidth: 10,
    hyphenWidth: 4,
  };
  const target = 116;
  const cfg = { minSpaceFrac: 0.5, maxSpaceFrac: 2.5, hyphenPenalty: 1 };

  const cheap = breakParagraph(stream, target, cfg);
  assert.equal(cheap.fallback, false);
  assert.deepEqual(cheap.hyphenBreaks, [3], "low penalty should hyphenate");
  assert.equal(cheap.lines[0].end, 3);

  const pricey = breakParagraph(stream, target, { ...cfg, hyphenPenalty: 1e9 });
  assert.equal(pricey.fallback, false);
  assert.deepEqual(pricey.hyphenBreaks, [], "huge penalty should avoid the hyphen");
  assert.equal(pricey.lines[0].end, 4);
});

test("empty and single-word streams are handled", () => {
  const empty = breakParagraph(wordsToStream([], 10), 100, CONFIG);
  assert.deepEqual(empty.lines, []);

  const single = breakParagraph(wordsToStream([40], 10), 100, CONFIG);
  assert.equal(single.lines.length, 1);
  assert.equal(single.lines[0].start, 0);
  assert.equal(single.lines[0].end, 0);
  assert.equal(single.fallback, false);
});

test("a greedy line that breaks at a hyphen still fits the column", () => {
  // Four syllables that pack to exactly the column width, joined by hyphens: a
  // greedy fill that ignores the hyphen glyph would take all four and paint a
  // hyphen past the edge. The encoded gaps are rigid, so the browser could only
  // resolve such a line by breaking somewhere we never chose.
  const stream: SegmentStream = {
    segmentWidths: [25, 25, 25, 25, 40],
    joins: ["hyphen", "hyphen", "hyphen", "space"],
    spaceWidth: 10,
    hyphenWidth: 8,
  };
  const target = 100;

  const result = greedyBreak(stream, target, CONFIG);
  for (const line of result.lines) {
    let width = 0;
    for (let k = line.start; k <= line.end; k++) {
      width += stream.segmentWidths[k];
      if (k < line.end && stream.joins[k] === "space") width += stream.spaceWidth;
    }
    if (line.hyphenated) width += stream.hyphenWidth;
    assert.ok(
      width <= target + 1e-6,
      `line ${line.start}-${line.end} is ${width}px in a ${target}px column`,
    );
  }
});

test("an unjustifiable column relaxes the stretch bound instead of falling back", () => {
  // Uniform words in a column where no break sequence lands inside a tight
  // stretch bound. Relaxing keeps the layout exact; the greedy fallback would
  // not, so it must not be reached.
  const stream = wordsToStream(new Array(9).fill(37), 10);
  const cfg: JustifyConfig = { minSpaceFrac: 1, maxSpaceFrac: 1.05, hyphenPenalty: 100 };

  const result = breakParagraph(stream, 100, cfg);
  assert.equal(result.fallback, false, "should not reach the greedy fallback");
  assert.equal(result.relaxed, true, "should report the relaxed stretch bound");
  // Every line still fits: no line's boxes plus its natural spaces overflow.
  for (const line of result.lines) {
    let boxes = 0;
    let spaces = 0;
    for (let k = line.start; k <= line.end; k++) {
      boxes += stream.segmentWidths[k];
      if (k < line.end) spaces++;
    }
    assert.ok(boxes + spaces * stream.spaceWidth <= 100 + 1e-6);
  }
});

test("a word wider than the column still falls back to greedy", () => {
  const result = breakParagraph(wordsToStream(new Array(4).fill(200), 10), 50, CONFIG);
  assert.equal(result.fallback, true);
  assert.equal(result.relaxed, false);
  assert.equal(result.lines.length, 4);
});
