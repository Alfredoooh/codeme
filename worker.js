import { extractText, getDocumentProxy } from "unpdf";

// ══════════════════════════════════════════════════════════════
// WORKER — DeepSeek V4 (Flash + Pro, thinking on/off), streaming,
// título automático obrigatório, resposta com marcador de "processo"
// para o cliente poder ocultar streaming de blocos especiais
// (documentos, tabelas, gráficos) atrás de um pill.
// ══════════════════════════════════════════════════════════════

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const DEEPSEEK_BASE = "https://api.deepseek.com/v1";

// Modelos atuais da API DeepSeek (V4). Os nomes antigos
// deepseek-chat / deepseek-reasoner foram descontinuados em
// 24/07/2026 — não usar mais.
const DEEPSEEK_MODELS = {
  flash: {
    model: "deepseek-v4-flash",
    max_tokens: 8192,
    temperature: 1.0,
    thinking: "disabled",
  },
  pro: {
    model: "deepseek-v4-pro",
    max_tokens: 8192,
    temperature: 1.0,
    thinking: "disabled",
  },
  reasoning: {
    model: "deepseek-v4-flash",
    max_tokens: 65536,
    thinking: "enabled",
    reasoning_effort: "high",
    // temperature omitida de propósito: a API ignora esse campo
    // quando thinking está enabled.
  },
};

const GROQ_BASE = "https://api.groq.com/openai/v1";
const GOPAY_BASE = "https://rouxavcvorjiwhpjhsye.supabase.co/functions/v1/api-v1";

const FREE_CREDITS = 100;
const CREDIT_PACKAGES = {
  basic:   { credits: 500,  price: 2500, name: "Básico",  productId: "SUBSTITUI_PELO_ID_BASICO"  },
  premium: { credits: 1500, price: 7500, name: "Premium", productId: "db3b0e10-d3da-439b-9c0c-06c112ba524b" },
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: Object.assign({}, CORS_HEADERS, { "Content-Type": "application/json" }),
  });
}

function error(msg, status = 400) {
  return json({ error: msg }, status);
}

function randomId(bytes = 16) {
  const arr = new Uint8Array(bytes);
  crypto.getRandomValues(arr);
  return Array.from(arr, function(b) { return b.toString(16).padStart(2, "0"); }).join("");
}

async function hashPassword(password) {
  const enc  = new TextEncoder().encode(password);
  const hash = await crypto.subtle.digest("SHA-256", enc);
  return btoa(String.fromCharCode(...new Uint8Array(hash)));
}

async function generateToken(payload, secret, env) {
  const jti = randomId(16);
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body   = btoa(JSON.stringify(Object.assign({}, payload, {
    jti,
    iat: Date.now(),
    exp: Date.now() + 30 * 24 * 60 * 60 * 1000,
  })));
  const msg = header + "." + body;
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sig    = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(msg));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  const token = msg + "." + sigB64;
  if (env && env.IPC_USERS) {
    await env.IPC_USERS.put(
      "session:" + jti,
      JSON.stringify({ userId: payload.id, createdAt: Date.now() }),
      { expirationTtl: 30 * 24 * 60 * 60 }
    );
  }
  return token;
}

async function verifyToken(token, secret, env) {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const msg = parts[0] + "." + parts[1];
    const key = await crypto.subtle.importKey(
      "raw", new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" }, false, ["verify"]
    );
    const sigBytes = Uint8Array.from(
      atob(parts[2].replace(/-/g, "+").replace(/_/g, "/")),
      function(c) { return c.charCodeAt(0); }
    );
    const valid = await crypto.subtle.verify("HMAC", key, sigBytes, new TextEncoder().encode(msg));
    if (!valid) return null;
    const payload = JSON.parse(atob(parts[1]));
    if (payload.exp < Date.now()) return null;
    if (payload.jti && env && env.IPC_USERS) {
      const session = await env.IPC_USERS.get("session:" + payload.jti);
      if (!session) return null;
    }
    return payload;
  } catch (e) { return null; }
}

async function getAuthUser(request, env) {
  const auth = request.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return null;
  return verifyToken(auth.slice(7), env.JWT_SECRET, env);
}

async function requireAdmin(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return null;
  const userData = await env.IPC_USERS.get("user:" + payload.id);
  if (!userData) return null;
  const user = JSON.parse(userData);
  if (!user.isAdmin) return null;
  return user;
}

async function verifyFirebaseToken(idToken, projectId) {
  try {
    const parts = idToken.split(".");
    if (parts.length !== 3) return null;
    const header  = JSON.parse(atob(parts[0].replace(/-/g, "+").replace(/_/g, "/")));
    const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp < now)            return null;
    if (payload.iat > now + 300)      return null;
    if (payload.aud !== projectId)    return null;
    if (payload.iss !== "https://securetoken.google.com/" + projectId) return null;
    if (!payload.sub || payload.sub.length === 0) return null;
    const publicKeys = await fetch("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com").then(r => r.json());
    const certPem    = publicKeys[header.kid];
    if (!certPem) return null;
    const certCleaned = certPem
      .replace(/-----BEGIN CERTIFICATE-----/, "")
      .replace(/-----END CERTIFICATE-----/, "")
      .replace(/\n/g, "").trim();
    const certDer = Uint8Array.from(atob(certCleaned), function(c) { return c.charCodeAt(0); });
    const spkiKey = extractSpkiFromCert(certDer);
    if (!spkiKey) return null;
    const cryptoKey = await crypto.subtle.importKey(
      "spki", spkiKey,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false, ["verify"]
    );
    const signingInput = parts[0] + "." + parts[1];
    const sigBytes     = Uint8Array.from(
      atob(parts[2].replace(/-/g, "+").replace(/_/g, "/")),
      function(c) { return c.charCodeAt(0); }
    );
    const valid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", cryptoKey, sigBytes, new TextEncoder().encode(signingInput));
    if (!valid) return null;
    return {
      uid:      payload.sub,
      email:    payload.email   || null,
      name:     payload.name    || null,
      picture:  payload.picture || null,
      provider: (payload.firebase && payload.firebase.sign_in_provider) || "unknown",
    };
  } catch (e) {
    console.error("[FIREBASE VERIFY ERROR]", e.message);
    return null;
  }
}

