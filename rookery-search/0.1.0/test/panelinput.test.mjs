// `wirePanel`'s TEXT INPUT, over a real DOM (linkedom), because the bug this pins was
// invisible to every other kind of test here.
//
// WHAT IT WAS. `apply()` read `const s = ok ? score(row.text, q) : -1` and hid a row on
// `s < 0`. But `score` returns `null` for no match — its own header says so — and
// `null < 0` is FALSE in JavaScript. So a non-matching row was kept: the input reordered
// the list and filtered nothing, in BOTH panel kinds, from the day `#panel` shipped.
//
// WHY NOTHING CAUGHT IT. The unit suite pins `score` (which was right), the parity
// harness compares the JS scorer against the Typst one (also right), and the demo's
// `check.sh` greps the BUILT MARKUP, where the input has not been typed into. The
// defect lived in the one line joining a correct scorer to a correct list, and only a
// DOM test that types can see it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wirePanel } from "../src/panel.js";

const PANEL = `<!doctype html><body><div class="panel" data-panel-ready="false">
<input class="panel-input" type="search"><p class="panel-count">3 rows</p><ul class="panel-results">
<li class="panel-row" data-panel-text="alpha abstract">a</li>
<li class="panel-row" data-panel-text="beta reference">b</li>
<li class="panel-row" data-panel-text="gamma chore">c</li>
</ul></div></body>`;

const wire = () => {
  const { document } = parseHTML(PANEL);
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  const input = document.querySelector(".panel-input");
  return {
    document,
    type: (v) => {
      input.value = v;
      input.dispatchEvent(new document.defaultView.Event("input"));
    },
    shown: () =>
      [...document.querySelectorAll(".panel-row")]
        .filter((r) => !r.hidden)
        .map((r) => r.textContent),
    count: () => document.querySelector(".panel-count").textContent,
  };
};

test("an empty query shows every row, in the build-time order", () => {
  const p = wire();
  assert.deepEqual(p.shown(), ["a", "b", "c"]);
  assert.equal(p.count(), "3 rows");
});

test("a query HIDES the rows it does not match", () => {
  const p = wire();
  p.type("abstract");
  assert.deepEqual(p.shown(), ["a"]);
  assert.equal(p.count(), "1 of 3");
});

test("a query matching nothing hides everything and says so", () => {
  const p = wire();
  p.type("zzz");
  assert.deepEqual(p.shown(), []);
  assert.equal(p.count(), "nothing matches");
});

test("clearing the query restores every row", () => {
  const p = wire();
  p.type("abstract");
  p.type("");
  assert.deepEqual(p.shown(), ["a", "b", "c"]);
  assert.equal(p.count(), "3 rows");
});
