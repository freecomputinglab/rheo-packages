// `lib.js` — the three morph-survival primitives. `wiring` and `rehydrate` are
// exercised without a DOM at all (an `AbortController` is a node global, and a
// wiring key is any object); `only` builds a throwaway document with linkedom
// rather than making the whole file DOM-bound.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wiring, only, rehydrate } from "../src/lib.js";

// READ AT MODULE SCOPE, before any test can call `rehydrate` and create the
// array. Importing the module must not touch `__rheoRehydrate`, and asserting
// that inside a test would depend on which test ran first.
const untouchedAtImport = !("__rheoRehydrate" in globalThis);

// A `.widget` div, the shape `only` is asked to guarantee exactly one of.
const widget = (document) => () => {
  const el = document.createElement("div");
  el.className = "widget";
  return el;
};

test("importing the module does not create the hook array", () => {
  assert.equal(untouchedAtImport, true);
});

test("wiring: the first signal for a key is live", () => {
  assert.equal(wiring({}).aborted, false);
});

test("wiring: a second pass aborts the first and hands back a live signal", () => {
  const key = {};
  const first = wiring(key);
  const second = wiring(key);
  assert.equal(first.aborted, true);
  assert.equal(second.aborted, false);
});

test("wiring: two keys do not disturb each other", () => {
  const one = {};
  const other = {};
  const onlySignal = wiring(one);
  const otherSignal = wiring(other);
  wiring(other);
  assert.equal(onlySignal.aborted, false, "re-wiring one key aborted another's");
  assert.equal(otherSignal.aborted, true);
});

test("only: three passes leave exactly one matching child", () => {
  const { document } = parseHTML("<main></main>");
  const parent = document.querySelector("main");
  const make = widget(document);
  only(parent, ".widget", make);
  only(parent, ".widget", make);
  only(parent, ".widget", make);
  assert.equal(parent.querySelectorAll(".widget").length, 1);
});

test("only: returns the element it appended", () => {
  const { document } = parseHTML("<main></main>");
  const parent = document.querySelector("main");
  const made = only(parent, ".widget", widget(document));
  assert.equal(parent.querySelector(".widget"), made);
  assert.equal(made.parentNode, parent);
});

test("rehydrate: creates the array when absent, then appends in order", () => {
  delete globalThis.__rheoRehydrate;
  const first = () => {};
  const second = () => {};
  rehydrate(first);
  assert.deepEqual(globalThis.__rheoRehydrate, [first]);
  rehydrate(second);
  assert.deepEqual(globalThis.__rheoRehydrate, [first, second]);
  delete globalThis.__rheoRehydrate;
});

test("rehydrate: an array rheo's client got there first is appended to, not replaced", () => {
  const theirs = () => {};
  globalThis.__rheoRehydrate = [theirs];
  const ours = () => {};
  rehydrate(ours);
  assert.deepEqual(globalThis.__rheoRehydrate, [theirs, ours]);
  delete globalThis.__rheoRehydrate;
});
