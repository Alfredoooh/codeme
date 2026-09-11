// ══════════════════════════════════════════════════════════════
// FILE: worker/index.js
// ══════════════════════════════════════════════════════════════
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const DEEPSEEK_BASE = "https://api.deepseek.com/v1";
const TOOLS_SERVER_BASE = "https://aitools-nexa.onrender.com";

// ═══ DeepSeek V4.1-Flash — modelo unificado.
// ID na API: "deepseek-flash". Visão, tool calling e raciocínio
// vivem todos no mesmo modelo. As duas chaves abaixo são apenas
// perfis de uso — ambas apontam para o mesmo ID; a diferença é o
// reasoning_effort e o max_tokens. ═══
const DEEPSEEK_MODELS = {
  flash: {
    model: "deepseek-flash",
    max_tokens: 8192,
    temperature: 1.0,
    reasoning_effort: "low",
  },
  reasoning: {
    model: "deepseek-flash",
    max_tokens: 65536,
    temperature: 1.0,
    reasoning_effort: "high",
  },
};

const GROQ_BASE = "https://api.groq.com/openai/v1";
const DEEPGRAM_BASE = "https://api.deepgram.com/v1";
const GOPAY_BASE = "https://rouxavcvorjiwhpjhsye.supabase.co/functions/v1/api-v1";

const FREE_CREDITS = 100;
const CREDIT_PACKAGES = {
  basic:   { credits: 500,  price: 2500, name: "Básico",  productId: "SUBSTITUI_PELO_ID_BASICO"  },
  premium: { credits: 1500, price: 7500, name: "Premium", productId: "db3b0e10-d3da-439b-9c0c-06c112ba524b" },
};

// ═══ Limite de avatar — espelha kAvatarMaxImageBytes em
// lib/features/settings/avatar_upload_utils.dart. ═══
const AVATAR_MAX_IMAGE_BYTES = 1 * 1024 * 1024; // 1MB
const AVATAR_MAX_BASE64_CHARS = Math.ceil(AVATAR_MAX_IMAGE_BYTES * 4 / 3) + 100;

// ═══ Password hashing — PBKDF2 nativo do Web Crypto ═══
const PBKDF2_ITERATIONS = 100000;
const PBKDF2_SALT_BYTES = 16;
const PBKDF2_KEY_LENGTH = 32;

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: Object.assign({}, CORS_HEADERS, { "Content-Type": "application/json" }) });
}
function error(msg, status = 400) { return json({ error: msg }, status); }
function randomId(bytes = 16) {
  const arr = new Uint8Array(bytes);
  crypto.getRandomValues(arr);
  return Array.from(arr, b => b.toString(16).padStart(2, "0")).join("");
}
function bytesToHex(bytes) {
  return Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, "0")).join("");
}
function hexToBytes(hex) {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  return bytes;
}
function base64UrlEncode(bytes) {
  let binary = "";
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  for (let i = 0; i < arr.length; i++) binary += String.fromCharCode(arr[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

// ═══ HASH DE PASSWORD — PBKDF2-SHA256 ═══
async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(PBKDF2_SALT_BYTES));
  const keyMaterial = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(password), { name: "PBKDF2" }, false, ["deriveBits"]
  );
  const derivedBits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: PBKDF2_ITERATIONS, hash: "SHA-256" },
    keyMaterial,
    PBKDF2_KEY_LENGTH * 8
  );
  return "pbkdf2:" + PBKDF2_ITERATIONS + ":" + bytesToHex(salt) + ":" + bytesToHex(derivedBits);
}
async function verifyPassword(password, storedHash) {
  try {
    const parts = storedHash.split(":");
    if (parts.length !== 4 || parts[0] !== "pbkdf2") return false;
    const iterations = parseInt(parts[1], 10);
    const salt = hexToBytes(parts[2]);
    const expectedHex = parts[3];
    const keyMaterial = await crypto.subtle.importKey(
      "raw", new TextEncoder().encode(password), { name: "PBKDF2" }, false, ["deriveBits"]
    );
    const derivedBits = await crypto.subtle.deriveBits(
      { name: "PBKDF2", salt, iterations, hash: "SHA-256" },
      keyMaterial,
      PBKDF2_KEY_LENGTH * 8
    );
    const derivedHex = bytesToHex(derivedBits);
    if (derivedHex.length !== expectedHex.length) return false;
    let diff = 0;
    for (let i = 0; i < derivedHex.length; i++) diff |= derivedHex.charCodeAt(i) ^ expectedHex.charCodeAt(i);
    return diff === 0;
  } catch (e) {
    console.error("[PASSWORD VERIFY ERROR]", e.message);
    return false;
  }
}

function normalizeEmail(email) { return String(email).toLowerCase().trim(); }
function normalizePhone(phone) {
  const trimmed = String(phone).trim();
  const hasPlus = trimmed.startsWith("+");
  const digits = trimmed.replace(/[^\d]/g, "");
  return hasPlus ? "+" + digits : digits;
}
function isValidEmail(email) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email); }
function isValidPhone(phone) { return /^\+?\d{8,15}$/.test(phone); }

