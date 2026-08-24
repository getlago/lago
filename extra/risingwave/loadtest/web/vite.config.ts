import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5181,
    // The API and the SSE stream live on the Fastify server.
    proxy: {
      "/api": { target: "http://localhost:5180", changeOrigin: true, ws: false },
    },
  },
  build: { outDir: "dist", sourcemap: true },
});
