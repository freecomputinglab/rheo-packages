import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: {
      entry: "src/contents.js",
      formats: ["iife"],
      name: "RheoContentsPanel",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