function extractSpkiFromCert(certDer) {
  try {
    function readLength(buf, off) {
      if (buf[off] < 0x80) return { len: buf[off], next: off + 1 };
      const numBytes = buf[off] & 0x7f;
      let len = 0;
      for (let i = 0; i < numBytes; i++) { len = (len << 8) | buf[off + 1 + i]; }
      return { len: len, next: off + 1 + numBytes };
    }
    function skipTag(buf, off) {
      off++;
      const r = readLength(buf, off);
      return r.next + r.len;
    }
    function enterSequence(buf, off) {
      if (buf[off] !== 0x30) return null;
      off++;
      const r = readLength(buf, off);
      return r.next;
    }
    let pos = enterSequence(certDer, 0);
    if (pos === null) return null;
    pos = enterSequence(certDer, pos);
    if (pos === null) return null;
    if (certDer[pos] === 0xa0) { pos = skipTag(certDer, pos); }
    pos = skipTag(certDer, pos);
    pos = skipTag(certDer, pos);
    pos = skipTag(certDer, pos);
    pos = skipTag(certDer, pos);
    pos = skipTag(certDer, pos);
    if (certDer[pos] !== 0x30) return null;
    const spkiStart = pos;
    pos++;
    const r       = readLength(certDer, pos);
    const spkiEnd = r.next + r.len;
    return certDer.slice(spkiStart, spkiEnd).buffer;
  } catch (e) {
    console.error("[SPKI EXTRACT ERROR]", e.message);
    return null;
  }
}

// ══════════════════════════════════════════════════════════════
// DEEPSEEK V4 — chamadas de chat (stream e não-stream). Formato
// OpenAI-compatible: messages: [{role, content}], stream: bool.
// thinking / reasoning_effort controlam o modo de raciocínio no
// V4-Flash — não são mais nomes de modelo separados.
// ══════════════════════════════════════════════════════════════

function buildSystemInstruction(language, customSystemPrompt) {
  if (customSystemPrompt && customSystemPrompt.trim().length > 0) return customSystemPrompt;
  return language === "en"
    ? "You are Nexa, a helpful AI assistant. Always respond in English. Be concise and direct. When the user asks for a table, use markdown table format. When providing code, always wrap it in fenced code blocks with the language identifier."
    : "Es Nexa, um assistente de IA util. Responde sempre em portugues. Se conciso e direto. Quando o utilizador pedir uma tabela, usa formato de tabela markdown. Quando deres codigo, coloca-o sempre em blocos com o identificador de linguagem.";
}

function buildDeepseekMessages(messages, systemPrompt, language) {
  const sysContent = systemPrompt && systemPrompt.trim().length > 0
    ? systemPrompt
    : buildSystemInstruction(language || "pt", "");
  return [
    { role: "system", content: sysContent },
    ...messages.filter(function(m) { return m.role !== "system"; })
      .map(function(m) { return { role: m.role, content: m.content }; }),
  ];
}

async function deepseekChat(apiKey, messages, modelKey, systemPrompt, language, stream) {
  const cfg = DEEPSEEK_MODELS[modelKey] || DEEPSEEK_MODELS.flash;
  const allMessages = buildDeepseekMessages(messages, systemPrompt, language);

  const requestBody = {
    model: cfg.model,
    messages: allMessages,
    max_tokens: cfg.max_tokens,
    stream: !!stream,
  };

  if (cfg.temperature !== undefined) requestBody.temperature = cfg.temperature;
  if (cfg.thinking !== undefined) requestBody.thinking = cfg.thinking;
  if (cfg.reasoning_effort !== undefined) requestBody.reasoning_effort = cfg.reasoning_effort;

  return fetch(DEEPSEEK_BASE + "/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + apiKey },
    body: JSON.stringify(requestBody),
  });
}

async function deepseekGenerateTitle(apiKey, message, language) {
  const prompt = language === "en"
    ? "Generate a short, natural title (max 6 words) that summarizes the topic of a conversation that starts with this message: \"" + message + "\". Reply with ONLY the title text, no punctuation, no quotes, no prefix like 'Title:'."
    : "Gera um titulo curto e natural (max 6 palavras) que resuma o tema de uma conversa que comeca com esta mensagem: \"" + message + "\". Responde APENAS com o texto do titulo, sem pontuacao, sem aspas, sem prefixo como 'Titulo:'.";
  try {
    const res = await fetch(DEEPSEEK_BASE + "/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": "Bearer " + apiKey },
      body: JSON.stringify({
        model: "deepseek-v4-flash",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 24,
        temperature: 0.4,
        thinking: "disabled",
        stream: false,
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const text = data.choices?.[0]?.message?.content || "";
    const cleaned = text.trim().replace(/^["'“]|["'”]$/g, "").slice(0, 48);
    return cleaned.length > 0 ? cleaned : null;
  } catch (e) {
    console.error("[NEXA TITLE ERROR]", e.message);
    return null;
  }
}

async function groqChat(apiKey, messages, model, systemPrompt, language) {
  const sysContent = systemPrompt && systemPrompt.trim().length > 0
    ? systemPrompt
    : buildSystemInstruction(language || "pt", "");
  const allMessages = [
    { role: "system", content: sysContent },
    ...messages.filter(function(m) { return m.role !== "system"; }),
  ];
  return fetch(GROQ_BASE + "/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + apiKey },
    body: JSON.stringify({
      model: model || "llama-3.3-70b-versatile",
      messages: allMessages,
      max_tokens: 8192,
      temperature: 0.7,
      stream: false,
    }),
  });
}

async function groqChatStream(apiKey, messages, model, systemPrompt, language) {
  const sysContent = systemPrompt && systemPrompt.trim().length > 0
    ? systemPrompt
    : buildSystemInstruction(language || "pt", "");
  const allMessages = [
    { role: "system", content: sysContent },
    ...messages.filter(function(m) { return m.role !== "system"; }),
  ];
  return fetch(GROQ_BASE + "/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + apiKey },
    body: JSON.stringify({
      model: model || "llama-3.3-70b-versatile",
      messages: allMessages,
      max_tokens: 8192,
      temperature: 0.7,
      stream: true,
    }),
  });
}

// ══════════════════════════════════════════════════════════════
// PDF EXTRACTION (unpdf)
// ══════════════════════════════════════════════════════════════

async function extractPdfText(base64Data) {
  try {
    const binaryStr = atob(base64Data);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) bytes[i] = binaryStr.charCodeAt(i);
    const pdf = await getDocumentProxy(bytes);
    const { text } = await extractText(pdf, { mergePages: true });
    return text || "";
  } catch (e) {
    console.error("[NEXA PDF EXTRACT ERROR]", e.message);
    return null;
  }
}

async function expandMessagesWithAttachments(messages) {
  const expanded = [];
  for (const m of messages) {
    if (!m.attachments || m.attachments.length === 0) {
      expanded.push(m);
      continue;
    }
    let extraText = "";
    for (const att of m.attachments) {
      const mime = (att.mimeType || "").toLowerCase();
      if (mime === "application/pdf" && att.base64) {
        const text = await extractPdfText(att.base64);
        if (text && text.trim().length > 0) {
          const truncated = text.length > 12000 ? text.slice(0, 12000) + "\n[...texto truncado...]" : text;
          extraText += "\n\n[Conteúdo extraído do PDF \"" + (att.name || "documento.pdf") + "\"]:\n" + truncated;
        } else {
          extraText += "\n\n[Não foi possível extrair texto do PDF \"" + (att.name || "documento.pdf") + "\" — pode ser um PDF de imagens/scan.]";
        }
      }
      // Imagens e outros tipos: ignorados aqui: o cliente já informa
      // o utilizador que não são analisados nesta versão.
    }
    expanded.push({
      role: m.role,
      content: extraText ? m.content + extraText : m.content,
    });
  }
  return expanded;
}

// ══════════════════════════════════════════════════════════════
// AGENDA — eventos simples por utilizador.
// ══════════════════════════════════════════════════════════════

async function handleListEvents(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const raw = await env.IPC_USERS.get("events:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  const all = await Promise.all(ids.map(async function(id) {
    const data = await env.IPC_USERS.get("event:" + id);
    return data ? JSON.parse(data) : null;
  }));
  const events = all.filter(function(e) { return e !== null; })
    .sort(function(a, b) { return a.startAt - b.startAt; });
  return json({ events });
}

