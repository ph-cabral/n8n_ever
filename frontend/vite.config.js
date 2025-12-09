import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 5050,
    watch: {
      usePolling: true,
      interval: 100,
    },
    // hmr: {
    //   host: 'mari.ever',
    //   port: 5050,
    //   overlay: false,
    // },
  },
  optimizeDeps: {
    exclude: [],
  },
});
