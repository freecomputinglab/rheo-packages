import { defineConfig } from "vite";
import { viteStaticCopy } from "vite-plugin-static-copy";

export default defineConfig({
  plugins: [
    viteStaticCopy({
      targets: [
        { src: "src/lib.typ", dest: "", rename: { stripBase: 1 } },
        { src: "src/sidebar.css", dest: "", rename: { stripBase: 1 } },
      ],
    }),
  ],
  build: {
    lib: {
      entry: "src/sidebar.js",
      formats: ["iife"],
      name: "RheoSidebar",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
