# 🔍 API de Busca com AI

API completa de busca inteligente com processamento de linguagem natural e algoritmos de Machine Learning.

## 🚀 Características
 
- **Web Scraping próprio** - Sem APIs externas de busca
- **Algoritmos de IA**:
  - TF-IDF para relevância
  - Análise de sentimento
  - Extração de palavras-chave
  - Sumarização automática
  - Ranking inteligente
- **Processamento de Linguagem Natural** em português
- **API REST completa** com Express.js

## 📁 Estrutura do Projeto

```
busca-ia-api/
├── src/
│   ├── index.js              # Servidor principal
│   ├── crawler.js            # Web scraping
│   ├── routes/
│   │   └── search.js         # Rotas de busca
│   └── ml/
│       ├── ranking.js        # Algoritmos de ranking
│       └── nlp.js            # Processamento NLP
├── package.json
└── README.md
```

## 🛠️ Instalação no Spck Editor

1. **Criar projeto**:
   - Abrir Spck Editor
   - Criar novo projeto "Express Server 4"
   - Nome: `busca-ia-api`

2. **Criar arquivos**:
   - Copiar cada arquivo do artifact
   - Criar as pastas `src/`, `src/routes/`, `src/ml/`

3. **Instalar dependências**:
   - O Spck instala automaticamente ao detectar `package.json`
   - Ou usar: npm install

## 🎯 Como Usar

### Iniciar o servidor:
```bash
npm start
```

### Endpoints:

#### 1. Busca Simples
```http
POST /api/search
Content-Type: application/json

{
  "query": "inteligência artificial",
  "maxResults": 10
}
```

#### 2. Busca Avançada
```http
POST /api/search/advanced
Content-Type: application/json

{
  "query": "machine learning",
  "maxResults": 15,
  "language": "pt",
  "contentType": "academic"
}
```

### Resposta Exemplo:
```json
{
  "success": true,
  "query": "inteligência artificial",
  "keywords": ["inteligência", "artificial"],
  "totalFound": 8,
  "results": [
    {
      "title": "Inteligência Artificial - Wikipedia",
      "url": "https://pt.wikipedia.org/wiki/Intelig%C3%AAncia_artificial",
      "snippet": "Descrição sobre IA...",
      "relevanceScore": 0.8547,
      "analysis": {
        "sentiment": "positivo",
        "keywordDensity": "3.45",
        "readability": "médio",
        "wordCount": 234
      },
      "metrics": {
        "tfIdf": 0.4523,
        "position": 0.3124,
        "length": 0.8900
      }
    }
  ],
  "timestamp": "2026-01-17T16:22:00.000Z"
}
```

## 🧠 Algoritmos de IA Implementados

### 1. TF-IDF (Term Frequency-Inverse Document Frequency)
Calcula a importância de palavras nos documentos.

### 2. Análise de Sentimento
Classifica texto como positivo, negativo ou neutro.

### 3. Ranking Multi-critério
Combina múltiplos scores:
- Relevância TF-IDF (50%)
- Posição das palavras-chave (30%)
- Tamanho do conteúdo (20%)

### 4. Processamento NLP
- Tokenização
- Remoção de stopwords
- Stemming
- Extração de entidades
- Sumarização automática

## 📊 Funcionalidades Futuras

- [ ] Cache de resultados
- [ ] Indexação persistente
- [ ] Mais fontes de dados
- [ ] Web scraping paralelo
- [ ] Suporte a mais idiomas
- [ ] API de análise de tendências

## 🔧 Tecnologias

- **Express.js** - Framework web
- **Cheerio** - Web scraping
- **Axios** - HTTP requests
- **Natural** - NLP (opcional)
- **Algoritmos próprios** - ML sem dependências externas

## 📝 Notas

- API totalmente funcional no telemóvel via Spck Editor
- Sem necessidade de APIs externas pagas
- Todos os algoritmos implementados do zero
- Otimizado para português brasileiro

## 🤝 Contribuir

Sinta-se livre para melhorar os algoritmos e adicionar novas funcionalidades!

---

**Desenvolvido com ❤️ para aprendizado de IA e Web Scraping**