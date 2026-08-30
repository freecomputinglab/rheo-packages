// The `tags:` query language, ported from `src/tagquery.typ`: shunting-yard to
// RPN, an evaluator, and the atom extractor the UI marks pills with.
//
// Every rule here has a Typst twin and `test/parity.mjs` pins the two together
// case for case.

import { clusters, fold } from "./text.js";

// `_prec`'s twin, plus the associativity table it does not need: Typst spells
// `!`'s right-associativity as a literal `c != "!"` in the pop test, which
// reads as an accident rather than a rule, so it is named here.
export const OPS = { "!": 3, "&": 2, "|": 1 };
export const RIGHT = { "!": true };
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
