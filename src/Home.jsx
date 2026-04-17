import { useState, useRef, useEffect, useCallback } from "react";
import AppLogo from "./assets/AppLogo";
import { TwEmoji } from "./data/emojis.jsx";
import {
  EmojiPickerOverlay,
  DocContextMenu,
  FolderSheet,
  NewFolderDialog,
  ThemeDialog,
  AiSheet,
  TemplatesSheet,
} from "./widgets/HomeWidgets";

/* ─────────────────────────────────────────────────────────────────────────────
   FlutterBridge helpers
   Tudo passa pelo bridge nativo — nunca window.alert / window.prompt
───────────────────────────────────────────────────────────────────────────── */
const FB = {
  ready: false,
  _q: [],
  _init() {
    if (this.ready) return;
    this.ready = true;
    this._q.forEach(fn => fn());
    this._q = [];
  },
  _run(fn) {
    if (this.ready) fn(); else this._q.push(fn);
  },
  alert(title, msg)           { this._run(() => window.FlutterBridge?.alert(title, msg)); },
  confirm(title, msg)         { return new Promise(res => this._run(() =>
    (window.FlutterBridge?.confirm(title, msg) || Promise.resolve(false)).then(res))); },
  modal(title, body, actions) { return new Promise(res => this._run(() =>
    (window.FlutterBridge?.modal(title, body, actions) || Promise.resolve(null)).then(res))); },
  toast(msg, dur = "short")   { this._run(() => window.FlutterBridge?.toast(msg, dur)); },
  setTheme(params)            { this._run(() => window.FlutterBridge?.setTheme(params)); },
};

/* ── Tags ── */
const TAGS = [
  { id: "work",     label: "Trabalho", color: "#2563eb", bg: "#dbeafe" },
  { id: "school",   label: "Escola",   color: "#7c3aed", bg: "#f3e8ff" },
  { id: "church",   label: "Igreja",   color: "#059669", bg: "#d1fae5" },
  { id: "biz",      label: "Negócios", color: "#d97706", bg: "#fef3c7" },
  { id: "personal", label: "Pessoal",  color: "#db2777", bg: "#fce7f3" },
];

const haptic = () => { try { if (navigator.vibrate) navigator.vibrate(8); } catch (_) {} };

/* ── Lucide icons ── */
const IC = {
  menu: `<line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/>`,
  "chevron-right": `<polyline points="9 18 15 12 9 6"/>`,
  "chevron-down": `<path d="m6 9 6 6 6-6"/>`,
  plus: `<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>`,
  send: `<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>`,
  x: `<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>`,
  search: `<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>`,
  "more-horizontal": `<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>`,
  pencil: `<path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>`,
  "trash-2": `<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>`,
  "folder-plus": `<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/><line x1="12" y1="11" x2="12" y2="17"/><line x1="9" y1="14" x2="15" y2="14"/>`,
  move: `<polyline points="5 9 2 12 5 15"/><polyline points="9 5 12 2 15 5"/><line x1="2" y1="12" x2="22" y2="12"/><polyline points="19 9 22 12 19 15"/><polyline points="15 19 12 22 9 19"/>`,
  users: `<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`,
  book: `<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>`,
  settings: `<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>`,
  sparkles: `<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/><path d="M5 3v4"/><path d="M19 17v4"/><path d="M3 5h4"/><path d="M17 19h4"/>`,
  bell: `<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>`,
  lock: `<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>`,
  palette: `<circle cx="13.5" cy="6.5" r=".5"/><circle cx="17.5" cy="10.5" r=".5"/><circle cx="8.5" cy="7.5" r=".5"/><circle cx="6.5" cy="12.5" r=".5"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"/>`,
  "log-out": `<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>`,
  sun: `<circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>`,
  moon: `<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>`,
  monitor: `<rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>`,
  "layout-template": `<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><path d="M9 21V9"/>`,
  check: `<polyline points="20 6 9 12 4 9"/>`,
  "arrow-left": `<line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/>`,
};

const Icon = ({ name, size = 18, sw = 2, style }) => (
  <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size}
    viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
    style={style} dangerouslySetInnerHTML={{ __html: IC[name] || "" }} />
);

