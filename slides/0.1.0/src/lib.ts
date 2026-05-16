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

function setupSlideTitle() {
  const reveal = document.querySelector('.reveal') as HTMLElement | null;
  if (!reveal) return;
  const header = document.createElement('div');
  header.className = 'slide-title-bar';
  reveal.appendChild(header);
  const update = () => {
    const current = document.querySelector('.reveal .slides section.present') as HTMLElement | null;
    const title = current?.dataset.slideTitle ?? '';
    header.textContent = title;
    header.style.display = title ? '' : 'none';
  };
  Reveal.on('ready', update);
  Reveal.on('slidechanged', update);
}

function init() {
  applyStyles();
  setupSlideTitle();
  Reveal.initialize({ hash: true });
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
