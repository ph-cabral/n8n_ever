import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],

  // Base para assets
  base: "/",

  build: {
    outDir: "dist",
    assetsDir: "assets",
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ["react", "react-dom", "react-router-dom"],
        },
      },
    },
  },

  server: {
    // ✅ Escucha en todas las interfaces
    host: "0.0.0.0",
    port: 5050,

    // ✅ CRÍTICO: Permitir el host mari.ever
    allowedHosts: ["mari.ever", "localhost", "127.0.0.1"],

    // ✅ Hot Module Replacement
    hmr: {
      host: "mari.ever",
      port: 5050,
      protocol: "ws", // Usar WebSocket sin SSL
    },

    // ✅ Watch en Docker
    watch: {
      usePolling: true,
      interval: 100,
    },

    // ✅ Proxy para n8n (opcional si usas nginx)
    proxy: {
      "/webhook": {
        target: "http://n8n:5678",
        changeOrigin: true,
        secure: false,
      },
    },
  },

  // ✅ Prevenir errores de optimización
  optimizeDeps: {
    exclude: [],
  },
});
