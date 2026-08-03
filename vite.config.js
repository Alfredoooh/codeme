import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Build 100% estático, sem CDN, sem esm.sh, sem importmap.
// Tudo o que está em "dependencies" no package.json é descarregado
// via npm install e empacotado localmente pelo Vite/Rollup dentro
// de dist/. O output final não tem nenhuma referência externa —
// é só HTML + JS + CSS servidos tal como estão, exatamente o que
// o Render runtime: static espera.
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    emptyOutDir: true
  }
});