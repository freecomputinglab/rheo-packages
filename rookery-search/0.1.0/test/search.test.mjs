// `search` — the JS-side ranker over a `#search-index` row list. Cross-
// language agreement with Typst's `_rank` is `just parity`'s job (the
// `tier-parity` fixture); this file unit-tests the function standalone: tier
// boundaries, tie-breaks, the `tags:` predicate, `limit`, and the
// `row.body`/`row.text`/`row.tags` "field simply absent" fallbacks that stand
// in for an older island or a `body-search: false` build.
import { test } from "node:test";
import assert from "node:assert/strict";
import { search } from "../src/rookery-search.js";

test("search: a tier-0 (name/text) hit outranks a tier-1 (body) hit regardless of raw score", () => {
  const rows = [
    // No "alpha" substring/subsequence in "Beta widget" — falls through to
    // body, where "alpha" is the body's very first term (best possible rank).
    { id: "idea:bbb", name: "idea:bbb", text: "Beta widget", body: "alpha context depth" },
    // "Alpha" is right there in the title — a much lower fuzzy-score number
    // than the body hit above, but tier 0 must still win.
    { id: "idea:aaa", name: "idea:aaa", text: "Alpha window", body: "" },
  ];
  const out = search(rows, "alpha", null);
  assert.deepEqual(out.map((h) => h.id), ["idea:aaa", "idea:bbb"]);
  assert.equal(out[0].kind, "name");
  assert.equal(out[1].kind, "body");
});

test("search: ties within a tier break on id, ascending, not insertion order", () => {
  const rows = [
    { id: "idea:zzz", name: "idea:zzz", text: "window", body: "" },
    { id: "idea:aaa", name: "idea:aaa", text: "window", body: "" },
  ];
  const out = search(rows, "window", null);
  assert.deepEqual(out.map((h) => h.id), ["idea:aaa", "idea:zzz"]);
});

test("search: a row with no body (body-search: false) never reaches tier 1", () => {
  const rows = [{ id: "idea:ccc", name: "idea:ccc", text: "Gamma" }]; // no `body` key at all
  assert.deepEqual(search(rows, "alpha", null), []);
});

test("search: an empty body (real, not omitted) also never reaches tier 1", () => {
  const rows = [{ id: "idea:ccc", name: "idea:ccc", text: "Gamma", body: "" }];
  assert.deepEqual(search(rows, "alpha", null), []);
});

test("search: bare `tags:x` with no residual text — every survivor lands at score 0, ordered by id", () => {
  const rows = [
    { id: "idea:ddd", name: "idea:ddd", text: "Delta", tags: ["draft"] },
    { id: "idea:eee", name: "idea:eee", text: "Echo", tags: ["draft"] },
    { id: "idea:fff", name: "idea:fff", text: "Foxtrot" }, // no `tags` key — an untagged/older row
  ];
  const out = search(rows, "tags:draft", null);
  assert.deepEqual(out.map((h) => h.id), ["idea:ddd", "idea:eee"]);
  assert.deepEqual(out.map((h) => h.score), [0, 0]);
  assert.deepEqual(out.map((h) => h.kind), ["name", "name"]);
});

test("search: `tags:` filters BEFORE the residual text ranks", () => {
  const rows = [
    { id: "idea:ddd", name: "idea:ddd", text: "window depth", tags: ["draft"] },
    { id: "idea:eee", name: "idea:eee", text: "window budget" }, // matches text, wrong/missing tag
  ];
  const out = search(rows, "tags:draft window", null);
  assert.deepEqual(out.map((h) => h.id), ["idea:ddd"]);
});

test("search: limit slices the sorted output; null limit returns everything", () => {
  const rows = [
    { id: "idea:aaa", name: "idea:aaa", text: "window", body: "" },
    { id: "idea:bbb", name: "idea:bbb", text: "window", body: "" },
    { id: "idea:ccc", name: "idea:ccc", text: "window", body: "" },
  ];
  assert.equal(search(rows, "window", 2).length, 2);
  assert.equal(search(rows, "window", null).length, 3);
  assert.equal(search(rows, "window").length, 3); // limit omitted entirely
});

test("search: within tier 1, higher bodyScore ranks first", () => {
  const rows = [
    // "window" is a late term (low rank -> low points) and only a prefix hit.
    { id: "idea:low", name: "idea:low", text: "Zzz", body: "alpha beta gamma delta epsilon window" },
    // "window" is the exact first term -> best possible bodyScore.
    { id: "idea:high", name: "idea:high", text: "Zzz", body: "window alpha beta" },
  ];
  const out = search(rows, "window", null);
  assert.deepEqual(out.map((h) => h.id), ["idea:high", "idea:low"]);
  assert.ok(out[0].score > out[1].score);
});
