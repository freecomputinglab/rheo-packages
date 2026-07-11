// Ambient types for Hypher (the Knuth-Liang hyphenation engine) and its
// language pattern packages, neither of which ships TypeScript declarations.

declare module "hypher" {
  /** A minimal view of the Hypher engine: we only ever split words. */
  export default class Hypher {
    constructor(language: unknown);
    hyphenate(word: string): string[];
  }
}

declare module "hyphenation.en-us" {
  const patterns: unknown;
  export default patterns;
}
