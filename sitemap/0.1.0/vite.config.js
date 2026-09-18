import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: {
      entry: "src/index.js",
      formats: ["iife"],
      name: "RheoSitemap",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