async function handleCreateEvent(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.title || !body.startAt) return error("Campos 'title' e 'startAt' obrigatórios");
  const id = crypto.randomUUID();
  const event = {
    id, userId: payload.id,
    title: body.title,
    description: body.description || "",
    startAt: Number(body.startAt),
    endAt: body.endAt ? Number(body.endAt) : Number(body.startAt) + 3600000,
    allDay: !!body.allDay,
    color: body.color || "#6F5AF6",
    createdAt: Date.now(),
  };
  await env.IPC_USERS.put("event:" + id, JSON.stringify(event));
  const raw = await env.IPC_USERS.get("events:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  ids.push(id);
  await env.IPC_USERS.put("events:" + payload.id, JSON.stringify(ids));
  return json(event, 201);
}

async function handleUpdateEvent(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id = new URL(request.url).pathname.split("/").pop();
  const data = await env.IPC_USERS.get("event:" + id);
  if (!data) return error("Evento não encontrado", 404);
  const event = JSON.parse(data);
  if (event.userId !== payload.id) return error("Acesso negado", 403);
  const body = await request.json().catch(function() { return null; });
  if (!body) return error("Body inválido");
  if (body.title       !== undefined) event.title       = body.title;
  if (body.description !== undefined) event.description = body.description;
  if (body.startAt     !== undefined) event.startAt     = Number(body.startAt);
  if (body.endAt       !== undefined) event.endAt       = Number(body.endAt);
  if (body.allDay      !== undefined) event.allDay      = !!body.allDay;
  if (body.color       !== undefined) event.color       = body.color;
  await env.IPC_USERS.put("event:" + id, JSON.stringify(event));
  return json(event);
}

async function handleDeleteEvent(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id = new URL(request.url).pathname.split("/").pop();
  const data = await env.IPC_USERS.get("event:" + id);
  if (!data) return error("Evento não encontrado", 404);
  const event = JSON.parse(data);
  if (event.userId !== payload.id) return error("Acesso negado", 403);
  await env.IPC_USERS.delete("event:" + id);
  const raw = await env.IPC_USERS.get("events:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  await env.IPC_USERS.put("events:" + payload.id, JSON.stringify(ids.filter(function(i) { return i !== id; })));
  return json({ success: true });
}

// ══════════════════════════════════════════════════════════════
// PROJECTS (auxiliares mantidos apenas para o admin poder limpar
// dados legados de utilizadores criados antes desta versão. Não
// há endpoints públicos para criar/editar/listar projetos.)
// ══════════════════════════════════════════════════════════════

async function loadProjectIndex(env, userId) {
  const raw = await env.IPC_USERS.get("projidx:" + userId);
  return raw ? JSON.parse(raw) : [];
}

async function deleteProjectNode(env, userId, id) {
  await env.IPC_USERS.delete("proj:" + userId + ":" + id);
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
    const url  = new URL(request.url);
    const path = url.pathname;

    if (path === "/auth/register"                        && request.method === "POST")   return handleRegister(request, env);
    if (path === "/auth/login"                           && request.method === "POST")   return handleLogin(request, env);
    if (path === "/auth/logout"                          && request.method === "POST")   return handleLogout(request, env);
    if (path === "/auth/logout-all"                      && request.method === "POST")   return handleLogoutAll(request, env);
    if (path === "/auth/firebase"                        && request.method === "POST")   return handleFirebaseAuth(request, env);
    if (path === "/auth/forgot-password"                 && request.method === "POST")   return handleForgotPassword(request, env);
    if (path === "/auth/reset-password"                  && request.method === "POST")   return handleResetPassword(request, env);
    if (path === "/user/me"                              && request.method === "GET")    return handleGetMe(request, env);
    if (path === "/user/me"                              && request.method === "PUT")    return handleUpdateMe(request, env);
    if (path === "/user/profile"                         && request.method === "PUT")    return handleUpdateProfile(request, env);
    if (path === "/user/avatar"                          && request.method === "PUT")    return handleUpdateAvatar(request, env);
    if (path === "/ai/chat"                              && request.method === "POST")   return handleAiChat(request, env);
    if (path === "/ai/title"                             && request.method === "POST")   return handleAiTitle(request, env);
    if (path === "/ai/summarize"                         && request.method === "POST")   return handleAiSummarize(request, env);
    if (path === "/ai/transcribe"                        && request.method === "POST")   return handleAiTranscribe(request, env);
    if (path === "/ai/suggest"                           && request.method === "GET")    return handleAiSuggest(request, env);
    if (path === "/credits/balance"                      && request.method === "GET")    return handleCreditsBalance(request, env);
    if (path === "/credits/checkout"                     && request.method === "POST")   return handleCreditsCheckout(request, env);
    if (path === "/credits/webhook"                      && request.method === "POST")   return handleCreditsWebhook(request, env);
    if (path === "/conversations"                        && request.method === "GET")    return handleListConversations(request, env);
    if (path === "/conversations"                        && request.method === "POST")   return handleCreateConversation(request, env);
    if (path === "/conversations/all"                    && request.method === "DELETE") return handleDeleteAllConversations(request, env);
    if (path === "/conversations/search"                 && request.method === "GET")    return handleSearchConversations(request, env);
    if (path.match(/^\/conversations\/[^/]+$/)           && request.method === "GET")    return handleGetConversation(request, env);
    if (path.match(/^\/conversations\/[^/]+$/)           && request.method === "PUT")    return handleUpdateConversation(request, env);
    if (path.match(/^\/conversations\/[^/]+$/)           && request.method === "DELETE") return handleDeleteConversation(request, env);
    if (path.match(/^\/conversations\/[^/]+\/pin$/)      && request.method === "PUT")    return handlePinConversation(request, env);
    if (path.match(/^\/conversations\/[^/]+\/archive$/)  && request.method === "PUT")    return handleArchiveConversation(request, env);

    if (path === "/events"                                && request.method === "GET")    return handleListEvents(request, env);
    if (path === "/events"                                && request.method === "POST")   return handleCreateEvent(request, env);
    if (path.match(/^\/events\/[^/]+$/)                   && request.method === "PUT")    return handleUpdateEvent(request, env);
    if (path.match(/^\/events\/[^/]+$/)                   && request.method === "DELETE") return handleDeleteEvent(request, env);

    if (path === "/admin/stats"                                       && request.method === "GET")    return handleAdminStats(request, env);
    if (path === "/admin/users"                                       && request.method === "GET")    return handleAdminListUsers(request, env);
    if (path.match(/^\/admin\/users\/[^/]+$/)                         && request.method === "GET")    return handleAdminGetUser(request, env);
    if (path.match(/^\/admin\/users\/[^/]+$/)                         && request.method === "PUT")    return handleAdminUpdateUser(request, env);
    if (path.match(/^\/admin\/users\/[^/]+$/)                         && request.method === "DELETE") return handleAdminDeleteUser(request, env);
    if (path.match(/^\/admin\/users\/[^/]+\/block$/)                  && request.method === "PUT")    return handleAdminBlockUser(request, env);
    if (path.match(/^\/admin\/users\/[^/]+\/credits$/)                && request.method === "PUT")    return handleAdminSetCredits(request, env);
    if (path.match(/^\/admin\/users\/[^/]+\/conversations$/)          && request.method === "GET")    return handleAdminUserConversations(request, env);
    if (path === "/admin/notify"                                       && request.method === "POST")   return handleAdminNotify(request, env);

    return error("Not found", 404);
  },
};

