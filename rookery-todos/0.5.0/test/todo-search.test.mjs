// `score` and `passes` — the pure half of the `#todos-search` filter, split out
// of `todo-search.js` so it can be tested without a DOM.

import { test } from "node:test";
import assert from "node:assert/strict";

import { passes, score } from "../src/todo-search.js";

test("a non-subsequence does not match", () => {
  assert.equal(score("the manifest parser", "zzz"), -1);
  // Right letters, wrong order: a subsequence match is ordered.
  assert.equal(score("abc", "cba"), -1);
});

test("an empty query scores 0 for everything", () => {
  // Equal scores everywhere is what leaves the build-time priority order
  // untouched until someone types.
  assert.equal(score("anything at all", ""), 0);
  assert.equal(score("", ""), 0);
});

test("a contiguous match beats a scattered one", () => {
  const contiguous = score("manifest parser", "manifest");
  const scattered = score("m a n i f e s t", "manifest");
  assert.ok(contiguous > scattered, `${contiguous} should beat ${scattered}`);
  assert.ok(scattered > 0, "a scattered subsequence still matches");
});

test("matching is case-insensitive both ways", () => {
  assert.ok(score("The Manifest Parser", "manifest") > 0);
  assert.ok(score("the manifest parser", "MANIFEST") > 0);
});

test("an earlier first match scores higher, all else equal", () => {
  assert.ok(score("parser here", "parser") > score("well over there parser", "parser"));
});

const row = (status, type) => ({ status, type });

test("empty facets constrain nothing", () => {
  const none = { status: new Set(), type: new Set() };
  assert.equal(passes(row("ready", "bug"), none), true);
  assert.equal(passes(row("blocked", "docs"), none), true);
});

test("values within one facet OR", () => {
  const f = { status: new Set(["ready", "blocked"]), type: new Set() };
  assert.equal(passes(row("ready", "bug"), f), true);
  assert.equal(passes(row("blocked", "bug"), f), true);
  assert.equal(passes(row("open", "bug"), f), false);
});

test("facets AND across each other", () => {
  const f = { status: new Set(["blocked"]), type: new Set(["docs"]) };
  assert.equal(passes(row("blocked", "docs"), f), true);
  // Each half alone is not enough.
  assert.equal(passes(row("blocked", "bug"), f), false);
  assert.equal(passes(row("ready", "docs"), f), false);
});
