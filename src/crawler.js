const axios = require('axios');
const cheerio = require('cheerio');

// Simula motor de busca fazendo scraping direto
class WebCrawler {
  constructor() {
    this.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  }

  // Busca em múltiplas fontes
  async search(query, maxResults = 10) {
    const results = [];
    
    // Lista de sites para buscar
    const searchSources = [
      { name: 'Wikipedia', url: `https://pt.wikipedia.org/w/api.php?action=opensearch&search=${encodeURIComponent(query)}&limit=5&format=json` },
    ];

    try {
      // Buscar na Wikipedia
      const wikiResults = await this.searchWikipedia(query);
      results.push(...wikiResults);

      // Simular busca em mais sites (você pode adicionar mais)
      const customResults = await this.searchCustomSites(query, maxResults - results.length);
      results.push(...customResults);

      return results.slice(0, maxResults);
    } catch (error) {
      console.error('Erro no crawler:', error);
      return results;
    }
  }

  // Busca na Wikipedia
  async searchWikipedia(query) {
    try {
      const url = `https://pt.wikipedia.org/w/api.php?action=opensearch&search=${encodeURIComponent(query)}&limit=5&format=json`;
      const response = await axios.get(url);
      
      const [, titles, descriptions, urls] = response.data;
      
      return titles.map((title, i) => ({
        title,
        url: urls[i],
        snippet: descriptions[i] || 'Sem descrição',
        content: descriptions[i] || '',
        source: 'Wikipedia',
        date: new Date().toISOString()
      }));
    } catch (error) {
      console.error('Erro Wikipedia:', error);
      return [];
    }
  }

  // Busca customizada (scraping direto de sites)
  async searchCustomSites(query, limit) {
    const results = [];
    
    // Lista de sites para fazer scraping
    const sites = [
      'https://www.example.com',
      // Adicione mais sites aqui
    ];

    // Simulação de resultados (em produção você faria scraping real)
    for (let i = 0; i < Math.min(limit, 5); i++) {
      results.push({
        title: `Resultado ${i + 1} para "${query}"`,
        url: `https://example.com/result${i + 1}`,
        snippet: `Este é um resultado simulado sobre ${query}. Conteúdo relevante encontrado.`,
        content: `Conteúdo completo sobre ${query}. Lorem ipsum dolor sit amet.`,
        source: 'Custom Scraping',
        date: new Date().toISOString()
      });
    }

    return results;
  }

  // Scraping de uma página específica
  async scrapePage(url) {
    try {
      const response = await axios.get(url, {
        headers: { 'User-Agent': this.userAgent },
        timeout: 5000
      });

      const $ = cheerio.load(response.data);
      
      // Extrair conteúdo
      const title = $('title').text() || $('h1').first().text();
      const paragraphs = [];
      
      $('p').each((i, elem) => {
        const text = $(elem).text().trim();
        if (text.length > 50) {
          paragraphs.push(text);
        }
      });

      return {
        title,
        content: paragraphs.join(' '),
        paragraphs
      };
    } catch (error) {
      console.error(`Erro ao scrapear ${url}:`, error.message);
      return null;
    }
  }

  // Busca avançada
  async searchAdvanced(query, options = {}) {
    const { maxResults = 10, language = 'pt', dateFilter, contentType } = options;
    
    let results = await this.search(query, maxResults * 2);

    // Filtrar por idioma
    if (language) {
      results = results.filter(r => r.url.includes(`.${language}`));
    }

    // Filtrar por tipo de conteúdo
    if (contentType && contentType !== 'all') {
      results = results.filter(r => {
        if (contentType === 'news') return r.source.includes('news');
        if (contentType === 'academic') return r.source.includes('Wiki');
        return true;
      });
    }

    return results.slice(0, maxResults);
  }
}

module.exports = new WebCrawler();