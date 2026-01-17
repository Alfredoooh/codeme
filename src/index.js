const express = require('express');
const searchRoutes = require('./routes/search');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// Rotas
app.use('/api/search', searchRoutes);

// Rota principal
app.get('/', (req, res) => {
  res.json({
    message: 'API de Busca com IA',
    version: '1.0.0',
    endpoints: {
      search: '/api/search',
      searchAdvanced: '/api/search/advanced'
    }
  });
});

// Iniciar servidor
app.listen(PORT, () => {
  console.log(`🚀 Servidor rodando na porta ${PORT}`);
  console.log(`📡 Acesse: http://localhost:${PORT}`);
});