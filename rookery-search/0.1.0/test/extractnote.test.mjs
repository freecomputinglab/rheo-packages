// `extractNote(doc, pageUrl)` — lifts a note's own body out of its minted
// page (`doc`, as if just parsed by `DOMParser` from a `fetch`), between the
// heading and `footer.idea-footer`. It reaches for the GLOBAL `document` to
// build the wrapper and to `importNode` the lifted elements into it (that is
// the whole point of `importNode`: adopting nodes from the FOREIGN `doc`
// into the page's own document) — so a global `document` has to exist before
// calling it, exactly as it does in a real page. linkedom supplies both: one
// parsed document installed as `globalThis.document` (standing in for the
// live page), and a separate one per test via `DOMParser` (standing in for
// the fetched page).
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML, DOMParser } from "linkedom";
import { extractNote } from "./internal.mjs";

const { document } = parseHTML("<!doctype html><body></body>");
globalThis.document = document;

const parse = (html) => new DOMParser().parseFromString(html, "text/html");

test("extractNote: takes the elements between the heading and the footer, not the footer itself", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head"><h1 class="idea">Title</h1></div>
    <p>Body one</p>
    <div>Body two</div>
    <footer class="idea-footer">Context / Backlinks</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/ideas/etal.html");
  assert.notEqual(box, null);
  assert.equal(box.className, "idea-window idea-window-plain");
  const inner = box.querySelector(".idea-window-body");
  assert.notEqual(inner, null);
  assert.equal(inner.children.length, 2);
  assert.equal(inner.children[0].tagName, "P");
  assert.equal(inner.children[0].textContent, "Body one");
  assert.equal(inner.children[1].textContent, "Body two");
  assert.equal(box.querySelector("footer"), null);
});

test("extractNote: null when there is no h1.idea at all (not a minted page)", () => {
  const doc = parse(`<!doctype html><body>
    <p>Just a page</p>
    <footer class="idea-footer">f</footer>
  </body>`);
  assert.equal(extractNote(doc, "https://example.org/x.html"), null);
});

test("extractNote: null when the range between heading and footer is empty", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head"><h1 class="idea">Title</h1></div>
    <footer class="idea-footer">f</footer>
  </body>`);
  assert.equal(extractNote(doc, "https://example.org/x.html"), null);
});

test("extractNote: style — the wrapping .idea-head's style wins when both it and the h1 carry one", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head" style="--idea-link-color: red;">
      <h1 class="idea" style="--idea-link-color: blue;">Title</h1>
    </div>
    <p>Body</p>
    <footer class="idea-footer">f</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/x.html");
  assert.equal(box.getAttribute("style"), "--idea-link-color: red;");
});

test("extractNote: style — falls back to the h1's own style when .idea-head has none", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head">
      <h1 class="idea" style="--idea-link-color: blue;">Title</h1>
    </div>
    <p>Body</p>
    <footer class="idea-footer">f</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/x.html");
  assert.equal(box.getAttribute("style"), "--idea-link-color: blue;");
});

test("extractNote: rookery 0.2.0 shape — no .idea-head wrapper, h1 is a top-level sibling", () => {
  const doc = parse(`<!doctype html><body>
    <h1 class="idea" style="--idea-link-color: green;">Title</h1>
    <p>Body</p>
    <footer class="idea-footer">f</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/x.html");
  assert.notEqual(box, null);
  assert.equal(box.getAttribute("style"), "--idea-link-color: green;");
  assert.equal(box.querySelector(".idea-window-body").textContent.trim(), "Body");
});

test("extractNote: no style attribute at all when neither the head nor the h1 carries one", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head"><h1 class="idea">Title</h1></div>
    <p>Body</p>
    <footer class="idea-footer">f</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/x.html");
  assert.equal(box.hasAttribute("style"), false);
});

test("extractNote: drops <script> elements from the lifted range", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head"><h1 class="idea">Title</h1></div>
    <p>Body</p>
    <script>window.evil = true;</script>
    <footer class="idea-footer">f</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/x.html");
  assert.equal(box.querySelectorAll("script").length, 0);
});

test("extractNote: resolves relative href/src against the fetched page's URL", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head"><h1 class="idea">Title</h1></div>
    <p><a href="../style.css">css</a> <img src="img/a.png"></p>
    <footer class="idea-footer">f</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/site/ideas/etal.html");
  const a = box.querySelector("a");
  const img = box.querySelector("img");
  assert.equal(a.getAttribute("href"), "https://example.org/site/style.css");
  assert.equal(img.getAttribute("src"), "https://example.org/site/ideas/img/a.png");
});

test("extractNote: leaves a fragment-only link exactly as written", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head"><h1 class="idea">Title</h1></div>
    <p><a href="#loc-3">footnote</a></p>
    <footer class="idea-footer">f</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/site/ideas/etal.html");
  assert.equal(box.querySelector("a").getAttribute("href"), "#loc-3");
});

test("extractNote: leaves an empty href untouched (does not throw resolving against it)", () => {
  const doc = parse(`<!doctype html><body>
    <div class="idea-head"><h1 class="idea">Title</h1></div>
    <p><a href="">empty</a></p>
    <footer class="idea-footer">f</footer>
  </body>`);
  const box = extractNote(doc, "https://example.org/site/ideas/etal.html");
  assert.equal(box.querySelector("a").getAttribute("href"), "");
});
