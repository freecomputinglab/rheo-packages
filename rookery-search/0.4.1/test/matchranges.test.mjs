// `matchRanges` — every occurrence of every term in `text`, found against the
// FOLDED copy and merged where they overlap (or touch), but returned as
// offsets that slice the ORIGINAL `text`. That only works because `fold` is
// length-preserving (lowercasing an ASCII letter, or turning `-`/`_` into a
// space, never changes the character count) — see the boundary test below.
import { test } from "node:test";
import assert from "node:assert/strict";
import { matchRanges } from "./internal.mjs";

test("matchRanges: no terms is empty", () => {
  assert.deepEqual(matchRanges("hello world", []), []);
});

test("matchRanges: an empty term is skipped, not a wildcard match", () => {
  assert.deepEqual(matchRanges("hello world", [""]), []);
});

test("matchRanges: no occurrence is empty", () => {
  assert.deepEqual(matchRanges("hello world", ["zzz"]), []);
});

test("matchRanges: single term, single occurrence", () => {
  assert.deepEqual(matchRanges("hello world", ["world"]), [{ start: 6, end: 11 }]);
});

test("matchRanges: case-insensitive, matches the folded copy", () => {
  assert.deepEqual(matchRanges("Hello WORLD", ["world"]), [{ start: 6, end: 11 }]);
});

test("matchRanges: two terms, non-overlapping, both kept separate", () => {
  // fold() turns each "_" into a space, one-for-one, so "ab__cd" (6 chars)
  // folds to "ab  cd" (still 6) — offsets found in the fold land correctly
  // on the original.
  assert.deepEqual(matchRanges("ab__cd", ["ab", "cd"]), [
    { start: 0, end: 2 },
    { start: 4, end: 6 },
  ]);
});

test("matchRanges: overlapping ranges from two different terms are merged", () => {
  // "abc" at 0-3, "cde" at 2-5 — they overlap at index 2, so one range 0-5.
  assert.deepEqual(matchRanges("abcdef", ["abc", "cde"]), [{ start: 0, end: 5 }]);
});

test("matchRanges: touching (not overlapping) ranges still merge — boundary is <=, not <", () => {
  // "ab" at 0-2, "bc" at 1-3: overlapping by one character either way, but
  // this also exercises the exact boundary the merge condition checks
  // (`r.start <= last.end`), not just a comfortably-overlapping case.
  assert.deepEqual(matchRanges("abc", ["ab", "bc"]), [{ start: 0, end: 3 }]);
});

test("matchRanges: repeated adjacent occurrences of one term collapse into one range", () => {
  // "ab" occurs at 0, 2, 4 in "ababab". Each new occurrence starts exactly
  // where the previous one ended (r.start === last.end), which the merge
  // condition treats as touching and folds together.
  assert.deepEqual(matchRanges("ababab", ["ab"]), [{ start: 0, end: 6 }]);
});

test("matchRanges: ranges are sorted by start regardless of term order", () => {
  // "world" (second term) occurs before "hello" (first term) in the text —
  // confirms the final sort, not just accumulation order.
  assert.deepEqual(matchRanges("world hello", ["hello", "world"]), [
    { start: 0, end: 5 },
    { start: 6, end: 11 },
  ]);
});

test("matchRanges: length-preserving fold — offsets from the folded copy slice the ORIGINAL text correctly", () => {
  // fold("Rheo-Context") -> "rheo context": the hyphen becomes a space and
  // every letter lowercases, one-for-one, so both strings are 12 characters
  // long and "context" is found at index 5 in the fold. Slicing the
  // ORIGINAL "Rheo-Context" at [5, 12) must land exactly on "Context" —
  // proving the offset transfers across the fold rather than drifting.
  const text = "Rheo-Context";
  const ranges = matchRanges(text, ["context"]);
  assert.deepEqual(ranges, [{ start: 5, end: 12 }]);
  assert.equal(text.slice(ranges[0].start, ranges[0].end), "Context");
});
