// Browser half of `#panel` in `src/panel.typ`: filter, rank and reorder the rows
// already on the page.
//
// NOTHING IS FETCHED AND NOTHING IS BUILT HERE. The Typst side emitted every row
// up front with its haystack and its faceted values as `data-` attributes, so
// this only shows, hides and reorders them. If it never runs, the page is a
// complete readable list and the stylesheet keeps the chrome that would do
// nothing out of sight.
//
// GENERIC OVER WHATEVER FIELDS A ROW CARRIES. A panel declares its facets in
// Typst; this reads the pill groups off the DOM and takes each group's
// `data-panel-group` as the attribute name to test. So no facet vocabulary lives
// here, which is what lets one implementation serve submissions, todos and
// anything else.
//
// THE SCORER IS `score` FROM `score.js`, imported rather than re-ported. That
// function had three copies across this repo and a consuming site before panels
// existed; adding a fourth here would have been the whole problem again.

import { score } from "./score.js";

// Does a row survive the pills? Within a facet the values OR — two state pills
// mean "either" — and across facets they AND. An EMPTY set means that facet is
// unconstrained, which is what makes "no pills pressed" show everything rather
// than nothing.
const passes = (row, facets) => {
  for (const [field, wanted] of facets) {
    if (wanted.size === 0) continue;
    if (!wanted.has(row.values[field] ?? "")) return false;
  }
  return true;
};

export const wirePanel = (container, n) => {
  const input = container.querySelector(".panel-input");
  const list = container.querySelector(".panel-results");
  if (input === null || list === null) return null;

  // The facet fields, read off the groups the Typst side emitted. A panel with no
  // pills is legal and gets an empty map.
  const facets = new Map();
  for (const group of container.querySelectorAll(".panel-pill-group")) {
    const field = group.dataset.panelGroup;
    if (field) facets.set(field, new Set());
  }
  const fields = [...facets.keys()];

  // Read ONCE. The rows never change after this — filtering only toggles `hidden`
  // and re-appends — so the original index survives as the tiebreak that
  // preserves the order Typst sorted them into.
  const rows = [...list.querySelectorAll(".panel-row")].map((el, index) => {
    const values = {};
    for (const f of fields) values[f] = el.getAttribute(`data-${f}`) ?? "";
    return { el, index, text: el.getAttribute("data-panel-text") || "", values };
  });
  const total = rows.length;

  // `aria-controls` wired at RUNTIME, because the markup carries no id: a
  // hardcoded one cannot appear twice on a page and nothing stops a site putting
  // two panels on one.
  if (!list.id) list.id = `panel-results-${n}`;
  input.setAttribute("aria-controls", list.id);

  const count = container.querySelector(".panel-count");
  const noun = count ? (count.textContent.split(" ").slice(1).join(" ") || "rows") : "rows";

  const apply = () => {
    const q = input.value.trim();
    const kept = [];
    for (const row of rows) {
      // `score` returns -1 for no match and 0 for an EMPTY query, which is what
      // leaves the build-time order untouched until someone types.
      const s = passes(row, facets) ? score(row.text, q) : -1;
      if (s < 0) {
        row.el.hidden = true;
      } else {
        kept.push({ row, s });
      }
    }
    // Higher score first; equal scores keep their original order, which is
    // whatever the Typst side sorted them into.
    kept.sort((a, b) => b.s - a.s || a.row.index - b.row.index);

    // EVERY MATCH IS SHOWN. The list is a scroll box `--panel-rows` tall — a
    // stylesheet's business, not this script's — so there is nothing to cap here
    // and no row a reader cannot reach.
    //
    // `hidden` is the ATTRIBUTE rather than a class: it is what tells assistive
    // technology the row is gone, where a class would hide it visually and leave
    // it in the accessibility tree. It needs `.panel-row[hidden]` in the
    // stylesheet to bite, since the row sets its own `display` and the UA's
    // `[hidden]` rule loses to any author rule that does.
    for (const { row } of kept) {
      row.el.hidden = false;
      list.appendChild(row.el);
    }

    // Scrolled halfway down and then narrowing the query would otherwise leave
    // the box parked past the end of the new, shorter list.
    list.scrollTop = 0;

    if (count) {
      if (kept.length === 0) count.textContent = "nothing matches";
      else if (kept.length === total) count.textContent = `${total} ${noun}`;
      else count.textContent = `${kept.length} of ${total}`;
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

  for (const pill of container.querySelectorAll(".panel-pill")) {
    pill.addEventListener("click", () => {
      const set = facets.get(pill.dataset.panelFacet);
      if (!set) return;
      const value = pill.dataset.panelValue;
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

  container.setAttribute("data-panel-ready", "true");
  apply();
  return { container, apply };
};

export const initPanels = () => {
  let n = 0;
  for (const c of document.querySelectorAll(".panel")) wirePanel(c, n++);
};
