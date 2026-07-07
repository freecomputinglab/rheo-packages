/// <reference types="vite/client" />

// rheo-justify: client-side Knuth-Plass justification for HTML.
//
// This IIFE is the browser runtime that ties the Typst-emitted markup
// (lib.typ) together with the measurement (@chenglou/pretext), the optimal
// line-breaking core (kp.ts), the DOM encoder (encode.ts) and the author's
// justification-limits (limits.ts).
//
// FLOW on load, for every `<p class="rheo-kp" data-justify="true">` block:
//   1. Read the pristine text once (stored in a WeakMap so re-runs measure the
//      original, not our NBSP-rewritten output).
//   2. Measure the content-box width and the per-word / space widths with
//      pretext, at the block's resolved font + size.
//   3. Run kp.ts to choose the optimal breaks, honoring the author's
//      justification-limits (word-space elasticity).
//   4. Encode the decisions to a flat string (encode.ts) and write it back as
//      the block's text; `text-align: justify` (index.css) reproduces the KP
//      layout with fully selectable, reflowable text.
//   5. Re-justify on resize (shared, debounced ResizeObserver) and once the
//      web fonts finish loading.
//
// GRACEFUL NO-OP: without `Intl.Segmenter` (a pretext requirement) or when a
// block carries inline markup / no named font, the native browser rendering is
// left untouched. With JS disabled the browser simply renders the plain text.
//
// See issue rheo-packages-x18.

import { prepareWithSegments, type PreparedTextWithSegments } from "@chenglou/pretext";
import { wordsToStream, breakParagraph } from "./kp.ts";
import { encodeJustified } from "./encode.ts";
import { makeConfig, type PartialLimits } from "./limits.ts";

/** The pristine (pre-justification) text of each processed block. */
const pristineText = new WeakMap<HTMLElement, string>();

/** Blocks currently under management by the shared ResizeObserver. */
const managed = new Set<HTMLElement>();

/** Resolve a block's CSS font shorthand from its data attributes. */
function resolveFont(el: HTMLElement): { font: string; family: string } | null {
  const family = el.dataset.font?.trim();
  const size = el.dataset.size?.trim();
  if (!family || !size) return null;
  // pretext caveat: `system-ui` (and other keyword families) are unsafe to
  // measure on some platforms. Require a real, named family.
  if (/\bsystem-ui\b/i.test(family)) return null;
  return { font: `${size} ${family}`, family };
}

/**
 * Split a pretext-prepared paragraph into unbreakable word boxes: consecutive
 * non-whitespace segments are merged into one word (its width summed), and each
 * run of whitespace closes the current word. Returns the words, their measured
 * widths, and the natural space width. Mirrors encode.ts's word model, so KP
 * break-gap indices map 1:1 onto the words.
 */
function extractWords(
  prepared: PreparedTextWithSegments,
): { words: string[]; wordWidths: number[]; spaceWidth: number } {
  const { segments, widths, kinds } = prepared;
  const words: string[] = [];
  const wordWidths: number[] = [];
  const spaceWidths: number[] = [];

  let text = "";
  let width = 0;
  let hasWord = false;

  const flush = () => {
    if (hasWord) {
      words.push(text);
      wordWidths.push(width);
      text = "";
      width = 0;
      hasWord = false;
    }
  };

  for (let i = 0; i < segments.length; i++) {
    const kind = kinds[i];
    if (kind === "space" || kind === "preserved-space" || kind === "tab" || kind === "hard-break") {
      flush();
      if (widths[i] > 0) spaceWidths.push(widths[i]);
    } else {
      // text / glue / zero-width-break / soft-hyphen: glue into the current
      // word. v1 does not break inside a word (no client hyphenation dict).
      text += segments[i];
      width += widths[i];
      hasWord = true;
    }
  }
  flush();

  const spaceWidth = spaceWidths.length > 0 ? spaceWidths[0] : 0;
  return { words, wordWidths, spaceWidth };
}

