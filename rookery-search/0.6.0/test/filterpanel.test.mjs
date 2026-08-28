// `passesTags(row, pressed)` — the predicate behind `#filter-panel`'s pills.
//
// THE WHOLE DIFFERENCE FROM `#panel` IS HERE. That widget's facets OR within a group:
// two state pills mean "either". These INTERSECT: a row survives only if it carries
// every pressed tag, so a second pill always narrows. Everything else about the two
// panels — the input, the count, the reordering — is one shared `wirePanel`, which is
// why this is the only new predicate to pin.
import { test } from "node:test";
import assert from "node:assert/strict";
import { passesTags } from "./internal.mjs";

// A row as `wirePanel` builds it: the tag names off `data-panel-tags`, as a Set.
const row = (...tags) => ({ tags: new Set(tags) });

test("no pills pressed passes every row", () => {
  const pressed = new Set();
  assert.equal(passesTags(row(), pressed), true);
  assert.equal(passesTags(row("ready"), pressed), true);
});

test("one pill keeps only its carriers", () => {
  const pressed = new Set(["ready"]);
  assert.equal(passesTags(row("ready"), pressed), true);
  assert.equal(passesTags(row("ready", "epic-jobs"), pressed), true);
  assert.equal(passesTags(row("blocked"), pressed), false);
  assert.equal(passesTags(row(), pressed), false);
});

test("two pills INTERSECT — carrying one of the two is not enough", () => {
  const pressed = new Set(["ready", "epic-jobs"]);
  assert.equal(passesTags(row("ready", "epic-jobs"), pressed), true);
  assert.equal(passesTags(row("ready"), pressed), false);
  assert.equal(passesTags(row("epic-jobs"), pressed), false);
});

// THE PREFIX CASE, and the reason the Typst side space-pads `data-panel-tags` at both
// ends: an implementation testing the raw attribute with `includes("epic")` would
// match ` epic-jobs `. Splitting on spaces into a Set makes a half-match impossible,
// and this test is what keeps it that way if the parsing is ever "optimised" back to a
// substring test.
test("a tag that is another's prefix does not half-match", () => {
  assert.equal(passesTags(row("epic-jobs"), new Set(["epic"])), false);
  assert.equal(passesTags(row("epic"), new Set(["epic-jobs"])), false);
  assert.equal(passesTags(row("epic", "epic-jobs"), new Set(["epic"])), true);
});
