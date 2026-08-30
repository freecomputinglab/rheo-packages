import { defineConfig } from "vite";
import { viteStaticCopy } from "vite-plugin-static-copy";

export default defineConfig({
  plugins: [
    viteStaticCopy({
      targets: [
        { src: "src/*.typ", dest: "", rename: { stripBase: 1 } },
        { src: "src/rookery-search.css", dest: "", rename: { stripBase: 1 } },
      ],
    }),
  ],
  build: {
    lib: {
      entry: "src/rookery-search.js",
      formats: ["iife"],
      name: "RheoRookerySearch",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