async function generateToken(payload, secret, env) {
  const jti = randomId(16);
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = btoa(JSON.stringify(Object.assign({}, payload, { jti, iat: Date.now(), exp: Date.now() + 30 * 24 * 60 * 60 * 1000 })));
  const msg = header + "." + body;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(msg));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  const token = msg + "." + sigB64;
  if (env && env.NEXA_USERS) {
    await env.NEXA_USERS.put("session:" + jti, JSON.stringify({ userId: payload.id, createdAt: Date.now() }), { expirationTtl: 30 * 24 * 60 * 60 });
  }
  return token;
}
async function verifyToken(token, secret, env) {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const msg = parts[0] + "." + parts[1];
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
    const sigBytes = Uint8Array.from(atob(parts[2].replace(/-/g, "+").replace(/_/g, "/")), c => c.charCodeAt(0));
    const valid = await crypto.subtle.verify("HMAC", key, sigBytes, new TextEncoder().encode(msg));
    if (!valid) return null;
    const payload = JSON.parse(atob(parts[1]));
    if (payload.exp < Date.now()) return null;
    if (payload.jti && env && env.NEXA_USERS) {
      const session = await env.NEXA_USERS.get("session:" + payload.jti);
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
  const userData = await env.NEXA_USERS.get("user:" + payload.id);
  if (!userData) return null;
  const user = JSON.parse(userData);
  if (!user.isAdmin) return null;
  return user;
}

async function sendResendEmail(env, { to, subject, text, html }) {
  if (!env.RESEND_API_KEY) throw new Error("Envio de email não configurado (falta RESEND_API_KEY)");
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + env.RESEND_API_KEY },
    body: JSON.stringify({
      from: env.RESEND_FROM || "Nexa <notificacoes@nexa.app>",
      to: [to],
      subject,
      text,
      html,
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error("Resend falhou: " + errText);
  }
  return true;
}

function buildSystemInstruction(language, customSystemPrompt) {
  if (customSystemPrompt && customSystemPrompt.trim().length > 0) return customSystemPrompt;
  return language === "en"
    ? "You are Nexa, a helpful AI assistant. Always respond in English. Be concise and direct. When the user asks for a table, use markdown table format. When providing code, always wrap it in fenced code blocks with the language identifier."
    : "Es Nexa, um assistente de IA util. Responde sempre em portugues. Se conciso e direto. Quando o utilizador pedir uma tabela, usa formato de tabela markdown. Quando deres codigo, coloca-o sempre em blocos com o identificador de linguagem.";
}
function buildDeepseekMessages(messages, systemPrompt, language) {
  const sysContent = systemPrompt && systemPrompt.trim().length > 0 ? systemPrompt : buildSystemInstruction(language || "pt", "");
  return [
    { role: "system", content: sysContent },
    ...messages.filter(m => m.role !== "system").map(m => {
      const out = { role: m.role, content: m.content };
      if (m.tool_call_id !== undefined) out.tool_call_id = m.tool_call_id;
      if (m.tool_calls !== undefined) out.tool_calls = m.tool_calls;
      if (m.name !== undefined) out.name = m.name;
      return out;
    }),
  ];
}
async function deepseekChat(apiKey, messages, modelKey, systemPrompt, language, stream, tools) {
  const cfg = DEEPSEEK_MODELS[modelKey] || DEEPSEEK_MODELS.flash;
  const allMessages = buildDeepseekMessages(messages, systemPrompt, language);
  const requestBody = { model: cfg.model, messages: allMessages, max_tokens: cfg.max_tokens, stream: !!stream };
  if (cfg.temperature !== undefined) requestBody.temperature = cfg.temperature;
  if (cfg.reasoning_effort !== undefined) requestBody.reasoning_effort = cfg.reasoning_effort;
  if (Array.isArray(tools) && tools.length > 0) requestBody.tools = tools;
  return fetch(DEEPSEEK_BASE + "/chat/completions", { method: "POST", headers: { "Content-Type": "application/json", "Authorization": "Bearer " + apiKey }, body: JSON.stringify(requestBody) });
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
        model: "deepseek-flash",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 24,
        temperature: 0.4,
        reasoning_effort: "low",
        stream: false,
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const text = data.choices?.[0]?.message?.content || "";
    const cleaned = text.trim().replace(/^["'“]|["'”]$/g, "").slice(0, 48);
    return cleaned.length > 0 ? cleaned : null;
  } catch (e) { console.error("[NEXA TITLE ERROR]", e.message); return null; }
}

// ═══ ANEXOS — converte mensagens do utilizador com anexos de imagem
// para o formato multimodal do DeepSeek V4.1-Flash: content passa a
// ser um array de blocos [{type:"text",...},{type:"image_url",...}].
// Imagens suportadas: jpeg/png/gif/webp. Documentos não-imagem
// continuam a passar pelas tools (read_pdf_contents, etc). ═══
const SUPPORTED_IMAGE_MIMES = ["image/jpeg", "image/png", "image/gif", "image/webp"];

function isImageAttachment(att) {
  const mime = (att && att.mimeType) || "";
  return SUPPORTED_IMAGE_MIMES.includes(String(mime).toLowerCase());
}

function expandMessagesWithAttachments(messages) {
  return messages.map(m => {
    const out = { role: m.role };
    const imageAttachments = Array.isArray(m.attachments)
      ? m.attachments.filter(isImageAttachment)
      : [];

    if (m.role === "user" && imageAttachments.length > 0) {
      const blocks = [];
      if (typeof m.content === "string" && m.content.trim().length > 0) {
        blocks.push({ type: "text", text: m.content });
      }
      for (const att of imageAttachments) {
        const mime = att.mimeType || "image/jpeg";
        const imageUrl = { url: "data:" + mime + ";base64," + att.base64 };
        if (att.detail && ["low", "high", "auto"].includes(att.detail)) {
          imageUrl.detail = att.detail;
        }
        blocks.push({ type: "image_url", image_url: imageUrl });
      }
      out.content = blocks;
    } else {
      out.content = m.content;
    }

    if (m.tool_call_id !== undefined) out.tool_call_id = m.tool_call_id;
    if (m.tool_calls !== undefined) out.tool_calls = m.tool_calls;
    if (m.name !== undefined) out.name = m.name;
    return out;
  });
}

// ═══ TOOLS — proxy para o servidor externo ═══
async function handleToolsList(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  try {
    const res = await fetch(TOOLS_SERVER_BASE + "/tools");
    if (!res.ok) return error("Erro ao obter tools", res.status);
    const data = await res.json();
    return json(data);
  } catch (e) { return error("Erro ao contactar servidor de tools: " + e.message, 502); }
}
async function handleToolsExecute(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body || !body.name) return error("Campo 'name' é obrigatório");
  try {
    const res = await fetch(TOOLS_SERVER_BASE + "/tools/execute", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
    const data = await res.json();
    return json(data, res.status);
  } catch (e) { return error("Erro ao contactar servidor de tools: " + e.message, 502); }
}

async function handleListEvents(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const raw = await env.NEXA_USERS.get("events:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  const all = await Promise.all(ids.map(async id => { const data = await env.NEXA_USERS.get("event:" + id); return data ? JSON.parse(data) : null; }));
  const events = all.filter(e => e !== null).sort((a, b) => a.startAt - b.startAt);
  return json({ events });
}
async function handleCreateEvent(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body || !body.title || !body.startAt) return error("Campos 'title' e 'startAt' obrigatórios");
  const id = crypto.randomUUID();
  const event = { id, userId: payload.id, title: body.title, description: body.description || "", startAt: Number(body.startAt), endAt: body.endAt ? Number(body.endAt) : Number(body.startAt) + 3600000, allDay: !!body.allDay, color: body.color || "#6F5AF6", createdAt: Date.now() };
  await env.NEXA_USERS.put("event:" + id, JSON.stringify(event));
  const raw = await env.NEXA_USERS.get("events:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  ids.push(id);
  await env.NEXA_USERS.put("events:" + payload.id, JSON.stringify(ids));
  return json(event, 201);
}
async function handleUpdateEvent(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id = new URL(request.url).pathname.split("/").pop();
  const data = await env.NEXA_USERS.get("event:" + id);
  if (!data) return error("Evento não encontrado", 404);
  const event = JSON.parse(data);
  if (event.userId !== payload.id) return error("Acesso negado", 403);
  const body = await request.json().catch(() => null);
  if (!body) return error("Body inválido");
  if (body.title !== undefined) event.title = body.title;
  if (body.description !== undefined) event.description = body.description;
  if (body.startAt !== undefined) event.startAt = Number(body.startAt);
  if (body.endAt !== undefined) event.endAt = Number(body.endAt);
  if (body.allDay !== undefined) event.allDay = !!body.allDay;
  if (body.color !== undefined) event.color = body.color;
  await env.NEXA_USERS.put("event:" + id, JSON.stringify(event));
  return json(event);
}
async function handleDeleteEvent(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id = new URL(request.url).pathname.split("/").pop();
  const data = await env.NEXA_USERS.get("event:" + id);
  if (!data) return error("Evento não encontrado", 404);
  const event = JSON.parse(data);
  if (event.userId !== payload.id) return error("Acesso negado", 403);
  await env.NEXA_USERS.delete("event:" + id);
  const raw = await env.NEXA_USERS.get("events:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  await env.NEXA_USERS.put("events:" + payload.id, JSON.stringify(ids.filter(i => i !== id)));
  return json({ success: true });
}

async function loadProjectIndex(env, userId) {
  const raw = await env.NEXA_USERS.get("projidx:" + userId);
  return raw ? JSON.parse(raw) : [];
}
async function deleteProjectNode(env, userId, id) {
  await env.NEXA_USERS.delete("proj:" + userId + ":" + id);
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === "/auth/register" && request.method === "POST") return handleRegister(request, env);
    if (path === "/auth/login" && request.method === "POST") return handleLogin(request, env);
    if (path === "/auth/logout" && request.method === "POST") return handleLogout(request, env);
    if (path === "/auth/logout-all" && request.method === "POST") return handleLogoutAll(request, env);
    if (path === "/user/me" && request.method === "GET") return handleGetMe(request, env);
    if (path === "/user/me" && request.method === "PUT") return handleUpdateMe(request, env);
    if (path === "/user/profile" && request.method === "PUT") return handleUpdateProfile(request, env);
    if (path === "/user/avatar" && request.method === "PUT") return handleUpdateAvatar(request, env);
    if (path === "/ai/chat" && request.method === "POST") return handleAiChat(request, env);
    if (path === "/ai/title" && request.method === "POST") return handleAiTitle(request, env);
    if (path === "/ai/summarize" && request.method === "POST") return handleAiSummarize(request, env);
    if (path === "/ai/transcribe" && request.method === "POST") return handleAiTranscribe(request, env);
    if (path === "/ai/suggest" && request.method === "GET") return handleAiSuggest(request, env);
    if (path === "/credits/balance" && request.method === "GET") return handleCreditsBalance(request, env);
    if (path === "/credits/checkout" && request.method === "POST") return handleCreditsCheckout(request, env);
    if (path === "/credits/webhook" && request.method === "POST") return handleCreditsWebhook(request, env);
    if (path === "/conversations" && request.method === "GET") return handleListConversations(request, env);
    if (path === "/conversations" && request.method === "POST") return handleCreateConversation(request, env);
    if (path === "/conversations/all" && request.method === "DELETE") return handleDeleteAllConversations(request, env);
    if (path === "/conversations/search" && request.method === "GET") return handleSearchConversations(request, env);
    if (path.match(/^\/conversations\/[^/]+$/) && request.method === "GET") return handleGetConversation(request, env);
    if (path.match(/^\/conversations\/[^/]+$/) && request.method === "PUT") return handleUpdateConversation(request, env);
    if (path.match(/^\/conversations\/[^/]+$/) && request.method === "DELETE") return handleDeleteConversation(request, env);
    if (path.match(/^\/conversations\/[^/]+\/pin$/) && request.method === "PUT") return handlePinConversation(request, env);
    if (path.match(/^\/conversations\/[^/]+\/archive$/) && request.method === "PUT") return handleArchiveConversation(request, env);

    if (path === "/events" && request.method === "GET") return handleListEvents(request, env);
    if (path === "/events" && request.method === "POST") return handleCreateEvent(request, env);
    if (path.match(/^\/events\/[^/]+$/) && request.method === "PUT") return handleUpdateEvent(request, env);
    if (path.match(/^\/events\/[^/]+$/) && request.method === "DELETE") return handleDeleteEvent(request, env);

    if (path === "/tools" && request.method === "GET") return handleToolsList(request, env);
    if (path === "/tools/execute" && request.method === "POST") return handleToolsExecute(request, env);

    if (path === "/admin/stats" && request.method === "GET") return handleAdminStats(request, env);
    if (path === "/admin/users" && request.method === "GET") return handleAdminListUsers(request, env);
    if (path.match(/^\/admin\/users\/[^/]+$/) && request.method === "GET") return handleAdminGetUser(request, env);
    if (path.match(/^\/admin\/users\/[^/]+$/) && request.method === "PUT") return handleAdminUpdateUser(request, env);
    if (path.match(/^\/admin\/users\/[^/]+$/) && request.method === "DELETE") return handleAdminDeleteUser(request, env);
    if (path.match(/^\/admin\/users\/[^/]+\/block$/) && request.method === "PUT") return handleAdminBlockUser(request, env);
    if (path.match(/^\/admin\/users\/[^/]+\/credits$/) && request.method === "PUT") return handleAdminSetCredits(request, env);
    if (path.match(/^\/admin\/users\/[^/]+\/conversations$/) && request.method === "GET") return handleAdminUserConversations(request, env);
    if (path === "/admin/notify" && request.method === "POST") return handleAdminNotify(request, env);

    return error("Not found", 404);
  },
};

// ═══ AUTH ═══
async function handleRegister(request, env) {
  const body = await request.json().catch(() => null);
  if (!body) return error("Body inválido");

  const rawEmail = body.email ? String(body.email) : null;
  const rawPhone = body.phone ? String(body.phone) : null;
  const password = body.password ? String(body.password) : "";
  const name = body.name ? String(body.name).trim() : "";

  if (!rawEmail && !rawPhone) return error("Indica um email ou número de telemóvel");
  if (rawEmail && rawPhone) return error("Indica apenas um: email OU telemóvel");
  if (password.length < 6) return error("A password deve ter pelo menos 6 caracteres");
  if (!name) return error("Nome obrigatório");

  let email = null, phone = null;
  if (rawEmail) {
    email = normalizeEmail(rawEmail);
    if (!isValidEmail(email)) return error("Email inválido");
  } else {
    phone = normalizePhone(rawPhone);
    if (!isValidPhone(phone)) return error("Número de telemóvel inválido");
  }

  if (email) {
    const existing = await env.NEXA_USERS.get("email:" + email);
    if (existing) return error("Este email já está registado.");
  } else {
    const existing = await env.NEXA_USERS.get("phone:" + phone);
    if (existing) return error("Este número de telemóvel já está registado.");
  }

  const userId = crypto.randomUUID();
  const passwordHash = await hashPassword(password);

  const user = {
    id: userId,
    name,
    email,
    phone,
    avatar: null,
    provider: "password",
    passwordHash,
    credits: FREE_CREDITS,
    isAdmin: false,
    blocked: false,
    preferences: { language: "pt", theme: "system", fontSize: "medium" },
    profile: { age: null, country: null, state: null, city: null, occupation: null, occupationDetail: null, bio: null },
    stats: { totalConversations: 0, totalMessages: 0 },
    createdAt: Date.now(),
  };

  await env.NEXA_USERS.put("user:" + userId, JSON.stringify(user));
  if (email) await env.NEXA_USERS.put("email:" + email, userId);
  if (phone) await env.NEXA_USERS.put("phone:" + phone, userId);
  await env.NEXA_USERS.put("useridx:" + userId, "1");

  const token = await generateToken({ id: user.id, email: user.email, name: user.name }, env.JWT_SECRET, env);
  return json({
    token,
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    avatar: user.avatar,
    provider: "password",
    credits: user.credits,
    preferences: user.preferences,
  });
}

async function handleLogin(request, env) {
  const body = await request.json().catch(() => null);
  if (!body) return error("Body inválido");

  const rawEmail = body.email ? String(body.email) : null;
  const rawPhone = body.phone ? String(body.phone) : null;
  const password = body.password ? String(body.password) : "";

  if (!rawEmail && !rawPhone) return error("Indica um email ou número de telemóvel");
  if (!password) return error("Password obrigatória");

  let userId = null;
  if (rawEmail) {
    const email = normalizeEmail(rawEmail);
    userId = await env.NEXA_USERS.get("email:" + email);
  } else {
    const phone = normalizePhone(rawPhone);
    userId = await env.NEXA_USERS.get("phone:" + phone);
  }

  if (!userId) return error("Email/telemóvel ou password incorretos.", 401);

  const userData = await env.NEXA_USERS.get("user:" + userId);
  if (!userData) return error("Email/telemóvel ou password incorretos.", 401);
  const user = JSON.parse(userData);

  if (!user.passwordHash) return error("Email/telemóvel ou password incorretos.", 401);
  const validPassword = await verifyPassword(password, user.passwordHash);
  if (!validPassword) return error("Email/telemóvel ou password incorretos.", 401);

  if (user.blocked) return error("Esta conta foi bloqueada", 403);

  const token = await generateToken({ id: user.id, email: user.email, name: user.name }, env.JWT_SECRET, env);
  return json({
    token,
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    avatar: user.avatar || null,
    provider: "password",
    credits: user.credits ?? FREE_CREDITS,
    preferences: user.preferences || {},
  });
}

async function handleLogout(request, env) {
  const auth = request.headers.get("Authorization") || "";
  if (auth.startsWith("Bearer ")) {
    const token = auth.slice(7);
    const parts = token.split(".");
    if (parts.length === 3) {
      try { const payload = JSON.parse(atob(parts[1])); if (payload.jti) await env.NEXA_USERS.delete("session:" + payload.jti); } catch (e) {}
    }
  }
  return json({ success: true });
}
async function handleLogoutAll(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  await env.NEXA_USERS.put("session_epoch:" + payload.id, String(Date.now()));
  return json({ success: true });
}

async function handleGetMe(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const userData = await env.NEXA_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  return json({ id: user.id, name: user.name, email: user.email, phone: user.phone || null, avatar: user.avatar || null, provider: user.provider || "password", credits: user.credits ?? FREE_CREDITS, preferences: user.preferences || {}, profile: user.profile || {}, isAdmin: !!user.isAdmin, stats: user.stats || {}, createdAt: user.createdAt });
}
async function handleUpdateMe(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body) return error("Body inválido");
  const userData = await env.NEXA_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);

  if (body.name) user.name = String(body.name).trim();
  if (body.preferences && typeof body.preferences === "object") user.preferences = Object.assign({}, user.preferences || {}, body.preferences);

  if (body.password) {
    const currentPassword = body.currentPassword ? String(body.currentPassword) : "";
    if (!currentPassword) return error("Indica a password atual para a alterar.");
    const validCurrent = await verifyPassword(currentPassword, user.passwordHash);
    if (!validCurrent) return error("Password atual incorreta.", 401);
    const newPassword = String(body.password);
    if (newPassword.length < 6) return error("A nova password deve ter pelo menos 6 caracteres");
    user.passwordHash = await hashPassword(newPassword);
    await env.NEXA_USERS.put("session_epoch:" + user.id, String(Date.now()));
  }

  await env.NEXA_USERS.put("user:" + user.id, JSON.stringify(user));
  return json({ id: user.id, name: user.name, email: user.email, phone: user.phone || null, avatar: user.avatar || null, provider: user.provider || "password", credits: user.credits ?? FREE_CREDITS, preferences: user.preferences || {}, profile: user.profile || {}, createdAt: user.createdAt });
}
async function handleUpdateProfile(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body) return error("Body inválido");
  const userData = await env.NEXA_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  const allowed = ["age", "country", "state", "city", "occupation", "occupationDetail", "bio"];
  const nextProfile = Object.assign({}, user.profile || {});
  for (const key of allowed) { if (body[key] !== undefined) nextProfile[key] = body[key]; }
  if (nextProfile.age !== null && nextProfile.age !== undefined) {
    const ageNum = Number(nextProfile.age);
    if (!Number.isFinite(ageNum) || ageNum < 0 || ageNum > 120) return error("Idade inválida");
    nextProfile.age = ageNum;
  }
  if (nextProfile.occupation && !["student", "professional", "other"].includes(nextProfile.occupation)) return error("Campo 'occupation' inválido (student | professional | other)");
  user.profile = nextProfile;
  await env.NEXA_USERS.put("user:" + user.id, JSON.stringify(user));
  return json({ profile: user.profile });
}
async function handleUpdateAvatar(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body || !body.avatar) return error("avatar obrigatório");
  if (body.avatar.length > AVATAR_MAX_BASE64_CHARS) return error("Imagem demasiado grande (máx ~1MB)");
  const userData = await env.NEXA_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  user.avatar = body.avatar;
  await env.NEXA_USERS.put("user:" + user.id, JSON.stringify(user));
  return json({ avatar: user.avatar });
}
async function handleListConversations(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const url = new URL(request.url);
  const archived = url.searchParams.get("archived") === "true";
  const raw = await env.NEXA_USERS.get("convs:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  const all = await Promise.all(ids.map(async id => { const data = await env.NEXA_USERS.get("conv:" + id); return data ? JSON.parse(data) : null; }));
  const conversations = all.filter(c => c !== null && (archived ? c.archived === true : !c.archived)).sort((a, b) => { if (a.pinned && !b.pinned) return -1; if (!a.pinned && b.pinned) return 1; return b.updatedAt - a.updatedAt; });
  return json({ conversations });
}
async function handleCreateConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body) return error("Body inválido");
  const id = crypto.randomUUID();
  const now = Date.now();
  const conversation = { id, userId: payload.id, title: body.title || "Nova conversa", messages: body.messages || [], model: body.model || "deepseek-flash", pinned: false, archived: false, tags: body.tags || [], createdAt: now, updatedAt: now };
  await env.NEXA_USERS.put("conv:" + id, JSON.stringify(conversation));
  const raw = await env.NEXA_USERS.get("convs:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  ids.unshift(id);
  await env.NEXA_USERS.put("convs:" + payload.id, JSON.stringify(ids));
  await incrementUserStat(env, payload.id, "totalConversations", 1);
  return json(conversation, 201);
}
async function handleGetConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id = new URL(request.url).pathname.split("/").pop();
  const data = await env.NEXA_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  return json(conversation);
}
async function handleUpdateConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id = new URL(request.url).pathname.split("/").pop();
  const data = await env.NEXA_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  const body = await request.json().catch(() => null);
  if (!body) return error("Body inválido");
  if (body.title !== undefined) conversation.title = body.title;
  if (body.messages !== undefined) {
    const added = body.messages.length - conversation.messages.length;
    if (added > 0) await incrementUserStat(env, payload.id, "totalMessages", added);
    conversation.messages = body.messages;
  }
  if (body.model !== undefined) conversation.model = body.model;
  if (body.tags !== undefined) conversation.tags = body.tags;
  conversation.updatedAt = Date.now();
  await env.NEXA_USERS.put("conv:" + id, JSON.stringify(conversation));
  return json(conversation);
}
async function handleDeleteConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const id = new URL(request.url).pathname.split("/").pop();
  const data = await env.NEXA_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  await env.NEXA_USERS.delete("conv:" + id);
  const raw = await env.NEXA_USERS.get("convs:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  const updated = ids.filter(i => i !== id);
  await env.NEXA_USERS.put("convs:" + payload.id, JSON.stringify(updated));
  await incrementUserStat(env, payload.id, "totalConversations", -1);
  return json({ success: true });
}
async function handleDeleteAllConversations(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const raw = await env.NEXA_USERS.get("convs:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  await Promise.all(ids.map(id => env.NEXA_USERS.delete("conv:" + id)));
  await env.NEXA_USERS.put("convs:" + payload.id, JSON.stringify([]));
  const userData = await env.NEXA_USERS.get("user:" + payload.id);
  if (userData) { const user = JSON.parse(userData); if (user.stats) user.stats.totalConversations = 0; await env.NEXA_USERS.put("user:" + payload.id, JSON.stringify(user)); }
  return json({ success: true, deleted: ids.length });
}
async function handlePinConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const parts = new URL(request.url).pathname.split("/");
  const id = parts[2];
  const data = await env.NEXA_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  const body = await request.json().catch(() => ({}));
  conversation.pinned = body.pinned !== undefined ? body.pinned : !conversation.pinned;
  conversation.updatedAt = Date.now();
  await env.NEXA_USERS.put("conv:" + id, JSON.stringify(conversation));
  return json({ id, pinned: conversation.pinned });
}
async function handleArchiveConversation(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const parts = new URL(request.url).pathname.split("/");
  const id = parts[2];
  const data = await env.NEXA_USERS.get("conv:" + id);
  if (!data) return error("Conversa não encontrada", 404);
  const conversation = JSON.parse(data);
  if (conversation.userId !== payload.id) return error("Acesso negado", 403);
  const body = await request.json().catch(() => ({}));
  conversation.archived = body.archived !== undefined ? body.archived : !conversation.archived;
  conversation.pinned = false;
  conversation.updatedAt = Date.now();
  await env.NEXA_USERS.put("conv:" + id, JSON.stringify(conversation));
  return json({ id, archived: conversation.archived });
}
async function handleSearchConversations(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const url = new URL(request.url);
  const query = (url.searchParams.get("q") || "").toLowerCase().trim();
  if (!query) return json({ conversations: [] });
  const raw = await env.NEXA_USERS.get("convs:" + payload.id);
  const ids = raw ? JSON.parse(raw) : [];
  const all = await Promise.all(ids.map(async id => { const data = await env.NEXA_USERS.get("conv:" + id); return data ? JSON.parse(data) : null; }));
  const results = all.filter(c => { if (!c || c.archived) return false; if (c.title.toLowerCase().includes(query)) return true; return c.messages.some(m => m.content && m.content.toLowerCase().includes(query)); }).sort((a, b) => b.updatedAt - a.updatedAt);
  return json({ conversations: results });
}
async function handleAiTitle(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body || !body.message) return error("message obrigatório");
  const title = await deepseekGenerateTitle(env.DEEPSEEK_API_KEY, body.message, body.language || "pt");
  return json({ title: title || "Nova conversa" });
}
async function handleAiChat(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body || !body.messages) return error("messages obrigatório");
  const userData = await env.NEXA_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const userObj = JSON.parse(userData);
  if (userObj.blocked) return error("Esta conta foi bloqueada", 403);
  const currentCredits = userObj.credits ?? 0;
  if (currentCredits <= 0) return json({ error: "credits_exhausted", message: "Sem créditos. Recarrega para continuar." }, 402);
  userObj.credits = currentCredits - 1;
  await env.NEXA_USERS.put("user:" + payload.id, JSON.stringify(userObj));

  const rawMessages = body.messages;
  const messages = expandMessagesWithAttachments(rawMessages);
  const stream = body.stream !== undefined ? body.stream : false;
  const language = body.language || "pt";
  const customSystemPrompt = body.systemPrompt || "";
  const modelKey = body.model || "flash";
  const tools = Array.isArray(body.tools) ? body.tools : null;

  if (!env.DEEPSEEK_API_KEY) return error("DeepSeek não configurado", 500);
  const dsRes = await deepseekChat(env.DEEPSEEK_API_KEY, messages, modelKey, customSystemPrompt, language, stream, tools);
  if (!dsRes.ok) {
    const errText = await dsRes.text();
    console.error("[NEXA CHAT ERROR]", dsRes.status, errText);
    return error("Erro DeepSeek API: " + errText, dsRes.status);
  }
  if (stream) {
    return new Response(dsRes.body, { headers: Object.assign({}, CORS_HEADERS, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache", "X-Accel-Buffering": "no" }) });
  }
  const data = await dsRes.json();
  const choice = data.choices?.[0];
  const content = choice?.message?.content || "";
  const reasoning = choice?.message?.reasoning_content || null;
  const toolCalls = choice?.message?.tool_calls || null;
  return json({ content, reasoning, toolCalls, model: data.model || modelKey, usage: data.usage || null });
}
async function handleAiSummarize(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body || !body.messages) return error("messages obrigatório");
  const language = body.language || "pt";
  const prompt = language === "en" ? "Summarize the following conversation in a few sentences:\n\n" : "Resume a seguinte conversa em poucas frases:\n\n";
  const text = body.messages.map(m => (m.role === "user" ? "User: " : "Assistant: ") + m.content).join("\n");
  if (!env.DEEPSEEK_API_KEY) return error("DeepSeek não configurado", 500);
  const dsRes = await fetch(DEEPSEEK_BASE + "/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + env.DEEPSEEK_API_KEY },
    body: JSON.stringify({
      model: "deepseek-flash",
      messages: [{ role: "user", content: prompt + text }],
      max_tokens: 512,
      temperature: 0.5,
      reasoning_effort: "low",
      stream: false,
    }),
  });
  if (!dsRes.ok) return error("Erro ao resumir", dsRes.status);
  const data = await dsRes.json();
  const summary = data.choices?.[0]?.message?.content || "";
  return json({ summary });
}

