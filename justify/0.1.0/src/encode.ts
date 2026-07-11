// rheo-justify: encode Knuth-Plass break decisions into a flat DOM string.
//
// The trick (from the pretext / Andy Bell technique): once kp.ts has chosen the
// optimal break points, we do NOT position lines ourselves. Instead we rewrite
// the paragraph's text so that the browser's own line breaker, under
// `text-align: justify`, can only break where KP chose — reproducing the KP
// layout while keeping the text fully selectable and reflowable.
//
// The rewrite maps each break opportunity to a specific space character:
//   - CHOSEN break            -> U+0020 SPACE            (breakable, stretches)
//   - REJECTED break          -> U+00A0 NO-BREAK SPACE   (rigid, never breaks)
//   - CHOSEN hyphenation      -> U+00AD SOFT HYPHEN       (may break, shows "-")
//   - REJECTED hyphenation    -> (nothing)
//   - real hyphen in source   -> U+2011 NON-BREAKING HYPHEN (no opportunistic break)
// The last line stays ragged, which is the browser's default (it never
// justifies the final line).
//
// V1 SCOPE: plain text runs only. A block containing inline markup (links,
// emphasis) is out of scope — the caller must restrict v1 to text-only
// paragraphs. Per-text-node encoding that preserves element boundaries is a
// documented follow-up (see issue rheo-packages-t2j, option (b)).
//
// See issue rheo-packages-t2j.

/** U+0020 — a normal space: the browser may break here and it stretches. */
export const SPACE = " ";
/** U+00A0 — a no-break space: rigid, the browser will not break here. */
export const NBSP = " ";
/** U+00AD — a soft hyphen: an invisible break point that shows a hyphen when broken. */
export const SOFT_HYPHEN = "­";
/** U+2011 — a non-breaking hyphen: a visible hyphen the browser will not break at. */
export const NB_HYPHEN = "‑";
/** U+002D — the ASCII hyphen-minus we replace in source text. */
export const SOURCE_HYPHEN = "-";

/** A chosen hyphenation: insert a soft hyphen after `offset` chars of `word`. */
export interface Hyphenation {
  /** Index into the `words` array. */
  word: number;
  /** Number of characters of the word that precede the soft hyphen. */
  offset: number;
}

export interface EncodeInput {
  /**
   * The paragraph's words in order, with inter-word whitespace already
   * normalized so that each adjacent pair is separated by exactly one gap.
   * (This matches @chenglou/pretext's `prepare()` whitespace normalization.)
   */
  words: string[];
  /**
   * Gap indices chosen by KP as line breaks. Gap `i` sits between `words[i]`
   * and `words[i + 1]`. Every gap NOT listed here is held rigid with a no-break
   * space. Accepts anything iterable (e.g. the `breakJoins` array from kp.ts
   * when segments map 1:1 to words).
   */
  breaks: Iterable<number>;
  /** Chosen hyphenation points; rejected candidates are simply omitted. */
  hyphens?: Hyphenation[];
}

/**
 * Insert soft hyphens into a single word at the given character offsets and
 * replace any real hyphen with a non-breaking hyphen. Offsets refer to the
 * original word (the hyphen replacement is 1:1 so it does not shift them).
 */
function encodeWord(word: string, offsets: number[]): string {
  // Replace real hyphens first (length-preserving, so offsets stay valid).
  let out = word.split(SOURCE_HYPHEN).join(NB_HYPHEN);
  if (offsets.length === 0) return out;

  // Insert soft hyphens from the rightmost offset so earlier ones don't shift.
  const sorted = [...offsets].sort((a, b) => b - a);
  for (const offset of sorted) {
    if (offset <= 0 || offset >= out.length) continue; // skip word-edge offsets.
    out = out.slice(0, offset) + SOFT_HYPHEN + out.slice(offset);
  }
  return out;
}

/**
 * Encode KP break decisions into the flat string to place as the block's text
 * content. Combined with `text-align: justify`, the browser reproduces the KP
 * line breaks.
 */
export function encodeJustified(input: EncodeInput): string {
  const { words } = input;
  const breakSet = new Set<number>(input.breaks);

  // Group chosen hyphenations by word.
  const perWord = new Map<number, number[]>();
  for (const h of input.hyphens ?? []) {
    if (h.word < 0 || h.word >= words.length) {
      throw new RangeError(`hyphenation word index ${h.word} out of range`);
    }
    const list = perWord.get(h.word) ?? [];
    list.push(h.offset);
    perWord.set(h.word, list);
  }

  let out = "";
  for (let i = 0; i < words.length; i++) {
    out += encodeWord(words[i], perWord.get(i) ?? []);
    if (i < words.length - 1) {
      // Gap `i` between word i and i+1.
      out += breakSet.has(i) ? SPACE : NBSP;
    }
  }
  return out;
}
