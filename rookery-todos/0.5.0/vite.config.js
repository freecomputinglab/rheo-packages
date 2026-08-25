import { defineConfig } from "vite";
import { viteStaticCopy } from "vite-plugin-static-copy";

// Same shape as @rheo/rookery-search's: one IIFE bundle plus a static copy of
// every `.typ` and the stylesheet, so `dist/` holds exactly what `typst.toml`'s
// entrypoint and asset keys point at. `dist/` is gitignored — it is a build
// artifact, and the release workflow tars it.
export default defineConfig({
  plugins: [
    viteStaticCopy({
      targets: [
        { src: "src/*.typ", dest: "", rename: { stripBase: 1 } },
        { src: "src/rookery-todos.css", dest: "", rename: { stripBase: 1 } },
      ],
    }),
  ],
  build: {
    lib: {
      entry: "src/rookery-todos.js",
      formats: ["iife"],
      name: "RheoRookeryTodos",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