async function handleRegister(request, env) {
  const body = await request.json().catch(function() { return null; });
  if (!body) return error("Body inválido");
  const { name, email, password } = body;
  if (!name || !email || !password) return error("Campos obrigatórios em falta");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return error("Email inválido");
  if (password.length < 6) return error("Password deve ter pelo menos 6 caracteres");
  const existing = await env.IPC_USERS.get("email:" + email.toLowerCase());
  if (existing) return error("Este email já está registado");
  const id           = crypto.randomUUID();
  const passwordHash = await hashPassword(password);
  const user = {
    id, name, email: email.toLowerCase(),
    passwordHash, avatar: null, provider: "email", firebaseUid: null,
    credits: FREE_CREDITS, isAdmin: false, blocked: false,
    preferences: { language: "pt", theme: "system", fontSize: "medium" },
    profile: {
      age: body.age || null, country: body.country || null,
      state: body.state || null, city: body.city || null,
      occupation: body.occupation || null, occupationDetail: body.occupationDetail || null, bio: null,
    },
    stats: { totalConversations: 0, totalMessages: 0 },
    createdAt: Date.now(),
  };
  await env.IPC_USERS.put("user:" + id, JSON.stringify(user));
  await env.IPC_USERS.put("email:" + email.toLowerCase(), id);
  await env.IPC_USERS.put("useridx:" + id, "1");
  const token = await generateToken({ id, email: user.email, name }, env.JWT_SECRET, env);
  return json({ token, id, name, email: user.email, credits: FREE_CREDITS }, 201);
}

async function handleLogin(request, env) {
  const body = await request.json().catch(function() { return null; });
  if (!body) return error("Body inválido");
  const { email, password } = body;
  if (!email || !password) return error("Campos obrigatórios em falta");
  const userId = await env.IPC_USERS.get("email:" + email.toLowerCase());
  if (!userId) return error("Email ou password incorretos", 401);
  const userData = await env.IPC_USERS.get("user:" + userId);
  if (!userData) return error("Email ou password incorretos", 401);
  const user = JSON.parse(userData);
  if (user.blocked) return error("Esta conta foi bloqueada", 403);
  if (user.passwordHash !== await hashPassword(password)) return error("Email ou password incorretos", 401);
  const token = await generateToken({ id: user.id, email: user.email, name: user.name }, env.JWT_SECRET, env);
  return json({ token, id: user.id, name: user.name, email: user.email, credits: user.credits ?? FREE_CREDITS, preferences: user.preferences || {} });
}

async function handleLogout(request, env) {
  const auth = request.headers.get("Authorization") || "";
  if (auth.startsWith("Bearer ")) {
    const token = auth.slice(7);
    const parts = token.split(".");
    if (parts.length === 3) {
      try {
        const payload = JSON.parse(atob(parts[1]));
        if (payload.jti) await env.IPC_USERS.delete("session:" + payload.jti);
      } catch (e) {}
    }
  }
  return json({ success: true });
}

async function handleLogoutAll(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  await env.IPC_USERS.put("session_epoch:" + payload.id, String(Date.now()));
  return json({ success: true });
}

async function handleFirebaseAuth(request, env) {
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.idToken) return error("idToken obrigatório");
  const projectId    = env.FIREBASE_PROJECT_ID;
  const firebaseUser = await verifyFirebaseToken(body.idToken, projectId);
  if (!firebaseUser) return error("Token Firebase inválido ou expirado", 401);
  const uid = firebaseUser.uid;
  let userId = await env.IPC_USERS.get("firebase:" + uid);
  if (!userId) {
    if (firebaseUser.email) userId = await env.IPC_USERS.get("email:" + firebaseUser.email.toLowerCase());
    if (!userId) {
      userId = crypto.randomUUID();
      const user = {
        id: userId,
        name: firebaseUser.name || firebaseUser.email || "Utilizador Nexa",
        email: firebaseUser.email ? firebaseUser.email.toLowerCase() : null,
        passwordHash: null, avatar: firebaseUser.picture || null,
        provider: firebaseUser.provider, firebaseUid: uid,
        credits: FREE_CREDITS, isAdmin: false, blocked: false,
        preferences: { language: "pt", theme: "system", fontSize: "medium" },
        profile: { age: null, country: null, state: null, city: null, occupation: null, occupationDetail: null, bio: null },
        stats: { totalConversations: 0, totalMessages: 0 },
        createdAt: Date.now(),
      };
      await env.IPC_USERS.put("user:" + userId, JSON.stringify(user));
      if (firebaseUser.email) await env.IPC_USERS.put("email:" + firebaseUser.email.toLowerCase(), userId);
      await env.IPC_USERS.put("useridx:" + userId, "1");
    } else {
      const userData = await env.IPC_USERS.get("user:" + userId);
      if (userData) {
        const user = JSON.parse(userData);
        user.firebaseUid = uid;
        user.provider    = firebaseUser.provider;
        if (!user.avatar && firebaseUser.picture) user.avatar = firebaseUser.picture;
        if (!user.name   && firebaseUser.name)    user.name   = firebaseUser.name;
        await env.IPC_USERS.put("user:" + userId, JSON.stringify(user));
      }
    }
    await env.IPC_USERS.put("firebase:" + uid, userId);
  }
  const userData = await env.IPC_USERS.get("user:" + userId);
  if (!userData) return error("Erro ao carregar utilizador", 500);
  const user  = JSON.parse(userData);
  if (user.blocked) return error("Esta conta foi bloqueada", 403);
  const token = await generateToken({ id: user.id, email: user.email, name: user.name }, env.JWT_SECRET, env);
  return json({ token, id: user.id, name: user.name, email: user.email, avatar: user.avatar || null, provider: user.provider, credits: user.credits ?? FREE_CREDITS, preferences: user.preferences || {} });
}

