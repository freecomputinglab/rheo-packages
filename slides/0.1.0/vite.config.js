import { defineConfig } from "vite";

export default defineConfig({
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
