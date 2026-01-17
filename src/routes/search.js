const express = require('express');
const router = express.Router();
const crawler = require('../crawler');
const { rankResults } = require('../ml/ranking');
const { extractKeywords } = require('../ml/nlp');
const aiEngine = require('../ml/ai_engine');

// Busca com IA gerando resposta completa
router.post('/', async (req, res) => {
  try {
    const { query, maxResults = 10 } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'Query é obrigatório' });
    }

    console.log(`🔍 Buscando: ${query}`);

    // Fazer crawling
    const rawResults = await crawler.search(query, maxResults);

    if (rawResults.length === 0) {
      return res.json({
        success: true,
        query,
        aiResponse: {
          answer: `Não encontrei resultados para "${query}". Tenta reformular a pergunta.`,
          markdown: `**Nenhum resultado**\n\nNão encontrei informações sobre "${query}".`,
          confidence: 0,
          sources: [],
          totalSources: 0
        },
        results: [],
        timestamp: new Date().toISOString()
      });
    }

    // Extrair palavras-chave
    const keywords = extractKeywords(query);

    // Rankear resultados
    const rankedResults = rankResults(rawResults, keywords);

    // GERAR RESPOSTA DE IA
    const aiResponse = await aiEngine.generateAIResponse(query, rankedResults);

    res.json({
      success: true,
      query,
      keywords,
      aiResponse,
      results: rankedResults,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Erro na busca:', error);
    res.status(500).json({ 
      error: 'Erro ao processar busca',
      details: error.message 
    });
  }
});

module.exports = router;