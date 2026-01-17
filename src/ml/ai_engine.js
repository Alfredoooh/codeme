// Motor de IA para gerar respostas inteligentes em linguagem natural

const { extractKeywords, summarize, tokenize, removeStopwords } = require('./nlp');

class AIEngine {
  constructor() {
    this.maxTokens = 2000;
  }

  // Gerar resposta completa de IA com streaming de tokens
  async generateAIResponse(query, results) {
    if (!results || results.length === 0) {
      return this.generateNoResultsResponse(query);
    }

    // Extrair todo o contexto
    const context = this.extractContext(results);
    
    // Identificar intenção
    const intent = this.identifyIntent(query);
    
    // Gerar resposta em linguagem natural
    const response = await this.generateNaturalResponse(query, context, intent, results);
    
    return response;
  }

  // Extrair contexto de todos os resultados
  extractContext(results) {
    const allText = results.map(r => {
      return `Fonte: ${r.source}\nTítulo: ${r.title}\nConteúdo: ${r.snippet} ${r.content}`;
    }).join('\n\n');

    return {
      fullText: allText,
      titles: results.map(r => r.title),
      sources: results.map(r => ({ source: r.source, url: r.url })),
      snippets: results.map(r => r.snippet)
    };
  }

  // Identificar intenção da pergunta
  identifyIntent(query) {
    const lower = query.toLowerCase();
    
    if (lower.match(/o que é|o que são|defin|significa|conceito/)) {
      return 'definition';
    }
    if (lower.match(/como|passo|tutorial|guia/)) {
      return 'howto';
    }
    if (lower.match(/quando|data|ano|dia/)) {
      return 'temporal';
    }
    if (lower.match(/onde|local|localização/)) {
      return 'location';
    }
    if (lower.match(/quem|pessoa/)) {
      return 'person';
    }
    if (lower.match(/por que|porque|razão|motivo/)) {
      return 'reason';
    }
    if (lower.match(/quantos|quanto|número/)) {
      return 'quantity';
    }
    if (lower.match(/melhor|pior|comparar|diferença/)) {
      return 'comparison';
    }
    if (lower.match(/notícias|hoje|recente|atual/)) {
      return 'news';
    }
    
    return 'general';
  }

  // Gerar resposta em linguagem natural
  async generateNaturalResponse(query, context, intent, results) {
    let response = '';
    const sentences = this.extractSentences(context.fullText);
    const keywords = extractKeywords(query, 10);

    switch (intent) {
      case 'definition':
        response = this.generateDefinitionResponse(query, sentences, keywords, results);
        break;
      case 'howto':
        response = this.generateHowToResponse(query, sentences, keywords, results);
        break;
      case 'temporal':
        response = this.generateTemporalResponse(query, sentences, keywords, results);
        break;
      case 'news':
        response = this.generateNewsResponse(query, sentences, keywords, results);
        break;
      case 'comparison':
        response = this.generateComparisonResponse(query, sentences, keywords, results);
        break;
      default:
        response = this.generateGeneralResponse(query, sentences, keywords, results);
    }

    return {
      answer: response,
      markdown: this.formatAsMarkdown(response),
      sources: results.slice(0, 5).map(r => ({
        title: r.title,
        url: r.url,
        source: r.source
      })),
      confidence: this.calculateConfidence(results, keywords),
      totalSources: results.length
    };
  }

  // Gerar resposta de definição
  generateDefinitionResponse(query, sentences, keywords, results) {
    const relevantSentences = this.findRelevantSentences(sentences, keywords, 5);
    const mainSource = results[0];

    let response = `**${query}**\n\n`;
    
    if (relevantSentences.length > 0) {
      response += `${relevantSentences[0]}\n\n`;
      
      if (relevantSentences.length > 1) {
        response += `**Detalhes:**\n\n`;
        relevantSentences.slice(1, 4).forEach(sent => {
          response += `• ${sent}\n`;
        });
      }
    }

    response += `\n**Fontes consultadas:**\n`;
    results.slice(0, 3).forEach(r => {
      response += `• ${r.source} - ${r.title}\n`;
    });

    return response;
  }

  // Gerar resposta de notícias
  generateNewsResponse(query, sentences, keywords, results) {
    let response = `**Notícias recentes sobre ${keywords.join(', ')}:**\n\n`;

    const newsResults = results.filter(r => r.source.includes('News')).slice(0, 5);
    
    if (newsResults.length > 0) {
      newsResults.forEach((r, i) => {
        response += `📰 **${r.title}**\n`;
        response += `${r.snippet}\n`;
        response += `_Fonte: ${r.source}_\n\n`;
      });
    } else {
      const relevantSentences = this.findRelevantSentences(sentences, keywords, 5);
      relevantSentences.forEach(sent => {
        response += `• ${sent}\n\n`;
      });
    }

    response += `\n_Baseado em ${results.length} fontes consultadas_`;

    return response;
  }

