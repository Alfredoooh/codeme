const axios = require('axios');
const cheerio = require('cheerio');

// Web Crawler com buscas REAIS
class WebCrawler {
  constructor() {
    this.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  }

  // Busca em múltiplas fontes REAIS
  async search(query, maxResults = 10) {
    const results = [];
    
    try {
      // 1. Buscar na Wikipedia PT
      console.log('🔍 Buscando na Wikipedia...');
      const wikiResults = await this.searchWikipedia(query);
      results.push(...wikiResults);

      // 2. Buscar no DuckDuckGo (via scraping)
      console.log('🔍 Buscando no DuckDuckGo...');
      const duckResults = await this.searchDuckDuckGo(query, maxResults);
      results.push(...duckResults);

      // 3. Buscar notícias no Google News RSS
      console.log('🔍 Buscando notícias...');
      const newsResults = await this.searchGoogleNews(query);
      results.push(...newsResults);

      // Remover duplicados por URL
      const uniqueResults = this.removeDuplicates(results);

      return uniqueResults.slice(0, maxResults);
    } catch (error) {
      console.error('Erro no crawler:', error.message);
      return results.slice(0, maxResults);
    }
  }

  // Busca REAL na Wikipedia
  async searchWikipedia(query) {
    try {
      const url = `https://pt.wikipedia.org/w/api.php?action=opensearch&search=${encodeURIComponent(query)}&limit=5&format=json`;
      const response = await axios.get(url, { timeout: 5000 });
      
      const [, titles, descriptions, urls] = response.data;
      
      return titles.map((title, i) => ({
        title,
        url: urls[i],
        snippet: descriptions[i] || 'Artigo da Wikipedia',
        content: descriptions[i] || title,
        source: 'Wikipedia',
        date: new Date().toISOString()
      }));
    } catch (error) {
      console.error('Erro Wikipedia:', error.message);
      return [];
    }
  }

  // Busca REAL no DuckDuckGo
  async searchDuckDuckGo(query, limit = 10) {
    try {
      const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
      const response = await axios.get(url, {
        headers: { 'User-Agent': this.userAgent },
        timeout: 10000
      });

      const $ = cheerio.load(response.data);
      const results = [];

      $('.result').each((i, elem) => {
        if (results.length >= limit) return false;

        const titleElem = $(elem).find('.result__title');
        const snippetElem = $(elem).find('.result__snippet');
        const urlElem = $(elem).find('.result__url');

        const title = titleElem.text().trim();
        const snippet = snippetElem.text().trim();
        let url = urlElem.attr('href') || '';

        // Limpar URL do DuckDuckGo
        if (url.includes('uddg=')) {
          url = decodeURIComponent(url.split('uddg=')[1]);
        }

        if (title && url) {
          results.push({
            title,
            url,
            snippet: snippet || 'Sem descrição disponível',
            content: `${title}. ${snippet}`,
            source: 'DuckDuckGo',
            date: new Date().toISOString()
          });
        }
      });

      return results;
    } catch (error) {
      console.error('Erro DuckDuckGo:', error.message);
      return [];
    }
  }

  // Busca REAL no Google News RSS
  async searchGoogleNews(query) {
    try {
      const url = `https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=pt-BR&gl=BR&ceid=BR:pt-419`;
      const response = await axios.get(url, { timeout: 5000 });

      const $ = cheerio.load(response.data, { xmlMode: true });
      const results = [];

      $('item').slice(0, 5).each((i, elem) => {
        const title = $(elem).find('title').text();
        const link = $(elem).find('link').text();
        const description = $(elem).find('description').text();
        const pubDate = $(elem).find('pubDate').text();

        if (title && link) {
          results.push({
            title,
            url: link,
            snippet: description || 'Notícia recente',
            content: `${title}. ${description}`,
            source: 'Google News',
            date: pubDate || new Date().toISOString()
          });
        }
      });

      return results;
    } catch (error) {
      console.error('Erro Google News:', error.message);
      return [];
    }
  }

  // Scraping de página específica
  async scrapePage(url) {
    try {
      const response = await axios.get(url, {
        headers: { 'User-Agent': this.userAgent },
        timeout: 8000
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

      // Extrair meta description
      const metaDesc = $('meta[name="description"]').attr('content') || '';

      return {
        title,
        content: paragraphs.join(' '),
        description: metaDesc,
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
      results = results.filter(r => 
        r.url.includes(`.${language}`) || 
        r.source.includes('News') ||
        r.source === 'Wikipedia'
      );
    }

    // Filtrar por tipo de conteúdo
    if (contentType && contentType !== 'all') {
      results = results.filter(r => {
        if (contentType === 'news') return r.source.includes('News');
        if (contentType === 'academic') return r.source.includes('Wiki');
        return true;
      });
    }

    // Filtrar por data
    if (dateFilter) {
      const filterDate = new Date(dateFilter);
      results = results.filter(r => new Date(r.date) >= filterDate);
    }

    return results.slice(0, maxResults);
  }

  // Remover URLs duplicadas
  removeDuplicates(results) {
    const seen = new Set();
    return results.filter(r => {
      if (seen.has(r.url)) return false;
      seen.add(r.url);
      return true;
    });
  }
}

module.exports = new WebCrawler();