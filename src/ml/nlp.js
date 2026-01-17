// Processamento de Linguagem Natural

// Stopwords em português
const stopwords = new Set([
  'a', 'o', 'e', 'de', 'da', 'do', 'em', 'um', 'uma', 'os', 'as',
  'ao', 'aos', 'à', 'às', 'para', 'por', 'com', 'sem', 'sob',
  'sobre', 'este', 'esse', 'aquele', 'isto', 'isso', 'aquilo',
  'ele', 'ela', 'eles', 'elas', 'eu', 'tu', 'nós', 'vós',
  'que', 'qual', 'quando', 'onde', 'como', 'por que', 'porque'
]);

// Extrair palavras-chave de um texto
function extractKeywords(text, maxKeywords = 5) {
  // Limpar e tokenizar
  const words = text
    .toLowerCase()
    .replace(/[^\w\sáàâãéèêíïóôõöúçñ]/g, '')
    .split(/\s+/)
    .filter(word => word.length > 3 && !stopwords.has(word));

  // Contar frequências
  const frequencies = {};
  words.forEach(word => {
    frequencies[word] = (frequencies[word] || 0) + 1;
  });

  // Ordenar por frequência
  const sorted = Object.entries(frequencies)
    .sort((a, b) => b[1] - a[1])
    .slice(0, maxKeywords)
    .map(([word]) => word);

  return sorted;
}

// Tokenização básica
function tokenize(text) {
  return text
    .toLowerCase()
    .replace(/[^\w\sáàâãéèêíïóôõöúçñ]/g, '')
    .split(/\s+/)
    .filter(word => word.length > 0);
}

// Remover stopwords
function removeStopwords(words) {
  return words.filter(word => !stopwords.has(word));
}

// Stemming simplificado (remover sufixos comuns)
function stem(word) {
  const suffixes = ['mente', 'ação', 'ador', 'ante', 'ância', 'ência', 'ismo', 'ista', 'oso', 'osa'];
  
  for (const suffix of suffixes) {
    if (word.endsWith(suffix) && word.length > suffix.length + 3) {
      return word.slice(0, -suffix.length);
    }
  }
  
  return word;
}

// Calcular similaridade entre dois textos (Jaccard)
function calculateSimilarity(text1, text2) {
  const words1 = new Set(removeStopwords(tokenize(text1)));
  const words2 = new Set(removeStopwords(tokenize(text2)));
  
  const intersection = new Set([...words1].filter(w => words2.has(w)));
  const union = new Set([...words1, ...words2]);
  
  return union.size > 0 ? intersection.size / union.size : 0;
}

// Extrair entidades nomeadas simples (nomes próprios)
function extractEntities(text) {
  const words = text.split(/\s+/);
  const entities = [];
  
  words.forEach(word => {
    // Palavras que começam com maiúscula (possíveis entidades)
    if (/^[A-ZÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇ]/.test(word) && word.length > 3) {
      entities.push(word);
    }
  });
  
  return [...new Set(entities)];
}

// Sumarização automática (extração de frases importantes)
function summarize(text, numSentences = 3) {
  const sentences = text
    .split(/[.!?]+/)
    .map(s => s.trim())
    .filter(s => s.length > 20);
  
  if (sentences.length <= numSentences) {
    return sentences.join('. ') + '.';
  }
  
  // Extrair palavras-chave do texto todo
  const keywords = extractKeywords(text, 10);
  
  // Pontuar cada frase baseado em palavras-chave
  const scoredSentences = sentences.map(sentence => {
    const words = tokenize(sentence);
    const score = words.filter(word => keywords.includes(word)).length;
    return { sentence, score };
  });
  
  // Pegar as N frases com maior score
  return scoredSentences
    .sort((a, b) => b.score - a.score)
    .slice(0, numSentences)
    .map(s => s.sentence)
    .join('. ') + '.';
}

// Análise de frequência de palavras
function wordFrequency(text) {
  const words = removeStopwords(tokenize(text));
  const freq = {};
  
  words.forEach(word => {
    freq[word] = (freq[word] || 0) + 1;
  });
  
  return Object.entries(freq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .reduce((obj, [word, count]) => {
      obj[word] = count;
      return obj;
    }, {});
}

module.exports = {
  extractKeywords,
  tokenize,
  removeStopwords,
  stem,
  calculateSimilarity,
  extractEntities,
  summarize,
  wordFrequency
};