async function handleForgotPassword(request, env) {
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.email) return error("Email obrigatório");
  const email  = body.email.toLowerCase();
  const userId = await env.IPC_USERS.get("email:" + email);
  if (userId) {
    const resetToken = randomId(24);
    await env.IPC_USERS.put("reset:" + resetToken, JSON.stringify({ userId, email, createdAt: Date.now() }), { expirationTtl: 3600 });
    console.log("[NEXA RESET] Token para " + email + ": " + resetToken);
  }
  return json({ success: true, message: "Se a conta existir, receberás um email com as instruções." });
}

async function handleResetPassword(request, env) {
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.token || !body.password) return error("Token e password obrigatórios");
  if (body.password.length < 6) return error("Password deve ter pelo menos 6 caracteres");
  const resetData = await env.IPC_USERS.get("reset:" + body.token);
  if (!resetData) return error("Token inválido ou expirado", 400);
  const userId   = JSON.parse(resetData).userId;
  const userData = await env.IPC_USERS.get("user:" + userId);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  user.passwordHash = await hashPassword(body.password);
  await env.IPC_USERS.put("user:" + userId, JSON.stringify(user));
  await env.IPC_USERS.delete("reset:" + body.token);
  return json({ success: true, message: "Password atualizada com sucesso." });
}

async function handleGetMe(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const userData = await env.IPC_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  return json({
    id: user.id, name: user.name, email: user.email, avatar: user.avatar || null,
    provider: user.provider || "email", credits: user.credits ?? FREE_CREDITS,
    preferences: user.preferences || {}, profile: user.profile || {},
    isAdmin: !!user.isAdmin, stats: user.stats || {}, createdAt: user.createdAt,
  });
}

async function handleUpdateMe(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body) return error("Body inválido");
  const userData = await env.IPC_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  if (body.name) user.name = body.name.trim();
  if (body.password) {
    if (body.password.length < 6) return error("Password deve ter pelo menos 6 caracteres");
    user.passwordHash = await hashPassword(body.password);
  }
  if (body.preferences && typeof body.preferences === "object") {
    user.preferences = Object.assign({}, user.preferences || {}, body.preferences);
  }
  await env.IPC_USERS.put("user:" + user.id, JSON.stringify(user));
  return json({ id: user.id, name: user.name, email: user.email, avatar: user.avatar || null, provider: user.provider || "email", credits: user.credits ?? FREE_CREDITS, preferences: user.preferences || {}, profile: user.profile || {}, createdAt: user.createdAt });
}

async function handleUpdateProfile(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body) return error("Body inválido");
  const userData = await env.IPC_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  const allowed = ["age", "country", "state", "city", "occupation", "occupationDetail", "bio"];
  const nextProfile = Object.assign({}, user.profile || {});
  for (const key of allowed) {
    if (body[key] !== undefined) nextProfile[key] = body[key];
  }
  if (nextProfile.age !== null && nextProfile.age !== undefined) {
    const ageNum = Number(nextProfile.age);
    if (!Number.isFinite(ageNum) || ageNum < 0 || ageNum > 120) return error("Idade inválida");
    nextProfile.age = ageNum;
  }
  if (nextProfile.occupation && !["student", "professional", "other"].includes(nextProfile.occupation)) {
    return error("Campo 'occupation' inválido (student | professional | other)");
  }
  user.profile = nextProfile;
  await env.IPC_USERS.put("user:" + user.id, JSON.stringify(user));
  return json({ profile: user.profile });
}

async function handleUpdateAvatar(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.avatar) return error("avatar obrigatório");
  if (body.avatar.length > 270000) return error("Imagem demasiado grande (máx ~200KB)");
  const userData = await env.IPC_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  user.avatar = body.avatar;
  await env.IPC_USERS.put("user:" + user.id, JSON.stringify(user));
  return json({ avatar: user.avatar });
}

async function handleListConversations(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const url      = new URL(request.url);
  const archived = url.searchParams.get("archived") === "true";
  const raw      = await env.IPC_USERS.get("convs:" + payload.id);
  const ids      = raw ? JSON.parse(raw) : [];
  const all      = await Promise.all(ids.map(async function(id) {
    const data = await env.IPC_USERS.get("conv:" + id);
    return data ? JSON.parse(data) : null;
  }));
  const conversations = all
    .filter(function(c) { return c !== null && (archived ? c.archived === true : !c.archived); })
    .sort(function(a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.updatedAt - a.updatedAt;
    });
  return json({ conversations });
}

async function handleCreateConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body) return error("Body inválido");
  const id  = crypto.randomUUID();
  const now = Date.now();
  const conversation = {
    id, userId: payload.id,
    title:    body.title    || "Nova conversa",
    messages: body.messages || [],
    model:    body.model    || "deepseek-v4-flash",
    pinned: false, archived: false,
    tags: body.tags || [],
    createdAt: now, updatedAt: now,
  };
  await env.IPC_USERS.put("conv:" + id, JSON.stringify(conversation));
  const raw = await env.IPC_USERS.get("convs:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  ids.unshift(id);
  await env.IPC_USERS.put("convs:" + payload.id, JSON.stringify(ids));
  await incrementUserStat(env, payload.id, "totalConversations", 1);
  return json(conversation, 201);
}

async function handleGetConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id   = new URL(request.url).pathname.split("/").pop();
  const data = await env.IPC_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  return json(conversation);
}

async function handleUpdateConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id   = new URL(request.url).pathname.split("/").pop();
  const data = await env.IPC_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  const body = await request.json().catch(function() { return null; });
  if (!body) return error("Body inválido");
  if (body.title    !== undefined) conversation.title    = body.title;
  if (body.messages !== undefined) {
    const added = body.messages.length - conversation.messages.length;
    if (added > 0) await incrementUserStat(env, payload.id, "totalMessages", added);
    conversation.messages = body.messages;
  }
  if (body.model !== undefined) conversation.model = body.model;
  if (body.tags  !== undefined) conversation.tags  = body.tags;
  conversation.updatedAt = Date.now();
  await env.IPC_USERS.put("conv:" + id, JSON.stringify(conversation));
  return json(conversation);
}

async function handleDeleteConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id   = new URL(request.url).pathname.split("/").pop();
  const data = await env.IPC_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  await env.IPC_USERS.delete("conv:" + id);
  const raw     = await env.IPC_USERS.get("convs:" + payload.id);
  const ids     = raw ? JSON.parse(raw) : [];
  const updated = ids.filter(function(i) { return i !== id; });
  await env.IPC_USERS.put("convs:" + payload.id, JSON.stringify(updated));
  await incrementUserStat(env, payload.id, "totalConversations", -1);
  return json({ success: true });
}