  // Gerar resposta temporal
  generateTemporalResponse(query, sentences, keywords, results) {
    const datePatterns = /\d{4}|\d{1,2}\/\d{1,2}\/\d{2,4}|hoje|ontem|recente|atual/gi;
    const sentencesWithDates = sentences.filter(s => datePatterns.test(s));

    let response = `**Informação temporal sobre ${keywords.join(', ')}:**\n\n`;

    if (sentencesWithDates.length > 0) {
      sentencesWithDates.slice(0, 5).forEach(sent => {
        response += `• ${sent}\n`;
      });
    } else {
      const relevantSentences = this.findRelevantSentences(sentences, keywords, 5);
      relevantSentences.forEach(sent => {
        response += `• ${sent}\n`;
      });
    }

    response += `\n_Fontes: ${results.slice(0, 3).map(r => r.source).join(', ')}_`;

    return response;
  }

  // Gerar resposta How-To
  generateHowToResponse(query, sentences, keywords, results) {
    const steps = this.extractSteps(sentences);

    let response = `**Como ${query.replace(/como /gi, '')}:**\n\n`;

    if (steps.length > 0) {
      steps.forEach((step, i) => {
        response += `${i + 1}. ${step}\n\n`;
      });
    } else {
      const relevantSentences = this.findRelevantSentences(sentences, keywords, 6);
      relevantSentences.forEach((sent, i) => {
        response += `**Passo ${i + 1}:** ${sent}\n\n`;
      });
    }

    response += `_Baseado em informações de ${results.length} fontes_`;

    return response;
  }

  // Gerar resposta de comparação
  generateComparisonResponse(query, sentences, keywords, results) {
    let response = `**Comparação: ${keywords.join(' vs ')}**\n\n`;

    const comparisonSentences = sentences.filter(s => 
      s.match(/diferença|enquanto|mas|porém|embora|comparado|versus/i)
    );

    if (comparisonSentences.length > 0) {
      comparisonSentences.slice(0, 5).forEach(sent => {
        response += `• ${sent}\n\n`;
      });
    } else {
      const relevantSentences = this.findRelevantSentences(sentences, keywords, 5);
      relevantSentences.forEach(sent => {
        response += `• ${sent}\n\n`;
      });
    }

    response += `_Análise baseada em ${results.length} fontes_`;

    return response;
  }

  // Gerar resposta geral
  generateGeneralResponse(query, sentences, keywords, results) {
    const relevantSentences = this.findRelevantSentences(sentences, keywords, 6);

    let response = `**${query}**\n\n`;

    if (relevantSentences.length > 0) {
      response += `${relevantSentences[0]}\n\n`;
      
      if (relevantSentences.length > 1) {
        response += `**Informações adicionais:**\n\n`;
        relevantSentences.slice(1, 5).forEach(sent => {
          response += `• ${sent}\n`;
        });
      }
    }

    response += `\n\n_Encontrado em ${results.length} fontes incluindo ${results.slice(0, 2).map(r => r.source).join(', ')}_`;

    return response;
  }

  // Sem resultados
  generateNoResultsResponse(query) {
    return {
      answer: `Não consegui encontrar informações sobre "${query}". Tenta reformular a pergunta ou usar termos diferentes.`,
      markdown: `**Nenhum resultado encontrado**\n\nNão consegui encontrar informações sobre "${query}".`,
      sources: [],
      confidence: 0,
      totalSources: 0
    };
  }

  // Extrair sentenças relevantes
  findRelevantSentences(sentences, keywords, limit = 5) {
    const scored = sentences.map(sent => {
      const score = keywords.filter(k => 
        sent.toLowerCase().includes(k.toLowerCase())
      ).length;
      return { sentence: sent, score };
    })
    .filter(s => s.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(s => s.sentence.trim());

    return scored;
  }

  // Extrair sentenças
  extractSentences(text) {
    return text
      .split(/[.!?]+/)
      .map(s => s.trim())
      .filter(s => s.length > 30 && s.length < 300);
  }

  // Extrair passos
  extractSteps(sentences) {
    const stepPatterns = /primeiro|segundo|terceiro|passo|etapa|\d+\.|depois|em seguida|finalmente/i;
    return sentences
      .filter(s => stepPatterns.test(s))
      .slice(0, 10)
      .map(s => s.replace(/^(primeiro|segundo|terceiro|passo|etapa|\d+\.)\s*/i, '').trim());
  }

  // Formatar como Markdown
  formatAsMarkdown(text) {
    return text; // Já está em markdown
  }

  // Calcular confiança
  calculateConfidence(results, keywords) {
    let confidence = 0.4;
    confidence += Math.min(results.length * 0.05, 0.3);
    
    const reliableSources = results.filter(r => 
      r.source.includes('Wikipedia') || 
      r.source.includes('News') ||
      r.url.includes('.gov') ||
      r.url.includes('.edu')
    ).length;
    
    confidence += reliableSources * 0.05;

    return Math.min(confidence, 0.95);
  }
}

module.exports = new AIEngine();