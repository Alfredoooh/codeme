const http = require('http');
const { execFile } = require('child_process');

const PORT = process.env.PORT || 10000;

// Segredo simples para ninguém mais usar o seu servidor.
// Defina AUTH_KEY nas variáveis de ambiente do Render.
const AUTH_KEY = process.env.AUTH_KEY || '';

// Cookies do YouTube (opcional, mas é o que mais ajuda contra o bloqueio de bot).
// Cole o conteúdo do cookies.txt na variável de ambiente YT_COOKIES.
const fs = require('fs');
const COOKIES_PATH = '/tmp/cookies.txt';
if (process.env.YT_COOKIES) {
  fs.writeFileSync(COOKIES_PATH, process.env.YT_COOKIES);
}

const cache = new Map(); // id -> { data, time }
const CACHE_TTL = 90 * 60 * 1000; // 90 min (as URLs expiram em ~6h)

// Tentativas em ordem: cada cliente do YouTube é bloqueado de um jeito diferente
const ATTEMPTS = [
  ['--extractor-args', 'youtube:player_client=android_vr'],
  ['--extractor-args', 'youtube:player_client=tv_embedded'],
  ['--extractor-args', 'youtube:player_client=ios'],
  ['--extractor-args', 'youtube:player_client=mweb'],
  []
];

function runYtDlp(videoId, extra) {
  return new Promise((resolve, reject) => {
    const args = [
      `https://www.youtube.com/watch?v=${videoId}`,
      '-f', 'bestaudio[ext=m4a]/bestaudio',
      '--no-playlist',
      '--no-warnings',
      '--socket-timeout', '15',
      '-J', // devolve o JSON completo em vez de só a URL
      ...extra
    ];
    if (fs.existsSync(COOKIES_PATH)) args.push('--cookies', COOKIES_PATH);
    
    execFile('yt-dlp', args, { timeout: 40000, maxBuffer: 20 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) return reject(new Error((stderr || err.message).toString().slice(0, 400)));
      try { resolve(JSON.parse(stdout)); }
      catch (e) { reject(new Error('JSON inválido do yt-dlp')); }
    });
  });
}

async function extract(videoId) {
  const hit = cache.get(videoId);
  if (hit && Date.now() - hit.time < CACHE_TTL) return hit.data;
  
  const errors = [];
  for (const extra of ATTEMPTS) {
    try {
      const info = await runYtDlp(videoId, extra);
      const url = info.url || (info.requested_formats && info.requested_formats[0] && info.requested_formats[0].url);
      if (!url) { errors.push('sem url'); continue; }
      const data = {
        url,
        ext: info.ext || 'm4a',
        mime: (info.ext === 'webm') ? 'audio/webm' : 'audio/mp4',
        headers: info.http_headers || {},
        title: info.title || '',
        duration: info.duration || 0
      };
      cache.set(videoId, { data, time: Date.now() });
      return data;
    } catch (e) {
      errors.push(e.message);
    }
  }
  const err = new Error('todas as tentativas falharam');
  err.details = errors;
  throw err;
}

function send(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Access-Control-Allow-Origin': '*' });
  res.end(JSON.stringify(obj));
}

http.createServer(async (req, res) => {
  const u = new URL(req.url, `http://${req.headers.host}`);
  
  if (u.pathname === '/') return send(res, 200, { ok: true, service: 'vibely-extractor' });
  
  // Usado pelo app para "acordar" o servidor do plano grátis
  if (u.pathname === '/health') return send(res, 200, { ok: true });
  
  if (AUTH_KEY && u.searchParams.get('key') !== AUTH_KEY) {
    return send(res, 401, { error: 'não autorizado' });
  }
  
  if (u.pathname === '/extract') {
    const id = u.searchParams.get('id');
    if (!id || !/^[\w-]{6,20}$/.test(id)) return send(res, 400, { error: 'id inválido' });
    try {
      const data = await extract(id);
      return send(res, 200, data);
    } catch (e) {
      return send(res, 502, { error: e.message, details: e.details || [] });
    }
  }
  
  send(res, 404, { error: 'não encontrado' });
}).listen(PORT, () => console.log('vibely-extractor na porta ' + PORT));