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
// change the other, re-run the fixture. Every exported ranking function now has
// a Typst twin: the one exception used to be `snippet`, and it is gone along
// with the preview excerpt it built.
//
// EMBEDDING. Every bar on the page is found by its `data-rookery-search`
// attribute, whose VALUE is the id of the island it reads. So several bars can
// share one island, or point at different ones, and none of them needs an id of
// its own — ids are assigned here at runtime, because markup that carries a
// hardcoded id cannot be placed twice on a page.

export const fold = (s) => s.toLowerCase().replaceAll("-", " ").replaceAll("_", " ");

// EXTENDED GRAPHEME CLUSTERS, because that is what Typst counts. `str.clusters()`
// there is UAX #29; a spread (`[...s]`) here is UTF-16 CODE POINTS, and the two
// part company on every cluster wider than one code point:
//
//     "e" + "́"        1 cluster   vs 2 code points
//     "❤️"                  1 cluster   vs 2 code points
//     the family ZWJ emoji  1 cluster   vs 7 code points
//
// MEASURED by the generated half of `just parity`: with the spread, 73 of 250
// generated `fuzzy-score` cases disagreed. `hc.length` feeds the length-difference
// bonus and `first` the near-start bonus, and both are GLOBAL terms in the score,
// so one such sequence anywhere in a hay moved every query against it — not only a
// query that touched the sequence. Typst is the reference: a reader perceives `é`
// as one character, and the bonuses are about how much of a perceived string a
// query covered.
//
// A FIXED LOCALE, not `undefined`. Grapheme segmentation is script-driven rather
// than locale-tailored, so `"en"` does not change the answer for any script — but
// pinning it means the fixture under node's default locale and a reader's browser
// in any locale cannot come out differently, which is the whole point of a parity
// test.
//
// SEGMENTING IS 14x THE COST OF A SPREAD, so the hay is memoised and the query is
// not. MEASURED on this machine, 400 rows x 3 scored fields, the work one keystroke
// does: 4.35ms segmented, 0.30ms spread, 0.30ms segmented-and-memoised (1200
// entries). 4.35ms is inside a frame today and outside one on a slower machine or a
// rookery several times this size, and the memo buys all of it back.
//
// THE HAY IS THE RIGHT KEY AND THE QUERY IS NOT. A hay is one of a bounded set —
// the island's rows, folded — so the cache tops out at rows x fields and every
// keystroke after the first is a hit. A query is NEW TEXT on every keystroke, so
// caching it would grow without bound for no hit at all; `clustersCached` is
// therefore used for `hay` only, and `clusters` directly for everything else.
const SEGMENTER = new Intl.Segmenter("en", { granularity: "grapheme" });
export const clusters = (s) => [...SEGMENTER.segment(s)].map((g) => g.segment);

const CLUSTER_CACHE = new Map();
const clustersCached = (s) => {
  let v = CLUSTER_CACHE.get(s);
  if (v === undefined) {
    v = clusters(s);
    CLUSTER_CACHE.set(s, v);
  }
  return v;
};

// ---- tags: query — the port of `parse-tag-query` and its evaluator ---------
//
// The reader's `tags:` axis, for the live bar. `src/lib.typ`'s section comment
// above `_prec` carries the full rules — the syntax, the FROZEN escape set
// `( ) | & ! \`, why shunting-yard rather than recursive descent, and why
// parsing never fails. The `<tag-parity>` fixture in `test/parity.typ` pins
// these three functions to their Typst twins over 21 cases, diffing the RPN
// itself as data, so change neither copy alone.

// `_prec`'s twin, plus the associativity table it does not need: Typst spells
// `!`'s right-associativity as a literal `c != "!"` in the pop test, which
// reads as an accident rather than a rule, so it is named here.
const OPS = { "!": 3, "&": 2, "|": 1 };
const RIGHT = { "!": true };

