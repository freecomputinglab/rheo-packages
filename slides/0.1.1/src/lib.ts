/// <reference types="vite/client" />

import Reveal from 'reveal.js';
import revealCss from 'reveal.js/dist/reveal.css?raw';

const themes = import.meta.glob('../node_modules/reveal.js/dist/theme/*.css', {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>;

const themeMap: Record<string, string> = {};
for (const [path, css] of Object.entries(themes)) {
  const name = path.split('/').pop()!.replace(/\.css$/, '');
  themeMap[name] = css;
}

declare global {
  var RheoRehydrate:
    | {
        only?: (parent: Element, selector: string, make: () => Element) => Element;
      }
    | undefined;
  var __rheoRehydrate: Array<() => void> | undefined;
}

// `@rheo/rehydrate`'s `only`, READ AT CALL TIME. Script execution order between
// two packages is whatever order a consuming project imported them in, which
// neither package can see — so the global is looked up when this runs rather
// than when the module is evaluated. The fallback is the same three lines the
// helper wraps, so a page that never received it still gets exactly one of each
// element instead of a fresh copy per pass.
const only = (parent: Element, selector: string, make: () => Element): Element => {
  const helper = globalThis.RheoRehydrate?.only;
  if (helper) return helper(parent, selector, make);
  parent.querySelectorAll(selector).forEach((node) => node.remove());
  const el = make();
  parent.append(el);
  return el;
};

// This package's own stylesheet, identified by a class of its own. A bare
// `style` selector would match — and therefore delete — every other stylesheet
// in `<head>`.
const STYLE_SELECTOR = 'style.rheo-slides-theme';

function applyStyles() {
  const reveal = document.querySelector('.reveal') as HTMLElement | null;
  const themeName = reveal?.dataset.theme ?? 'black';
  const themeCss = themeMap[themeName] ?? themeMap.black;
  only(document.head, STYLE_SELECTOR, () => {
    const style = document.createElement('style');
    style.className = 'rheo-slides-theme';
    style.textContent = revealCss + themeCss;
    return style;
  });
}

// The handler the previous pass registered with Reveal. `Reveal.off` matches on
// function identity, and each pass builds a new `update` closure, so the old
// reference has to be kept rather than re-derived.
let titleUpdate: (() => void) | null = null;

function setupSlideTitle() {
  const reveal = document.querySelector('.reveal') as HTMLElement | null;
  if (!reveal) return;
  const header = only(reveal, ':scope > .slide-title-bar', () => {
    const el = document.createElement('div');
    el.className = 'slide-title-bar';
    return el;
  }) as HTMLElement;
  const update = () => {
    const current = document.querySelector('.reveal .slides section.present') as HTMLElement | null;
    const titleEl = current?.querySelector(':scope > .rheo-slide-title') as HTMLElement | null;
    header.innerHTML = titleEl?.innerHTML ?? '';
    header.style.display = titleEl ? '' : 'none';
  };

  // RE-REGISTERED EVERY PASS rather than bound once on first load: `update`
  // closes over `header`, and the `only` call above replaces that element, so a
  // handler held over from an earlier pass would write into a node that is no
  // longer in the document and the title bar would silently stop updating.
  // Dropping the previous one first is what keeps them from accumulating.
  if (titleUpdate) {
    Reveal.off('ready', titleUpdate);
    Reveal.off('slidechanged', titleUpdate);
  }
  titleUpdate = update;
  Reveal.on('ready', update);
  Reveal.on('slidechanged', update);
}

function init(mode: 'first-load' | 'rehydrate') {
  // Nothing here applies to a page with no deck, which is most of them. Before
  // this return, `applyStyles` appended its `<style>` unconditionally — under
  // rehydrate that would have added one to `<head>` per edit, for ever.
  const reveal = document.querySelector('.reveal') as HTMLElement | null;
  if (!reveal) return;

  applyStyles();
  setupSlideTitle();

  if (mode === 'first-load') {
    const transition = reveal.dataset.transition;
    Reveal.initialize({ hash: true, ...(transition ? { transition } : {}) });
    return;
  }

  // NEVER `Reveal.initialize` again: it resets the deck to slide one, and a
  // morph exists precisely so the reader stays where they were. Reveal keeps its
  // own slide state and the morph preserves the deck's DOM, so the only thing it
  // can be wrong about afterwards is the slide COUNT, which `sync` recomputes.
  //
  // `sync` is absent from the static `Reveal` export until `initialize` has run
  // — reveal.js copies the deck instance across onto it at that point — so this
  // line is only ever reached on a path where it exists. The guard is for a
  // Reveal old enough not to have it at all, not for the ordinary case.
  if (typeof Reveal.sync === 'function') Reveal.sync();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => init('first-load'));
} else {
  init('first-load');
}

// REHYDRATE AFTER A rheo MORPH. rheo's dev server patches a content edit into
// the live DOM instead of reloading, which re-executes no script and hands back
// the pre-hydration markup. `js_rehydrate = true` in `typst.toml` is the other
// half of the declaration: without it rheo reloads the page and never calls
// this.
//
// `globalThis`, not `window`: reading `window` at module-evaluation time throws
// under node. They are the same object in a browser.
//
// `??=` rather than an assignment: load order between rheo's live client and
// this module is not something either end can assume.
(globalThis.__rheoRehydrate ??= []).push(() => init('rehydrate'));
