// Wiring the two surfaces to the DOM: `wire` for the embedded bar, `wireModal`
// for the overlay.

import { readIndex } from "./island.js";
import { renderRow } from "./row.js";
import { search, splitQuery } from "./score.js";
import { selection } from "./selection.js";
import { extractNote, fetchNote, previewCache } from "./preview.js";
import { KEYWORD_LIMIT, appendMarked, markTermsInNode, matchRanges } from "./marks.js";
import { parseTagQuery, positiveAtoms } from "./tagquery.js";
import { fold } from "./text.js";

// The `limit` attribute, which is a NUMBER, the string "none", or absent.
//
// `null` is what `search()` already reads as uncapped (`score.js`: `limit == null ?
// out : out.slice(0, limit)`), so "none" resolves to that rather than to Infinity —
// the core has meant this all along and only the attribute could not say it.
//
// ABSENT IS NOT UNCAPPED. It means an older page's markup, or one rendered before
// this attribute existed, and both want the widget's own default — which is why the
// fallback is a parameter here rather than a constant.
const readLimit = (raw, fallback) => {
  if (raw === "none") return null;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : fallback;
};

export const wire = (root, rows, n) => {
  const input = root.querySelector(".rookery-search-input");
  const list = root.querySelector(".rookery-search-results");
  if (input === null || list === null) return;
  const limit = readLimit(root.dataset.rookerySearchLimit, 8);

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

  const sel = selection(list, input);

  const render = () => {
    const q = input.value.trim();
    list.replaceChildren();
    // BEFORE the early return below, not after the rows are appended: the rows
    // this cleared against are already gone, and a closed dropdown must not leave
    // the input pointing at an option that no longer exists.
    sel.clear();
    const open = q !== "" && !dismissed;
    root.dataset.rookerySearchOpen = open ? "true" : "false";
    input.setAttribute("aria-expanded", open ? "true" : "false");
    if (!open) return;
    // HIGHLIGHT TERMS COME FROM THE RESIDUAL, not the raw input: a query of
    // `tags:draft window` must mark "window" and never the literal "tags:draft",
    // which is an instruction rather than something any note contains.
    //
    // Note the `open` test above still reads the RAW input, on purpose — a bare
    // `tags:draft` with no residual text should open the dropdown, and it is
    // non-empty even though its residual is "".
    //
    // The tag expression's POSITIVE atoms travel beside them, so a chip an atom
    // prefix-matched is marked too. Computed once per render, not per row.
    const { rpn, text } = splitQuery(q);
    const terms = fold(text).split(" ").filter((t) => t !== "");
    const atoms = positiveAtoms(rpn);
    for (const hit of search(rows, q, limit)) {
      list.append(renderRow(hit, terms, atoms));
    }
  };

  input.addEventListener("input", () => {
    dismissed = false;
    render();
  });
  input.addEventListener("keydown", (ev) => {
    // ArrowDown/ArrowUp plus Ctrl-n/Ctrl-p, the same pair the modal takes, so a
    // reader does not have to learn two sets of keys for one search.
    //
    // `preventDefault` on the arrows because a `type="search"` input would
    // otherwise move the text caret to the end or the start of the value — the
    // arrows belong to the list while the list is open, which is exactly what
    // `open` tests. With the dropdown shut they are the caret's again.
    const open = root.dataset.rookerySearchOpen === "true";
    if (open && (ev.key === "ArrowDown" || (ev.ctrlKey && ev.key === "n"))) {
      ev.preventDefault();
      sel.move(1);
    } else if (open && (ev.key === "ArrowUp" || (ev.ctrlKey && ev.key === "p"))) {
      ev.preventDefault();
      sel.move(-1);
    } else if (ev.key === "Enter") {
      // THE HREF COMES OFF THE ROW, not out of a parallel `hits` array the way
      // the modal reads it: the row IS an `<a>`, so its `href` property is the
      // resolved URL and there is no second copy of the result list to keep in
      // step with the DOM. Enter with nothing selected is left alone — the field
      // may be inside a form, and swallowing a submit no reader asked us to
      // swallow is worse than doing nothing.
      const row = sel.current();
      if (row !== null) {
        ev.preventDefault();
        window.location.href = row.href;
      }
    } else if (ev.key === "Escape") {
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
export const wireModal = (dialog, rows) => {
  const input = dialog.querySelector(".rookery-search-input");
  const list = dialog.querySelector(".rookery-search-list");
  const preview = dialog.querySelector(".rookery-search-preview");
  if (input === null || list === null || preview === null) return null;
  // 30, not `wire`'s 8, and deliberately so: a full-height overlay pane has room
  // a dropdown under an input does not, which is why `#search-modal`'s own
  // default is 30 (`src/lib.typ:416`) where `#search-bar`'s is 8. Do not tidy
  // the two into agreement.
  const limit = readLimit(dialog.dataset.rookerySearchLimit, 30);

  let hits = [];
  // Bumped by every `renderPreview`, so a `fetch` that lands after the reader
  // has moved on cannot paint over a later selection's pane. Arrow-keying down
  // a list of hits starts a request per row it passes through and those can
  // resolve in any order — without this, the slowest one wins the pane.
  let previewGen = 0;

  // THE KEYWORD ROW — the failed-fetch fallback, and the ONE place the
  // compressed index is reader-facing. The island's `body` field is not prose:
  // it is that note's most distinctive terms, space-joined in weight order.
  // MEASURED on a weeknotes copy: `"entry actual notes general introductory site
  // first weeknotes wrote post posted blog writing"`. There is nothing there to
  // excerpt, which is why the excerpt is gone rather than merely demoted.
  //
  // CHIPS, NOT A PARAGRAPH. Set as running text that string reads as debug
  // output that leaked into the UI; one box per term says "these are the note's
  // terms" without needing a caption to say it. It also makes the ORDER visible
  // as an order: the compression pass already sorts by weight, so display order
  // is meaningful — most distinctive first.
  //
  // Except that a term the reader's query matched is hoisted ahead of the
  // unmatched ones among the shown terms. Weight order is the default, but a
  // matched term is WHY this note is on screen, and it must not be the one term
  // the cap cut off. Sliced to `KEYWORD_LIMIT` after the hoist for that reason.
  //
  // The line above the row says why a bag of words is the preview at all —
  // without it a reader is left to infer that the pane failed rather than that
  // this is the intended rendering. It reuses `.rookery-search-preview-empty`
  // rather than earning a class of its own: it is the same KIND of line as "No
  // preview" and "No match found" — muted, italic, a note ABOUT the pane rather
  // than content in it.
  //
  // AN EMPTY BODY KEEPS THE PLAIN "No preview" LINE, and it is a real case, not
  // a defensive one — MEASURED: a genuinely empty note ships an empty `body`,
  // and `body-search: false` omits the field from every row. An empty chip row
  // would be a frame with nothing in it above a sentence explaining nothing.
  //
  // `createElement`/`textContent` throughout, never `innerHTML`, for the reason
  // the module header gives: a term comes out of the author's own notes and must
  // never be able to inject markup. `<mark>` is the only markup here and
  // `appendMarked` is what appends it — the same element and class a result row
  // and a fetched note's text nodes are marked with, so a match looks identical
  // wherever the reader meets it.
  const renderKeywords = (hit) => {
    const terms = (hit.body ?? "").split(" ").filter((t) => t !== "");
    if (terms.length === 0) {
      const empty = document.createElement("p");
      empty.className = "rookery-search-preview-empty";
      empty.textContent = "No preview";
      preview.append(empty);
      return;
    }
    const queryTerms = fold(input.value.trim()).split(" ").filter((t) => t !== "");
    // The ranges are carried alongside each term rather than recomputed for the
    // chips: whether a term matched IS whether it has any ranges, so one
    // `matchRanges` per term answers both the hoist and the marking.
    const matched = [];
    const rest = [];
    for (const term of terms) {
      const ranges = matchRanges(term, queryTerms);
      (ranges.length > 0 ? matched : rest).push({ term, ranges });
    }
    const why = document.createElement("p");
    why.className = "rookery-search-preview-empty";
    why.textContent = "This note’s page could not be loaded — showing its keywords instead.";
    const row = document.createElement("div");
    row.className = "rookery-search-keywords";
    for (const { term, ranges } of [...matched, ...rest].slice(0, KEYWORD_LIMIT)) {
      const chip = document.createElement("span");
      chip.className = "rookery-search-keyword";
      appendMarked(chip, term, ranges);
      row.append(chip);
    }
    preview.append(why, row);
  };

  const renderPreview = () => {
    // `sel` is declared BELOW this function and read only when it runs, which is
    // always after `selection(..)` has returned it — the closure is what makes
    // that legal, and the alternative (threading the index through every caller)
    // would put two copies of "which row is active" in one file.
    const hit = hits[sel.index()];
    const gen = ++previewGen;
    preview.replaceChildren();
    // `replaceChildren` replaces CHILDREN, so the loading flag set below
    // outlives the content it belonged to unless it is deleted by hand. Cleared
    // on the way in, not only when a request settles: this path also runs for a
    // hit with no href to fetch, where nothing would ever clear it.
    delete preview.dataset.rookerySearchLoading;
    if (hit === undefined) return;

    // NO EXCERPT UP FRONT. The fetched rendering is the first and only text this
    // pane shows; until it lands there is the indicator below and nothing else.
    //
    // The excerpt used to render synchronously here, on the reasoning that it was
    // already in hand and cost no request. What that bought was a visible reflow
    // on EVERY selection — plain text for a few milliseconds, then the same note
    // again as real content, a different and worse rendering of the thing about to
    // replace it. It also pinned the island's `body` field to being readable
    // prose, which is what stopped that field being compressed into a note's most
    // distinctive terms.
    //
    // `renderKeywords` is the FAILED-FETCH fallback and nothing else: a build
    // opened over `file://`, a note whose page 404s, a hit with no href at all.
    // Those are the cases where there is no rendering coming and the island's own
    // terms are the final answer.
    if (typeof hit.href !== "string" || hit.href === "") {
      renderKeywords(hit);
      return;
    }
    // THE LOADING AFFORDANCE, and it is an attribute rather than an element: one
    // data attribute and one `::after` in the stylesheet keeps it out of the
    // content flow entirely — nothing to append, nothing to remove, and no
    // chance of it surviving a `replaceChildren` as a stray node.
    //
    // Set whenever there is an href, no longer only on a cache MISS. The
    // cache-miss guard existed because the pane already held the excerpt, so
    // flagging a memoised row would flash a spinner over content for one frame
    // every time the reader arrow-keyed back up a list they had been down. With
    // the pane empty the indicator IS the pane's only content, and a memoised
    // href resolves on a microtask — the attribute is set and cleared inside one
    // task, before a paint, so there is nothing left to flash.
    preview.dataset.rookerySearchLoading = "true";
    fetchNote(hit.href).then((box) => {
      // Cleared BEFORE the early return, so a miss stops the indicator too: a
      // 404, a `file://` build, a page that is not a minted note all resolve to
      // `null`, and an indicator left spinning would be promising a rendering
      // that is never coming. Guarded on the generation like the paint below it,
      // so a stale request cannot clear a later selection's indicator.
      if (gen === previewGen) delete preview.dataset.rookerySearchLoading;
      if (gen !== previewGen) return;
      // The fallback, and the ONLY place the keyword row is rendered for a hit
      // that had an href: the fetch is settled and it failed, so there is no
      // richer rendering coming and the island's own terms are the final answer.
      if (box === null) {
        renderKeywords(hit);
        return;
      }
      // The residual, not the raw input: marking the fetched page for the literal
      // "tags:" would highlight an instruction rather than a match. Same rule as
      // both `render`s.
      const terms = fold(splitQuery(input.value.trim()).text)
        .split(" ")
        .filter((t) => t !== "");
      // Cloned, not moved: the cache holds this `<div>` for the rest of the
      // session and `markTermsInNode` edits what it walks.
      const clone = box.cloneNode(true);
      markTermsInNode(clone, terms);
      preview.replaceChildren(clone);
    });
  };

  // Marks exactly one row selected (clamped, no wrap), names it as the input's
  // active descendant, scrolls it into view, and re-renders the preview to match.
  // The first three are `selection`'s, shared with `#search-bar`'s dropdown; the
  // preview is this surface's own, which is why it is passed in.
  //
  // `aria-controls` alongside, because `selection` has just given the list an id
  // and the combobox pattern this input already claims (`role="combobox"`,
  // `aria-expanded`) is incomplete without it. The dropdown wired its own at
  // `wire`; the modal never did.
  const sel = selection(list, input, () => renderPreview());
  input.setAttribute("aria-controls", list.id);
  const select = sel.select;

  const render = () => {
    const q = input.value.trim();
    list.replaceChildren();
    // CLEARED HERE, with the rows it referred to, and NOT left to `select(0)` at
    // the bottom: the no-hits path below returns before reaching it, so
    // `aria-activedescendant` survived pointing at a row that had just been
    // removed from the document. MEASURED — after a query matching nothing, the
    // input still named `…-opt-0` while the list held zero rows. `select(0)` sets
    // it again on every path that has something to select.
    sel.clear();
    // EMPTY QUERY shows the corpus, not nothing: `search(rows, "", limit)`
    // already returns everything at score 0, dated rows newest-first ahead of
    // undated rows (which keep their id order) — see `dateCmp` — telescope's
    // empty-prompt behaviour, deliberately unlike `#search-bar`'s dropdown,
    // which stays shut on an empty query.
    //
    // With a `tags:` expression and no residual text, that becomes the whole
    // FILTERED corpus ranked the same way — the same sentence one level in.
    hits = search(rows, q, limit);
    // The residual, not the raw input: see `wire`'s `render` above. Marking the
    // literal "tags:" in every note is the failure this avoids. And the tag
    // expression's positive atoms alongside, for the chips — this is the surface
    // where they are visible at all.
    const { rpn, text } = splitQuery(q);
    const terms = fold(text).split(" ").filter((t) => t !== "");
    const atoms = positiveAtoms(rpn);
    for (const hit of hits) {
      const row = renderRow(hit, terms, atoms);
      row.addEventListener("pointerenter", () => {
        select([...list.children].indexOf(row));
      });
      list.append(row);
    }
    // NO HITS: the pane has to be emptied HERE, because `select` cannot do it.
    // It returns on `els.length === 0` before reaching its `renderPreview()`
    // call, and `renderPreview` is the only thing that ever clears the pane —
    // so a query matching nothing used to leave the LAST match's preview on
    // screen beside an empty result list. Not fixed inside `select`, which is
    // about which row is highlighted and is also called from `pointerenter`
    // above, where there is by construction a row to select.
    //
    // `previewGen` is bumped for the same reason `renderPreview` bumps it: a
    // `fetchNote` begun for the previous query is still in flight, and its
    // `.then` paints the pane unless the generation has moved on. Without this
    // the stale note reappears over the filler a moment later — the same bug,
    // one keystroke behind.
    if (hits.length === 0) {
      previewGen += 1;
      // The generation bump above already orphans an in-flight request's paint,
      // but its `.then` no longer clears the loading flag once it is orphaned —
      // so this path has to clear it, or the filler sits under a spinner that
      // never stops.
      delete preview.dataset.rookerySearchLoading;
      const empty = document.createElement("p");
      empty.className = "rookery-search-preview-empty";
      empty.textContent = "No match found";
      preview.replaceChildren(empty);
      return;
    }
    select(0);
  };

  input.addEventListener("input", render);

  dialog.addEventListener("keydown", (ev) => {
    if (ev.key === "ArrowDown" || (ev.ctrlKey && ev.key === "n")) {
      ev.preventDefault();
      sel.move(1);
    } else if (ev.key === "ArrowUp" || (ev.ctrlKey && ev.key === "p")) {
      ev.preventDefault();
      sel.move(-1);
    } else if (ev.key === "Enter") {
      ev.preventDefault();
      const hit = hits[sel.index()];
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
  // closing it directly. `clear`, not `select(0)`: the list has not been
  // re-rendered yet, so there is no row 0 to point `aria-activedescendant` at,
  // and the next `open` re-renders and selects for itself.
  dialog.addEventListener("close", () => {
    sel.clear();
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
