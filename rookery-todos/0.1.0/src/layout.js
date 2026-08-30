// Layered ("Sugiyama-lite") layout for a dependency DAG.
//
// Pure functions over the JSON payload `#todo-graph-view` emits, kept apart
// from the DOM half so they can be unit-tested under `node --test` without a
// browser or a DOM shim.

// Longest-path layering. A node's layer is one more than the deepest layer
// among the things it depends on, so layer 0 is a node that depends on nothing
// — work that is unblocked — and the drawing reads TOP-DOWN: what you can pick
// up on the top row, and what it releases hanging below it.
//
// LONGEST path rather than shortest, deliberately. With shortest-path layering
// an edge can span several layers and cross unrelated nodes; with longest-path
// every edge is exactly one layer long, which is what keeps the arrows short
// and the picture readable.
//
// Iterative with a worklist rather than recursive: the input is author-written
// and can be arbitrarily deep, and a blown stack is a worse failure than a
// slow layout. The caller guarantees acyclicity — the Typst side panics on a
// cycle before this ever runs — but the iteration counter below still bounds
// the loop, so a bad payload degrades to a wrong picture rather than a hang.
export function layer(nodes, edges) {
  const deps = new Map(nodes.map((n) => [n.name, []]));
  for (const e of edges) {
    if (deps.has(e.from)) deps.get(e.from).push(e.to);
  }
  const layerOf = new Map(nodes.map((n) => [n.name, 0]));
  const limit = nodes.length + 1;
  for (let pass = 0; pass < limit; pass++) {
    let changed = false;
    for (const n of nodes) {
      const want = deps.get(n.name).reduce(
        (acc, d) => (layerOf.has(d) ? Math.max(acc, layerOf.get(d) + 1) : acc),
        0,
      );
      if (want > layerOf.get(n.name)) {
        layerOf.set(n.name, want);
        changed = true;
      }
    }
    if (!changed) break;
  }
  return layerOf;
}

// Group nodes into rows by layer, ordering within a row by priority then name
// so the picture is stable across builds. An unprioritised node sorts last,
// matching how the list views order theirs.
export function rows(nodes, layerOf) {
  const byLayer = new Map();
  for (const n of nodes) {
    const l = layerOf.get(n.name) ?? 0;
    if (!byLayer.has(l)) byLayer.set(l, []);
    byLayer.get(l).push(n);
  }
  const out = [];
  for (const l of [...byLayer.keys()].sort((a, b) => a - b)) {
    const row = byLayer.get(l).sort((a, b) => {
      const pa = a.priority ?? 9;
      const pb = b.priority ?? 9;
      return pa !== pb ? pa - pb : a.name.localeCompare(b.name);
    });
    out.push(row);
  }
  return out;
}

// Node centres on a simple grid. Coordinates only — the caller decides what to
// draw with them, which is what keeps this file testable.
export const GEOM = { w: 160, h: 34, gapX: 22, gapY: 58, pad: 12 };

export function place(rowsOfNodes) {
  const widest = rowsOfNodes.reduce((m, r) => Math.max(m, r.length), 0);
  const boardW = widest * GEOM.w + Math.max(0, widest - 1) * GEOM.gapX;
  const pos = new Map();
  // LAYER 0 AT THE TOP — the todos that depend on nothing, i.e. the work that
  // is unblocked — with whatever waits on them hanging below. An index page
  // reads "here is what you can pick up, and here is what it releases".
  //
  // `depth` is still needed for `height` below, which is why it survives the
  // formula no longer using it.
  const depth = rowsOfNodes.length;
  rowsOfNodes.forEach((row, i) => {
    const rowW = row.length * GEOM.w + Math.max(0, row.length - 1) * GEOM.gapX;
    const x0 = GEOM.pad + (boardW - rowW) / 2;
    const y = GEOM.pad + i * (GEOM.h + GEOM.gapY);
    row.forEach((n, j) => {
      pos.set(n.name, { x: x0 + j * (GEOM.w + GEOM.gapX), y });
    });
  });
  return {
    pos,
    width: boardW + GEOM.pad * 2,
    height: depth * GEOM.h + Math.max(0, depth - 1) * GEOM.gapY + GEOM.pad * 2,
  };
}
