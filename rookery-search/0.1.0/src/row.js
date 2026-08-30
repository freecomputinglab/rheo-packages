// One result row: the note's title, its tag pills, and the keyword row under it.

import { fold } from "./text.js";
import { KEYWORD_LIMIT, appendMarked, matchRanges } from "./marks.js";

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
//
// A TAGGED HIT ALSO GETS A SECOND LINE of tag pills, and it is emitted HERE —
// in the one shared row builder — rather than in `wireModal` alone. The
// dropdown gets the same DOM and HIDES it in CSS
// (`.rookery-search-tags { display: none }`, shown again by
// `.rookery-search-list .rookery-search-tags`). That is the whole modal-only
// mechanism: no `showTags` parameter, no branch on which surface called, no
// second row builder — the sharing above exists precisely to stop the two
// surfaces drifting into building rows two ways, and a visibility rule is
// something CSS can express without breaking it.
//
// The tags are why a `tags:` query is legible at all: an atom matches a tag by
// PREFIX (`evalTagQuery`'s `tg.startsWith(tok.v)` above, so `tags:note` also
// matches `notebook`), and a row that shows its own tags explains its own
// presence in the list instead of looking like a mystery hit.
//
// `atoms` is `positiveAtoms(rpn)` — passed in rather than re-parsed here,
// because both callers already hold the split query. It is the THIRD argument
// the tag pills left room for, and it is only ever the positive atoms: a
// negation marks nothing (see `positiveAtoms`), and the residual TEXT `terms`
// never mark a chip, because the text query does not search tags and marking
// one would claim it does.
export const renderRow = (hit, terms, atoms = []) => {
  const a = document.createElement("a");
  a.className = "rookery-search-row";
  a.setAttribute("role", "option");
  a.href = hit.href;
  const title = document.createElement("span");
  title.className = "rookery-search-title";
  // NO `|| hit.name` FALLBACK, and do not restore one as defensive: `text` is
  // rookery's derived `label` as of 0.6.0 and is never empty, so a fallback would
  // be dead code that also hid a real bug if the island ever shipped `""`.
  const titleText = hit.text;
  appendMarked(title, titleText, matchRanges(titleText, terms));
  const id = document.createElement("span");
  id.className = "rookery-search-id";
  const idText = `[${hit.id}]`;
  appendMarked(id, idText, matchRanges(idText, terms));
  // A `<wbr>` BETWEEN THE TWO SPANS, and it is load-bearing rather than
  // cosmetic. `.rookery-search-id` is `white-space: nowrap`, and appending the
  // spans adjacently gives the line breaker no opportunity between them — so
  // it treats the title's last word plus the whole `[idea:<slug>]` id as one
  // unbreakable run. A bracketed slug is long, that run never fits, and the
  // breaker falls back to the last opportunity it does have: the space before
  // the title's final word, which then drops onto line two under the id.
  //
  // MEASURED in headless Chromium at 1280px, before the fix: the row `Amanda
  // Holmes and Adrian Johnston` broke after "Adrian" at every pane width, in
  // both the dropdown and the modal. `<wbr>` adds no advance width, so the
  // id's x position is unchanged (196.1px either way) and the gap still comes
  // from `.rookery-search-id`'s own `margin-left: 0.4em`.
  //
  // REJECTED alternatives, both measured: a space text node fixes it but
  // widens the gap by a word space; `.rookery-search-title { display: block }`
  // fixes it but forces the id onto its own line in EVERY row.
  a.append(title, document.createElement("wbr"), id);
  // `hit.tags ?? []` for the same reason `search` reads it that way: a note
  // with no tags, or a row from an older island, simply has no key —
  // `#search-index` omits the field rather than shipping `[]` per row.
  //
  // OMITTED ENTIRELY for an untagged note, never emitted empty. The modal's
  // list has a fixed max-height, so a blank second line on every untagged row
  // would cut the number of visible results for nothing; an untagged row stays
  // one line tall.
  //
  // `<span>`, never `<div>`/`<ul>`/`<li>`. This package's markup is phrasing
  // content only throughout (see `#search-bar`'s comment in `src/lib.typ`)
  // because a bar has to be placeable mid-sentence; a `display: flex` span is
  // how the second line is made.
  //
  // Each chip carries rookery's own `idea-tag-<tag>` class alongside this
  // package's, mirroring the classes rookery emits on a note's heading and box,
  // so a project that already styles one of its tags gets the modal for free
  // with no new selectors. KNOWN HAZARD, pre-existing rather than introduced
  // here: `#idea` validates tags nowhere, so a tag containing a space already
  // emits a broken two-class `idea-tag-my tag` in rookery itself. Not
  // sanitised here — that would silently disagree with rookery's own output.
  //
  // A CHIP THAT IS EVIDENCE FOR THE QUERY IS MARKED, and only the PREFIX an
  // atom actually matched — `notebook` under `tags:note` shows `note` marked
  // and `book` plain, which is the whole point: the mark is what explains a
  // prefix match. The LONGEST matching atom wins, so `tags:note|noteb` marks
  // `noteb` rather than stopping at whichever atom came first in the RPN.
  //
  // `fold` is length-preserving (each folded character replaces exactly one —
  // see `matchRanges`), so an atom's length measured against the folded copy
  // slices correctly out of the chip's own text. That is what makes marking a
  // prefix safe with no cluster arithmetic.
  //
  // A chip that did NOT contribute gets no mark at all: no `atoms` entry is its
  // prefix, `ranges` is empty, and `appendMarked` degrades to a single text
  // node. Same `<mark class="rookery-search-mark">` as the title, the id, the
  // keyword chips and the fetched page, via the file's one mark-inserting pair.
  // `createElement`/`textContent` throughout, never `innerHTML` — a tag comes
  // out of the author's own notes and must never be able to inject markup.
  const tags = hit.tags ?? [];
  if (tags.length > 0) {
    const tagBox = document.createElement("span");
    tagBox.className = "rookery-search-tags";
    for (const t of tags) {
      const chip = document.createElement("span");
      chip.className = `rookery-search-tag idea-tag-${t}`;
      const folded = fold(t);
      let len = 0;
      for (const atom of atoms) {
        if (atom.length > len && folded.startsWith(atom)) len = atom.length;
      }
      appendMarked(chip, t, len === 0 ? [] : [{ start: 0, end: len }]);
      tagBox.append(chip);
    }
    a.append(tagBox);
  }
  return a;
};
