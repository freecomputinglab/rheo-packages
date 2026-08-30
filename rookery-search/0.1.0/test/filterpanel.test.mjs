// `passesTags(row, pressed, mode)` — the predicate behind `#filter-panel`'s pills.
//
// TWO COMPOSITIONS, and the default is "any". A row survives if it carries ANY pressed
// tag, so a second pill WIDENS; `"all"` keeps only a row carrying every pressed tag, so
// it narrows. The default is "any" because the tags a pill row is built from are usually
// mutually exclusive in practice — one epic per todo — and intersecting two of those
// returns nothing at all.
//
// Everything else about the two panel kinds — the input, the count, the reordering — is
// one shared `wirePanel`, which is why this is the only new predicate to pin.
import { test } from "node:test";
import assert from "node:assert/strict";
import { passesTags } from "./internal.mjs";

// A row as `wirePanel` builds it: the tag names off `data-panel-tags`, as a Set.
const row = (...tags) => ({ tags: new Set(tags) });

test("no pills pressed passes every row, in both modes", () => {
  const pressed = new Set();
  for (const mode of ["any", "all"]) {
    assert.equal(passesTags(row(), pressed, mode), true);
    assert.equal(passesTags(row("ready"), pressed, mode), true);
  }
});

test("one pill keeps only its carriers, in both modes", () => {
  const pressed = new Set(["ready"]);
  for (const mode of ["any", "all"]) {
    assert.equal(passesTags(row("ready"), pressed, mode), true);
    assert.equal(passesTags(row("ready", "epic-jobs"), pressed, mode), true);
    assert.equal(passesTags(row("blocked"), pressed, mode), false);
    assert.equal(passesTags(row(), pressed, mode), false);
  }
});

// THE DEFAULT. Two pills UNION: pressing a second one widens the result, which is what
// makes a row of mutually exclusive tags (one epic per todo) usable at all.
test("two pills UNION by default — carrying either is enough", () => {
  const pressed = new Set(["ready", "epic-jobs"]);
  assert.equal(passesTags(row("ready", "epic-jobs"), pressed, "any"), true);
  assert.equal(passesTags(row("ready"), pressed, "any"), true);
  assert.equal(passesTags(row("epic-jobs"), pressed, "any"), true);
  assert.equal(passesTags(row("blocked"), pressed, "any"), false);
});

// AN UNRECOGNISED MODE FALLS BACK TO THE DEFAULT rather than throwing: the value comes
// off a DOM attribute, and a page carrying a typo should still filter.
test("anything that is not \"all\" composes as \"any\"", () => {
  const pressed = new Set(["ready", "epic-jobs"]);
  for (const mode of ["any", undefined, "", "ALL", "every"]) {
    assert.equal(passesTags(row("ready"), pressed, mode), true);
  }
});

test("`all` INTERSECTS — carrying one of the two is not enough", () => {
  const pressed = new Set(["ready", "epic-jobs"]);
  assert.equal(passesTags(row("ready", "epic-jobs"), pressed, "all"), true);
  assert.equal(passesTags(row("ready"), pressed, "all"), false);
  assert.equal(passesTags(row("epic-jobs"), pressed, "all"), false);
});

// THE PREFIX CASE, and the reason the Typst side space-pads `data-panel-tags` at both
// ends: an implementation testing the raw attribute with `includes("epic")` would
// match ` epic-jobs `. Splitting on spaces into a Set makes a half-match impossible,
// and this test is what keeps it that way if the parsing is ever "optimised" back to a
// substring test.
test("a tag that is another's prefix does not half-match", () => {
  for (const mode of ["any", "all"]) {
    assert.equal(passesTags(row("epic-jobs"), new Set(["epic"]), mode), false);
    assert.equal(passesTags(row("epic"), new Set(["epic-jobs"]), mode), false);
    assert.equal(passesTags(row("epic", "epic-jobs"), new Set(["epic"]), mode), true);
  }
});
