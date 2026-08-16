// @rheo/rookery-search — the search bar's behaviour. RHEO ONLY: this file is
// injected by rheo via `[tool.rheo.html] js_scripts` in the package manifest,
// and it reads an index whose hrefs point at pages only rheo mints. Under plain
// `typst compile` nothing injects it, `#search-bar` emits nothing, and the
// Typst-side `search-ideas` remains the supported path.
//
// Built with vite into `dist/lib.js` as an IIFE bundle exposing the global
// `RheoRookerySearch`, the same shape every other JS package here ships. An ES
// module in `src/` and a global at runtime: the module form is what lets the
// parity fixture import it under node, the global is what lets a site build its
// own UI on this ranking instead of forking it.
//
// No dependencies, and it should stay that way — vite is bundling one file.
//
// PARITY. `score` below is a line-for-line port of `fuzzy-score` in
// `src/lib.typ`. The two must agree, and `just parity` is what enforces it —
// it feeds one list of (hay, query) pairs through both and diffs the scores.
// Change one, change the other, re-run the fixture.
//
// EMBEDDING. Every bar on the page is found by its `data-rookery-search`
// attribute, whose VALUE is the id of the island it reads. So several bars can
// share one island, or point at different ones, and none of them needs an id of
// its own — ids are assigned here at runtime, because markup that carries a
// hardcoded id cannot be placed twice on a page.

export const fold = (s) => s.toLowerCase().replaceAll("-", " ").replaceAll("_", " ");

// Port of `fuzzy-score`. `null` (Typst `none`) when the query's characters do
// not all appear in `hay` in order; otherwise an integer, higher better.
export const score = (hay, query) => {
  const h = fold(hay);
  const q = fold(query);
  if (q === "") return 0;
  const hc = [...h];
  const qc = [...q];
  let i = 0;
  let first = null;
  let prev = null;
  let points = 0;
  for (const ch of qc) {
    let found = null;
    for (let j = i; j < hc.length; j++) {
      if (hc[j] === ch) {
        found = j;
        break;
      }
    }
    if (found === null) return null;
    if (first === null) first = found;
    points += prev !== null && found === prev + 1 ? 3 : 1;
    prev = found;
    i = found + 1;
  }
  if (h.startsWith(q)) points += 10;
  else if (h.includes(q)) points += 5;
  points += Math.max(0, 5 - first);
  points += Math.max(0, 10 - (hc.length - qc.length));
  return points;
};

// Same rule as `search-ideas`: match on the id AND the title, take the better
// of the two, rank best-first, break ties by id so the order is stable.
export const search = (rows, query, limit) => {
  const out = [];
  for (const row of rows) {
    const sName = score(row.name, query);
    const sText = row.text === "" ? null : score(row.text, query);
    const s =
      sName === null ? sText : sText === null ? sName : Math.max(sName, sText);
    if (s === null) continue;
    out.push({ ...row, score: s });
  }
  out.sort((a, b) => b.score - a.score || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return limit == null ? out : out.slice(0, limit);
};

export const readIndex = (elemId) => {
  const el = document.getElementById(elemId);
  if (el === null) return null;
  try {
    return JSON.parse(el.textContent);
  } catch {
    return null;
  }
};

const wire = (root, rows, n) => {
  const input = root.querySelector(".rookery-search-input");
  const list = root.querySelector(".rookery-search-results");
  if (input === null || list === null) return;
  const limit = Number(root.dataset.rookerySearchLimit || "8");

  // Assigned here, not in the markup: a bar has to be placeable more than once
  // on a page, and duplicate ids would break both `aria-controls` and any CSS
  // or script keyed off them.
  list.id = `rookery-search-listbox-${n}`;
  input.setAttribute("aria-controls", list.id);

  const render = () => {
    const q = input.value.trim();
    list.replaceChildren();
    const open = q !== "";
    root.dataset.rookerySearchOpen = open ? "true" : "false";
    input.setAttribute("aria-expanded", open ? "true" : "false");
    if (!open) return;
    for (const hit of search(rows, q, limit)) {
      const a = document.createElement("a");
      a.className = "rookery-search-row";
      a.setAttribute("role", "option");
      a.href = hit.href;
      const title = document.createElement("span");
      title.className = "rookery-search-title";
      title.textContent = hit.text === "" ? hit.name : hit.text;
      const id = document.createElement("span");
      id.className = "rookery-search-id";
      id.textContent = hit.id;
      a.append(title, id);
      list.append(a);
    }
  };

  input.addEventListener("input", render);
  input.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape") {
      input.value = "";
      render();
      input.blur();
    }
  });
};

export const init = () => {
  const roots = document.querySelectorAll("[data-rookery-search]");
  if (roots.length === 0) return;
  const cache = new Map();
  let n = 0;
  for (const root of roots) {
    const elemId = root.dataset.rookerySearch || "rookery-search-index";
    if (!cache.has(elemId)) cache.set(elemId, readIndex(elemId));
    const rows = cache.get(elemId);
    // No island for this bar (a site placed one with `index: false` and no
    // other bar emitted it, or the build emitted none) — leave the input inert
    // rather than throwing.
    if (rows === null) continue;
    wire(root, rows, n++);
  }
};

// Auto-init in a browser. Guarded so the parity fixture can `import` this module
// under node, where there is no document and nothing to wire.
if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}