/** The content-box (inner) width of an element, in px. */
function contentWidth(el: HTMLElement): number {
  const cs = getComputedStyle(el);
  const padL = parseFloat(cs.paddingLeft) || 0;
  const padR = parseFloat(cs.paddingRight) || 0;
  return el.clientWidth - padL - padR;
}

/** Parse the `data-justify-limits` JSON, tolerating a missing/invalid value. */
function parseLimits(el: HTMLElement): PartialLimits | undefined {
  const raw = el.dataset.justifyLimits;
  if (!raw) return undefined;
  try {
    return JSON.parse(raw) as PartialLimits;
  } catch {
    return undefined;
  }
}

/** Justify a single block from its pristine text. Safe to call repeatedly. */
function justifyBlock(el: HTMLElement): void {
  if (el.dataset.justify !== "true") return;
  // v1 is text-only: leave blocks that carry inline markup to the browser.
  if (el.childElementCount > 0) return;

  // Capture the pristine text on first sight; reuse it on every re-run.
  let source = pristineText.get(el);
  if (source === undefined) {
    source = el.textContent ?? "";
    pristineText.set(el, source);
  }
  if (source.trim() === "") return;

  const resolved = resolveFont(el);
  if (!resolved) return;

  const targetWidth = contentWidth(el);
  if (!(targetWidth > 0)) return;

  const prepared = prepareWithSegments(source, resolved.font);
  const { words, wordWidths, spaceWidth } = extractWords(prepared);
  if (words.length === 0) return;

  const stream = wordsToStream(wordWidths, spaceWidth, prepared.discretionaryHyphenWidth);
  const cfg = makeConfig(parseLimits(el), { spaceWidth });
  const result = breakParagraph(stream, targetWidth, cfg);

  // 1 word == 1 segment, so KP's break-gap indices are word-gap indices.
  el.textContent = encodeJustified({ words, breaks: result.breakJoins });

  // Reproduce the KP layout; belt-and-suspenders alongside index.css.
  el.style.textAlign = "justify";
  el.style.hyphens = "none";
  (el.style as CSSStyleDeclaration & { webkitHyphens?: string }).webkitHyphens = "none";
}

/** Re-justify a block, restoring its pristine text first so widths re-measure. */
function rejustify(el: HTMLElement): void {
  const source = pristineText.get(el);
  if (source !== undefined) el.textContent = source;
  justifyBlock(el);
}

let rafId = 0;
const dirty = new Set<HTMLElement>();

/** Shared, rAF-debounced observer that re-justifies blocks on column resize. */
const observer =
  typeof ResizeObserver !== "undefined"
    ? new ResizeObserver((entries) => {
        for (const entry of entries) dirty.add(entry.target as HTMLElement);
        if (rafId) cancelAnimationFrame(rafId);
        rafId = requestAnimationFrame(() => {
          rafId = 0;
          const els = [...dirty];
          dirty.clear();
          for (const el of els) rejustify(el);
        });
      })
    : null;

async function init(): Promise<void> {
  // pretext relies on Intl.Segmenter; without it, leave native rendering.
  if (typeof Intl === "undefined" || typeof Intl.Segmenter === "undefined") return;

  const blocks = Array.from(
    document.querySelectorAll<HTMLElement>("p.rheo-kp"),
  ).filter((el) => !el.closest(".rheo-kp-skip"));
  if (blocks.length === 0) return;

  // Wait for web fonts so canvas measurement matches the rendered text.
  if (document.fonts?.ready) {
    try {
      await document.fonts.ready;
    } catch {
      /* fall through and measure with whatever is available */
    }
  }

  for (const el of blocks) {
    justifyBlock(el);
    if (observer && !managed.has(el)) {
      observer.observe(el);
      managed.add(el);
    }
  }

  // A late-arriving font swap changes metrics; re-justify once it lands.
  document.fonts?.addEventListener?.("loadingdone", () => {
    for (const el of blocks) rejustify(el);
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => void init());
} else {
  void init();
}
