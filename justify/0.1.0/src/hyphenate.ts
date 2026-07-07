// rheo-justify: turn a word into the soft-hyphen offsets a client hyphenator
// permits. This is the pure, DOM-free core (mirrors the split between kp.ts and
// lib.ts): given a hyphenation dictionary it decides *where* a word may break,
// leaving the measurement and DOM work to lib.ts.
//
// Client-side hyphenation lets the Knuth-Plass optimizer break long words at
// syllable boundaries, so each line packs closer to its full width — fewer
// lines, tighter spacing. v1 honors the standard Typst `text.hyphenate` knob and
// covers English only (see lib.ts for the language gate).

/** A hyphenation dictionary that splits a word into its syllable pieces. */
export interface Hyphenator {
  /** Split `word` into pieces at permitted hyphenation points (e.g. Hypher). */
  hyphenate(word: string): string[];
}

/**
 * Character offsets within `word` at which a soft hyphen may be inserted, in
 * ascending order. Empty when the word must stay whole.
 *
 * Words that already contain a real hyphen are left untouched: encode.ts turns
 * their hyphen into a non-breaking hyphen, and layering a discretionary break
 * on top would risk a double hyphen. Word-edge offsets are never returned.
 */
export function wordHyphenPoints(word: string, dict: Hyphenator): number[] {
  if (word.includes("-")) return [];
  const parts = dict.hyphenate(word);
  if (parts.length < 2) return [];

  const offsets: number[] = [];
  let acc = 0;
  for (let i = 0; i < parts.length - 1; i++) {
    acc += parts[i].length;
    if (acc > 0 && acc < word.length) offsets.push(acc);
  }
  return offsets;
}
