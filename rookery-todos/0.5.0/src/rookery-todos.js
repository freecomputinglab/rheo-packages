// Browser half of @rheo/rookery-todos: the dependency graph view.
//
// Finds every `.todo-graph` the Typst side emitted, reads the JSON payload
// beside it, and replaces the no-JS fallback list with an SVG drawing. If this
// never runs — JS disabled, a paged or EPUB target, a script error — the
// fallback list stays exactly where it was and the page still says which todos
// depend on which. That is why the fallback is markup rather than a spinner.

import { GEOM, layer, place, rows } from "./layout.js";

const SVG = "http://www.w3.org/2000/svg";

function el(name, attrs, text) {
  const n = document.createElementNS(SVG, name);
  for (const [k, v] of Object.entries(attrs || {})) n.setAttribute(k, v);
  if (text != null) n.textContent = text;
  return n;
}

// One node box. Status and priority ride as CLASSES, never as inline styles,
// so a project restyles the graph from its own stylesheet without touching the
// package — the same rule the list views follow.
function drawNode(node, pt) {
  const classes = ["todo-graph-box", `todo-graph-${node.status}`];
  if (node.priority != null) classes.push(`idea-tag-todo-p${node.priority}`);
  if (node.type) classes.push(`idea-tag-todo-${node.type}`);

  const g = el("g", { class: classes.join(" ") });
  g.appendChild(
    el("rect", {
      x: pt.x,
      y: pt.y,
      width: GEOM.w,
      height: GEOM.h,
      rx: 5,
      class: "todo-graph-rect",
    }),
  );

  const label = el("text", {
    x: pt.x + GEOM.w / 2,
    y: pt.y + GEOM.h / 2,
    class: "todo-graph-label",
    "text-anchor": "middle",
    "dominant-baseline": "central",
  });
  // Truncated to fit the box rather than clipped by it, so a long title
  // degrades to an ellipsis instead of overflowing into its neighbour.
  const text = node.title || node.name;
  label.textContent = text.length > 20 ? `${text.slice(0, 19)}…` : text;
  label.appendChild(el("title", {}, text));

  if (node.href) {
    const a = el("a", { href: node.href, class: "todo-graph-link" });
    a.appendChild(label);
    g.appendChild(a);
  } else {
    g.appendChild(label);
  }
  return g;
}

// An edge leaves the bottom of the box that UNBLOCKS and arrives at the top of
// the box waiting on it, so the arrow reads "upper unblocks lower".
//
// The geometry is unchanged from when the drawing ran the other way: bottom of
// the first argument, top of the second, cubic control points at the midpoint.
// Only which position is passed as which argument moved — see the call site.
function drawEdge(upper, lower, unresolved) {
  const x1 = upper.x + GEOM.w / 2;
  const y1 = upper.y + GEOM.h;
  const x2 = lower.x + GEOM.w / 2;
  const y2 = lower.y;
  const mid = (y1 + y2) / 2;
  return el("path", {
    d: `M ${x1} ${y1} C ${x1} ${mid}, ${x2} ${mid}, ${x2} ${y2}`,
    class: `todo-graph-edge${unresolved ? " todo-graph-edge-unresolved" : ""}`,
    fill: "none",
    "marker-end": "url(#todo-graph-arrow)",
  });
}

function arrowDefs() {
  const defs = el("defs");
  const marker = el("marker", {
    id: "todo-graph-arrow",
    viewBox: "0 0 8 8",
    refX: 7,
    refY: 4,
    markerWidth: 6,
    markerHeight: 6,
    orient: "auto-start-reverse",
  });
  marker.appendChild(el("path", { d: "M 0 0 L 8 4 L 0 8 z", class: "todo-graph-arrowhead" }));
  defs.appendChild(marker);
  return defs;
}

export function render(container) {
  const script = container.querySelector("script.todo-graph-data");
  if (!script) return;

  let data;
  try {
    data = JSON.parse(script.textContent);
  } catch {
    // A malformed payload leaves the fallback list in place. Failing loudly
    // here would replace readable markup with nothing.
    return;
  }
  const nodes = data.nodes || [];
  if (nodes.length === 0) return;

  const edges = data.edges || [];
  const layerOf = layer(nodes, edges);
  const grid = rows(nodes, layerOf);
  const { pos, width, height } = place(grid);

  const svg = el("svg", {
    class: "todo-graph-svg",
    viewBox: `0 0 ${width} ${height}`,
    width: "100%",
    role: "img",
    "aria-label": `Dependency graph of ${nodes.length} todos`,
  });
  svg.appendChild(arrowDefs());

  // Edges first, so a box always paints over a line rather than under it.
  //
  // An edge is stored as (from: dependent, to: dependency) — a fact about the
  // todos, and unchanged by any of this. The DEPENDENCY is what sits above, so
  // the arrow leaves it and lands on the dependent below: "A unblocks B".
  for (const e of edges) {
    const upper = pos.get(e.to);
    const lower = pos.get(e.from);
    if (upper && lower) svg.appendChild(drawEdge(upper, lower, false));
  }
  for (const n of nodes) {
    const pt = pos.get(n.name);
    if (pt) svg.appendChild(drawNode(n, pt));
  }

  const fallback = container.querySelector(".todo-graph-fallback");
  if (fallback) fallback.remove();
  container.appendChild(svg);
}

function init() {
  for (const c of document.querySelectorAll(".todo-graph")) render(c);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
