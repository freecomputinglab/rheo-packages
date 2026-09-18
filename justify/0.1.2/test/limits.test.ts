// Tests for the justification-limits -> KP elasticity mapping. Run with:
//   node --experimental-strip-types --test test/limits.test.ts

import { test } from "node:test";
import assert from "node:assert/strict";

import { breakParagraph, wordsToStream } from "../src/kp.ts";
import {
  DEFAULT_LIMITS,
  limitsToElasticity,
  makeConfig,
  parseRelLength,
  resolveLimits,
} from "../src/limits.ts";

test("unset limits resolve to the package (column-4) default", () => {
  const resolved = resolveLimits(null);
  assert.deepEqual(resolved, DEFAULT_LIMITS);

  const cfg = makeConfig(null);
  assert.equal(cfg.minSpaceFrac, 0.83);
  assert.equal(cfg.maxSpaceFrac, 1.5);
});

test("partial limits fold onto the default (Typst semantics)", () => {
  // Author set only spacing.max; min and tracking keep the default.
  const resolved = resolveLimits({ spacing: { max: { ratio: 2.0, length: 0 } } });
  assert.deepEqual(resolved.spacing.min, DEFAULT_LIMITS.spacing.min);
  assert.deepEqual(resolved.spacing.max, { ratio: 2.0, length: 0 });
  assert.deepEqual(resolved.tracking, DEFAULT_LIMITS.tracking);
});

test("ratio-only bounds map straight to fractions", () => {
  const e = limitsToElasticity({
    spacing: { min: { ratio: 0.9, length: 0 }, max: { ratio: 1.2, length: 0 } },
    tracking: { min: 0, max: 0 },
  });
  assert.equal(e.minSpaceFrac, 0.9);
  assert.equal(e.maxSpaceFrac, 1.2);
});

test("absolute space part is folded in relative to the space width", () => {
  // 90% - 1pt of a 10px space = 0.9 - 0.1 = 0.8; 100% + 2pt = 1.2.
  const e = limitsToElasticity(
    {
      spacing: { min: { ratio: 0.9, length: -1 }, max: { ratio: 1.0, length: 2 } },
      tracking: { min: 0, max: 0 },
    },
    /* spaceWidth */ 10,
  );
  assert.ok(Math.abs(e.minSpaceFrac - 0.8) < 1e-9);
  assert.ok(Math.abs(e.maxSpaceFrac - 1.2) < 1e-9);
});

test("a non-zero absolute part without a space width is rejected", () => {
  assert.throws(() =>
    limitsToElasticity({
      spacing: { min: { ratio: 0.9, length: -1 }, max: { ratio: 1.5, length: 0 } },
      tracking: { min: 0, max: 0 },
    }),
  );
});

test("parseRelLength parses the Typst repr forms", () => {
  assert.deepEqual(parseRelLength("90% + 0pt"), { ratio: 0.9, length: 0 });
  const twoThirds = parseRelLength("66.67%");
  assert.ok(Math.abs(twoThirds.ratio - 0.6667) < 1e-9 && twoThirds.length === 0);
  assert.deepEqual(parseRelLength("150% + 0pt"), { ratio: 1.5, length: 0 });
  const neg = parseRelLength("90% - 1pt");
  assert.ok(Math.abs(neg.ratio - 0.9) < 1e-9 && Math.abs(neg.length + 1) < 1e-9);
  assert.throws(() => parseRelLength("0.01em"), /em/);
});

test("different author bounds produce different line breaks", () => {
  // Same paragraph, same width: tight vs loose limits pick different breaks.
  // (End-to-end HTML verification lands with the lib.typ template, rheo-packages-vhv.)
  const stream = wordsToStream(new Array(12).fill(30), 10);
  const target = 180;

  const tight = breakParagraph(
    stream,
    target,
    makeConfig({ spacing: { min: { ratio: 0.95, length: 0 }, max: { ratio: 1.1, length: 0 } } }),
  );
  const loose = breakParagraph(
    stream,
    target,
    makeConfig({ spacing: { min: { ratio: 0.7, length: 0 }, max: { ratio: 2.0, length: 0 } } }),
  );

  assert.notDeepEqual(
    tight.breakJoins,
    loose.breakJoins,
    "tight and loose limits should break at different points",
  );
  // The loose bounds admit a feasible optimal layout here; the tight ones fall back.
  assert.equal(loose.fallback, false);
});
