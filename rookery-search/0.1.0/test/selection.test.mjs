// `selection(list, input, onSelect)` — the active-option factory shared by
// `wire`'s dropdown and `wireModal`'s modal. Per the module's own comment
// above it: -1 means no active option, movement clamps and never wraps,
// `aria-activedescendant` lives on the INPUT, and row ids come from the
// list's own id. A stale-`aria-activedescendant` bug already hid in this
// exact function (found by manual browser probing, not by review) — the
// "DOM replaced under it" test below targets that class of bug directly.
//
// Real DOM-like nodes (linkedom), not hand-rolled objects: `selection` calls
// `list.querySelectorAll`, `el.setAttribute`/`removeAttribute`, and
// `el.scrollIntoView` — worth exercising against the real thing. linkedom
// has no `scrollIntoView` (no layout engine to scroll), so it's stubbed to a
// no-op per element, same as a browser call this suite doesn't need to
// assert on.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { selection } from "./internal.mjs";

const { document } = parseHTML("<!doctype html><body></body>");

const makeRow = () => {
  const row = document.createElement("li");
  row.className = "rookery-search-row";
  row.scrollIntoView = () => {}; // not implemented by linkedom
  return row;
};

const makeList = (n, { id } = {}) => {
  const list = document.createElement("ul");
  if (id !== undefined) list.id = id;
  for (let i = 0; i < n; i++) list.append(makeRow());
  document.body.append(list);
  return list;
};

const makeInput = () => {
  const input = document.createElement("input");
  document.body.append(input);
  return input;
};

test("selection: assigns the list an id when it has none, and leaves an existing id alone", () => {
  const listA = makeList(2);
  selection(listA, makeInput());
  assert.match(listA.id, /^rookery-search-list-\d+$/);

  const listB = makeList(2);
  selection(listB, makeInput());
  assert.notEqual(listA.id, listB.id); // monotonic across instances

  const listC = makeList(2, { id: "my-list" });
  selection(listC, makeInput());
  assert.equal(listC.id, "my-list"); // not overwritten
});

test("selection: row ids are derived from the list's own id, for every row", () => {
  const list = makeList(3, { id: "my-list" });
  const input = makeInput();
  const sel = selection(list, input);
  sel.select(1);
  const rows = [...list.querySelectorAll(".rookery-search-row")];
  assert.deepEqual(rows.map((r) => r.id), ["my-list-opt-0", "my-list-opt-1", "my-list-opt-2"]);
  assert.equal(input.getAttribute("aria-activedescendant"), "my-list-opt-1");
});

test("selection: exactly one row is marked selected", () => {
  const list = makeList(3, { id: "my-list" });
  const sel = selection(list, makeInput());
  sel.select(1);
  const rows = [...list.querySelectorAll(".rookery-search-row")];
  assert.deepEqual(rows.map((r) => r.getAttribute("aria-selected")), ["false", "true", "false"]);
  assert.equal(rows[1].getAttribute("data-rookery-search-selected"), "true");
  assert.equal(rows[0].hasAttribute("data-rookery-search-selected"), false);
  assert.equal(rows[2].hasAttribute("data-rookery-search-selected"), false);
});

test("selection: an empty list selects nothing — clear(), not a throw", () => {
  const list = makeList(0, { id: "my-list" });
  const input = makeInput();
  const sel = selection(list, input);
  sel.select(0);
  assert.equal(sel.index(), -1);
  assert.equal(sel.current(), null);
  assert.equal(input.hasAttribute("aria-activedescendant"), false);
});

test("selection: clamps, never wraps, at both ends", () => {
  const list = makeList(3, { id: "my-list" });
  const sel = selection(list, makeInput());

  assert.equal(sel.index(), -1);
  sel.move(-1); // "up" from nothing activates the list at row 0, not the end
  assert.equal(sel.index(), 0);
  sel.move(-1); // already at 0 — stays, does not wrap to row 2
  assert.equal(sel.index(), 0);

  sel.move(1);
  sel.move(1);
  assert.equal(sel.index(), 2); // last row
  sel.move(1); // already at the end — stays, does not wrap to row 0
  assert.equal(sel.index(), 2);

  sel.select(-100);
  assert.equal(sel.index(), 0);
  sel.select(100);
  assert.equal(sel.index(), 2);
});

test("selection: clear() removes aria-activedescendant entirely (not sets it empty)", () => {
  const list = makeList(2, { id: "my-list" });
  const input = makeInput();
  const sel = selection(list, input);
  sel.select(1);
  assert.equal(input.getAttribute("aria-activedescendant"), "my-list-opt-1");
  sel.clear();
  assert.equal(sel.index(), -1);
  assert.equal(input.hasAttribute("aria-activedescendant"), false);
  for (const row of list.querySelectorAll(".rookery-search-row")) {
    assert.equal(row.getAttribute("aria-selected"), "false");
    assert.equal(row.hasAttribute("data-rookery-search-selected"), false);
  }
});

test("selection: onSelect fires on a real selection, not on the no-rows clear() path", () => {
  const list = makeList(0, { id: "my-list" });
  const input = makeInput();
  let calls = 0;
  const sel = selection(list, input, () => calls++);

  sel.select(0);
  assert.equal(calls, 0); // no rows: hits clear(), never reaches onSelect

  list.append(makeRow()); // a row shows up (e.g. a fresh render)
  sel.select(0);
  assert.equal(calls, 1);
});

test("selection: a DOM swap under it never leaves aria-activedescendant pointing at a removed row", () => {
  // The regression class the bead's own comment flags: re-rendering the list
  // (a new query producing fewer/different rows) must not leave the input
  // naming a row id from the old DOM.
  const list = makeList(3, { id: "my-list" });
  const input = makeInput();
  const sel = selection(list, input);
  sel.select(2);
  assert.equal(input.getAttribute("aria-activedescendant"), "my-list-opt-2");

  // Simulate a re-render: old rows gone, one new row in their place.
  sel.clear();
  list.replaceChildren();
  list.append(makeRow());
  sel.select(0);

  assert.equal(input.getAttribute("aria-activedescendant"), "my-list-opt-0");
  const [freshRow] = list.querySelectorAll(".rookery-search-row");
  assert.equal(freshRow.getAttribute("aria-selected"), "true");
});
