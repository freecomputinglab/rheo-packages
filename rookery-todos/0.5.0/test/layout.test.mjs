// Unit tests for the graph layout — the pure half of the browser code, which
// is why it lives in `src/layout.js` apart from the DOM rendering.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { GEOM, layer, place, rows } from "../src/layout.js";

const n = (name, extra = {}) => ({ name, ...extra });
const e = (from, to) => ({ from, to });

test("a chain layers one step at a time", () => {
  const nodes = [n("a"), n("b"), n("c")];
  const L = layer(nodes, [e("b", "a"), e("c", "b")]);
  assert.equal(L.get("a"), 0);
  assert.equal(L.get("b"), 1);
  assert.equal(L.get("c"), 2);
});

test("longest path wins, so every edge spans exactly one layer", () => {
  // d depends on both b (layer 1) and a (layer 0); shortest-path layering
  // would put it at 1 and leave the d->b edge spanning zero layers.
  const nodes = [n("a"), n("b"), n("d")];
  const L = layer(nodes, [e("b", "a"), e("d", "a"), e("d", "b")]);
  assert.equal(L.get("d"), 2);
});

test("an unresolved dependency does not shift a layer", () => {
  const nodes = [n("a")];
  const L = layer(nodes, [e("a", "ghost")]);
  assert.equal(L.get("a"), 0);
});

test("independent nodes all sit on layer 0", () => {
  const nodes = [n("a"), n("b"), n("c")];
  const L = layer(nodes, []);
  assert.deepEqual([...L.values()], [0, 0, 0]);
});

test("rows order by priority then name, unprioritised last", () => {
  const nodes = [
    n("zebra", { priority: 0 }),
    n("apple"),
    n("mango", { priority: 0 }),
    n("kiwi", { priority: 2 }),
  ];
  const L = layer(nodes, []);
  assert.deepEqual(rows(nodes, L)[0].map((x) => x.name), [
    "mango",
    "zebra",
    "kiwi",
    "apple",
  ]);
});

test("layer 0 is drawn at the top", () => {
  const nodes = [n("a"), n("b")];
  const L = layer(nodes, [e("b", "a")]);
  const { pos } = place(rows(nodes, L));
  // `a` depends on nothing, so it is the unblocked work and sits ABOVE `b`,
  // which waits on it. The arrow between them then reads "a unblocks b".
  assert.ok(pos.get("a").y < pos.get("b").y);
});

test("the top row sits at the padding", () => {
  const nodes = [n("a"), n("b")];
  const L = layer(nodes, [e("b", "a")]);
  const { pos } = place(rows(nodes, L));
  assert.equal(pos.get("a").y, GEOM.pad);
});

test("a row is centred on the widest row", () => {
  const nodes = [n("solo"), n("x"), n("y")];
  const L = layer(nodes, [e("solo", "x"), e("solo", "y")]);
  const { pos, width } = place(rows(nodes, L));
  const centre = width / 2;
  assert.equal(pos.get("solo").x + GEOM.w / 2, centre);
});

test("an empty graph produces no rows", () => {
  assert.deepEqual(rows([], layer([], [])), []);
});
