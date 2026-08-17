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

// One `<a class="rookery-search-row">` per hit, carrying the title (or the id
// when untitled) and the bracketed id — bracketed because that is how an id
// reads everywhere else in a rookery: `[idea:etal]` beside a note's title, in
// a window's summary, in an outline row. Shared by the dropdown (`wire`) and
// the modal (`wireModal`) so the two never drift into building rows two ways.
//
// `terms` highlights every occurrence it finds in the title/id text, the
// same `<mark>` the preview pane uses. This is a literal-substring
// highlight, not a reconstruction of `fuzzy-score`'s own SUBSEQUENCE match —
// the two can disagree (a scattered subsequence match highlights nothing
// here), but a literal substring is what a reader actually typed most of the
// time, and highlighting it is far more useful than highlighting nothing at
// all rather than trying to be exactly right for every fuzzy match.
const renderRow = (hit, terms) => {
  const a = document.createElement("a");
  a.className = "rookery-search-row";
  a.setAttribute("role", "option");
  a.href = hit.href;
  const title = document.createElement("span");
  title.className = "rookery-search-title";
  const titleText = hit.text === "" ? hit.name : hit.text;
  appendMarked(title, titleText, matchRanges(titleText, terms));
  const id = document.createElement("span");
  id.className = "rookery-search-id";
  const idText = `[${hit.id}]`;
  appendMarked(id, idText, matchRanges(idText, terms));
  a.append(title, id);
  return a;
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
    const terms = fold(q).split(" ").filter((t) => t !== "");
    for (const hit of search(rows, q, limit)) {
      list.append(renderRow(hit, terms));
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

// Renders `text` into `container` as text nodes plus `<mark>`s for every
// range in `ranges` (cluster offsets into `text`, as `snippet` returns them).
// Built with `document.createElement`/`textContent` throughout, never
// `innerHTML` — `text` comes from the author's own notes, and `<mark>` is the
// only markup this should ever produce.
const renderMarked = (container, text, ranges) => {
  const chars = [...text];
  let cursor = 0;
  for (const r of ranges) {
    if (r.start > cursor) {
      container.append(document.createTextNode(chars.slice(cursor, r.start).join("")));
    }
    const mark = document.createElement("mark");
    mark.className = "rookery-search-mark";
    mark.textContent = chars.slice(r.start, r.end).join("");
    container.append(mark);
    cursor = r.end;
  }
  if (cursor < chars.length) {
    container.append(document.createTextNode(chars.slice(cursor).join("")));
  }
};

// The preview excerpt's radius, in clusters, either side of a body match.
// Only used by the plain-text FALLBACK path below (no real-content div found
// for a hit) — not exposed as a knob, since it is an implementation detail
// of the modal, not a public contract the way `#search-index`'s `body-chars`
// is.
const PREVIEW_RADIUS = 160;

// Wraps every occurrence of every `terms` entry inside `root`'s text nodes in
// a `<mark>`, walking the real DOM rather than reconstructing HTML from a
// string — `root` is a clone of author-written, Typst-rendered content
// (`#idea-body`'s output, via `#search-bodies`' hidden per-note divs), so
// there is real markup to preserve: a link's `href`, a code span's
// highlighting, and so on. Case-insensitive and `-`/`_`-folding, the same
// `fold()` every other match in this module uses; `fold` is length-preserving
// (each folded character replaces exactly one), so a match found in a text
// node's FOLDED copy slices correctly out of the node's own original text.
//
// Plain `indexOf` in UTF-16 units, not the cluster-accurate search `snippet`
// uses: this walks one DOM text node at a time rather than concatenating the
// whole body into one string first, so there is no cross-language parity
// requirement here to justify the extra care.
// Every occurrence of every `terms` entry in `text`, folded and
// case-insensitive, merged where they overlap. UTF-16 string offsets
// throughout, not `snippet`'s cluster-accurate ones: neither a title/id row
// nor a real-content clone's individual text nodes are ever diffed against a
// Typst counterpart, so there is no cross-language parity reason to pay for
// cluster precision here. `fold` is length-preserving (each folded character
// replaces exactly one), so an offset found in the FOLDED copy slices
// correctly out of `text` itself.
const matchRanges = (text, terms) => {
  const folded = fold(text);
  const ranges = [];
  for (const term of terms) {
    if (term === "") continue;
    let from = 0;
    while (true) {
      const idx = folded.indexOf(term, from);
      if (idx === -1) break;
      ranges.push({ start: idx, end: idx + term.length });
      from = idx + term.length;
    }
  }
  if (ranges.length === 0) return [];
  ranges.sort((a, b) => a.start - b.start);
  const merged = [ranges[0]];
  for (const r of ranges.slice(1)) {
    const last = merged[merged.length - 1];
    if (r.start <= last.end) last.end = Math.max(last.end, r.end);
    else merged.push({ ...r });
  }
  return merged;
};

// Appends `text` into `container` as plain text nodes plus `<mark>`s for
// every range `matchRanges` found — never `innerHTML`, matching every other
// mark-insertion in this module.
const appendMarked = (container, text, ranges) => {
  let cursor = 0;
  for (const r of ranges) {
    if (r.start > cursor) container.append(document.createTextNode(text.slice(cursor, r.start)));
    const mark = document.createElement("mark");
    mark.className = "rookery-search-mark";
    mark.textContent = text.slice(r.start, r.end);
    container.append(mark);
    cursor = r.end;
  }
  if (cursor < text.length) container.append(document.createTextNode(text.slice(cursor)));
};

// Wraps every occurrence of every `terms` entry inside `root`'s text nodes in
// a `<mark>`, walking the real DOM rather than reconstructing HTML from a
// string — `root` is a clone of author-written, Typst-rendered content
// (`#idea-body`'s output, via `#search-bodies`' hidden per-note divs), so
// there is real markup to preserve: a link's `href`, a code span's
// highlighting, and so on.
const markTermsInNode = (root, terms) => {
  if (terms.length === 0) return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const textNodes = [];
  let n;
  while ((n = walker.nextNode()) !== null) textNodes.push(n);

  for (const textNode of textNodes) {
    const ranges = matchRanges(textNode.textContent, terms);
    if (ranges.length === 0) continue;
    const frag = document.createDocumentFragment();
    appendMarked(frag, textNode.textContent, ranges);
    textNode.replaceWith(frag);
  }
};

const wireModal = (dialog, rows) => {
  const input = dialog.querySelector(".rookery-search-input");
  const list = dialog.querySelector(".rookery-search-list");
  const preview = dialog.querySelector(".rookery-search-preview");
  if (input === null || list === null || preview === null) return null;
  const limit = Number(dialog.dataset.rookerySearchLimit || "8");

  let hits = [];
  let selected = 0;

  const renderPreview = () => {
    preview.replaceChildren();
    const hit = hits[selected];
    if (hit === undefined) return;

    // The real content `#search-bodies` emits, if the project's package
    // version has it — a hidden `<div data-rookery-search-body="ID">`
    // holding `#idea-body`'s actual rendering (links, styling, a real
    // `<pre><code>` for a quoted code block, not the flattened string the
    // JSON island carries). Cloned rather than moved, since the source div
    // has to survive for the next preview too.
    const real = document.querySelector(
      `[data-rookery-search-body="${hit.id}"]`,
    );
    if (real !== null && real.textContent.trim() !== "") {
      const clone = real.cloneNode(true);
      const terms = fold(input.value.trim()).split(" ").filter((t) => t !== "");
      markTermsInNode(clone, terms);
      preview.append(...clone.childNodes);
      return;
    }

    const body = hit.body ?? "";
    if (body === "") {
      const empty = document.createElement("p");
      empty.className = "rookery-search-preview-empty";
      empty.textContent = "No preview";
      preview.append(empty);
      return;
    }
    // FALLBACK, for a project on a `#search-index`-only build (no
    // `#search-bodies`, e.g. an older `@rheo/rookery-search` or `index:
    // false` with a hand-rolled index): the plain-text excerpt this pane
    // always showed before real content existed. Centred on the match for a
    // body hit; from the start for a name hit — a radius of Infinity makes
    // `snippet` return the whole body with no truncation, since its window
    // is clamped to the body's own length. EITHER WAY every matched term
    // still gets wrapped in `<mark>`, because both paths go through the same
    // `snippet` call.
    const radius = hit.kind === "body" ? PREVIEW_RADIUS : Number.POSITIVE_INFINITY;
    const { text, ranges } = snippet(body, input.value.trim(), radius);
    const p = document.createElement("p");
    renderMarked(p, text, ranges);
    preview.append(p);
  };

  // Marks exactly one row selected (clamped, no wrap — see keyboard handling
  // below), scrolls it into view, and re-renders the preview to match.
  const select = (i) => {
    const els = list.querySelectorAll(".rookery-search-row");
    if (els.length === 0) return;
    selected = Math.max(0, Math.min(i, els.length - 1));
    for (const [idx, el] of els.entries()) {
      if (idx === selected) {
        el.setAttribute("aria-selected", "true");
        el.setAttribute("data-rookery-search-selected", "true");
      } else {
        el.setAttribute("aria-selected", "false");
        el.removeAttribute("data-rookery-search-selected");
      }
    }
    els[selected].scrollIntoView({ block: "nearest" });
    renderPreview();
  };

  const render = () => {
    const q = input.value.trim();
    list.replaceChildren();
    // EMPTY QUERY shows the corpus, not nothing: `search(rows, "", limit)`
    // already returns everything at score 0 in id order — telescope's
    // empty-prompt behaviour, deliberately unlike `#search-bar`'s dropdown,
    // which stays shut on an empty query.
    hits = search(rows, q, limit);
    const terms = fold(q).split(" ").filter((t) => t !== "");
    for (const hit of hits) {
      const row = renderRow(hit, terms);
      row.addEventListener("pointerenter", () => {
        select([...list.children].indexOf(row));
      });
      list.append(row);
    }
    select(0);
  };

  input.addEventListener("input", render);

  dialog.addEventListener("keydown", (ev) => {
    if (ev.key === "ArrowDown" || (ev.ctrlKey && ev.key === "n")) {
      ev.preventDefault();
      select(selected + 1);
    } else if (ev.key === "ArrowUp" || (ev.ctrlKey && ev.key === "p")) {
      ev.preventDefault();
      select(selected - 1);
    } else if (ev.key === "Enter") {
      ev.preventDefault();
      const hit = hits[selected];
      if (hit !== undefined) window.location.href = hit.href;
    } else if (ev.key === "Escape") {
      // NOT left to native `<dialog>` Escape-to-close, despite that being the
      // usual advice: MEASURED, a focused `type="search"` input with a
      // non-empty value consumes Escape for its OWN default action (clearing
      // the field) before it reaches the dialog's cancel algorithm, so the
      // modal never closes on the first press. Closing explicitly here is
      // reliable regardless of what the input holds.
      ev.preventDefault();
      dialog.close();
    }
  });

  // A `<dialog>`'s backdrop clicks register on the dialog element itself, so
  // the click target must BE the dialog (not a descendant) before closing —
  // otherwise every click inside the panel would close it.
  dialog.addEventListener("click", (ev) => {
    if (ev.target === dialog) dialog.close();
  });

  // Resets selection state once the dialog has actually closed, by whatever
  // means — the explicit Escape handler above, a backdrop click, or a caller
  // closing it directly.
  dialog.addEventListener("close", () => {
    selected = 0;
  });

  return {
    open: () => {
      dialog.showModal();
      render();
      // Select the input's contents (not clear it), so a reopen starts a
      // fresh query without losing what was there before.
      input.focus();
      input.select();
    },
  };
};

export const init = () => {
  // The dialog ALSO carries `data-rookery-search` (it shares the bar's
  // island-lookup attribute), so the bar query must exclude it — otherwise a
  // page with both a bar and a modal would wire the dialog as a second,
  // broken dropdown.
  const roots = document.querySelectorAll("[data-rookery-search]:not(dialog)");
  const dialogs = document.querySelectorAll("dialog[data-rookery-search]");
  if (roots.length === 0 && dialogs.length === 0) return;

  // Shared across bars AND modals, so a page with both parses the JSON once.
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
  if (bars.length > 0) {
    // ONE listener for every bar on the page, not one each: the question a
    // click asks is "which bars was this outside of", and that is naturally a
    // single pass. Two bars therefore close independently and correctly — a
    // click on one is outside the other, and dismisses only it.
    //
    // `pointerdown`, not `click`: it fires before focus moves, so the
    // dropdown is gone by the time the reader's press lands and nothing
    // flickers. A result link is INSIDE its own bar, so following one never
    // counts as a click outside — navigation is unaffected.
    document.addEventListener("pointerdown", (ev) => {
      for (const bar of bars) {
        if (!bar.root.contains(ev.target)) bar.dismiss();
      }
    });
  }

  const modals = new Map();
  for (const dialog of dialogs) {
    const elemId = dialog.dataset.rookerySearch || "rookery-search-index";
    if (!cache.has(elemId)) cache.set(elemId, readIndex(elemId));
    const rows = cache.get(elemId);
    if (rows === null) continue;
    const modal = wireModal(dialog, rows);
    if (modal !== null) modals.set(elemId, modal);
  }
  if (modals.size === 0) return;

  for (const trigger of document.querySelectorAll(".rookery-search-trigger")) {
    const modal = modals.get(trigger.dataset.rookerySearchModal);
    if (modal === undefined) continue;
    trigger.addEventListener("click", () => modal.open());
  }

  // Registered once per page, not once per modal — opens the FIRST modal in
  // document order, matching telescope's own convention of one global
  // shortcut. `preventDefault()` because Ctrl+K is a browser binding in some
  // browsers and the page must win here.
  document.addEventListener("keydown", (ev) => {
    if (!(ev.ctrlKey || ev.metaKey) || ev.key.toLowerCase() !== "k") return;
    // A reader typing in some other field means the literal keystroke, not
    // the shortcut.
    const t = ev.target;
    if (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable) return;
    ev.preventDefault();
    modals.values().next().value?.open();
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