async function handleDeleteAllConversations(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const raw = await env.IPC_USERS.get("convs:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  await Promise.all(ids.map(function(id) { return env.IPC_USERS.delete("conv:" + id); }));
  await env.IPC_USERS.put("convs:" + payload.id, JSON.stringify([]));
  const userData = await env.IPC_USERS.get("user:" + payload.id);
  if (userData) {
    const user = JSON.parse(userData);
    if (user.stats) user.stats.totalConversations = 0;
    await env.IPC_USERS.put("user:" + payload.id, JSON.stringify(user));
  }
  return json({ success: true, deleted: ids.length });
}

async function handlePinConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const parts = new URL(request.url).pathname.split("/");
  const id    = parts[2];
  const data  = await env.IPC_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  const body = await request.json().catch(function() { return {}; });
  conversation.pinned    = body.pinned !== undefined ? body.pinned : !conversation.pinned;
  conversation.updatedAt = Date.now();
  await env.IPC_USERS.put("conv:" + id, JSON.stringify(conversation));
  return json({ id, pinned: conversation.pinned });
}

async function handleArchiveConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const parts = new URL(request.url).pathname.split("/");
  const id    = parts[2];
  const data  = await env.IPC_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  const body = await request.json().catch(function() { return {}; });
  conversation.archived  = body.archived !== undefined ? body.archived : !conversation.archived;
  conversation.pinned    = false;
  conversation.updatedAt = Date.now();
  await env.IPC_USERS.put("conv:" + id, JSON.stringify(conversation));
  return json({ id, archived: conversation.archived });
}

async function handleSearchConversations(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const url   = new URL(request.url);
  const query = (url.searchParams.get("q") || "").toLowerCase().trim();
  if (!query) return json({ conversations: [] });
  const raw = await env.IPC_USERS.get("convs:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  const all = await Promise.all(ids.map(async function(id) {
    const data = await env.IPC_USERS.get("conv:" + id);
    return data ? JSON.parse(data) : null;
  }));
  const results = all
    .filter(function(c) {
      if (!c || c.archived) return false;
      if (c.title.toLowerCase().includes(query)) return true;
      return c.messages.some(function(m) { return m.content && m.content.toLowerCase().includes(query); });
    })
    .sort(function(a, b) { return b.updatedAt - a.updatedAt; });
  return json({ conversations: results });
}

async function handleAiTitle(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.message) return error("message obrigatório");
  const title = await deepseekGenerateTitle(env.DEEPSEEK_API_KEY, body.message, body.language || "pt");
  return json({ title: title || "Nova conversa" });
}

// ══════════════════════════════════════════════════════════════
// /ai/chat — DeepSeek V4 (flash | pro | reasoning) ou Groq,
// stream ou não.
// ══════════════════════════════════════════════════════════════

async function handleAiChat(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.messages) return error("messages obrigatório");
  const userData = await env.IPC_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const userObj = JSON.parse(userData);
  if (userObj.blocked) return error("Esta conta foi bloqueada", 403);
  const currentCredits = userObj.credits ?? 0;
  if (currentCredits <= 0) return json({ error: "credits_exhausted", message: "Sem créditos. Recarrega para continuar." }, 402);
  userObj.credits = currentCredits - 1;
  await env.IPC_USERS.put("user:" + payload.id, JSON.stringify(userObj));

  const rawMessages        = body.messages;
  const messages           = await expandMessagesWithAttachments(rawMessages);
  const stream             = body.stream !== undefined ? body.stream : false;
  const language           = body.language || "pt";
  const customSystemPrompt = body.systemPrompt || "";
  const provider           = body.provider || "deepseek";
  const modelKey           = body.model || "flash"; // flash | pro | reasoning

  if (provider === "groq") {
    const groqModel = body.groqModel || "llama-3.3-70b-versatile";
    if (!env.GROQ_API_KEY) return error("Groq não configurado", 500);
    if (stream) {
      const groqRes = await groqChatStream(env.GROQ_API_KEY, messages, groqModel, customSystemPrompt, language);
      if (!groqRes.ok) return error("Erro Groq API: " + await groqRes.text(), groqRes.status);
      return new Response(groqRes.body, {
        headers: Object.assign({}, CORS_HEADERS, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache", "X-Accel-Buffering": "no" }),
      });
    }
    const groqRes = await groqChat(env.GROQ_API_KEY, messages, groqModel, customSystemPrompt, language);
    if (!groqRes.ok) return error("Erro Groq API: " + await groqRes.text(), groqRes.status);
    const data    = await groqRes.json();
    const content = data.choices?.[0]?.message?.content || "";
    return json({ content, reasoning: null, model: groqModel, usage: data.usage || null });
  }

  // provider === "deepseek" (padrão)
  if (!env.DEEPSEEK_API_KEY) return error("DeepSeek não configurado", 500);
  const dsRes = await deepseekChat(env.DEEPSEEK_API_KEY, messages, modelKey, customSystemPrompt, language, stream);
  if (!dsRes.ok) {
    const errText = await dsRes.text();
    console.error("[NEXA CHAT ERROR]", dsRes.status, errText);
    return error("Erro DeepSeek API: " + errText, dsRes.status);
  }

  if (stream) {
    return new Response(dsRes.body, {
      headers: Object.assign({}, CORS_HEADERS, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache", "X-Accel-Buffering": "no" }),
    });
  }

  const data      = await dsRes.json();
  const choice    = data.choices?.[0];
  const content   = choice?.message?.content || "";
  const reasoning = choice?.message?.reasoning_content || null;
  return json({ content, reasoning, model: data.model || modelKey, usage: data.usage || null });
}

async function handleAiSummarize(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.messages) return error("messages obrigatório");
  const language = body.language || "pt";
  const prompt   = language === "en"
    ? "Summarize the following conversation in a few sentences:\n\n"
    : "Resume a seguinte conversa em poucas frases:\n\n";
  const text = body.messages.map(function(m) {
    return (m.role === "user" ? "User: " : "Assistant: ") + m.content;
  }).join("\n");
  if (!env.DEEPSEEK_API_KEY) return error("DeepSeek não configurado", 500);
  const dsRes = await fetch(DEEPSEEK_BASE + "/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + env.DEEPSEEK_API_KEY },
    body: JSON.stringify({
      model: "deepseek-v4-flash",
      messages: [{ role: "user", content: prompt + text }],
      max_tokens: 512,
      temperature: 0.5,
      thinking: "disabled",
      stream: false,
    }),
  });
  if (!dsRes.ok) return error("Erro ao resumir", dsRes.status);
  const data    = await dsRes.json();
  const summary = data.choices?.[0]?.message?.content || "";
  return json({ summary });
}