// Port of `parse-tag-query` in src/lib.typ. Shunting-yard to RPN, iterative
// (no recursion), tokens as 2-slot objects. NEVER throws: every malformed
// form repairs, because a live search box types every prefix of a valid
// query on the way to it.
//
// `clusters(src)`, matching Typst's `.clusters()` — never index the string, and
// never spread it either: a spread is code points, which is a different count and
// was the drift `clusters` above exists to end. `c.trim() === ""` mirrors Typst's
// `c.trim() == ""` rather than a `/\s/` test, so each side's whitespace
// definition stays tied to its own runtime's trim instead of to a regex
// dialect. Typst guards the residual slice because `array.join()` on an EMPTY
// array is `none` there; `[].join("")` is `""` here, so the guard is
// unnecessary and the two still agree on a query ending in a bare space.
//
// The `i++` in the escape branch consumes the escaped cluster, which is why
// this stays a `for` and not a `for...of`.
export const parseTagQuery = (src) => {
  const cs = clusters(src);
  const out = [];
  const stack = [];
  const repaired = [];
  let atom = "";
  let residual = "";
  const flushAtom = () => {
    if (atom === "") return;
    out.push({ t: "atom", v: fold(atom) });
    atom = "";
  };
  const pushOp = (op) => {
    while (stack.length) {
      const top = stack[stack.length - 1];
      if (top === "(") break;
      const higher = OPS[top] > OPS[op] || (OPS[top] === OPS[op] && !RIGHT[op]);
      if (!higher) break;
      out.push({ t: "op", v: stack.pop() });
    }
    stack.push(op);
  };
  for (let i = 0; i < cs.length; i++) {
    const c = cs[i];
    if (c === "\\") {
      if (i + 1 < cs.length) { atom += cs[i + 1]; i++; }
      else repaired.push("trailing-backslash");
      continue;
    }
    if (c.trim() === "") { residual = cs.slice(i + 1).join(""); break; }
    if (c === "(") { flushAtom(); stack.push("("); continue; }
    if (c === ")") {
      flushAtom();
      let found = false;
      while (stack.length) {
        const top = stack.pop();
        if (top === "(") { found = true; break; }
        out.push({ t: "op", v: top });
      }
      if (!found) repaired.push("unmatched-close");
      continue;
    }
    if (c in OPS) { flushAtom(); pushOp(c); continue; }
    atom += c;
  }
  flushAtom();
  while (stack.length) {
    const top = stack.pop();
    if (top === "(") repaired.push("unclosed-open");
    else out.push({ t: "op", v: top });
  }
  return { rpn: out, residual: residual.trim(), repaired };
};

// Port of `eval-tag-query`. `tags` must already be folded. An empty RPN is
// NO FILTER (true), and a binary op with too few operands is skipped — that
// is what makes a half-typed `tags:a&` behave as `tags:a`.
export const evalTagQuery = (rpn, tags) => {
  if (rpn.length === 0) return true;
  const st = [];
  for (const tok of rpn) {
    if (tok.t === "atom") {
      st.push(tags.some((tg) => tg === tok.v || tg.startsWith(tok.v)));
      continue;
    }
    if (tok.v === "!") {
      if (st.length === 0) continue;
      st.push(!st.pop());
      continue;
    }
    if (st.length < 2) continue;
    const b = st.pop();
    const a = st.pop();
    st.push(tok.v === "&" ? a && b : a || b);
  }
  return st.length === 0 ? true : st[st.length - 1];
};

