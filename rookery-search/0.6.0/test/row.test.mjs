// `renderRow(hit, terms)` — one result row: a title span, a break opportunity,
// and the `[idea:<slug>]` id span.
//
// The `<wbr>` between the two spans is what these tests exist for. Without it
// the browser sees the title's last word and the whole nowrap id as ONE
// unbreakable run, and drops that final word onto a second line in every row at
// every pane width — see bead rheo-packages-row-wbr-eas7 for the measurements.
// A DOM shim cannot reproduce line breaking, so what is pinned here is the
// STRUCTURE that makes the break possible.

import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { renderRow } from "./internal.mjs";

const { document } = parseHTML("<!doctype html><body></body>");
globalThis.document = document;

const hit = { id: "idea:amanda-holmes", name: "amanda-holmes", text: "Amanda Holmes and Adrian Johnston", href: "ideas/amanda-holmes.html" };

test("a row separates title and id with a break opportunity", () => {
  const row = renderRow(hit, []);
  const kids = [...row.childNodes].filter((n) => n.nodeType === 1);
  assert.deepEqual(
    kids.map((n) => n.nodeName.toLowerCase()),
    ["span", "wbr", "span"],
  );
  assert.equal(kids[0].className, "rookery-search-title");
  assert.equal(kids[2].className, "rookery-search-id");
});

test("the wbr adds no text, so the row reads as title then id", () => {
  const row = renderRow(hit, []);
  // No word space introduced: a space text node would fix the break too, but
  // widens the gap the id's own `margin-left` already supplies.
  assert.equal(row.textContent, "Amanda Holmes and Adrian Johnston[idea:amanda-holmes]");
});

test("an untitled note falls back to its name", () => {
  const row = renderRow({ ...hit, text: "" }, []);
  assert.match(row.textContent, /^amanda-holmes\[/);
});
