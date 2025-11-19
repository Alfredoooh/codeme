# Deploy DeepSeek Playground no Render

## 1. Estrutura do Projeto

Crie a seguinte estrutura de arquivos:

```
deepseek-playground/
├── package.json
├── vite.config.js
├── index.html
└── src/
    ├── main.jsx
    └── App.jsx
```

## 2. Arquivos de Configuração

### `package.json`
```json
{
  "name": "deepseek-playground",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "lucide-react": "^0.263.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^4.3.9",
    "tailwindcss": "^3.3.0",
    "postcss": "^8.4.24",
    "autoprefixer": "^10.4.14"
  }
}
```

### `vite.config.js`
```js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    assetsDir: 'assets'
  }
})
```

### `index.html`
```html
<!DOCTYPE html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>DeepSeek Playground</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
```

### `src/main.jsx`
```jsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
```

### `src/index.css`
```css
@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  -webkit-font-smoothing: antialiased;
}
```

### `tailwind.config.js`
```js
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,jsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

### `postcss.config.js`
```js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

### `src/App.jsx`
Cole o código React completo do playground aqui.

## 3. Deploy no Render

### Opção 1: Via GitHub (Recomendado)

1. **Crie um repositório no GitHub** e faça push do código:
```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/seu-usuario/deepseek-playground.git
git push -u origin main
```

2. **No Render Dashboard**:
   - Clique em "New +" → "Static Site"
   - Conecte seu repositório GitHub
   - Configure:
     - **Name**: deepseek-playground
     - **Branch**: main
     - **Build Command**: `npm install && npm run build`
     - **Publish Directory**: `dist`

3. Clique em "Create Static Site"

### Opção 2: Via Render CLI

```bash
# Instalar Render CLI
npm install -g render-cli

# Login
render login

# Deploy
render deploy
```

### Opção 3: Build Local + Upload Manual

```bash
# Instalar dependências
npm install

# Build para produção
npm run build

# O build estará na pasta 'dist'
# Faça upload manual no Render
```

## 4. Variáveis de Ambiente (Opcional)

Se quiser proteger a API key:

1. No Render Dashboard, vá em "Environment"
2. Adicione: `VITE_DEEPSEEK_API_KEY` = sua-api-key
3. No código, use: `import.meta.env.VITE_DEEPSEEK_API_KEY`

## 5. Comandos Úteis

```bash
# Desenvolvimento local
npm run dev

# Build de produção
npm run build

# Preview do build
npm run preview

# Verificar build
ls -la dist/
```

## 6. Troubleshooting

**Erro de build?**
- Verifique se todas as dependências estão no `package.json`
- Confirme que o Node.js está na versão 16+

**Deploy falhou?**
- Verifique logs no Render Dashboard
- Confirme que `dist` está sendo gerado
- Teste o build localmente primeiro

## 7. URL Final

Após o deploy, sua aplicação estará em:
`https://deepseek-playground.onrender.com`

(ou o nome que você escolheu)