// The atoms whose PRESENCE on a note is evidence for the query — i.e. every
// atom not negated. Walked over the RPN with the same small stack
// `evalTagQuery` uses, so a `!` consumes the atom below it. Nothing here
// reproduces the boolean result; a chip is marked when it is evidence, not
// when it is decisive.
//
// Per stack slot the SET of atoms that produced it: `!` replaces that set with
// the empty set (nothing on the row is evidence for an absence — there is no
// element to mark), `&`/`|` union the two below, and the surviving
// top-of-stack set is the answer. So `!draft` yields nothing, `a|b` yields
// both (a note carrying both is satisfied twice and both chips are evidence),
// and `!(draft|todo)&note` yields only `note`.
//
// Lenient exactly as `evalTagQuery` is — a missing operand is skipped, never
// thrown on, because a live search box types every prefix of a valid query on
// the way to it.
//
// NO PARITY REQUIREMENT: there is no Typst counterpart, and none is wanted.
// `#search-ideas` returns data; which chip to highlight is presentation, and
// the Typst side renders no chips.
//
// PRESENTATION ONLY, and subordinate: if this and `evalTagQuery` ever disagree
// about a note, `evalTagQuery` is right by definition — it decides which rows
// exist, this only decides what is marked on one.
export const positiveAtoms = (rpn) => {
  const st = [];
  for (const tok of rpn) {
    if (tok.t === "atom") {
      st.push(new Set([tok.v]));
      continue;
    }
    if (tok.v === "!") {
      if (st.length === 0) continue;
      st.pop();
      st.push(new Set());
      continue;
    }
    if (st.length < 2) continue;
    const b = st.pop();
    const a = st.pop();
    st.push(new Set([...a, ...b]));
  }
  return st.length === 0 ? [] : [...st[st.length - 1]];
};

// Port of `split-query`. Only a LEADING `tags:` is recognised, so a note
// body containing "tags:" can never be mistaken for a filter.
export const splitQuery = (q) => {
  const s = q.replace(/^\s+/, "");
  if (!s.toLowerCase().startsWith("tags:")) return { rpn: [], text: q, repaired: [] };
  const { rpn, residual, repaired } = parseTagQuery(s.slice(5));
  return { rpn, text: residual, repaired };
};

