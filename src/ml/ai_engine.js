// Motor de IA para gerar respostas inteligentes baseadas nos resultados

const { extractKeywords, summarize, tokenize, removeStopwords } = require('./nlp');

class AIEngine {
  constructor() {
    this.contextWindow = [];
  }

  // Gerar resposta de IA baseada nos resultados
  async generateResponse(query, results) {
    if (!results || results.length === 0) {
      return {
        answer: `Não encontrei informações suficientes sobre "${query}". Tenta reformular a pergunta.`,
        confidence: 0,
        sources: []
      };
    }

    // Extrair informação de todos os resultados
    const allContent = results
      .map(r => `${r.title}. ${r.snippet}. ${r.content}`)
      .join(' ');

    // Identificar tipo de pergunta
    const questionType = this.identifyQuestionType(query);
    
    // Gerar resposta baseada no tipo
    let answer = '';
    let confidence = 0;

    switch (questionType) {
      case 'definition':
        answer = this.generateDefinition(query, results, allContent);
        confidence = 0.85;
        break;
      case 'factual':
        answer = this.generateFactualAnswer(query, results, allContent);
        confidence = 0.75;
        break;
      case 'howto':
        answer = this.generateHowToAnswer(query, results, allContent);
        confidence = 0.70;
        break;
      case 'comparison':
        answer = this.generateComparison(query, results, allContent);
        confidence = 0.80;
        break;
      case 'opinion':
        answer = this.generateOpinionAnswer(query, results, allContent);
        confidence = 0.65;
        break;
      default:
        answer = this.generateGeneralAnswer(query, results, allContent);
        confidence = 0.60;
    }

    // Extrair fontes principais
    const sources = results.slice(0, 3).map(r => ({
      title: r.title,
      url: r.url,
      relevance: r.relevanceScore
    }));

    return {
      answer: answer.trim(),
      confidence: Math.min(confidence * (results.length / 10), 0.95),
      sources,
      totalSources: results.length,
      keywords: extractKeywords(query)
    };
  }

  // Identificar tipo de pergunta
  identifyQuestionType(query) {
    const lower = query.toLowerCase();
    
    if (lower.match(/o que é|o que são|definição|significa|conceito/)) {
      return 'definition';
    }
    if (lower.match(/como|tutorial|passo a passo|fazer/)) {
      return 'howto';
    }
    if (lower.match(/diferença|comparar|vs|versus|melhor/)) {
      return 'comparison';
    }
    if (lower.match(/opinião|acha|pensa|recomenda/)) {
      return 'opinion';
    }
    if (lower.match(/quando|onde|quem|quantos|qual/)) {
      return 'factual';
    }
    
    return 'general';
  }

  // Gerar definição
  generateDefinition(query, results, allContent) {
    const firstResult = results[0];
    const sentences = allContent.split(/[.!?]+/).filter(s => s.trim().length > 30);
    
    // Pegar primeira frase relevante
    const keywords = extractKeywords(query);
    const relevantSentence = sentences.find(s => 
      keywords.some(k => s.toLowerCase().includes(k))
    ) || sentences[0];

    return `Baseado em ${results.length} fontes: ${relevantSentence.trim()}. ` +
           `Segundo ${firstResult.source}, isso está relacionado com ${keywords.join(', ')}. ` +
           `Encontrei informações em fontes como ${results.slice(0, 2).map(r => r.source).join(' e ')}.`;
  }

  // Resposta factual
  generateFactualAnswer(query, results, allContent) {
    const sentences = allContent.split(/[.!?]+/).filter(s => s.trim().length > 20);
    const keywords = extractKeywords(query);
    
    // Encontrar sentença mais relevante
    const scored = sentences.map(s => ({
      text: s,
      score: keywords.filter(k => s.toLowerCase().includes(k)).length
    })).sort((a, b) => b.score - a.score);

    const topSentences = scored.slice(0, 3).map(s => s.text.trim());

    return `Com base em ${results.length} fontes, aqui está o que encontrei: ` +
           topSentences.join('. ') + '. ' +
           `As principais fontes são ${results.slice(0, 2).map(r => r.source).join(' e ')}.`;
  }

  // Resposta How-to
  generateHowToAnswer(query, results, allContent) {
    const steps = this.extractSteps(allContent);
    
    if (steps.length > 0) {
      return `Baseado nas fontes consultadas, aqui está um guia: ` +
             steps.slice(0, 5).join('. ') + '. ' +
             `Essas informações vêm de ${results.length} fontes incluindo ${results[0].source}.`;
    }

    return `Encontrei ${results.length} fontes sobre "${query}". ` +
           `As principais informações sugerem que: ${summarize(allContent, 2)} ` +
           `Para mais detalhes, consulta ${results[0].source}.`;
  }

  // Extrair passos de how-to
  extractSteps(text) {
    const sentences = text.split(/[.!?]+/);
    const steps = [];
    
    sentences.forEach(s => {
      const lower = s.toLowerCase();
      if (lower.match(/primeiro|segundo|terceiro|passo|etapa|\d+\.|depois|em seguida/)) {
        steps.push(s.trim());
      }
    });
    
    return steps;
  }

  // Comparação
  generateComparison(query, results, allContent) {
    const keywords = extractKeywords(query);
    const sentences = allContent.split(/[.!?]+/).filter(s => s.trim().length > 30);
    
    const comparisons = sentences.filter(s => 
      s.match(/diferença|melhor|pior|enquanto|mas|porém|embora/)
    );

    if (comparisons.length > 0) {
      return `Analisando ${results.length} fontes: ${comparisons.slice(0, 2).join('. ')}. ` +
             `As informações vêm principalmente de ${results.slice(0, 2).map(r => r.source).join(' e ')}.`;
    }

    return `Com base em ${results.length} fontes sobre "${query}": ` +
           `${summarize(allContent, 3)} ` +
           `Consulta ${results[0].source} para mais detalhes.`;
  }

  // Resposta de opinião
  generateOpinionAnswer(query, results, allContent) {
    return `Baseado em ${results.length} fontes, há diferentes perspectivas: ` +
           `${summarize(allContent, 3)} ` +
           `As opiniões variam entre as fontes consultadas, incluindo ${results.slice(0, 2).map(r => r.source).join(' e ')}.`;
  }

  // Resposta geral
  generateGeneralAnswer(query, results, allContent) {
    const summary = summarize(allContent, 3);
    const keywords = extractKeywords(query);
    
    return `Encontrei ${results.length} fontes sobre "${query}". ` +
           `${summary} ` +
           `Os tópicos principais incluem: ${keywords.slice(0, 5).join(', ')}. ` +
           `Fontes: ${results.slice(0, 3).map(r => r.source).join(', ')}.`;
  }

  // Análise de confiança baseada em múltiplos fatores
  calculateConfidence(results, query) {
    let confidence = 0.5;

    // Mais resultados = mais confiança
    confidence += Math.min(results.length * 0.05, 0.3);

    // Fontes confiáveis aumentam confiança
    const reliableSources = results.filter(r => 
      r.source.includes('Wikipedia') || 
      r.source.includes('News') ||
      r.url.includes('.gov') ||
      r.url.includes('.edu')
    ).length;
    
    confidence += reliableSources * 0.05;

    // Relevância média alta
    const avgRelevance = results.reduce((sum, r) => sum + (r.relevanceScore || 0), 0) / results.length;
    confidence += avgRelevance * 0.2;

    return Math.min(confidence, 0.95);
  }
}

module.exports = new AIEngine();