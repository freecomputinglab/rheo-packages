// Tests for the DOM-string encoder. Run with:
//   node --experimental-strip-types --test test/encode.test.ts

import { test } from "node:test";
import assert from "node:assert/strict";

import {
  encodeJustified,
  NBSP,
  NB_HYPHEN,
  SOFT_HYPHEN,
  SPACE,
} from "../src/encode.ts";

test("gap characters match the chosen break set exactly", () => {
  const words = ["a", "b", "c", "d"];
  const out = encodeJustified({ words, breaks: [1] }); // break only after "b".

  const expected = "a" + NBSP + "b" + SPACE + "c" + NBSP + "d";
  assert.equal(out, expected);

  // Explicit code-point checks.
  assert.equal(out.charCodeAt(1), 0x00a0, "gap 0 must be NBSP");
  assert.equal(out.charCodeAt(3), 0x0020, "gap 1 must be SPACE");
  assert.equal(out.charCodeAt(5), 0x00a0, "gap 2 must be NBSP");
});

test("chosen hyphenation inserts a soft hyphen at the offset", () => {
  const words = ["hello", "computation", "here"];
  const out = encodeJustified({
    words,
    breaks: [0, 1],
    hyphens: [{ word: 1, offset: 5 }], // compu-tation
  });

  assert.ok(out.includes("compu" + SOFT_HYPHEN + "tation"), "soft hyphen at offset 5");
  assert.equal((out.match(new RegExp(SOFT_HYPHEN, "g")) ?? []).length, 1);
});

test("multiple hyphenations in one word insert without shifting each other", () => {
  const words = ["internationalization"];
  const out = encodeJustified({
    words,
    breaks: [],
    hyphens: [
      { word: 0, offset: 5 },
      { word: 0, offset: 13 },
    ],
  });
  assert.equal(out, "inter" + SOFT_HYPHEN + "national" + SOFT_HYPHEN + "ization");
});

test("real source hyphens become non-breaking hyphens", () => {
  const words = ["well-known", "state-of-the-art"];
  const out = encodeJustified({ words, breaks: [0] });

  assert.ok(out.includes("well" + NB_HYPHEN + "known"), "compound hyphen -> U+2011");
  assert.equal(out.includes("-"), false, "no raw ASCII hyphen should remain");
  assert.equal((out.match(new RegExp(NB_HYPHEN, "g")) ?? []).length, 4);
});

test("soft hyphen and non-breaking hyphen coexist in the same word", () => {
  const words = ["e-mailing"]; // hyphenate after "e-mail" (offset 6).
  const out = encodeJustified({ words, breaks: [], hyphens: [{ word: 0, offset: 6 }] });
  assert.equal(out, "e" + NB_HYPHEN + "mail" + SOFT_HYPHEN + "ing");
});

test("last gap stays ragged when it is not a chosen break", () => {
  const words = ["one", "two", "three"];
  const out = encodeJustified({ words, breaks: [0] }); // only first gap breaks.
  assert.equal(out.charCodeAt(out.indexOf("two") - 1), 0x0020); // gap 0 = SPACE
  assert.equal(out.charCodeAt(out.indexOf("three") - 1), 0x00a0); // gap 1 = NBSP
});

test("out-of-range hyphenation word index throws", () => {
  assert.throws(
    () => encodeJustified({ words: ["a"], breaks: [], hyphens: [{ word: 3, offset: 0 }] }),
    RangeError,
  );
});

test("edge offsets (0 or word length) are ignored", () => {
  const words = ["word"];
  const out = encodeJustified({
    words,
    breaks: [],
    hyphens: [
      { word: 0, offset: 0 },
      { word: 0, offset: 4 },
    ],
  });
  assert.equal(out, "word", "no soft hyphen at the word edges");
});
