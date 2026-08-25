// The preview pane's rich content: fetching a note's own minted page and
// extracting the part of it worth showing.

import { markTermsInNode } from "./marks.js";

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
export const previewCache = new Map();
// The note itself, lifted out of its minted page: every element between the
// page's heading and its `<footer class="idea-footer">` — body, footnotes,
// references. Not the heading, because the selected result row above the pane
// already carries the title and id; not the footer, because Context/Backlinks
// are navigation for that page rather than content of the note. `null` when the
// document holds no `h1.idea` (not a minted page) or the range is empty.
//
// THE RANGE STARTS AFTER `.idea-head`, NOT AFTER THE `<h1>`, and the two are
// different elements. rookery 0.3.0 and later wrap a minted page's permalink tab and its
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
// Under rookery 0.3.0 and later that container is `.idea-head`; under 0.2.0 it was the
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
export const extractNote = (doc, pageUrl) => {
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
export const fetchNote = (href) => {
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
