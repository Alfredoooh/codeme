// Algoritmos de ranking e análise com IA

// Calcular TF-IDF (Term Frequency-Inverse Document Frequency)
function calculateTFIDF(text, keywords) {
  const words = text.toLowerCase().split(/\s+/);
  const totalWords = words.length;
  
  let score = 0;
  
  keywords.forEach(keyword => {
    const keywordLower = keyword.toLowerCase();
    const frequency = words.filter(w => w.includes(keywordLower)).length;
    const tf = frequency / totalWords;
    
    // IDF simplificado
    const idf = Math.log(1 + (1 / (frequency + 1)));
    score += tf * idf;
  });
  
  return score;
}

// Calcular relevância baseada em posição das palavras-chave
function calculatePositionScore(text, keywords) {
  const textLower = text.toLowerCase();
  let score = 0;
  
  keywords.forEach(keyword => {
    const position = textLower.indexOf(keyword.toLowerCase());
    if (position !== -1) {
      // Palavras no início têm mais peso
      score += 1 / (position + 1);
    }
  });
  
  return score;
}

// Análise de sentimento simples
function analyzeSentiment(text) {
  const positiveWords = ['bom', 'ótimo', 'excelente', 'melhor', 'grande', 'sucesso', 'qualidade'];
  const negativeWords = ['ruim', 'péssimo', 'problema', 'erro', 'falha', 'pior'];
  
  const words = text.toLowerCase().split(/\s+/);
  
  let positive = 0;
  let negative = 0;
  
  words.forEach(word => {
    if (positiveWords.some(pw => word.includes(pw))) positive++;
    if (negativeWords.some(nw => word.includes(nw))) negative++;
  });
  
  const total = positive + negative;
  if (total === 0) return 'neutro';
  
  const score = (positive - negative) / total;
  
  if (score > 0.3) return 'positivo';
  if (score < -0.3) return 'negativo';
  return 'neutro';
}

// Rankear resultados usando múltiplos algoritmos
function rankResults(results, keywords) {
  return results.map(result => {
    const text = `${result.title} ${result.snippet} ${result.content}`;
    
    // Calcular múltiplos scores
    const tfIdfScore = calculateTFIDF(text, keywords);
    const positionScore = calculatePositionScore(text, keywords);
    const lengthScore = Math.min(text.length / 1000, 1); // Preferir textos mais longos
    
    // Score final ponderado
    const finalScore = (
      tfIdfScore * 0.5 +
      positionScore * 0.3 +
      lengthScore * 0.2
    );
    
    return {
      ...result,
      relevanceScore: parseFloat(finalScore.toFixed(4)),
      metrics: {
        tfIdf: parseFloat(tfIdfScore.toFixed(4)),
        position: parseFloat(positionScore.toFixed(4)),
        length: parseFloat(lengthScore.toFixed(4))
      }
    };
  }).sort((a, b) => b.relevanceScore - a.relevanceScore);
}

// Analisar texto completo
function analyzeText(text, keywords) {
  return {
    sentiment: analyzeSentiment(text),
    keywordDensity: calculateKeywordDensity(text, keywords),
    readability: calculateReadability(text),
    wordCount: text.split(/\s+/).length
  };
}

// Densidade de palavras-chave
function calculateKeywordDensity(text, keywords) {
  const words = text.toLowerCase().split(/\s+/);
  const totalWords = words.length;
  
  let keywordCount = 0;
  keywords.forEach(keyword => {
    keywordCount += words.filter(w => w.includes(keyword.toLowerCase())).length;
  });
  
  return totalWords > 0 ? (keywordCount / totalWords * 100).toFixed(2) : 0;
}

// Índice de legibilidade simples
function calculateReadability(text) {
  const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0);
  const words = text.split(/\s+/);
  
  if (sentences.length === 0 || words.length === 0) return 0;
  
  const avgWordsPerSentence = words.length / sentences.length;
  const avgCharsPerWord = text.replace(/\s/g, '').length / words.length;
  
  // Score simplificado (quanto menor, mais legível)
  const score = avgWordsPerSentence * 0.5 + avgCharsPerWord * 0.5;
  
  if (score < 15) return 'fácil';
  if (score < 25) return 'médio';
  return 'difícil';
}

module.exports = {
  rankResults,
  analyzeText,
  calculateTFIDF,
  analyzeSentiment
};