async function handleAiTranscribe(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  if (!env.GROQ_API_KEY) return error("Groq não configurado", 500);
  let formData;
  try { formData = await request.formData(); }
  catch (e) { return error("Esperado multipart/form-data com campo 'file'"); }
  const audioFile = formData.get("file");
  const language  = formData.get("language") || "pt";
  const prompt    = formData.get("prompt")   || "";
  if (!audioFile) return error("Campo 'file' obrigatório");
  const outForm = new FormData();
  outForm.append("file", audioFile);
  outForm.append("model", "whisper-large-v3-turbo");
  outForm.append("language", language);
  outForm.append("response_format", "json");
  if (prompt) outForm.append("prompt", prompt);
  const groqRes = await fetch(GROQ_BASE + "/audio/transcriptions", {
    method: "POST",
    headers: { "Authorization": "Bearer " + env.GROQ_API_KEY },
    body: outForm,
  });
  if (!groqRes.ok) {
    const errText = await groqRes.text();
    return error("Erro Groq Whisper: " + errText, groqRes.status);
  }
  const data = await groqRes.json();
  return json({ text: data.text || "", language: data.language || language, duration: data.duration || null });
}

async function handleAiSuggest(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const url  = new URL(request.url);
  const q    = (url.searchParams.get("q")    || "").trim();
  const lang = (url.searchParams.get("lang") || "pt-PT").trim();
  if (!q) return json({ suggestions: [] });
  const hl = lang.split("-")[0] || "pt";
  const gl = (lang.split("-")[1] || "PT").toUpperCase();
  const googleUrl = "https://suggestqueries.google.com/complete/search?client=firefox&hl=" + encodeURIComponent(hl) + "&gl=" + encodeURIComponent(gl) + "&q=" + encodeURIComponent(q);
  let googleRes;
  try {
    googleRes = await fetch(googleUrl, { headers: { "User-Agent": "Mozilla/5.0 (compatible; NexaSuggest/1.0)" } });
  } catch (e) {
    return error("Erro ao obter sugestões", 502);
  }
  if (!googleRes.ok) return error("Erro ao obter sugestões", googleRes.status);
  const data = await googleRes.json().catch(function() { return null; });
  const suggestions = data && Array.isArray(data[1]) ? data[1] : [];
  return new Response(JSON.stringify({ suggestions }), {
    status: 200,
    headers: Object.assign({}, CORS_HEADERS, { "Content-Type": "application/json", "Cache-Control": "public, max-age=120" }),
  });
}

async function handleCreditsBalance(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const userData = await env.IPC_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  return json({ credits: user.credits ?? 0, packages: CREDIT_PACKAGES });
}

async function handleCreditsCheckout(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.package) return error("Campo 'package' obrigatório (basic | premium)");
  const pkg = CREDIT_PACKAGES[body.package];
  if (!pkg) return error("Pacote inválido");
  const productId    = pkg.productId;
  const checkoutRes  = await fetch(GOPAY_BASE + "/checkout-links", {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-api-key": env.GOPAY_API_KEY },
    body: JSON.stringify({ product_id: productId }),
  });
  if (!checkoutRes.ok) return error("Erro ao gerar checkout GoPay: " + await checkoutRes.text(), 500);
  const checkout    = await checkoutRes.json();
  const checkoutUrl = checkout.url || checkout.checkout_url || checkout.link || checkout.checkout_link;
  if (!checkoutUrl) return error("GoPay não devolveu URL de checkout: " + JSON.stringify(checkout), 500);
  const pendingKey = "pending_credit:" + productId + ":" + payload.id;
  await env.IPC_USERS.put(pendingKey, JSON.stringify({ userId: payload.id, package: body.package, credits: pkg.credits, createdAt: Date.now() }), { expirationTtl: 3600 });
  return json({ checkout_url: checkoutUrl, product_id: productId, package: body.package, credits: pkg.credits, price: pkg.price });
}

