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
// `src/lib.typ`, and `bodyScore` is the same port of `body-score`. The two
// pairs must agree, and `just parity` is what enforces it — it feeds two
// fixtures through both languages and diffs the scores. Change one side,
// change the other, re-run the fixture. `snippet` below has NO Typst
// counterpart and none is wanted (a static Typst listing shows titles, not
// excerpts) — do not go looking for it in `lib.typ`.
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

// Port of `body-score`: an AND, full-text match over a note's body. `null`
// unless every whitespace-split term in `query` appears in `body`. The
// earliness term counts CLUSTERS, not UTF-16 units — a bare `indexOf` is a
// UTF-16 offset and would diverge from Typst's `.clusters()` count the moment
// a body contains a non-ASCII character, so the match is re-measured through
// a spread.
export const bodyScore = (body, query) => {
  const h = fold(body);
  const q = fold(query);
  if (q.trim() === "") return null;
  const terms = q.split(" ").filter((t) => t !== "");
  if (terms.length === 0) return null;
  for (const term of terms) {
    if (!h.includes(term)) return null;
  }
  let points = 0;
  if (h.includes(q)) points += 6;
  for (const term of terms) {
    points += 2;
    const i = h.indexOf(term);
    const cl = [...h.slice(0, i)].length;
    points += Math.max(0, 3 - Math.floor(cl / 200));
  }
  return points;
};

