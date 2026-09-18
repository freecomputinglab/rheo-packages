import { test } from "node:test";
import assert from "node:assert/strict";

import { wordHyphenPoints, type Hyphenator } from "../src/hyphenate.ts";

/** A fake dictionary driven by a lookup table, so tests are deterministic. */
function dictOf(table: Record<string, string[]>): Hyphenator {
  return { hyphenate: (word) => table[word] ?? [word] };
}

test("syllable splits become cumulative character offsets", () => {
  const dict = dictOf({ comprehension: ["com", "pre", "hen", "sion"] });
  assert.deepEqual(wordHyphenPoints("comprehension", dict), [3, 6, 9]);
});

test("a word the dictionary does not split yields no offsets", () => {
  const dict = dictOf({}); // hyphenate() returns [word]
  assert.deepEqual(wordHyphenPoints("the", dict), []);
});

test("offsets are strictly inside the word (never at either edge)", () => {
  // A degenerate split with empty leading/trailing pieces must not produce a
  // 0 or word-length offset.
  const dict = dictOf({ ab: ["", "ab", ""] });
  assert.deepEqual(wordHyphenPoints("ab", dict), []);
});

test("words containing a real hyphen are left whole", () => {
  // encode.ts turns the real hyphen into a non-breaking hyphen; we must not
  // also add a discretionary break, or a double hyphen could appear.
  const dict = dictOf({ "line-break": ["line", "break"] });
  assert.deepEqual(wordHyphenPoints("line-break", dict), []);
});

test("multiple offsets stay ascending and match piece lengths", () => {
  const dict = dictOf({ typesetting: ["type", "set", "ting"] });
  assert.deepEqual(wordHyphenPoints("typesetting", dict), [4, 7]);
});
