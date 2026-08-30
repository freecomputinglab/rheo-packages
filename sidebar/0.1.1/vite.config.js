import { defineConfig } from "vite";

export default defineConfig({
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
