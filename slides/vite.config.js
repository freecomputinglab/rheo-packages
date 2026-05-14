import { defineConfig } from "vite";
import { viteStaticCopy } from "vite-plugin-static-copy";

export default defineConfig({
  plugins: [
    viteStaticCopy({
      targets: [
        { src: "src/lib.typ", dest: "", rename: { stripBase: 1 } },
        { src: "src/index.css", dest: "" }
      ]
    })
  ],
  build: {
    lib: {
      entry: "src/lib.ts",
      formats: ["iife"],
      name: "RheoSlides",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
