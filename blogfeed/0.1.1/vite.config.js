import { defineConfig } from "vite";

export default defineConfig({
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