async function handleCreditsWebhook(request, env) {
  const signature = request.headers.get("X-Webhook-Signature") || "";
  const rawBody   = await request.text();
  if (!env.GOPAY_WEBHOOK_SECRET) {
    console.error("[NEXA WEBHOOK] GOPAY_WEBHOOK_SECRET não configurado — recusando webhook por segurança");
    return error("Webhook não configurado", 500);
  }
  if (!signature) return error("Assinatura ausente", 401);
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(env.GOPAY_WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sigBytes = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const expected = btoa(String.fromCharCode(...new Uint8Array(sigBytes)));
  if (expected !== signature) return error("Assinatura inválida", 401);

  let event;
  try { event = JSON.parse(rawBody); } catch { return error("Body inválido"); }
  const eventType  = event.event || event.type || "";
  const isApproved = eventType === "payment.approved" || eventType === "Pagamento Aprovado" || event.status === "completed" || event.status === "approved";
  if (!isApproved) return json({ received: true });
  const productId = event.product_id || event.data?.product_id;
  if (!productId)  return json({ received: true, note: "Sem product_id" });
  const listRes = await env.IPC_USERS.list({ prefix: "pending_credit:" + productId + ":" });
  let pending = null, pendingKey = null;
  if (listRes.keys && listRes.keys.length > 0) {
    pendingKey = listRes.keys[0].name;
    const raw  = await env.IPC_USERS.get(pendingKey);
    if (raw) pending = JSON.parse(raw);
  }
  if (!pending) return json({ received: true, note: "Sem pendente para este produto" });
  const userDataRaw = await env.IPC_USERS.get("user:" + pending.userId);
  if (userDataRaw) {
    const user = JSON.parse(userDataRaw);
    user.credits = (user.credits ?? 0) + pending.credits;
    await env.IPC_USERS.put("user:" + pending.userId, JSON.stringify(user));
  }
  await env.IPC_USERS.delete(pendingKey);
  await env.IPC_USERS.put("purchase:" + crypto.randomUUID(), JSON.stringify({ userId: pending.userId, package: pending.package, credits: pending.credits, productId, paidAt: Date.now() }));
  return json({ success: true, credits_added: pending.credits });
}

async function incrementUserStat(env, userId, stat, delta) {
  try {
    const userData = await env.IPC_USERS.get("user:" + userId);
    if (!userData) return;
    const user = JSON.parse(userData);
    if (!user.stats) user.stats = {};
    user.stats[stat] = (user.stats[stat] || 0) + delta;
    if (user.stats[stat] < 0) user.stats[stat] = 0;
    await env.IPC_USERS.put("user:" + userId, JSON.stringify(user));
  } catch (e) {
    console.error("[NEXA STAT ERROR]", e);
  }
}

// ===================== ADMIN =====================

async function handleAdminStats(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  let totalUsers = 0;
  let cursor = undefined;
  while (true) {
    const list = await env.IPC_USERS.list({ prefix: "user:", limit: 1000, cursor });
    totalUsers += list.keys.filter(function(k) {
      return !k.name.slice("user:".length).includes(":");
    }).length;
    if (list.list_complete) break;
    cursor = list.cursor;
  }
  return json({ totalUsers });
}

async function handleAdminListUsers(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const ids = [];
  let cursor = undefined;
  while (true) {
    const list = await env.IPC_USERS.list({ prefix: "user:", limit: 1000, cursor });
    list.keys.forEach(function(k) {
      const id = k.name.slice("user:".length);
      if (id && !id.includes(":")) ids.push(id);
    });
    if (list.list_complete) break;
    cursor = list.cursor;
  }
  const users = await Promise.all(ids.map(async function(id) {
    const raw = await env.IPC_USERS.get("user:" + id);
    if (!raw) return null;
    const u = JSON.parse(raw);
    return {
      id: u.id, name: u.name, email: u.email, avatar: u.avatar || null,
      credits: u.credits ?? 0, isAdmin: !!u.isAdmin, blocked: !!u.blocked,
      profile: u.profile || {}, stats: u.stats || {}, createdAt: u.createdAt,
      preferences: u.preferences || {},
    };
  }));
  return json({ users: users.filter(Boolean), cursor: null });
}

async function handleAdminGetUser(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const id  = new URL(request.url).pathname.split("/").pop();
  const raw = await env.IPC_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u = JSON.parse(raw);
  return json({
    id: u.id, name: u.name, email: u.email, avatar: u.avatar || null,
    provider: u.provider, credits: u.credits ?? 0, isAdmin: !!u.isAdmin, blocked: !!u.blocked,
    preferences: u.preferences || {}, profile: u.profile || {}, stats: u.stats || {}, createdAt: u.createdAt,
  });
}

async function handleAdminUpdateUser(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const id  = new URL(request.url).pathname.split("/").pop();
  const raw = await env.IPC_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u    = JSON.parse(raw);
  const body = await request.json().catch(function() { return null; });
  if (!body) return error("Body inválido");

  if (body.name      !== undefined) u.name      = String(body.name).trim();
  if (body.credits   !== undefined) u.credits   = Number(body.credits);
  if (body.isAdmin   !== undefined) u.isAdmin   = !!body.isAdmin;
  if (body.blocked   !== undefined) {
    u.blocked = !!body.blocked;
    if (u.blocked) await env.IPC_USERS.put("session_epoch:" + id, String(Date.now()));
  }
  if (body.password  !== undefined && body.password.length >= 6) {
    u.passwordHash = await hashPassword(body.password);
  }
  if (body.email !== undefined) {
    const newEmail = String(body.email).toLowerCase().trim();
    if (newEmail !== u.email) {
      if (u.email) await env.IPC_USERS.delete("email:" + u.email);
      await env.IPC_USERS.put("email:" + newEmail, id);
      u.email = newEmail;
    }
  }
  if (body.preferences && typeof body.preferences === "object") {
    u.preferences = Object.assign({}, u.preferences || {}, body.preferences);
  }
  if (body.profile && typeof body.profile === "object") {
    u.profile = Object.assign({}, u.profile || {}, body.profile);
  }

  await env.IPC_USERS.put("user:" + id, JSON.stringify(u));
  return json({
    id: u.id, name: u.name, email: u.email, avatar: u.avatar || null,
    credits: u.credits, isAdmin: !!u.isAdmin, blocked: !!u.blocked,
    preferences: u.preferences || {}, profile: u.profile || {}, stats: u.stats || {}, createdAt: u.createdAt,
  });
}

async function handleAdminDeleteUser(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const id  = new URL(request.url).pathname.split("/").pop();
  const raw = await env.IPC_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u = JSON.parse(raw);
  const convsRaw = await env.IPC_USERS.get("convs:" + id);
  const convIds  = convsRaw ? JSON.parse(convsRaw) : [];
  await Promise.all(convIds.map(function(cid) { return env.IPC_USERS.delete("conv:" + cid); }));
  await env.IPC_USERS.delete("convs:" + id);
  // Limpeza de dados de projeto legados (não há mais endpoints
  // públicos para criar novos projetos, mas contas antigas podem
  // ainda ter registos em KV que precisam ser removidos).
  const projIds = await loadProjectIndex(env, id);
  await Promise.all(projIds.map(function(pid) { return deleteProjectNode(env, id, pid); }));
  await env.IPC_USERS.delete("projidx:" + id);
  if (u.email)       await env.IPC_USERS.delete("email:" + u.email);
  if (u.firebaseUid) await env.IPC_USERS.delete("firebase:" + u.firebaseUid);
  await env.IPC_USERS.delete("useridx:" + id);
  await env.IPC_USERS.delete("user:" + id);
  return json({ success: true });
}

async function handleAdminBlockUser(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const parts = new URL(request.url).pathname.split("/");
  const id    = parts[3];
  const raw   = await env.IPC_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u    = JSON.parse(raw);
  const body = await request.json().catch(function() { return {}; });
  u.blocked = body.blocked !== undefined ? !!body.blocked : !u.blocked;
  await env.IPC_USERS.put("user:" + id, JSON.stringify(u));
  if (u.blocked) await env.IPC_USERS.put("session_epoch:" + id, String(Date.now()));
  return json({ id, blocked: u.blocked });
}

async function handleAdminSetCredits(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const parts = new URL(request.url).pathname.split("/");
  const id    = parts[3];
  const raw   = await env.IPC_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u    = JSON.parse(raw);
  const body = await request.json().catch(function() { return {}; });
  if (typeof body.credits !== "number") return error("Campo 'credits' obrigatório (número)");
  u.credits = body.credits;
  await env.IPC_USERS.put("user:" + id, JSON.stringify(u));
  return json({ id, credits: u.credits });
}

async function handleAdminUserConversations(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const parts = new URL(request.url).pathname.split("/");
  const id    = parts[3];
  const raw   = await env.IPC_USERS.get("convs:" + id);
  const ids   = raw ? JSON.parse(raw) : [];
  const all   = await Promise.all(ids.map(async function(cid) {
    const data = await env.IPC_USERS.get("conv:" + cid);
    return data ? JSON.parse(data) : null;
  }));
  return json({ conversations: all.filter(Boolean) });
}

async function handleAdminNotify(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const body = await request.json().catch(function() { return null; });
  if (!body || !body.subject || !body.message) return error("Campos 'subject' e 'message' obrigatórios");
  let targetEmails = [];
  if (Array.isArray(body.userIds) && body.userIds.length > 0) {
    const users = await Promise.all(body.userIds.map(async function(id) {
      const raw = await env.IPC_USERS.get("user:" + id);
      return raw ? JSON.parse(raw) : null;
    }));
    targetEmails = users.filter(function(u) { return u && u.email; }).map(function(u) { return u.email; });
  } else if (body.email) {
    targetEmails = [body.email];
  } else {
    return error("Indica 'userIds' ou 'email'");
  }
  if (!env.RESEND_API_KEY) return error("Envio de email não configurado (falta RESEND_API_KEY)", 500);
  const results = [];
  for (const to of targetEmails) {
    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": "Bearer " + env.RESEND_API_KEY },
        body: JSON.stringify({
          from: env.RESEND_FROM || "Nexa <notificacoes@nexa.app>",
          to: [to], subject: body.subject, text: body.message,
        }),
      });
      results.push({ to, ok: res.ok, status: res.status });
    } catch (e) {
      results.push({ to, ok: false, error: e.message });
    }
  }
  return json({ sent: results.filter(function(r) { return r.ok; }).length, total: targetEmails.length, results });
}