// ═══ TRANSCRIÇÃO — Groq (Whisper) + Deepgram fallback ═══
async function transcribeWithGroq(apiKey, audioFile, language, prompt) {
  const outForm = new FormData();
  outForm.append("file", audioFile);
  outForm.append("model", "whisper-large-v3-turbo");
  outForm.append("language", language);
  outForm.append("response_format", "json");
  if (prompt) outForm.append("prompt", prompt);
  const res = await fetch(GROQ_BASE + "/audio/transcriptions", { method: "POST", headers: { "Authorization": "Bearer " + apiKey }, body: outForm });
  if (!res.ok) { const errText = await res.text(); throw new Error("Groq: " + errText); }
  const data = await res.json();
  return { text: data.text || "", language: data.language || language, duration: data.duration || null, provider: "groq" };
}
async function transcribeWithDeepgram(apiKey, audioFile, language) {
  const buf = await audioFile.arrayBuffer();
  const contentType = audioFile.type || "audio/webm";
  const dgLang = language === "pt" ? "pt" : language;
  const url = DEEPGRAM_BASE + "/listen?model=nova-2&language=" + encodeURIComponent(dgLang) + "&smart_format=true";
  const res = await fetch(url, { method: "POST", headers: { "Authorization": "Token " + apiKey, "Content-Type": contentType }, body: buf });
  if (!res.ok) { const errText = await res.text(); throw new Error("Deepgram: " + errText); }
  const data = await res.json();
  const text = data.results?.channels?.[0]?.alternatives?.[0]?.transcript || "";
  const duration = data.metadata?.duration || null;
  return { text, language: dgLang, duration, provider: "deepgram" };
}
async function handleAiTranscribe(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  let formData;
  try { formData = await request.formData(); } catch (e) { return error("Esperado multipart/form-data com campo 'file'"); }
  const audioFile = formData.get("file");
  const language = formData.get("language") || "pt";
  const prompt = formData.get("prompt") || "";
  if (!audioFile) return error("Campo 'file' obrigatório");

  const attempts = [];
  if (env.GROQ_API_KEY) {
    try {
      const result = await transcribeWithGroq(env.GROQ_API_KEY, audioFile, language, prompt);
      return json(result);
    } catch (e) { attempts.push("Groq falhou: " + e.message); console.error("[NEXA TRANSCRIBE] Groq falhou, a tentar Deepgram:", e.message); }
  } else { attempts.push("Groq não configurado"); }

  if (env.DEEPGRAM_API_KEY) {
    try {
      const result = await transcribeWithDeepgram(env.DEEPGRAM_API_KEY, audioFile, language);
      return json(result);
    } catch (e) { attempts.push("Deepgram falhou: " + e.message); console.error("[NEXA TRANSCRIBE] Deepgram também falhou:", e.message); }
  } else { attempts.push("Deepgram não configurado"); }

  return error("Falha ao transcrever em todos os provedores disponíveis: " + attempts.join(" | "), 502);
}
async function handleAiSuggest(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const url = new URL(request.url);
  const q = (url.searchParams.get("q") || "").trim();
  const lang = (url.searchParams.get("lang") || "pt-PT").trim();
  if (!q) return json({ suggestions: [] });
  const hl = lang.split("-")[0] || "pt";
  const gl = (lang.split("-")[1] || "PT").toUpperCase();
  const googleUrl = "https://suggestqueries.google.com/complete/search?client=firefox&hl=" + encodeURIComponent(hl) + "&gl=" + encodeURIComponent(gl) + "&q=" + encodeURIComponent(q);
  let googleRes;
  try { googleRes = await fetch(googleUrl, { headers: { "User-Agent": "Mozilla/5.0 (compatible; NexaSuggest/1.0)" } }); } catch (e) { return error("Erro ao obter sugestões", 502); }
  if (!googleRes.ok) return error("Erro ao obter sugestões", googleRes.status);
  const data = await googleRes.json().catch(() => null);
  const suggestions = data && Array.isArray(data[1]) ? data[1] : [];
  return new Response(JSON.stringify({ suggestions }), { status: 200, headers: Object.assign({}, CORS_HEADERS, { "Content-Type": "application/json", "Cache-Control": "public, max-age=120" }) });
}
async function handleCreditsBalance(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const userData = await env.NEXA_USERS.get("user:" + payload.id);
  if (!userData) return error("Utilizador não encontrado", 404);
  const user = JSON.parse(userData);
  return json({ credits: user.credits ?? 0, packages: CREDIT_PACKAGES });
}
async function handleCreditsCheckout(request, env) {
  const payload = await getAuthUser(request, env);
  if (!payload) return error("Não autenticado", 401);
  const body = await request.json().catch(() => null);
  if (!body || !body.package) return error("Campo 'package' obrigatório (basic | premium)");
  const pkg = CREDIT_PACKAGES[body.package];
  if (!pkg) return error("Pacote inválido");
  const productId = pkg.productId;
  const checkoutRes = await fetch(GOPAY_BASE + "/checkout-links", { method: "POST", headers: { "Content-Type": "application/json", "x-api-key": env.GOPAY_API_KEY }, body: JSON.stringify({ product_id: productId }) });
  if (!checkoutRes.ok) return error("Erro ao gerar checkout GoPay: " + await checkoutRes.text(), 500);
  const checkout = await checkoutRes.json();
  const checkoutUrl = checkout.url || checkout.checkout_url || checkout.link || checkout.checkout_link;
  if (!checkoutUrl) return error("GoPay não devolveu URL de checkout: " + JSON.stringify(checkout), 500);
  const pendingKey = "pending_credit:" + productId + ":" + payload.id;
  await env.NEXA_USERS.put(pendingKey, JSON.stringify({ userId: payload.id, package: body.package, credits: pkg.credits, createdAt: Date.now() }), { expirationTtl: 3600 });
  return json({ checkout_url: checkoutUrl, product_id: productId, package: body.package, credits: pkg.credits, price: pkg.price });
}
async function handleCreditsWebhook(request, env) {
  const signature = request.headers.get("X-Webhook-Signature") || "";
  const rawBody = await request.text();
  if (!env.GOPAY_WEBHOOK_SECRET) { console.error("[NEXA WEBHOOK] GOPAY_WEBHOOK_SECRET não configurado — recusando webhook por segurança"); return error("Webhook não configurado", 500); }
  if (!signature) return error("Assinatura ausente", 401);
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(env.GOPAY_WEBHOOK_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sigBytes = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const expected = btoa(String.fromCharCode(...new Uint8Array(sigBytes)));
  if (expected !== signature) return error("Assinatura inválida", 401);
  let event;
  try { event = JSON.parse(rawBody); } catch { return error("Body inválido"); }
  const eventType = event.event || event.type || "";
  const isApproved = eventType === "payment.approved" || eventType === "Pagamento Aprovado" || event.status === "completed" || event.status === "approved";
  if (!isApproved) return json({ received: true });
  const productId = event.product_id || event.data?.product_id;
  if (!productId) return json({ received: true, note: "Sem product_id" });
  const eventUserId = event.user_id || event.data?.user_id || null;
  const listRes = await env.NEXA_USERS.list({ prefix: "pending_credit:" + productId + ":" });
  let pending = null, pendingKey = null;
  if (listRes.keys && listRes.keys.length > 0) {
    if (eventUserId) {
      for (const k of listRes.keys) {
        const raw = await env.NEXA_USERS.get(k.name);
        if (!raw) continue;
        const candidate = JSON.parse(raw);
        if (candidate.userId === eventUserId) { pending = candidate; pendingKey = k.name; break; }
      }
    }
    if (!pending) {
      if (listRes.keys.length > 1) console.error("[NEXA WEBHOOK] Múltiplos pendentes sem user_id no evento — usando o primeiro, risco de crédito incorreto");
      pendingKey = listRes.keys[0].name;
      const raw = await env.NEXA_USERS.get(pendingKey);
      if (raw) pending = JSON.parse(raw);
    }
  }
  if (!pending) return json({ received: true, note: "Sem pendente para este produto" });
  const userDataRaw = await env.NEXA_USERS.get("user:" + pending.userId);
  if (userDataRaw) { const user = JSON.parse(userDataRaw); user.credits = (user.credits ?? 0) + pending.credits; await env.NEXA_USERS.put("user:" + pending.userId, JSON.stringify(user)); }
  await env.NEXA_USERS.delete(pendingKey);
  await env.NEXA_USERS.put("purchase:" + crypto.randomUUID(), JSON.stringify({ userId: pending.userId, package: pending.package, credits: pending.credits, productId, paidAt: Date.now() }));
  return json({ success: true, credits_added: pending.credits });
}
async function incrementUserStat(env, userId, stat, delta) {
  try {
    const userData = await env.NEXA_USERS.get("user:" + userId);
    if (!userData) return;
    const user = JSON.parse(userData);
    if (!user.stats) user.stats = {};
    user.stats[stat] = (user.stats[stat] || 0) + delta;
    if (user.stats[stat] < 0) user.stats[stat] = 0;
    await env.NEXA_USERS.put("user:" + userId, JSON.stringify(user));
  } catch (e) { console.error("[NEXA STAT ERROR]", e); }
}

async function handleAdminStats(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  let totalUsers = 0;
  let cursor = undefined;
  while (true) {
    const list = await env.NEXA_USERS.list({ prefix: "user:", limit: 1000, cursor });
    totalUsers += list.keys.filter(k => !k.name.slice("user:".length).includes(":")).length;
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
    const list = await env.NEXA_USERS.list({ prefix: "user:", limit: 1000, cursor });
    list.keys.forEach(k => { const id = k.name.slice("user:".length); if (id && !id.includes(":")) ids.push(id); });
    if (list.list_complete) break;
    cursor = list.cursor;
  }
  const users = await Promise.all(ids.map(async id => {
    const raw = await env.NEXA_USERS.get("user:" + id);
    if (!raw) return null;
    const u = JSON.parse(raw);
    return { id: u.id, name: u.name, email: u.email, phone: u.phone || null, avatar: u.avatar || null, credits: u.credits ?? 0, isAdmin: !!u.isAdmin, blocked: !!u.blocked, profile: u.profile || {}, stats: u.stats || {}, createdAt: u.createdAt, preferences: u.preferences || {} };
  }));
  return json({ users: users.filter(Boolean), cursor: null });
}
async function handleAdminGetUser(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const id = new URL(request.url).pathname.split("/").pop();
  const raw = await env.NEXA_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u = JSON.parse(raw);
  return json({ id: u.id, name: u.name, email: u.email, phone: u.phone || null, avatar: u.avatar || null, provider: u.provider, credits: u.credits ?? 0, isAdmin: !!u.isAdmin, blocked: !!u.blocked, preferences: u.preferences || {}, profile: u.profile || {}, stats: u.stats || {}, createdAt: u.createdAt });
}
async function handleAdminUpdateUser(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const id = new URL(request.url).pathname.split("/").pop();
  const raw = await env.NEXA_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u = JSON.parse(raw);
  const body = await request.json().catch(() => null);
  if (!body) return error("Body inválido");
  if (body.name !== undefined) u.name = String(body.name).trim();
  if (body.credits !== undefined) u.credits = Number(body.credits);
  if (body.isAdmin !== undefined) u.isAdmin = !!body.isAdmin;
  if (body.blocked !== undefined) { u.blocked = !!body.blocked; if (u.blocked) await env.NEXA_USERS.put("session_epoch:" + id, String(Date.now())); }
  if (body.email !== undefined) {
    const newEmail = body.email ? normalizeEmail(body.email) : null;
    if (newEmail !== u.email) {
      if (u.email) await env.NEXA_USERS.delete("email:" + u.email);
      if (newEmail) await env.NEXA_USERS.put("email:" + newEmail, id);
      u.email = newEmail;
    }
  }
  if (body.phone !== undefined) {
    const newPhone = body.phone ? normalizePhone(body.phone) : null;
    if (newPhone !== u.phone) {
      if (u.phone) await env.NEXA_USERS.delete("phone:" + u.phone);
      if (newPhone) await env.NEXA_USERS.put("phone:" + newPhone, id);
      u.phone = newPhone;
    }
  }
  if (body.preferences && typeof body.preferences === "object") u.preferences = Object.assign({}, u.preferences || {}, body.preferences);
  if (body.profile && typeof body.profile === "object") u.profile = Object.assign({}, u.profile || {}, body.profile);
  await env.NEXA_USERS.put("user:" + id, JSON.stringify(u));
  return json({ id: u.id, name: u.name, email: u.email, phone: u.phone || null, avatar: u.avatar || null, credits: u.credits, isAdmin: !!u.isAdmin, blocked: !!u.blocked, preferences: u.preferences || {}, profile: u.profile || {}, stats: u.stats || {}, createdAt: u.createdAt });
}
async function handleAdminDeleteUser(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const id = new URL(request.url).pathname.split("/").pop();
  const raw = await env.NEXA_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u = JSON.parse(raw);
  const convsRaw = await env.NEXA_USERS.get("convs:" + id);
  const convIds = convsRaw ? JSON.parse(convsRaw) : [];
  await Promise.all(convIds.map(cid => env.NEXA_USERS.delete("conv:" + cid)));
  await env.NEXA_USERS.delete("convs:" + id);
  const projIds = await loadProjectIndex(env, id);
  await Promise.all(projIds.map(pid => deleteProjectNode(env, id, pid)));
  await env.NEXA_USERS.delete("projidx:" + id);
  if (u.email) await env.NEXA_USERS.delete("email:" + u.email);
  if (u.phone) await env.NEXA_USERS.delete("phone:" + u.phone);
  await env.NEXA_USERS.delete("useridx:" + id);
  await env.NEXA_USERS.delete("user:" + id);
  return json({ success: true });
}
async function handleAdminBlockUser(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const parts = new URL(request.url).pathname.split("/");
  const id = parts[3];
  const raw = await env.NEXA_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u = JSON.parse(raw);
  const body = await request.json().catch(() => ({}));
  u.blocked = body.blocked !== undefined ? !!body.blocked : !u.blocked;
  await env.NEXA_USERS.put("user:" + id, JSON.stringify(u));
  if (u.blocked) await env.NEXA_USERS.put("session_epoch:" + id, String(Date.now()));
  return json({ id, blocked: u.blocked });
}
async function handleAdminSetCredits(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const parts = new URL(request.url).pathname.split("/");
  const id = parts[3];
  const raw = await env.NEXA_USERS.get("user:" + id);
  if (!raw) return error("Utilizador não encontrado", 404);
  const u = JSON.parse(raw);
  const body = await request.json().catch(() => ({}));
  if (typeof body.credits !== "number") return error("Campo 'credits' obrigatório (número)");
  u.credits = body.credits;
  await env.NEXA_USERS.put("user:" + id, JSON.stringify(u));
  return json({ id, credits: u.credits });
}
async function handleAdminUserConversations(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const parts = new URL(request.url).pathname.split("/");
  const id = parts[3];
  const raw = await env.NEXA_USERS.get("convs:" + id);
  const ids = raw ? JSON.parse(raw) : [];
  const all = await Promise.all(ids.map(async cid => { const data = await env.NEXA_USERS.get("conv:" + cid); return data ? JSON.parse(data) : null; }));
  return json({ conversations: all.filter(Boolean) });
}
async function handleAdminNotify(request, env) {
  const admin = await requireAdmin(request, env);
  if (!admin) return error("Acesso negado", 403);
  const body = await request.json().catch(() => null);
  if (!body || !body.subject || !body.message) return error("Campos 'subject' e 'message' obrigatórios");
  let targetEmails = [];
  if (Array.isArray(body.userIds) && body.userIds.length > 0) {
    const users = await Promise.all(body.userIds.map(async id => { const raw = await env.NEXA_USERS.get("user:" + id); return raw ? JSON.parse(raw) : null; }));
    targetEmails = users.filter(u => u && u.email).map(u => u.email);
  } else if (body.email) { targetEmails = [body.email]; } else { return error("Indica 'userIds' ou 'email'"); }
  if (!env.RESEND_API_KEY) return error("Envio de email não configurado (falta RESEND_API_KEY)", 500);
  const results = [];
  for (const to of targetEmails) {
    try {
      const res = await fetch("https://api.resend.com/emails", { method: "POST", headers: { "Content-Type": "application/json", "Authorization": "Bearer " + env.RESEND_API_KEY }, body: JSON.stringify({ from: env.RESEND_FROM || "Nexa <notificacoes@nexa.app>", to: [to], subject: body.subject, text: body.message }) });
      results.push({ to, ok: res.ok, status: res.status });
    } catch (e) { results.push({ to, ok: false, error: e.message }); }
  }
  return json({ sent: results.filter(r => r.ok).length, total: targetEmails.length, results });
}