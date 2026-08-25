// Browser half of `#todos-search`: filter the rows already on the page.
//
// Nothing is fetched and nothing is built here. The Typst side emitted every
// row up front with its haystack, status and type as `data-` attributes; this
// only shows, hides and reorders them. If it never runs, the page is a complete
// readable list and the stylesheet keeps the chrome that would do nothing out
// of sight.
//
// The pure half is exported so it can be tested without a DOM — the same split
// `layout.js` and `rookery-todos.js` already use.

// A case-insensitive SUBSEQUENCE score: every character of `query` must appear
// in `haystack` in order, though not necessarily adjacently. Returns a number,
// or -1 for no match.
//
// AN EMPTY QUERY SCORES 0 FOR EVERYTHING, which is what leaves the build-time
// priority order untouched until someone types: equal scores keep their
// original index at the call site below.
//
// The score rewards contiguous runs and an earlier first match, so "manifest"
// beats a scattered m-a-n-i-f-e-s-t spread across a sentence.
//
// DELIBERATELY SIMPLER THAN `@rheo/rookery-search`'s ranking, which is mirrored
// in Typst and pinned by a parity test. This filter runs over tens of rows
// already on the page rather than a whole corpus, and copying that ranking here
// would create a second copy of it with no parity test to keep the two honest.
export function score(haystack, query) {
  if (!query) return 0;
  const h = haystack.toLowerCase();
  const q = query.toLowerCase();
  let hi = 0;
  let first = -1;
  let run = 0;
  let best = 0;
  for (let qi = 0; qi < q.length; qi++) {
    const found = h.indexOf(q[qi], hi);
    if (found === -1) return -1;
    if (first === -1) first = found;
    run = found === hi && qi > 0 ? run + 1 : 0;
    if (run > best) best = run;
    hi = found + 1;
  }
  // Contiguity dominates; an earlier first match breaks the tie. Both are
  // bounded so a long haystack cannot outscore a better match in a short one.
  return best * 100 + Math.max(0, 100 - first);
}

// Does a row survive the pills?
//
// `facets` is `{ status: Set, type: Set }`. Within a facet the values OR — two
// status pills mean "either" — and across facets they AND. An EMPTY set means
// that facet is unconstrained, which is what makes "no pills pressed" show
// everything rather than nothing.
export function passes(row, facets) {
  for (const [key, wanted] of Object.entries(facets)) {
    if (!wanted || wanted.size === 0) continue;
    if (!wanted.has(row[key])) return false;
  }
  return true;
}

function wire(container) {
  const input = container.querySelector(".todo-search-input");
  const list = container.querySelector(".todo-search-results");
  const count = container.querySelector(".todo-search-count");
  if (!input || !list) return;

  // Read once. The rows never change after this — filtering only toggles
  // `hidden` and re-appends, so the original index survives as the tiebreak
  // that preserves the build-time priority order.
  const rows = [...list.querySelectorAll(".todo-search-row")].map((el, index) => ({
    el,
    index,
    text: el.getAttribute("data-todo-text") || "",
    status: el.getAttribute("data-todo-status") || "",
    type: el.getAttribute("data-todo-type") || "",
  }));
  const total = rows.length;

  // `aria-controls` wired at RUNTIME, because the markup carries no id: a
  // hardcoded one cannot appear twice on a page and nothing stops a project
  // putting two of these widgets on one.
  if (!list.id) {
    list.id = `todo-search-results-${Math.round(performance.now() * 1000)}-${total}`;
  }
  input.setAttribute("aria-controls", list.id);

  const facets = { status: new Set(), type: new Set() };
  const pills = [...container.querySelectorAll(".todo-search-pill")];

  const apply = () => {
    const q = input.value.trim();
    const scored = [];
    for (const row of rows) {
      const s = passes(row, facets) ? score(row.text, q) : -1;
      if (s < 0) {
        // THE `hidden` ATTRIBUTE NEEDS `.todo-search-row[hidden]` IN THE
        // STYLESHEET to do anything here, and the two must move together. A
        // search row carries `todo-row`, which is `display: flex`, and the UA's
        // `[hidden] { display: none }` loses to any author rule setting
        // `display` — so on its own this hid nothing and the filter merely
        // reordered the list. MEASURED on a live site before the rule existed.
        //
        // Still the attribute rather than a class: `hidden` is what tells
        // assistive technology the row is gone, where a class would hide it
        // visually and leave it in the accessibility tree.
        row.el.hidden = true;
      } else {
        row.el.hidden = false;
        scored.push({ row, s });
      }
    }
    // Higher score first; equal scores keep their original order, which is the
    // priority order Typst sorted them into.
    scored.sort((a, b) => (b.s - a.s) || (a.row.index - b.row.index));
    for (const { row } of scored) list.appendChild(row.el);
    if (count) {
      count.textContent =
        scored.length === total ? `${total} todos` : `${scored.length} of ${total}`;
    }
  };

  input.addEventListener("input", apply);
  input.addEventListener("keydown", (ev) => {
    // Escape clears the query and restores the original order.
    if (ev.key === "Escape") {
      input.value = "";
      apply();
    }
  });

  for (const pill of pills) {
    pill.addEventListener("click", () => {
      const facet = pill.getAttribute("data-todo-facet");
      const value = pill.getAttribute("data-todo-value");
      const set = facets[facet];
      if (!set) return;
      if (set.has(value)) {
        set.delete(value);
        pill.setAttribute("aria-pressed", "false");
      } else {
        set.add(value);
        pill.setAttribute("aria-pressed", "true");
      }
      apply();
    });
  }

  container.setAttribute("data-todo-search-ready", "true");
}

function init() {
  for (const c of document.querySelectorAll(".todo-search")) wire(c);
}

if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}