// Port of `fuzzy-score`. `null` (Typst `none`) when the query's characters do
// not all appear in `hay` in order; otherwise an integer, higher better.
export const score = (hay, query) => {
  const h = fold(hay);
  const q = fold(query);
  if (q === "") return 0;
  // Cached on the folded HAY, fresh on the query — see `clustersCached`.
  const hc = clustersCached(h);
  const qc = clusters(q);
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

// Port of `body-score`: an AND match over a note's body, which here is always
// the COMPRESSED TERM STRING `#search-index` ships — that note's most
// distinctive terms, space-joined in weight order. `null` unless every
// whitespace-split query term is a substring of some term in that list, so a
// prefix query still lands (`justif` finds `justification`).
//
// The score is RANK, since position is the weight: per query term,
// `max(1, 10 - floor(rank / 4))` for the first term containing it, plus 3 when
// the query term IS one of the terms exactly. See `body-score` in `src/lib.typ`
// for the measurements and for every choice below; this is the port, not the
// record.
//
// TWO THINGS THAT WERE HERE ARE GONE. The +6 contiguous-phrase bonus, because no
// phrase survives compression. And all the cluster counting — the old earliness
// term had to re-measure `indexOf`'s UTF-16 offset through a spread to agree with
// Typst's `.clusters()`; a rank is a term INDEX, which both languages count
// identically for nothing.
//
// `toLowerCase()`, NOT `fold()`: folding turns `-`/`_` into spaces, which would
// split `rheo-context` into two query terms and lose the exact-match bonus.
// Deliberate, and mirrored in `body-score` — the compression preserves `.` and
// `-` inside a term precisely so a reader can type them.
export const bodyScore = (body, query) => {
  const h = body.toLowerCase();
  const q = query.toLowerCase();
  if (q.trim() === "") return null;
  const terms = q.split(" ").filter((t) => t !== "");
  if (terms.length === 0) return null;
  const kept = h.split(" ").filter((t) => t !== "");
  let points = 0;
  for (const term of terms) {
    let rank = null;
    for (let i = 0; i < kept.length; i++) {
      if (kept[i].includes(term)) {
        rank = i;
        break;
      }
    }
    if (rank === null) return null;
    points += Math.max(1, 10 - Math.floor(rank / 4));
    if (kept.includes(term)) points += 3;
  }
  return points;
};

// Same rule as `search-ideas`: match on the id AND the title first (tier 0),
// take the better of the two; failing that, match on the body (tier 1) via
// `bodyScore`. Every tier-0 row ranks above every tier-1 row; within a tier,
// best score first, ties broken by id so the order is stable.
//
// `row.body` MISSING IS THE WHOLE IMPLEMENTATION OF `body-search: false`, not
// merely tolerated: `#search-index(body-search: false)` omits the field, this
// reads it as `""`, and `bodyScore("", q)` is `null` for every non-empty query,
// so no row can reach tier 1 and the browser searches ids and titles only. Keep
// the `?? ""` and keep `bodyScore` returning `null` on an absent term match —
// between them they are what makes the switch need no JavaScript counterpart.
// It also covers an older island that never carried bodies at all.
// A LEADING `tags:` EXPRESSION IS EXTRACTED, NOT SCORED. The query is split once
// before the loop — the tag expression becomes a PREDICATE on each row, and the
// residual text is what the two tiers rank. `_rank`'s Typst twin does exactly
// this, in the same place and the same order, which is what `tier parity` pins.
//
// The predicate runs FIRST, ahead of every scorer, so a note the tags exclude is
// never scored at all. And it stays a predicate: no third tier, no score bonus
// for a tag hit, no perturbation of the tier/sort/limit block below. A tag says
// WHICH notes are in the corpus; the residual text says how they rank.
//
// `row.tags ?? []` for the same reason `row.body ?? ""` is there: an older
// island, or a row for a note with no tags, simply has no key — `#search-index`
// omits it rather than shipping `[]` per row.
//
// With a tag expression and NO residual text (`tags:draft` on its own), `q` is
// `""`, `score(hay, "")` is 0 for every survivor, and they all land in the name
// tier at score 0. THAT tie no longer breaks by id alone: for `q === ""` (a bare
// `""` query too) `dateCmp` below breaks it by `row.updated` first, newest
// first, undated last — the JS twin of `_rank`'s date branch in `src/lib.typ`,
// which mirrors `_sort-ids` in `rookery/0.3.0/src/pure.typ`. A REAL query
// (`q !== ""`) is untouched: ties there still break by id alone, exactly as
// before.
//
// `row.updated` is ALREADY the zero-padded `"[year][month][day]"` stamp
// `#search-index` ships (see its comment in `src/lib.typ`) — never a raw date
// object — so lexicographic string comparison is numeric-order comparison,
// with no parsing needed here.
const dateCmp = (a, b) => {
  if (a.updated == null && b.updated == null) return 0;
  if (a.updated == null) return 1;
  if (b.updated == null) return -1;
  return a.updated < b.updated ? 1 : a.updated > b.updated ? -1 : 0;
};

export const search = (rows, query, limit) => {
  const { rpn, text } = splitQuery(query);
  const q = text;
  const out = [];
  for (const row of rows) {
    if (rpn.length > 0 && !evalTagQuery(rpn, (row.tags ?? []).map(fold))) continue;
    const sName = score(row.name, q);
    const sText = row.text === "" ? null : score(row.text, q);
    const nameScore =
      sName === null ? sText : sText === null ? sName : Math.max(sName, sText);
    if (nameScore !== null) {
      out.push({ ...row, score: nameScore, kind: "name" });
      continue;
    }
    const bScore = bodyScore(row.body ?? "", q);
    if (bScore !== null) out.push({ ...row, score: bScore, kind: "body" });
  }
  const tier = (hit) => (hit.kind === "name" ? 0 : 1);
  out.sort(
    (a, b) =>
      tier(a) - tier(b) ||
      b.score - a.score ||
      (q === "" ? dateCmp(a, b) : 0) ||
      (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
  return limit == null ? out : out.slice(0, limit);
};

// `snippet` AND ITS CLUSTER-SPACE HELPER `findClusterMatches` WERE HERE, and
// both are gone. They built the preview excerpt — a window of `radius` clusters
// either side of the earliest query match in a note's `body`, "…"-truncated,
// with cluster-accurate mark ranges. Nothing excerpts that field any more: the
// island carries a note's most distinctive TERMS rather than a prefix of its
// prose, so there is no sentence to centre a window on, and the pane's fallback
// is the keyword row `renderKeywords` builds in `wireModal`. Cluster precision
// went with them — it existed because a window's OFFSETS had to agree with
// Typst's `.clusters()`, and nothing left in this file needs a CLUSTER offset.

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
const renderRow = (hit, terms, atoms = []) => {
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

// ---- The active option, shared by the bar and the modal --------------------
//
// ONE implementation for both surfaces, because it is one job: mark exactly one
// row of a `role="listbox"` as the active option, tell the `role="combobox"`
// input which one that is, and keep it in view. The two differ only in what
// FOLLOWS a selection — the modal repaints its preview pane, the bar does
// nothing — so that is the parameter.
//
// It was the modal's alone (`wireModal`'s `select`) while the bar had no keyboard
// navigation at all: the bar announced the full combobox pattern
// (`role="combobox"`, `aria-autocomplete="list"`, `aria-expanded`,
// `aria-controls`) over rows carrying `role="option"`, and then answered no arrow
// key, set `aria-selected` on nothing, and never named an active descendant. A
// reader who tabbed in and typed could only reach a result by tabbing through
// every one of them, with nothing to say which was current.
//
// `-1` MEANS NO ACTIVE OPTION, and it is a real state rather than a sentinel for
// zero. The modal opens on a selected first row, because its preview pane needs
// something to show and an empty pane beside a full list reads as broken. The bar
// must NOT: its dropdown appears under a field the reader is still typing in, and
// pre-highlighting a row there would claim Enter goes somewhere before they have
// looked. So the bar clears to `-1` on every render and the first ArrowDown lands
// on row 0.
//
// CLAMPED, NEVER WRAPPED, at both ends: arrowing past the last row keeps the last
// row rather than jumping to the first. A wrap in a list whose length changes on
// every keystroke loses the reader's place. From `-1`, ArrowUp clamps to row 0
// too — the first press activates the list either way, which is more predictable
// than "up from nothing means the end".
//
// `aria-activedescendant` is on the INPUT, which is where the combobox pattern
// puts it and the only place it can be: focus never leaves the field on either
// surface, so a screen reader learns the current option from this attribute or
// not at all. That needs per-row ids, which cannot live in the markup — a bar is
// placeable more than once on a page — so they are assigned here from the list's
// own id, itself assigned at runtime for the same reason.
let listSeq = 0;
const selection = (list, input, onSelect = null) => {
  if (list.id === "") list.id = `rookery-search-list-${listSeq++}`;
  let selected = -1;

  const rows = () => list.querySelectorAll(".rookery-search-row");

  // Selecting nothing: the attribute is REMOVED rather than set empty, because an
  // empty `aria-activedescendant` is a reference to an element with no id rather
  // than the absence of one.
  const clear = () => {
    selected = -1;
    input.removeAttribute("aria-activedescendant");
    for (const el of rows()) {
      el.setAttribute("aria-selected", "false");
      el.removeAttribute("data-rookery-search-selected");
    }
  };

  const select = (i) => {
    const els = rows();
    if (els.length === 0) {
      clear();
      return;
    }
    selected = Math.max(0, Math.min(i, els.length - 1));
    for (const [idx, el] of els.entries()) {
      el.id = `${list.id}-opt-${idx}`;
      if (idx === selected) {
        el.setAttribute("aria-selected", "true");
        el.setAttribute("data-rookery-search-selected", "true");
      } else {
        el.setAttribute("aria-selected", "false");
        el.removeAttribute("data-rookery-search-selected");
      }
    }
    input.setAttribute("aria-activedescendant", els[selected].id);
    els[selected].scrollIntoView({ block: "nearest" });
    if (onSelect !== null) onSelect();
  };

  return {
    select,
    clear,
    // `selected + d` through `select`, so the clamp is in one place.
    move: (d) => select(selected + d),
    index: () => selected,
    current: () => rows()[selected] ?? null,
  };
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

// `renderMarked` WAS HERE, and it is gone with the excerpt: it was the only
// mark-inserter taking CLUSTER offsets, because `snippet` was the only thing
// producing them, and it had exactly one caller (the excerpt's `<p>`).
// `appendMarked` below is the surviving one — same `<mark class="rookery-search-
// mark">`, UTF-16 offsets — and it has three callers: a row's title, a row's id,
// and every text node of a fetched note. Do not reintroduce a second one.

// How many chips the keyword row shows. 12, per the row's own comment in
// `wireModal`: the compressed field can run to dozens of terms and a 48-term row
// is a wall of boxes rather than a preview. Not exposed as a knob, exactly as
// the excerpt radius it replaces was not — it is an implementation detail of the
// modal rather than a public contract the way `#search-index`'s `body-terms` is.
const KEYWORD_LIMIT = 12;

// Every occurrence of every `terms` entry in `text`, folded and
// case-insensitive, merged where they overlap. UTF-16 string offsets, and
// nothing in this file asks for any other kind now that the excerpt's
// cluster-space window is gone: neither a title/id row, nor a keyword chip, nor
// a fetched note's individual text nodes are ever diffed against a Typst
// counterpart, so there is no cross-language parity reason to pay for cluster
// precision here. `fold` is length-preserving (each folded character replaces
// exactly one), so an offset found in the FOLDED copy slices correctly out of
// `text` itself.
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
// string — `root` is author-written, Typst-rendered content lifted out of the
// note's own minted page, so there is real markup to preserve: a link's
// `href`, a code span's highlighting, and so on. Case-insensitive and
// `-`/`_`-folding, the same `fold()` every other match here uses.
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

// ---- The preview pane's rich content: the note's own minted page ----------
//
// `#search-modal` emits the JSON island and nothing else, so the pane's rich
// rendering is FETCHED: the selected note's minted page (`ideas/<slug>.html`,
// which rookery's `.marrow.typ` already emits) is requested the first time that
// row is selected. See `search-modal`'s doc comment in `src/lib.typ` for the
// measurement behind that: rendering every note's body into every page cost
// `notes × pages` Typst renders — ~3,900 on a 57-note site, 14.6s against a
// 2.65s baseline — and the cost was per CALL, so truncating the bodies did not
// touch it. A page rheo already emits costs the build nothing at all.
//
// Keyed by href and holding the PROMISE, not the result: two quick selections
// of one row must share a single request, and a MISS has to be remembered too
// (as a resolved `null`), so a note whose page 404s is not re-fetched on every
// arrow key. Session-lived — a `Map` in module scope, gone on navigation.
const previewCache = new Map();

// The note itself, lifted out of its minted page: every element between the
// page's heading and its `<footer class="idea-footer">` — body, footnotes,
// references. Not the heading, because the selected result row above the pane
// already carries the title and id; not the footer, because Context/Backlinks
// are navigation for that page rather than content of the note. `null` when the
// document holds no `h1.idea` (not a minted page) or the range is empty.
//
// THE RANGE STARTS AFTER `.idea-head`, NOT AFTER THE `<h1>`, and the two are
// different elements. rookery 0.3.0 wraps a minted page's permalink tab and its
// `<h1>` in one `<div class="idea-head">` (so the stylesheet's
// `.idea-tab + h*.idea` rule always matches — Typst's HTML export otherwise
// groups the leading inline run under a `<p>` unpredictably). Inside that
// wrapper the `<h1>` is the LAST child, so walking ITS siblings finds nothing
// and every preview collapsed to the plain-text excerpt. MEASURED against
// `rookery.ohrg.org/build/html/ideas/*.html`. Falling back to the `<h1>` itself
// keeps a page minted by rookery 0.2.0, where the heading really is a top-level
// sibling of the body, working unchanged.
//
// Returned inside `<div class="idea-window idea-window-plain">` wrapping a
// `<div class="idea-window-body">`, wearing the h1's own `style`. Every part of
// that is load-bearing. The nesting and the class names are EXACTLY what
// rookery's `#idea-body` produces, which is what this pane used to be given, so
// the stylesheet needs no new selectors and no second code path — including the
// `.idea-window-body > :first-child` margin rule, which counts on the extra
// level. `.idea-window-plain` is rookery's own modifier for "not a box": it
// strips the accent rule and hover tint a real `#window` draws, which a preview
// must not draw inside the pane's own frame. And the style attribute carries
// `--idea-link-color` and the rest of the per-note theme custom properties,
// which on a minted page live on its heading container (there being no
// `.idea-box` around it) — take the siblings and leave that behind and the
// preview renders in rookery's default colours rather than the project's own.
// Under rookery 0.3.0 that container is `.idea-head`; under 0.2.0 it was the
// `<h1>` itself, so both are consulted, nearest first.
//
// Relative `href`/`src` values are resolved against the FETCHED page's URL, not
// left as written. A note's page sits in `ideas/`, the modal can be open on a
// vertebra at any depth, and a `../style.css` or `../index.html#loc-3` written
// for the first resolves somewhere else entirely in the second. Fragment-only
// links are left alone: they address content that travelled here too (a
// footnote marker and its footnote are both inside this range).
//
// `<script>` elements are dropped. A minted page's own scripts sit outside this
// range, so this guards against an author writing `html.elem("script", ..)`
// inside a note body rather than against anything routine — but a search
// preview should never run code merely to be looked at.
const extractNote = (doc, pageUrl) => {
  const h1 = doc.querySelector("h1.idea");
  if (h1 === null) return null;
  const head = h1.closest(".idea-head") ?? h1;
  const box = document.createElement("div");
  box.className = "idea-window idea-window-plain";
  const style = head.getAttribute("style") ?? h1.getAttribute("style");
  if (style !== null) box.setAttribute("style", style);
  const inner = document.createElement("div");
  inner.className = "idea-window-body";
  box.append(inner);
  for (let el = head.nextElementSibling; el !== null; el = el.nextElementSibling) {
    if (el.matches("footer.idea-footer")) break;
    inner.append(document.importNode(el, true));
  }
  if (inner.childNodes.length === 0) return null;
  for (const script of box.querySelectorAll("script")) script.remove();
  for (const el of box.querySelectorAll("[href], [src]")) {
    for (const attr of ["href", "src"]) {
      const raw = el.getAttribute(attr);
      if (raw === null || raw === "" || raw.startsWith("#")) continue;
      try {
        el.setAttribute(attr, new URL(raw, pageUrl).href);
      } catch {
        // Not a resolvable URL — leave the value exactly as the author wrote
        // it rather than guessing at a rewrite.
      }
    }
  }
  return box;
};

// One fetch-and-extract per href, memoised. Resolves to `extractNote`'s `<div>`
// or to `null`, and NEVER rejects: no server (a build opened over `file://`), a
// 404, a page that is not a minted note — all of them are a `null`, because the
// caller's answer to "no rich content" is the keyword row it renders instead,
// not an error to report.
const fetchNote = (href) => {
  if (previewCache.has(href)) return previewCache.get(href);
  const pending = fetch(href)
    .then((res) => (res.ok ? res.text() : null))
    .then((html) =>
      html === null
        ? null
        : extractNote(
            new DOMParser().parseFromString(html, "text/html"),
            new URL(href, document.baseURI),
          ),
    )
    .catch(() => null);
  previewCache.set(href, pending);
  return pending;
};

const wireModal = (dialog, rows) => {
  const input = dialog.querySelector(".rookery-search-input");
  const list = dialog.querySelector(".rookery-search-list");
  const preview = dialog.querySelector(".rookery-search-preview");
  if (input === null || list === null || preview === null) return null;
  // 30, not `wire`'s 8, and deliberately so: a full-height overlay pane has room
  // a dropdown under an input does not, which is why `#search-modal`'s own
  // default is 30 (`src/lib.typ:416`) where `#search-bar`'s is 8. Do not tidy
  // the two into agreement.
  const limit = Number(dialog.dataset.rookerySearchLimit || "30");

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