/* ── CSS ── */
const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;-webkit-font-smoothing:antialiased}
html,body,#root{width:100%;height:100%;overflow:hidden}
.home-screen{position:absolute;inset:0;display:flex;flex-direction:column;font-family:'DM Sans',system-ui,sans-serif;overflow:hidden;will-change:transform}
.home-screen.vis{transform:translateX(0);opacity:1;transition:transform .38s cubic-bezier(.32,1,.56,1),opacity .3s}
.home-screen.hid{transform:translateX(-30%);opacity:0;pointer-events:none;transition:transform .38s cubic-bezier(.32,1,.56,1),opacity .3s}
.ctx-item{display:flex;align-items:center;gap:10px;padding:12px 16px;font-size:14px;font-weight:500;font-family:'DM Sans',sans-serif;cursor:pointer;border:none;background:transparent;width:100%;text-align:left}
.ctx-item:active{background:rgba(0,0,0,.04)}
.ctx-item.danger{color:#ff3b30}

/* press scale — botões com feedback táctil */
.pressable{transition:transform .12s cubic-bezier(.34,1.56,.64,1),opacity .12s;cursor:pointer}
.pressable:active{transform:scale(.93);opacity:.75}

/* doc row press */
.doc-row{transition:background .12s,transform .1s cubic-bezier(.34,1.56,.64,1)}
.doc-row:active{transform:scale(.985);background:var(--doc-hover)!important}

@keyframes slideUp{
  from{transform:translateY(100%);opacity:0}
  to{transform:translateY(0);opacity:1}
}
@keyframes slideDown{
  from{transform:translateY(0);opacity:1}
  to{transform:translateY(100%);opacity:0}
}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes scaleIn{
  from{transform:scale(.92) translateY(8px);opacity:0}
  to{transform:scale(1) translateY(0);opacity:1}
}
@keyframes backdropIn{from{opacity:0}to{opacity:1}}
`;

/* ─────────────────────────────────────────────────────────────────────────────
   TRASH SCREEN
───────────────────────────────────────────────────────────────────────────── */
function TrashScreen({ docs, onRestore, onDelete, onBack, T, Icon }) {
  const trashedDocs = docs.filter(d => d.trashed);

  const handleEmptyTrash = async () => {
    const ok = await FB.confirm(
      "Esvaziar lixo",
      "Todos os documentos serão apagados permanentemente. Esta acção não pode ser desfeita."
    );
    if (ok) trashedDocs.forEach(d => onDelete(d.id));
  };

  const handleDelete = async (id) => {
    const ok = await FB.confirm("Apagar documento", "Este documento será apagado permanentemente.");
    if (ok) onDelete(id);
  };

  return (
    <div style={{
      position: "absolute", inset: 0, display: "flex",
      flexDirection: "column", background: T.bg,
      fontFamily: "'DM Sans',system-ui,sans-serif",
      animation: "scaleIn .28s cubic-bezier(.32,1,.56,1) both",
    }}>
      <div style={{
        height: 56, flexShrink: 0, display: "flex", alignItems: "center",
        padding: "0 8px", background: T.bar,
        borderBottom: `1px solid ${T.brd}`,
        position: "relative", zIndex: 10,
      }}>
        <button className="pressable" onClick={onBack} style={{
          width: 44, height: 44, border: "none", background: "transparent",
          display: "flex", alignItems: "center",
          justifyContent: "center", borderRadius: 12, color: T.sub,
        }}>
          <Icon name="arrow-left" size={22} />
        </button>
        <div style={{
          position: "absolute", left: "50%", transform: "translateX(-50%)",
          fontSize: 17, fontWeight: 700, color: T.text,
        }}>Lixo</div>
        {trashedDocs.length > 0 && (
          <button className="pressable" onClick={handleEmptyTrash}
            style={{
              position: "absolute", right: 12, border: "none",
              background: "transparent",
              fontSize: 13, fontWeight: 600, color: "#ff3b30", padding: "6px 8px",
            }}>
            Esvaziar
          </button>
        )}
      </div>
      <div style={{ flex: 1, overflowY: "auto", padding: "16px", scrollbarWidth: "none" }}>
        {trashedDocs.length === 0 ? (
          <div style={{
            display: "flex", flexDirection: "column", alignItems: "center",
            justifyContent: "center", height: "60%", gap: 14, color: T.sub,
          }}>
            <Icon name="trash-2" size={40} style={{ color: T.sub }} sw={1.5} />
            <div style={{ fontSize: 17, fontWeight: 600, color: T.text }}>Lixo vazio</div>
            <div style={{ fontSize: 14, color: T.sub }}>Documentos eliminados aparecem aqui</div>
          </div>
        ) : (
          <div style={{
            background: T.card, borderRadius: 16, overflow: "hidden",
            boxShadow: "0 1px 3px rgba(0,0,0,.07),0 4px 16px rgba(0,0,0,.05)",
          }}>
            {trashedDocs.map((doc, idx) => (
              <div key={doc.id} style={{
                padding: "14px 16px",
                borderBottom: idx < trashedDocs.length - 1 ? `1px solid ${T.brd}` : "none",
              }}>
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <TwEmoji cp={doc.emoji || "1f4c4"} size={22} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      fontSize: 14, fontWeight: 600, color: T.text,
                      overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
                    }}>{doc.title}</div>
                    <div style={{ fontSize: 12, color: T.sub }}>{doc.date}</div>
                  </div>
                  <button className="pressable" onClick={() => onRestore(doc.id)} style={{
                    border: "none", background: "rgba(0,122,255,.1)",
                    color: "#007aff", fontSize: 12, fontWeight: 600,
                    padding: "5px 10px", borderRadius: 8,
                  }}>Restaurar</button>
                  <button className="pressable" onClick={() => handleDelete(doc.id)} style={{
                    border: "none", background: "rgba(255,59,48,.1)",
                    color: "#ff3b30", fontSize: 12, fontWeight: 600,
                    padding: "5px 10px", borderRadius: 8,
                  }}>Apagar</button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

/* ── Drawer item ── */
function DrawerItem({ icon, label, textColor, subColor, iconColor, right, onClick, customIcon }) {
  return (
    <button className="pressable" onClick={onClick}
      style={{
        display: "flex", alignItems: "center", gap: 13, padding: "12px 18px",
        fontSize: 15, fontWeight: 500, color: textColor,
        border: "none", background: "transparent", width: "100%", textAlign: "left",
        fontFamily: "'DM Sans',sans-serif",
      }}
      onPointerOver={e => e.currentTarget.style.background = "rgba(128,128,128,.07)"}
      onPointerOut={e => e.currentTarget.style.background = "transparent"}>
      {customIcon
        ? <span style={{ flexShrink: 0, display: "flex", alignItems: "center" }}>{customIcon}</span>
        : <Icon name={icon} size={20} style={{ color: iconColor || textColor, flexShrink: 0 }} />}
      <span style={{ flex: 1 }}>{label}</span>
      {right}
    </button>
  );
}

/* ══════════════════════════════════════
   HOME SCREEN
══════════════════════════════════════ */
export default function Home({ visible, docs, setDocs, projects, setProjects, onOpenEditor }) {
  const [drawerOpen,    setDrawerOpen]    = useState(false);
  const [settingsOpen,  setSettingsOpen]  = useState(false);
  const [projExp,       setProjExp]       = useState({});
  const [activeTag,     setActiveTag]     = useState(null);
  const [aiOpen,        setAiOpen]        = useState(false);
  const [aiInput,       setAiInput]       = useState("");
  const [aiLoading,     setAiLoading]     = useState(false);
  const [scrolled,      setScrolled]      = useState(false);
  const [showTrash,     setShowTrash]     = useState(false);
  const [ctxMenu,       setCtxMenu]       = useState(null);
  const [folderSheet,   setFolderSheet]   = useState(null);
  const [emojiPicker,   setEmojiPicker]   = useState(null);
  const [newFolderDlg,  setNewFolderDlg]  = useState(null);
  const [newFolderName, setNewFolderName] = useState("");
  const [themeDlg,      setThemeDlg]      = useState(false);
  const [templatesOpen, setTemplatesOpen] = useState(false);
  const [theme,         setTheme]         = useState("system");

  /* ── Flutter bridge primary colour override ── */
  const [flutterPrimary, setFlutterPrimary] = useState(null);
  const [flutterDark,    setFlutterDark]    = useState(null);

  const scrollRef = useRef(null);

  /* CSS injection */
  useEffect(() => {
    const s = document.createElement("style");
    s.textContent = CSS;
    document.head.appendChild(s);
    return () => document.head.removeChild(s);
  }, []);

  /* ── FlutterBridge bootstrap ── */
  useEffect(() => {
    const init = () => FB._init();
    if (window.FlutterBridge) {
      init();
    } else {
      window.addEventListener("FlutterBridgeReady", init, { once: true });
    }
    return () => window.removeEventListener("FlutterBridgeReady", init);
  }, []);

  /* ── Listen for theme changes pushed from Flutter ── */
  useEffect(() => {
    const handler = e => {
      const { primaryColor, isDark } = e.detail || {};
      if (primaryColor) setFlutterPrimary(primaryColor);
      if (isDark !== undefined) setFlutterDark(isDark);
    };
    window.addEventListener("flutter_theme_changed", handler);
    return () => window.removeEventListener("flutter_theme_changed", handler);
  }, []);

  /* ── Sync theme changes to Flutter ── */
  const applyTheme = useCallback((newTheme) => {
    setTheme(newTheme);
    const dark = newTheme === "dark" || (newTheme === "system" && sysDark);
    FB.setTheme({
      isDark: dark,
      primaryColor: flutterPrimary || (dark ? "#ffffff" : "#000000"),
      backgroundColor: dark ? "#111111" : "#f5f5f7",
    });
  }, [flutterPrimary]);

  /* Theme resolution */
  const [sysDark, setSysDark] = useState(() => window.matchMedia("(prefers-color-scheme:dark)").matches);
  useEffect(() => {
    const mq = window.matchMedia("(prefers-color-scheme:dark)");
    const h = e => setSysDark(e.matches);
    mq.addEventListener("change", h);
    return () => mq.removeEventListener("change", h);
  }, []);

  const isDark = flutterDark !== null
    ? flutterDark
    : (theme === "dark" || (theme === "system" && sysDark));

  /* Theme colours */
  const accent = flutterPrimary || (isDark ? "#ffffff" : "#1c1c1e");
  const T = {
    bg:      isDark ? "#111111" : "#f5f5f7",
    card:    isDark ? "#1c1c1e" : "#ffffff",
    bar:     isDark ? "#1c1c1e" : "#ffffff",
    text:    isDark ? "#f2f2f7" : "#1c1c1e",
    sub:     isDark ? "#636366" : "#8e8e93",
    brd:     isDark ? "rgba(255,255,255,.07)" : "rgba(0,0,0,.06)",
    input:   isDark ? "#2c2c2e" : "#ffffff",
    pill:    isDark ? "#1c1c1e" : "#ffffff",
    chip:    isDark ? "#2c2c2e" : "#ffffff",
    chipBrd: isDark ? "rgba(255,255,255,.1)" : "rgba(0,0,0,.1)",
    hover:   isDark ? "rgba(255,255,255,.04)" : "rgba(0,0,0,.02)",
    accent,
  };

  const visibleDocs  = (activeTag ? docs.filter(d => d.tag === activeTag) : docs).filter(d => !d.trashed);
  const trashedCount = docs.filter(d => d.trashed).length;

  const trashDoc   = id => { setDocs(p => p.map(d => d.id === id ? { ...d, trashed: true } : d)); setCtxMenu(null); };
  const restoreDoc = id => setDocs(p => p.map(d => d.id === id ? { ...d, trashed: false } : d));
  const permDelete = id => setDocs(p => p.filter(d => d.id !== id));

  const moveToFolder = (docId, folderId, projId) => {
    setDocs(p => p.map(d => d.id === docId ? { ...d, folderId, projId } : d));
    setFolderSheet(null);
  };

  const confirmNewFolder = () => {
    if (!newFolderName.trim() || !newFolderDlg) return;
    setProjects(prev => prev.map(p => {
      if (p.id !== newFolderDlg.projId) return p;
      const nf = { id: "f" + Date.now(), name: newFolderName.trim(), emoji: "1f4c2", subFolders: [], files: [] };
      if (!newFolderDlg.parentFolderId) return { ...p, folders: [...p.folders, nf] };
      return {
        ...p,
        folders: p.folders.map(f =>
          f.id === newFolderDlg.parentFolderId
            ? { ...f, subFolders: [...(f.subFolders || []), nf] }
            : f
        ),
      };
    }));
    setNewFolderName("");
    setNewFolderDlg(null);
  };

  const setEmojiFor = (target, id, cp) => {
    if (target === "proj")   setProjects(p => p.map(pr => pr.id === id ? { ...pr, emoji: cp } : pr));
    if (target === "folder") setProjects(p => p.map(pr => ({ ...pr, folders: pr.folders.map(f => f.id === id ? { ...f, emoji: cp } : f) })));
    if (target === "doc")    setDocs(p => p.map(d => d.id === id ? { ...d, emoji: cp } : d));
    setEmojiPicker(null);
  };

  /* ── Novo projecto via bridge nativo ── */
  const handleNewProject = async () => {
    const name = await FB.modal(
      "Novo projecto",
      "Introduz o nome do projecto",
      [{ label: "Criar", style: "primary" }, { label: "Cancelar", style: "ghost" }]
    );
    if (name && name !== "Cancelar") {
      // bridge só devolve o label clicado; para nome real usar um input nativo
      // aqui usamos o label como sinal e criamos com nome genérico
      // (implementação real requereria um input widget do lado Flutter)
      setProjects(p => [...p, {
        id: "p" + Date.now(),
        name: "Novo projecto",
        emoji: "1f4c1",
        folders: [],
      }]);
    }
  };

  const doAI = async () => {
    const prompt = aiInput.trim(); if (!prompt) return;
    setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514", max_tokens: 900,
          system: "Cria um documento em português com HTML semântico (h1,h2,p). Responde APENAS com o HTML.",
          messages: [{ role: "user", content: prompt }],
        }),
      });
      const d = await r.json();
      const html = d.content?.map(i => i.text || "").join("") || "";
      const nd = { id: Date.now(), title: prompt.slice(0, 40), emoji: "1f9e0", preview: prompt.slice(0, 90) + "…", date: "Agora", tag: "work", content: html };
      setDocs(p => [nd, ...p]);
      setAiInput(""); setAiOpen(false);
      onOpenEditor(nd);
    } catch (_) {
      FB.toast("Erro ao gerar documento", "long");
    }
    setAiLoading(false);
  };

  const handleTemplateSelect = tmpl => {
    const doc = {
      id: Date.now(), title: tmpl.label, emoji: tmpl.emoji,
      preview: tmpl.desc, date: "Agora", tag: "work",
      content: `<h1>${tmpl.label}</h1><p>${tmpl.desc}</p>`,
    };
    setDocs(p => [doc, ...p]);
    setTemplatesOpen(false);
    onOpenEditor(doc);
  };

  /* ── Trash com confirm nativo ── */
  const handleTrashDoc = async (id) => {
    const ok = await FB.confirm("Mover para o lixo", "O documento será movido para o lixo.");
    if (ok) trashDoc(id);
  };

  /* Trash full-screen */
  if (showTrash) {
    return (
      <TrashScreen
        docs={docs} onRestore={restoreDoc} onDelete={permDelete}
        onBack={() => setShowTrash(false)} T={T} Icon={Icon}
      />
    );
  }

  return (
    <div className={`home-screen ${visible ? "vis" : "hid"}`}
      style={{ background: T.bg, "--doc-hover": T.hover }}>

      {/* ── Overlays from widgets ── */}
      {emojiPicker && (
        <EmojiPickerOverlay
          picker={emojiPicker} onSelect={setEmojiFor}
          onClose={() => setEmojiPicker(null)} T={T} Icon={Icon}
        />
      )}
      {ctxMenu && (
        <DocContextMenu
          ctxMenu={ctxMenu}
          onEdit={() => { onOpenEditor(docs.find(d => d.id === ctxMenu.docId)); setCtxMenu(null); }}
          onMove={() => { setFolderSheet(ctxMenu.docId); setCtxMenu(null); }}
          onTrash={() => handleTrashDoc(ctxMenu.docId)}
          onClose={() => setCtxMenu(null)}
          T={T} Icon={Icon}
        />
      )}
      {folderSheet && (
        <FolderSheet
          projects={projects}
          onMove={(fId, pId) => moveToFolder(folderSheet, fId, pId)}
          onClose={() => setFolderSheet(null)}
          T={T} Icon={Icon}
        />
      )}
      {newFolderDlg && (
        <NewFolderDialog
          newFolderDlg={newFolderDlg}
          newFolderName={newFolderName}
          setNewFolderName={setNewFolderName}
          onConfirm={confirmNewFolder}
          onClose={() => setNewFolderDlg(null)}
          T={T} Icon={Icon}
        />
      )}
      {themeDlg && (
        <ThemeDialog
          theme={theme} setTheme={applyTheme}
          onClose={() => setThemeDlg(false)}
          T={T} Icon={Icon} isDark={isDark}
        />
      )}
      {aiOpen && (
        <AiSheet
          aiInput={aiInput} setAiInput={setAiInput}
          aiLoading={aiLoading} onSubmit={doAI}
          onClose={() => setAiOpen(false)} T={T} Icon={Icon}
        />
      )}
      {templatesOpen && (
        <TemplatesSheet
          onSelect={handleTemplateSelect}
          onClose={() => setTemplatesOpen(false)}
          T={T} Icon={Icon}
        />
      )}

      {/* ── DRAWER MASK ── */}
      {drawerOpen && (
        <div
          style={{
            position: "fixed", inset: 0, zIndex: 49,
            background: "rgba(0,0,0,.32)",
            backdropFilter: "blur(2px)",
            WebkitBackdropFilter: "blur(2px)",
            animation: "backdropIn .22s ease both",
          }}
          onClick={() => setDrawerOpen(false)} />
      )}

      {/* ── DRAWER ── */}
      <div style={{
        position: "fixed", top: 0, left: 0, width: 272, height: "100%",
        background: T.card, zIndex: 50, display: "flex", flexDirection: "column",
        transform: drawerOpen ? "translateX(0)" : "translateX(-100%)",
        transition: "transform .36s cubic-bezier(.32,1,.56,1)",
        boxShadow: drawerOpen ? "4px 0 32px rgba(0,0,0,.18)" : "none",
        borderRight: drawerOpen ? `1px solid ${T.brd}` : 'none',
      }}>
        <div style={{
          paddingTop: 48, paddingBottom: 16, paddingLeft: 18, paddingRight: 18,
          borderBottom: `1px solid ${T.brd}`, display: "flex", alignItems: "center", gap: 12,
        }}>
          <AppLogo size={36} />
          <div>
            <div style={{ fontSize: 17, fontWeight: 700, color: T.text }}>Docu</div>
            <div style={{ fontSize: 12, color: T.sub }}>Espaço de trabalho</div>
          </div>
        </div>

        <div style={{ flex: 1, overflowY: "auto", scrollbarWidth: "none", paddingTop: 6 }}>
          <DrawerItem icon="book" label="Biblioteca" textColor={T.text} subColor={T.sub} onClick={() => setDrawerOpen(false)} />

          <DrawerItem icon="settings" label="Configurações" textColor={T.text} subColor={T.sub}
            right={<Icon name={settingsOpen ? "chevron-down" : "chevron-right"} size={15} style={{ color: T.sub }} />}
            onClick={() => setSettingsOpen(v => !v)} />

          {settingsOpen && (
            <div style={{ borderLeft: `2px solid ${T.brd}`, marginLeft: 38 }}>
              {[
                { icon: "bell",    label: "Notificações" },
                { icon: "lock",    label: "Privacidade" },
                { icon: "palette", label: "Tema",            action: "theme" },
                { icon: "users",   label: "Conta" },
                { icon: "log-out", label: "Terminar sessão", danger: true },
              ].map(s => (
                <button key={s.label} className="pressable" onClick={async () => {
                  if (s.action === "theme") { setThemeDlg(true); return; }
                  if (s.danger) {
                    const ok = await FB.confirm("Terminar sessão", "Tens a certeza que queres terminar sessão?");
                    if (ok) setDrawerOpen(false);
                    return;
                  }
                  setDrawerOpen(false);
                }} style={{
                  display: "flex", alignItems: "center", gap: 13,
                  padding: "11px 18px 11px 16px", fontSize: 14, fontWeight: 500,
                  color: s.danger ? "#ff3b30" : T.text,
                  border: "none", background: "transparent", width: "100%",
                  textAlign: "left", fontFamily: "'DM Sans',sans-serif",
                }}>
                  <Icon name={s.icon} size={16} style={{ color: s.danger ? "#ff3b30" : T.sub, flexShrink: 0 }} />
                  {s.label}
                </button>
              ))}
            </div>
          )}

          <DrawerItem icon="users" label="Membros" textColor={T.text} subColor={T.sub} onClick={() => setDrawerOpen(false)} />

          <DrawerItem icon="trash-2" label="Lixo" textColor="#ff3b30" subColor={T.sub}
            iconColor="#ff3b30"
            right={<>
              {trashedCount > 0 && (
                <span style={{
                  fontSize: 11, fontWeight: 700, background: "#ff3b30", color: "#fff",
                  borderRadius: 9999, padding: "1px 7px", marginRight: 4,
                }}>{trashedCount}</span>
              )}
              <Icon name="chevron-right" size={15} style={{ color: "#ffb3b0" }} />
            </>}
            onClick={() => { setShowTrash(true); setDrawerOpen(false); }} />

          <div style={{ height: 1, background: T.brd, margin: "6px 0" }} />

          <div style={{
            padding: "8px 18px 4px", fontSize: 11, fontWeight: 700, color: T.sub,
            textTransform: "uppercase", letterSpacing: ".07em",
            display: "flex", alignItems: "center", justifyContent: "space-between",
          }}>
            <span>Projetos</span>
            <button className="pressable"
              onClick={handleNewProject}
              style={{ border: "none", background: "transparent", color: T.sub, padding: 2 }}>
              <Icon name="plus" size={15} />
            </button>
          </div>

          {projects.map(proj => (
            <div key={proj.id}>
              <DrawerItem
                label={proj.name} textColor={T.text} subColor={T.sub}
                customIcon={
                  <span onClick={e => { e.stopPropagation(); setEmojiPicker({ target: "proj", id: proj.id }); }}>
                    <TwEmoji cp={proj.emoji} size={20} />
                  </span>
                }
                right={<Icon name={projExp[proj.id] ? "chevron-down" : "chevron-right"} size={14} style={{ color: T.sub }} />}
                onClick={() => setProjExp(p => ({ ...p, [proj.id]: !p[proj.id] }))} />

              {projExp[proj.id] && (
                <div style={{ borderLeft: `2px solid ${T.brd}`, marginLeft: 38 }}>
                  {proj.folders.map(folder => (
                    <div key={folder.id}>
                      <button className="pressable" style={{
                        display: "flex", alignItems: "center", gap: 13,
                        padding: "10px 18px 10px 16px", fontSize: 14, fontWeight: 400,
                        color: T.text, border: "none",
                        background: "transparent", width: "100%", textAlign: "left",
                        fontFamily: "'DM Sans',sans-serif",
                      }}>
                        <span onClick={e => { e.stopPropagation(); setEmojiPicker({ target: "folder", id: folder.id }); }}>
                          <TwEmoji cp={folder.emoji} size={16} />
                        </span>
                        <span style={{ flex: 1 }}>{folder.name}</span>
                        <button onClick={e => { e.stopPropagation(); setNewFolderDlg({ projId: proj.id, parentFolderId: folder.id }); setNewFolderName(""); }}
                          style={{ border: "none", background: "transparent", color: T.sub, padding: 4, borderRadius: 8 }}>
                          <Icon name="folder-plus" size={14} />
                        </button>
                        <Icon name="chevron-right" size={13} style={{ color: T.sub }} />
                      </button>
                      {(folder.subFolders || []).map(sf => (
                        <button key={sf.id} className="pressable" style={{
                          display: "flex", alignItems: "center", gap: 10,
                          padding: "8px 18px 8px 28px", fontSize: 13, fontWeight: 400,
                          color: T.text, border: "none",
                          background: "transparent", width: "100%", textAlign: "left",
                          fontFamily: "'DM Sans',sans-serif",
                        }}>
                          <TwEmoji cp={sf.emoji} size={14} />
                          <span style={{ flex: 1 }}>{sf.name}</span>
                        </button>
                      ))}
                    </div>
                  ))}
                  <button className="pressable" onClick={() => { setNewFolderDlg({ projId: proj.id }); setNewFolderName(""); }}
                    style={{
                      display: "flex", alignItems: "center", gap: 10,
                      padding: "10px 18px 10px 16px", fontSize: 13, color: T.sub,
                      fontWeight: 400, border: "none",
                      background: "transparent", width: "100%", textAlign: "left",
                      fontFamily: "'DM Sans',sans-serif",
                    }}>
                    <Icon name="folder-plus" size={15} style={{ color: T.sub }} /> Nova pasta
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* ── TOPBAR ── */}
      <div style={{
        height: 56, flexShrink: 0, display: "flex", alignItems: "center",
        padding: "0 8px", background: T.bar, position: "relative", zIndex: 10,
        boxShadow: scrolled ? `0 1px 0 ${T.brd},0 2px 8px rgba(0,0,0,.06)` : "none",
        transition: "transform .36s cubic-bezier(.32,1,.56,1),box-shadow .2s",
        transform: drawerOpen ? "translateX(272px)" : "none",
      }}>
        <button className="pressable" onClick={() => { haptic(); setDrawerOpen(true); }} style={{
          width: 44, height: 44, border: "none", background: "transparent",
          display: "flex", alignItems: "center",
          justifyContent: "center", borderRadius: 12, color: T.sub,
        }}>
          <Icon name="menu" size={22} />
        </button>
        <div style={{
          position: "absolute", left: "50%", transform: "translateX(-50%)",
          fontSize: 17, fontWeight: 700, color: T.text,
        }}>Documentos</div>
        <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 4 }}>
          <button className="pressable"
            onClick={() => setTemplatesOpen(true)}
            style={{
              width: 40, height: 40, border: "none", background: "transparent",
              display: "flex", alignItems: "center",
              justifyContent: "center", borderRadius: 12, color: T.sub,
            }}>
            <Icon name="layout-template" size={20} />
          </button>
          <button className="pressable"
            onClick={() => { haptic(); onOpenEditor({ id: Date.now(), title: "", emoji: "1f4c4", content: "" }); }}
            style={{
              width: 40, height: 40, border: "none", background: "transparent",
              display: "flex", alignItems: "center",
              justifyContent: "center", borderRadius: 12, color: T.sub,
            }}>
            <Icon name="plus" size={22} />
          </button>
        </div>
      </div>

      {/* ── SCROLL CONTENT ── */}
      <div
        ref={scrollRef}
        onScroll={() => setScrolled(scrollRef.current?.scrollTop > 4)}
        style={{
          flex: 1, overflowY: "auto", overflowX: "hidden",
          WebkitOverflowScrolling: "touch", padding: "16px 16px 180px",
          scrollbarWidth: "none",
          transform: drawerOpen ? "translateX(272px)" : "none",
          transition: "transform .36s cubic-bezier(.32,1,.56,1)",
        }}>

        {/* Search */}
        <div style={{
          display: "flex", alignItems: "center", gap: 10,
          background: T.card, borderRadius: 12,
          boxShadow: "0 1px 3px rgba(0,0,0,.07)",
          padding: "11px 14px", marginBottom: 16,
        }}>
          <Icon name="search" size={16} style={{ color: T.sub, flexShrink: 0 }} />
          <input
            placeholder="Pesquisar documentos…"
            style={{
              flex: 1, border: "none", outline: "none", fontSize: 15,
              color: T.text, background: "transparent",
              fontFamily: "'DM Sans',sans-serif",
              WebkitUserSelect: "text", userSelect: "text",
            }} />
        </div>

        {/* Tags */}
        <div style={{
          display: "flex", gap: 8, overflowX: "auto", paddingBottom: 4,
          marginBottom: 16, scrollbarWidth: "none", WebkitOverflowScrolling: "touch",
        }}>
          <button className="pressable"
            onClick={() => setActiveTag(null)}
            style={{
              flexShrink: 0, padding: "6px 14px", borderRadius: 9999, fontSize: 13,
              fontWeight: 600,
              border: `1.5px solid ${!activeTag ? T.accent : T.chipBrd}`,
              background: !activeTag ? T.accent : T.chip,
              color: !activeTag ? (isDark ? "#1c1c1e" : "#fff") : T.text,
              fontFamily: "'DM Sans',sans-serif",
            }}>Todos</button>
          {TAGS.map(t => (
            <button key={t.id} className="pressable"
              onClick={() => setActiveTag(activeTag === t.id ? null : t.id)}
              style={{
                flexShrink: 0, padding: "6px 14px", borderRadius: 9999, fontSize: 13,
                fontWeight: 600,
                border: `1.5px solid ${activeTag === t.id ? t.color : t.bg}`,
                background: activeTag === t.id ? t.color : T.chip,
                color: activeTag === t.id ? "#fff" : t.color,
                fontFamily: "'DM Sans',sans-serif",
              }}>{t.label}</button>
          ))}
        </div>

        <div style={{ fontSize: 13, fontWeight: 700, color: T.sub, marginBottom: 10, padding: "0 2px" }}>
          Recentes
        </div>

        {/* Doc list */}
        {visibleDocs.length === 0 ? (
          <div style={{ textAlign: "center", padding: "40px 20px", color: T.sub, fontSize: 15 }}>
            Nenhum documento
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 2, marginBottom: 20 }}>
            {visibleDocs.map((doc, idx) => {
              const tag     = TAGS.find(t => t.id === doc.tag);
              const isFirst = idx === 0;
              const isLast  = idx === visibleDocs.length - 1;
              const borderRadius = isFirst ? "12px 12px 3px 3px" : isLast ? "3px 3px 12px 12px" : "3px";

              return (
                <div key={doc.id}
                  className="doc-row"
                  onClick={() => onOpenEditor(doc)}
                  style={{
                    padding: "14px 16px",
                    background: T.card,
                    borderRadius,
                    boxShadow: "0 1px 2px rgba(0,0,0,.05)",
                    cursor: "pointer",
                  }}>
                  <div style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
                    <div
                      onClick={e => { e.stopPropagation(); setEmojiPicker({ target: "doc", id: doc.id }); }}
                      style={{
                        width: 42, height: 42, borderRadius: 11, background: T.bg,
                        display: "flex", alignItems: "center", justifyContent: "center",
                        flexShrink: 0, cursor: "pointer",
                        transition: "transform .12s cubic-bezier(.34,1.56,.64,1)",
                      }}
                      onPointerDown={e => e.currentTarget.style.transform = "scale(.88)"}
                      onPointerUp={e => e.currentTarget.style.transform = "scale(1)"}
                      onPointerLeave={e => e.currentTarget.style.transform = "scale(1)"}>
                      <TwEmoji cp={doc.emoji || "1f4c4"} size={26} />
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 4, marginBottom: 3 }}>
                        <div style={{
                          fontSize: 15, fontWeight: 600, color: T.text,
                          overflow: "hidden", textOverflow: "ellipsis",
                          whiteSpace: "nowrap", flex: 1,
                        }}>{doc.title}</div>
                        <button className="pressable" onClick={e => { e.stopPropagation(); onOpenEditor(doc); }}
                          style={{ border: "none", background: "transparent", color: T.sub, padding: 6, flexShrink: 0, borderRadius: 8 }}>
                          <Icon name="pencil" size={15} />
                        </button>
                        <button className="pressable" onClick={e => {
                          e.stopPropagation(); haptic();
                          const r = e.currentTarget.getBoundingClientRect();
                          setCtxMenu({ docId: doc.id, x: Math.min(r.right - 200, window.innerWidth - 215), y: r.bottom + 6 });
                        }} style={{ border: "none", background: "transparent", color: T.sub, padding: 6, flexShrink: 0, borderRadius: 8 }}>
                          <Icon name="more-horizontal" size={16} />
                        </button>
                      </div>
                      <div style={{
                        fontSize: 13, color: T.sub, marginBottom: 8,
                        overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
                      }}>{doc.preview}</div>
                      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                        {tag && (
                          <span style={{
                            padding: "2px 9px", borderRadius: 9999, fontSize: 11,
                            fontWeight: 600, background: tag.bg, color: tag.color,
                          }}>{tag.label}</span>
                        )}
                        <span style={{ fontSize: 11, color: T.sub }}>{doc.date}</span>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* ── FLOATING AI BAR ── */}
      <div style={{
        position: "fixed", left: "50%",
        transform: drawerOpen ? "translateX(calc(-50% + 136px))" : "translateX(-50%)",
        bottom: "max(20px,env(safe-area-inset-bottom,20px))",
        width: "min(92vw,460px)", zIndex: 20,
        transition: "transform .36s cubic-bezier(.32,1,.56,1)",
      }}>
        <div className="pressable" onClick={() => { haptic(); setAiOpen(true); }} style={{
          display: "flex", alignItems: "center", gap: 12, padding: "0 20px",
          height: 56, background: T.pill, borderRadius: 9999,
          border: `1px solid ${T.brd}`,
          boxShadow: "0 6px 24px rgba(0,0,0,.12),0 1px 4px rgba(0,0,0,.06)",
        }}>
          <Icon name="sparkles" size={20} style={{ color: "#007aff", flexShrink: 0 }} />
          <span style={{ fontSize: 15, color: T.sub, flex: 1 }}>Criar com IA…</span>
        </div>
      </div>
    </div>
  );
}