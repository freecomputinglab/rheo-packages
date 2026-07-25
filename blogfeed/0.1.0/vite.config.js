import { defineConfig } from "vite";
import { viteStaticCopy } from "vite-plugin-static-copy";

export default defineConfig({
  plugins: [
    viteStaticCopy({
      targets: [
        { src: "src/lib.typ", dest: "", rename: { stripBase: 1 } },
        { src: "src/blogfeed.css", dest: "", rename: { stripBase: 1 } },
      ],
    }),
  ],
  build: {
    lib: {
      entry: "src/blogfeed.js",
      formats: ["iife"],
      name: "RheoBlogfeed",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
