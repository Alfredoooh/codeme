const express = require('express');
const router = express.Router();
const crawler = require('../crawler');
const { rankResults, analyzeText } = require('../ml/ranking');
const { extractKeywords } = require('../ml/nlp');
const aiEngine = require('../ml/ai_engine');

// Busca simples
router.post('/', async (req, res) => {
  try {
    const { query, maxResults = 10 } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'Query é obrigatório' });
    }

    console.log(`🔍 Buscando: ${query}`);

    // Extrair palavras-chave da query
    const keywords = extractKeywords(query);

    // Fazer crawling
    const rawResults = await crawler.search(query, maxResults);

    // Rankear resultados com IA
    const rankedResults = rankResults(rawResults, keywords);

    // Analisar sentimento e relevância
    const enrichedResults = rankedResults.map(result => ({
      ...result,
      analysis: analyzeText(result.content, keywords)
    }));

    // Gerar resposta de IA
    const aiResponse = await aiEngine.generateResponse(query, enrichedResults);

    res.json({
      success: true,
      query,
      keywords,
      aiAnswer: aiResponse.answer,
      confidence: aiResponse.confidence,
      totalFound: enrichedResults.length,
      results: enrichedResults,
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

// Busca avançada
router.post('/advanced', async (req, res) => {
  try {
    const { 
      query, 
      maxResults = 10,
      language = 'pt',
      dateFilter = null,
      contentType = 'all'
    } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'Query é obrigatório' });
    }

    const keywords = extractKeywords(query);
    const rawResults = await crawler.searchAdvanced(query, {
      maxResults,
      language,
      dateFilter,
      contentType
    });

    const rankedResults = rankResults(rawResults, keywords);

    res.json({
      success: true,
      query,
      filters: { language, dateFilter, contentType },
      totalFound: rankedResults.length,
      results: rankedResults,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Erro na busca avançada:', error);
    res.status(500).json({ 
      error: 'Erro ao processar busca avançada',
      details: error.message 
    });
  }
});

module.exports = router;