// Same rule as `search-ideas`: match on the id AND the title first (tier 0),
// take the better of the two; failing that, match on the body (tier 1) via
// `bodyScore`. Every tier-0 row ranks above every tier-1 row; within a tier,
// best score first, ties broken by id so the order is stable. `row.body`
// missing (an older or truncated island) is treated as `""` — it simply
// never matches on body, it never throws.
export const search = (rows, query, limit) => {
  const out = [];
  for (const row of rows) {
    const sName = score(row.name, query);
    const sText = row.text === "" ? null : score(row.text, query);
    const nameScore =
      sName === null ? sText : sText === null ? sName : Math.max(sName, sText);
    if (nameScore !== null) {
      out.push({ ...row, score: nameScore, kind: "name" });
      continue;
    }
    const bScore = bodyScore(row.body ?? "", query);
    if (bScore !== null) out.push({ ...row, score: bScore, kind: "body" });
  }
  const tier = (hit) => (hit.kind === "name" ? 0 : 1);
  out.sort(
    (a, b) =>
      tier(a) - tier(b) || b.score - a.score || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
  return limit == null ? out : out.slice(0, limit);
};

// Cluster-accurate substring search over `h`'s cluster array — `score` and
// `bodyScore` above only ever ask "does this appear", `snippet` also needs
// "where", so it works in cluster space throughout rather than mixing UTF-16
// offsets back in.
const findClusterMatches = (hc, needle) => {
  const positions = [];
  if (needle.length === 0) return positions;
  outer: for (let i = 0; i + needle.length <= hc.length; i++) {
    for (let j = 0; j < needle.length; j++) {
      if (hc[i + j] !== needle[j]) continue outer;
    }
    positions.push({ start: i, end: i + needle.length });
  }
  return positions;
};

// The preview excerpt for the modal's right-hand pane. Finds the earliest
// occurrence of the whole (folded) query as a contiguous phrase, or failing
// that the earliest occurrence of any term, and takes `radius` clusters
// either side of it — `body` (unfolded) is sliced, not `h`, so casing and
// original punctuation survive in the excerpt. Prefixes/suffixes a "…" when
// the excerpt is truncated. `ranges` are cluster offsets INTO `text` (i.e.
// already account for a leading "…") of every term occurrence within the
// excerpt, for the caller to wrap in `<mark>`.
//
// NO PARITY REQUIREMENT: there is no Typst counterpart, and none is wanted —
// a static Typst listing shows titles, not excerpts.
export const snippet = (body, query, radius) => {
  const h = fold(body);
  const q = fold(query);
  const bc = [...body];
  const hc = [...h];
  const terms = q.split(" ").filter((t) => t !== "");
  const termClusters = terms.map((t) => [...t]);

  let anchor = null;
  if (q !== "") {
    const phraseMatches = findClusterMatches(hc, [...q]);
    if (phraseMatches.length > 0) anchor = phraseMatches[0];
  }
  if (anchor === null) {
    for (const tc of termClusters) {
      const m = findClusterMatches(hc, tc)[0];
      if (m !== undefined && (anchor === null || m.start < anchor.start)) anchor = m;
    }
  }
  if (anchor === null) anchor = { start: 0, end: 0 };

  const center = anchor.start + Math.floor((anchor.end - anchor.start) / 2);
  const start = Math.max(0, center - radius);
  const end = Math.min(bc.length, center + radius);
  const prefix = start > 0 ? "…" : "";
  const suffix = end < bc.length ? "…" : "";
  const text = prefix + bc.slice(start, end).join("") + suffix;

  const ranges = [];
  for (const tc of termClusters) {
    for (const m of findClusterMatches(hc, tc)) {
      if (m.end <= start || m.start >= end) continue;
      const clippedStart = Math.max(m.start, start);
      const clippedEnd = Math.min(m.end, end);
      ranges.push({
        start: prefix.length + (clippedStart - start),
        end: prefix.length + (clippedEnd - start),
      });
    }
  }
  ranges.sort((a, b) => a.start - b.start);

  return { text, ranges };
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

  // Set by a click outside this bar, cleared the moment the reader types
  // again. It is a separate piece of state from "the query is empty", because
  // a dismissed dropdown must STAY shut while its query is still in the input
  // — including when the reader clicks back into the field. Only new typing
  // brings it back, which is the one unambiguous signal that they want it.
  let dismissed = false;

  const render = () => {
    const q = input.value.trim();
    list.replaceChildren();
    const open = q !== "" && !dismissed;
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
      // Bracketed, because that is how an id reads everywhere else in a
      // rookery: `[idea:etal]` beside a note's title, in a window's summary,
      // in an outline row. A result should look like the thing it points at.
      id.textContent = `[${hit.id}]`;
      a.append(title, id);
      list.append(a);
    }
  };

  input.addEventListener("input", () => {
    dismissed = false;
    render();
  });
  input.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape") {
      input.value = "";
      dismissed = false;
      render();
      input.blur();
    }
  });

  return {
    root,
    // Called for every click that lands outside this bar. Leaves the query in
    // the input: the reader dismissed a dropdown, they did not ask to lose
    // what they had typed.
    dismiss: () => {
      if (dismissed) return;
      dismissed = true;
      render();
    },
  };
};

export const init = () => {
  const roots = document.querySelectorAll("[data-rookery-search]");
  if (roots.length === 0) return;
  const cache = new Map();
  const bars = [];
  let n = 0;
  for (const root of roots) {
    const elemId = root.dataset.rookerySearch || "rookery-search-index";
    if (!cache.has(elemId)) cache.set(elemId, readIndex(elemId));
    const rows = cache.get(elemId);
    // No island for this bar (a site placed one with `index: false` and no
    // other bar emitted it, or the build emitted none) — leave the input inert
    // rather than throwing.
    if (rows === null) continue;
    const bar = wire(root, rows, n++);
    if (bar) bars.push(bar);
  }
  if (bars.length === 0) return;

  // ONE listener for every bar on the page, not one each: the question a click
  // asks is "which bars was this outside of", and that is naturally a single
  // pass. Two bars therefore close independently and correctly — a click on
  // one is outside the other, and dismisses only it.
  //
  // `pointerdown`, not `click`: it fires before focus moves, so the dropdown is
  // gone by the time the reader's press lands and nothing flickers. A result
  // link is INSIDE its own bar, so following one never counts as a click
  // outside — navigation is unaffected.
  document.addEventListener("pointerdown", (ev) => {
    for (const bar of bars) {
      if (!bar.root.contains(ev.target)) bar.dismiss();
    }
  });
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
