// Text normalisation shared by every matcher: case and punctuation folding,
// grapheme clustering, and the cache in front of it.

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
export const clustersCached = (s) => {
  let v = CLUSTER_CACHE.get(s);
  if (v === undefined) {
    v = clusters(s);
    CLUSTER_CACHE.set(s, v);
  }
  return v;
};
