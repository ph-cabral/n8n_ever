import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  
  server: {
    host: '0.0.0.0',
    port: 5050,
    strictPort: true,
    
    hmr: {
      protocol: 'ws',
      host: '10.10.0.159', // 👈 CAMBIAR POR TU IP
      port: 5050
    },
    
    cors: true,
    
    // Proxy opcional para n8n
    proxy: {
      '/webhook': {
        target: 'http://10.10.0.159:5678',
        changeOrigin: true,
        secure: false
      }
    }
  },
  
  // Para desarrollo en red local
  preview: {
    host: '0.0.0.0',
    port: 5050
  }
})

