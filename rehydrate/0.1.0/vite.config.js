import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: {
      entry: "src/lib.js",
      formats: ["iife"],
      name: "RheoRehydrate",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
