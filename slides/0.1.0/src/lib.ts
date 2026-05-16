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

function applyStyles() {
  const reveal = document.querySelector('.reveal') as HTMLElement | null;
  const themeName = reveal?.dataset.theme ?? 'black';
  const themeCss = themeMap[themeName] ?? themeMap.black;
  const style = document.createElement('style');
  style.textContent = revealCss + themeCss;
  document.head.appendChild(style);
}

function init() {
  applyStyles();
  Reveal.initialize({ hash: true });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
