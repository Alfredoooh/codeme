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

import {
  Menu,
  ChevronRight,
  ChevronDown,
  Plus,
  Send,
  X,
  Search,
  MoreHorizontal,
  Pencil,
  Trash2,
  FolderPlus,
  Move,
  Users,
  BookOpen,
  Settings,
  Sparkles,
  Bell,
  Lock,
  Palette,
  LogOut,
  Sun,
  Moon,
  Monitor,
  LayoutGrid,
  Check,
  ArrowLeft,
  Folder,
} from "lucide-react";

/* ─────────────────────────────────────────────────────────────────────────────
   FlutterBridge helpers
───────────────────────────────────────────────────────────────────────────── */
const FB = {
  ready: false,
  _q: [],
  _init() {
    if (this.ready) return;
    this.ready = true;
    this._q.forEach((fn) => fn());
    this._q = [];
  },
  _run(fn) {
    if (this.ready) fn();
    else this._q.push(fn);
  },
  alert(title, msg) {
    this._run(() => window.FlutterBridge?.alert(title, msg));
  },
  confirm(title, msg) {
    return new Promise((res) =>
      this._run(() =>
        (window.FlutterBridge?.confirm(title, msg) || Promise.resolve(false)).then(res)
      )
    );
  },
  modal(title, body, actions) {
    return new Promise((res) =>
      this._run(() =>
        (window.FlutterBridge?.modal(title, body, actions) || Promise.resolve(null)).then(res)
      )
    );
  },
  toast(msg, dur = "short") {
    this._run(() => window.FlutterBridge?.toast(msg, dur));
  },
  setTheme(params) {
    this._run(() => window.FlutterBridge?.setTheme(params));
  },
};

const TAGS = [
  { id: "work", label: "Trabalho", color: "#2563eb", bg: "#dbeafe" },
  { id: "school", label: "Escola", color: "#7c3aed", bg: "#f3e8ff" },
  { id: "church", label: "Igreja", color: "#059669", bg: "#d1fae5" },
  { id: "biz", label: "Negócios", color: "#d97706", bg: "#fef3c7" },
  { id: "personal", label: "Pessoal", color: "#db2777", bg: "#fce7f3" },
];

const haptic = () => {
  try {
    if (navigator.vibrate) navigator.vibrate(8);
  } catch (_) {}
};

const ICONS = {
  menu: Menu,
  "chevron-right": ChevronRight,
  "chevron-down": ChevronDown,
  plus: Plus,
  send: Send,
  x: X,
  search: Search,
  "more-horizontal": MoreHorizontal,
  pencil: Pencil,
  "trash-2": Trash2,
  "folder-plus": FolderPlus,
  move: Move,
  users: Users,
  book: BookOpen,
  settings: Settings,
  sparkles: Sparkles,
  bell: Bell,
  lock: Lock,
  palette: Palette,
  "log-out": LogOut,
  sun: Sun,
  moon: Moon,
  monitor: Monitor,
  "layout-template": LayoutGrid,
  check: Check,
  "arrow-left": ArrowLeft,
  folder: Folder,
};

const Icon = ({ name, size = 18, sw = 2, style }) => {
  const Cmp = ICONS[name];
  if (!Cmp) return null;
  return <Cmp size={size} strokeWidth={sw} style={style} aria-hidden="true" />;
};

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;-webkit-font-smoothing:antialiased}
html,body,#root{width:100%;height:100%;overflow:hidden}
.home-screen{position:absolute;inset:0;display:flex;flex-direction:column;font-family:'DM Sans',system-ui,sans-serif;overflow:hidden;will-change:transform}
.home-screen.vis{transform:translateX(0);opacity:1;transition:transform .38s cubic-bezier(.32,1,.56,1),opacity .3s}
.home-screen.hid{transform:translateX(-30%);opacity:0;pointer-events:none;transition:transform .38s cubic-bezier(.32,1,.56,1),opacity .3s}
.pressable{transition:transform .12s cubic-bezier(.34,1.56,.64,1),opacity .12s;cursor:pointer}
.pressable:active{transform:scale(.93);opacity:.75}
.doc-row{transition:background .12s,transform .1s cubic-bezier(.34,1.56,.64,1)}
.doc-row:active{transform:scale(.985)}
.ctx-item{display:flex;align-items:center;gap:10px;padding:12px 16px;font-size:14px;font-weight:500;font-family:'DM Sans',sans-serif;cursor:pointer;border:none;background:transparent;width:100%;text-align:left}
.ctx-item:active{background:rgba(0,0,0,.04)}
.ctx-item.danger{color:#ff3b30}
@keyframes slideUp{from{transform:translateY(100%);opacity:0}to{transform:translateY(0);opacity:1}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
`;

function TrashScreen({ docs, onRestore, onDelete, onBack, T, Icon }) {
  const trashedDocs = docs.filter((d) => d.trashed);

  const handleEmptyTrash = async () => {
    const ok = await FB.confirm(
      "Esvaziar lixo",
      "Todos os documentos serão apagados permanentemente. Esta acção não pode ser desfeita."
    );
    if (ok) trashedDocs.forEach((d) => onDelete(d.id));
  };

  const handleDelete = async (id) => {
    const ok = await FB.confirm("Apagar documento", "Este documento será apagado permanentemente.");
    if (ok) onDelete(id);
  };

  return (
    <div style={{ position: "absolute", inset: 0, background: T.bg, color: T.text, display: "flex", flexDirection: "column" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "14px 16px", borderBottom: `1px solid ${T.brd}` }}>
        <button onClick={onBack} className="pressable" style={{ width: 40, height: 40, border: "none", background: "transparent", borderRadius: 12, color: T.text }}>
          <Icon name="arrow-left" />
        </button>
        <div style={{ fontSize: 17, fontWeight: 700, flex: 1 }}>Lixo</div>
        {trashedDocs.length > 0 && (
          <button onClick={handleEmptyTrash} className="pressable" style={{ border: "none", background: "transparent", color: "#ff3b30", fontSize: 13, fontWeight: 700, padding: "8px 10px" }}>
            Esvaziar
          </button>
        )}
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: 16 }}>
        {trashedDocs.length === 0 ? (
          <div style={{ marginTop: 72, textAlign: "center", color: T.sub }}>
            <div style={{ fontSize: 22, fontWeight: 700, color: T.text, marginBottom: 8 }}>Lixo vazio</div>
            <div>Documentos eliminados aparecem aqui</div>
          </div>
        ) : (
          <div style={{ display: "grid", gap: 12 }}>
            {trashedDocs.map((doc) => (
              <div
                key={doc.id}
                style={{
                  borderRadius: 16,
                  padding: 14,
                  background: T.card,
                  border: `1px solid ${T.brd}`,
                  boxShadow: "0 1px 2px rgba(0,0,0,.05)",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                  <div style={{ width: 42, height: 42, borderRadius: 12, background: T.bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <TwEmoji cp={doc.emoji || "1f5ce"} size={20} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: 700, fontSize: 15, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{doc.title || "Sem título"}</div>
                    <div style={{ fontSize: 12, color: T.sub, marginTop: 2 }}>{doc.date || ""}</div>
                  </div>
                </div>

                <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
                  <button
                    onClick={() => onRestore(doc.id)}
                    className="pressable"
                    style={{
                      border: "none",
                      background: "rgba(0,122,255,.1)",
                      color: "#007aff",
                      fontSize: 12,
                      fontWeight: 700,
                      padding: "7px 12px",
                      borderRadius: 10,
                    }}
                  >
                    Restaurar
                  </button>
                  <button
                    onClick={() => handleDelete(doc.id)}
                    className="pressable"
                    style={{
                      border: "none",
                      background: "rgba(255,59,48,.1)",
                      color: "#ff3b30",
                      fontSize: 12,
                      fontWeight: 700,
                      padding: "7px 12px",
                      borderRadius: 10,
                    }}
                  >
                    Apagar
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function DrawerItem({ icon, label, textColor, subColor, iconColor, right, onClick, customIcon }) {
  return (
    <button
      type="button"
      onClick={onClick}
      onPointerDown={(e) => (e.currentTarget.style.background = "rgba(128,128,128,.07)")}
      onPointerOut={(e) => (e.currentTarget.style.background = "transparent")}
      className="pressable"
      style={{
        display: "flex",
        alignItems: "center",
        gap: 12,
        width: "100%",
        border: "none",
        background: "transparent",
        padding: "11px 18px 11px 16px",
        textAlign: "left",
        color: textColor,
        fontFamily: "'DM Sans',sans-serif",
      }}
    >
      <div style={{ width: 22, display: "flex", justifyContent: "center", color: iconColor }}>
        {customIcon ? customIcon : <Icon name={icon} />}
      </div>
      <div style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>
        <div>{label}</div>
        {subColor ? <div style={{ fontSize: 12, color: subColor, marginTop: 1 }}>{subColor}</div> : null}
      </div>
      {right}
    </button>
  );
}

export default function Home({ visible, docs, setDocs, projects, setProjects, onOpenEditor }) {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [projExp, setProjExp] = useState({});
  const [activeTag, setActiveTag] = useState(null);
  const [query, setQuery] = useState("");
  const [aiOpen, setAiOpen] = useState(false);
  const [aiInput, setAiInput] = useState("");
  const [aiLoading, setAiLoading] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [showTrash, setShowTrash] = useState(false);
  const [ctxMenu, setCtxMenu] = useState(null);
  const [folderSheet, setFolderSheet] = useState(null);
  const [emojiPicker, setEmojiPicker] = useState(null);
  const [newFolderDlg, setNewFolderDlg] = useState(null);
  const [newFolderName, setNewFolderName] = useState("");
  const [themeDlg, setThemeDlg] = useState(false);
  const [templatesOpen, setTemplatesOpen] = useState(false);
  const [theme, setTheme] = useState("system");
  const [flutterPrimary, setFlutterPrimary] = useState(null);
  const [flutterDark, setFlutterDark] = useState(null);
  const scrollRef = useRef(null);

  useEffect(() => {
    const init = () => FB._init();
    if (window.FlutterBridge) init();
    else window.addEventListener("FlutterBridgeReady", init, { once: true });
    return () => window.removeEventListener("FlutterBridgeReady", init);
  }, []);

  useEffect(() => {
    const handler = (e) => {
      const { primaryColor, isDark } = e.detail || {};
      if (primaryColor) setFlutterPrimary(primaryColor);
      if (isDark !== undefined) setFlutterDark(isDark);
    };
    window.addEventListener("flutter_theme_changed", handler);
    return () => window.removeEventListener("flutter_theme_changed", handler);
  }, []);

  const [sysDark, setSysDark] = useState(() =>
    window.matchMedia("(prefers-color-scheme:dark)").matches
  );

  useEffect(() => {
    const mq = window.matchMedia("(prefers-color-scheme:dark)");
    const h = (e) => setSysDark(e.matches);
    mq.addEventListener("change", h);
    return () => mq.removeEventListener("change", h);
  }, []);

  const isDark = flutterDark !== null
    ? flutterDark
    : theme === "dark" || (theme === "system" && sysDark);

  const accent = flutterPrimary || (isDark ? "#ffffff" : "#1c1c1e");

  const T = {
    bg: isDark ? "#111111" : "#f5f5f7",
    card: isDark ? "#1c1c1e" : "#ffffff",
    bar: isDark ? "#1c1c1e" : "#ffffff",
    text: isDark ? "#f2f2f7" : "#1c1c1e",
    sub: isDark ? "#636366" : "#8e8e93",
    brd: isDark ? "rgba(255,255,255,.07)" : "rgba(0,0,0,.06)",
    input: isDark ? "#2c2c2e" : "#ffffff",
    pill: isDark ? "#1c1c1e" : "#ffffff",
    chip: isDark ? "#2c2c2e" : "#ffffff",
    chipBrd: isDark ? "rgba(255,255,255,.1)" : "rgba(0,0,0,.1)",
    hover: isDark ? "rgba(255,255,255,.04)" : "rgba(0,0,0,.02)",
    accent,
  };

  const applyTheme = useCallback(
    (newTheme) => {
      setTheme(newTheme);
      const dark = newTheme === "dark" || (newTheme === "system" && sysDark);
      FB.setTheme({
        isDark: dark,
        primaryColor: flutterPrimary || (dark ? "#ffffff" : "#000000"),
        backgroundColor: dark ? "#111111" : "#f5f5f7",
      });
    },
    [flutterPrimary, sysDark]
  );

  useEffect(() => {
    applyTheme(theme);
  }, [applyTheme, theme]);

  const visibleDocs = (activeTag ? docs.filter((d) => d.tag === activeTag) : docs)
    .filter((d) => !d.trashed)
    .filter((d) => {
      const q = query.trim().toLowerCase();
      if (!q) return true;
      return (
        (d.title || "").toLowerCase().includes(q) ||
        (d.preview || "").toLowerCase().includes(q) ||
        (d.content || "").toLowerCase().includes(q)
      );
    });

  const trashedCount = docs.filter((d) => d.trashed).length;

  const trashDoc = (id) => {
    setDocs((p) => p.map((d) => (d.id === id ? { ...d, trashed: true } : d)));
    setCtxMenu(null);
  };

  const restoreDoc = (id) => setDocs((p) => p.map((d) => (d.id === id ? { ...d, trashed: false } : d)));
  const permDelete = (id) => setDocs((p) => p.filter((d) => d.id !== id));

  const moveToFolder = (docId, folderId, projId) => {
    setDocs((p) => p.map((d) => (d.id === docId ? { ...d, folderId, projId } : d)));
    setFolderSheet(null);
  };

  const confirmNewFolder = () => {
    if (!newFolderName.trim() || !newFolderDlg) return;

    setProjects((prev) =>
      prev.map((p) => {
        if (p.id !== newFolderDlg.projId) return p;
        const nf = {
          id: "f" + Date.now(),
          name: newFolderName.trim(),
          emoji: "1f4c2",
          subFolders: [],
          files: [],
        };
        if (!newFolderDlg.parentFolderId) {
          return { ...p, folders: [...(p.folders || []), nf] };
        }
        return {
          ...p,
          folders: (p.folders || []).map((f) =>
            f.id === newFolderDlg.parentFolderId
              ? { ...f, subFolders: [...(f.subFolders || []), nf] }
              : f
          ),
        };
      })
    );

    setNewFolderName("");
    setNewFolderDlg(null);
  };

  const setEmojiFor = (target, id, cp) => {
    if (target === "proj") {
      setProjects((p) => p.map((pr) => (pr.id === id ? { ...pr, emoji: cp } : pr)));
    }
    if (target === "folder") {
      setProjects((p) =>
        p.map((pr) => ({
          ...pr,
          folders: (pr.folders || []).map((f) => (f.id === id ? { ...f, emoji: cp } : f)),
        }))
      );
    }
    if (target === "doc") {
      setDocs((p) => p.map((d) => (d.id === id ? { ...d, emoji: cp } : d)));
    }
    setEmojiPicker(null);
  };

  const handleNewProject = async () => {
    const _ = await FB.modal(
      "Novo projecto",
      "Introduz o nome do projecto",
      [{ label: "Criar", style: "primary" }, { label: "Cancelar", style: "ghost" }]
    );

    setProjects((p) => [
      ...p,
      {
        id: "p" + Date.now(),
        name: "Novo projecto",
        emoji: "1f4c1",
        folders: [],
      },
    ]);
  };

  const doAI = async () => {
    const prompt = aiInput.trim();
    if (!prompt) return;

    setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 900,
          system: "Cria um documento em português com HTML semântico (h1,h2,p). Responde APENAS com o HTML.",
          messages: [{ role: "user", content: prompt }],
        }),
      });

      const d = await r.json();
      const html = d.content?.map((i) => i.text || "").join("") || "";
      const nd = {
        id: Date.now(),
        title: prompt.slice(0, 40),
        emoji: "1f9e0",
        preview: prompt.slice(0, 90) + "…",
        date: "Agora",
        tag: "work",
        content: html,
      };
      setDocs((p) => [nd, ...p]);
      setAiInput("");
      setAiOpen(false);
      onOpenEditor?.(nd);
    } catch (_) {
      FB.toast("Erro ao gerar documento", "long");
    }
    setAiLoading(false);
  };

  const handleTemplateSelect = (tmpl) => {
    const doc = {
      id: Date.now(),
      title: tmpl.label,
      emoji: tmpl.emoji,
      preview: tmpl.desc,
      date: "Agora",
      tag: "work",
      content: `${tmpl.label}\n${tmpl.desc}\n`,
    };
    setDocs((p) => [doc, ...p]);
    setTemplatesOpen(false);
    onOpenEditor?.(doc);
  };

  const handleTrashDoc = async (id) => {
    const ok = await FB.confirm("Mover para o lixo", "O documento será movido para o lixo.");
    if (ok) trashDoc(id);
  };

  const handleDocOpen = (doc) => {
    onOpenEditor?.(doc);
  };

  if (showTrash) {
    return (
      <TrashScreen
        docs={docs}
        onRestore={restoreDoc}
        onDelete={permDelete}
        onBack={() => setShowTrash(false)}
        T={T}
        Icon={Icon}
      />
    );
  }

  return (
    <div className={`home-screen ${visible ? "vis" : "hid"}`} style={{ background: T.bg, color: T.text }}>
      <style>{CSS}</style>

      {emojiPicker && (
        <EmojiPickerOverlay
          onSelect={(cp) => setEmojiFor(emojiPicker.target, emojiPicker.id, cp)}
          onClose={() => setEmojiPicker(null)}
          T={T}
          Icon={Icon}
        />
      )}

      {ctxMenu && (
        <DocContextMenu
          doc={docs.find((d) => d.id === ctxMenu.docId)}
          x={ctxMenu.x}
          y={ctxMenu.y}
          onOpen={() => {
            const d = docs.find((x) => x.id === ctxMenu.docId);
            if (d) handleDocOpen(d);
            setCtxMenu(null);
          }}
          onMove={() => {
            setFolderSheet(ctxMenu.docId);
            setCtxMenu(null);
          }}
          onTrash={() => handleTrashDoc(ctxMenu.docId)}
          onClose={() => setCtxMenu(null)}
          T={T}
          Icon={Icon}
        />
      )}

      {folderSheet && (
        <FolderSheet
          docId={folderSheet}
          projects={projects}
          onSelect={(fId, pId) => moveToFolder(folderSheet, fId, pId)}
          onClose={() => setFolderSheet(null)}
          T={T}
          Icon={Icon}
        />
      )}

      {newFolderDlg && (
        <NewFolderDialog
          value={newFolderName}
          onChange={setNewFolderName}
          onConfirm={confirmNewFolder}
          onClose={() => setNewFolderDlg(null)}
          T={T}
          Icon={Icon}
        />
      )}

      {themeDlg && (
        <ThemeDialog
          theme={theme}
          onThemeChange={applyTheme}
          onClose={() => setThemeDlg(false)}
          T={T}
          Icon={Icon}
          isDark={isDark}
        />
      )}

      {aiOpen && (
        <AiSheet
          value={aiInput}
          onChange={setAiInput}
          onSubmit={doAI}
          loading={aiLoading}
          onClose={() => setAiOpen(false)}
          T={T}
          Icon={Icon}
        />
      )}

      {templatesOpen && (
        <TemplatesSheet
          onSelect={handleTemplateSelect}
          onClose={() => setTemplatesOpen(false)}
          T={T}
          Icon={Icon}
        />
      )}

      {drawerOpen && (
        <div
          onClick={() => setDrawerOpen(false)}
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(0,0,0,.22)",
            zIndex: 8,
            animation: "fadeIn .18s ease",
          }}
        />
      )}

      <aside
        style={{
          position: "fixed",
          inset: 0,
          width: 272,
          background: T.bar,
          borderRight: `1px solid ${T.brd}`,
          transform: drawerOpen ? "translateX(0)" : "translateX(-100%)",
          transition: "transform .36s cubic-bezier(.32,1,.56,1)",
          zIndex: 9,
          display: "flex",
          flexDirection: "column",
        }}
      >
        <div style={{ padding: "18px 16px 14px", display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ width: 42, height: 42, borderRadius: 14, overflow: "hidden", background: T.bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <AppLogo />
          </div>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 800, lineHeight: 1.1 }}>Docu</div>
            <div style={{ fontSize: 12, color: T.sub, marginTop: 2 }}>Espaço de trabalho</div>
          </div>
        </div>

        <div style={{ padding: "0 10px 10px" }}>
          <DrawerItem
            icon="plus"
            label="Novo projecto"
            textColor={T.text}
            iconColor={T.accent}
            onClick={() => {
              haptic();
              handleNewProject();
            }}
          />
          <DrawerItem
            icon="settings"
            label="Definições"
            textColor={T.text}
            iconColor={T.text}
            onClick={() => {
              haptic();
              setSettingsOpen((v) => !v);
            }}
            right={<Icon name={settingsOpen ? "chevron-down" : "chevron-right"} size={16} style={{ opacity: 0.8 }} />}
          />

          {settingsOpen && (
            <div style={{ margin: "2px 8px 10px", borderRadius: 16, overflow: "hidden", background: T.bg, border: `1px solid ${T.brd}` }}>
              {[
                { icon: "bell", label: "Notificações" },
                { icon: "lock", label: "Privacidade" },
                { icon: "palette", label: "Tema", action: "theme" },
                { icon: "users", label: "Conta" },
                { icon: "log-out", label: "Terminar sessão", danger: true },
              ].map((s) => (
                <button
                  key={s.label}
                  onClick={async () => {
                    if (s.action === "theme") {
                      setThemeDlg(true);
                      return;
                    }
                    if (s.danger) {
                      const ok = await FB.confirm("Terminar sessão", "Tens a certeza que queres terminar sessão?");
                      if (ok) setDrawerOpen(false);
                      return;
                    }
                    setDrawerOpen(false);
                  }}
                  className="pressable"
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 12,
                    padding: "11px 16px",
                    width: "100%",
                    border: "none",
                    background: "transparent",
                    textAlign: "left",
                    color: s.danger ? "#ff3b30" : T.text,
                    fontFamily: "'DM Sans',sans-serif",
                    fontSize: 14,
                    fontWeight: 500,
                  }}
                >
                  <div style={{ width: 22, display: "flex", justifyContent: "center" }}>
                    <Icon name={s.icon} size={17} />
                  </div>
                  <span>{s.label}</span>
                </button>
              ))}
            </div>
          )}

          <DrawerItem
            icon="trash-2"
            label="Lixo"
            textColor={T.text}
            iconColor={T.text}
            onClick={() => {
              setShowTrash(true);
              setDrawerOpen(false);
            }}
            right={
              trashedCount > 0 ? (
                <div
                  style={{
                    minWidth: 20,
                    height: 20,
                    padding: "0 6px",
                    borderRadius: 9999,
                    background: "#ff3b30",
                    color: "#fff",
                    fontSize: 11,
                    fontWeight: 700,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  {trashedCount}
                </div>
              ) : null
            }
          />
        </div>

        <div style={{ padding: "6px 16px 10px", color: T.sub, fontSize: 12, fontWeight: 700, textTransform: "uppercase", letterSpacing: ".08em" }}>
          Projectos
        </div>

        <div style={{ flex: 1, overflowY: "auto", paddingBottom: 20 }}>
          {projects.map((proj) => (
            <div key={proj.id} style={{ padding: "0 10px 8px" }}>
              <DrawerItem
                icon="chevron-right"
                label={proj.name}
                textColor={T.text}
                iconColor={T.text}
                customIcon={<TwEmoji cp={proj.emoji || "1f4c1"} size={20} />}
                right={
                  <button
                    type="button"
                    className="pressable"
                    onClick={(e) => {
                      e.stopPropagation();
                      setEmojiPicker({ target: "proj", id: proj.id });
                    }}
                    style={{ border: "none", background: "transparent", color: T.sub, padding: 4, borderRadius: 8 }}
                  >
                    <Icon name="pencil" size={15} />
                  </button>
                }
                onClick={() => setProjExp((p) => ({ ...p, [proj.id]: !p[proj.id] }))}
              />

              {projExp[proj.id] && (
                <div style={{ marginLeft: 14, marginTop: 2, borderLeft: `1px solid ${T.brd}` }}>
                  {(proj.folders || []).map((folder) => (
                    <div key={folder.id} style={{ paddingLeft: 10 }}>
                      <DrawerItem
                        icon="folder"
                        label={folder.name}
                        textColor={T.text}
                        iconColor={T.text}
                        customIcon={<TwEmoji cp={folder.emoji || "1f4c2"} size={18} />}
                        right={
                          <button
                            type="button"
                            className="pressable"
                            onClick={(e) => {
                              e.stopPropagation();
                              setEmojiPicker({ target: "folder", id: folder.id });
                            }}
                            style={{ border: "none", background: "transparent", color: T.sub, padding: 4, borderRadius: 8 }}
                          >
                            <Icon name="pencil" size={15} />
                          </button>
                        }
                        onClick={() => {}}
                      />

                      {(folder.subFolders || []).map((sf) => (
                        <DrawerItem
                          key={sf.id}
                          icon="folder"
                          label={sf.name}
                          textColor={T.text}
                          subColor={T.sub}
                          customIcon={<TwEmoji cp={sf.emoji || "1f4c2"} size={17} />}
                          onClick={() => {}}
                        />
                      ))}

                      <button
                        type="button"
                        className="pressable"
                        onClick={() => {
                          setNewFolderDlg({ projId: proj.id, parentFolderId: folder.id });
                          setNewFolderName("");
                        }}
                        style={{
                          display: "flex",
                          alignItems: "center",
                          gap: 10,
                          padding: "10px 18px 10px 16px",
                          fontSize: 13,
                          color: T.sub,
                          fontWeight: 500,
                          border: "none",
                          background: "transparent",
                          width: "100%",
                          textAlign: "left",
                          fontFamily: "'DM Sans',sans-serif",
                        }}
                      >
                        <Icon name="folder-plus" size={15} />
                        Nova subpasta
                      </button>
                    </div>
                  ))}

                  <button
                    type="button"
                    className="pressable"
                    onClick={() => {
                      setNewFolderDlg({ projId: proj.id });
                      setNewFolderName("");
                    }}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 10,
                      padding: "10px 18px 10px 16px",
                      fontSize: 13,
                      color: T.sub,
                      fontWeight: 500,
                      border: "none",
                      background: "transparent",
                      width: "100%",
                      textAlign: "left",
                      fontFamily: "'DM Sans',sans-serif",
                    }}
                  >
                    <Icon name="folder-plus" size={15} />
                    Nova pasta
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </aside>

      <main
        ref={scrollRef}
        onScroll={() => setScrolled(scrollRef.current?.scrollTop > 4)}
        style={{
          flex: 1,
          overflowY: "auto",
          overflowX: "hidden",
          WebkitOverflowScrolling: "touch",
          padding: "10px 16px 180px",
          scrollbarWidth: "none",
          transform: drawerOpen ? "translateX(272px)" : "none",
          transition: "transform .36s cubic-bezier(.32,1,.56,1)",
        }}
      >
        <div
          style={{
            position: "sticky",
            top: 0,
            zIndex: 4,
            paddingTop: 6,
            paddingBottom: 12,
            background: `linear-gradient(to bottom, ${T.bg} 70%, transparent)`,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <button
              onClick={() => {
                haptic();
                setDrawerOpen(true);
              }}
              className="pressable"
              style={{
                width: 44,
                height: 44,
                border: "none",
                background: "transparent",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                borderRadius: 12,
                color: T.sub,
              }}
            >
              <Icon name="menu" />
            </button>

            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 24, fontWeight: 800, lineHeight: 1.05 }}>Documentos</div>
              <div style={{ fontSize: 12, color: T.sub, marginTop: 4 }}>{scrolled ? "A navegar" : "Tudo num só lugar"}</div>
            </div>

            <button
              onClick={() => setTemplatesOpen(true)}
              className="pressable"
              style={{
                width: 40,
                height: 40,
                border: "none",
                background: "transparent",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                borderRadius: 12,
                color: T.sub,
              }}
            >
              <Icon name="layout-template" />
            </button>

            <button
              onClick={() => {
                haptic();
                onOpenEditor?.({ id: Date.now(), title: "", emoji: "1f4c4", content: "" });
              }}
              className="pressable"
              style={{
                width: 40,
                height: 40,
                border: "none",
                background: "transparent",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                borderRadius: 12,
                color: T.sub,
              }}
            >
              <Icon name="plus" />
            </button>
          </div>

          <div
            style={{
              marginTop: 14,
              display: "flex",
              alignItems: "center",
              gap: 10,
              background: T.input,
              border: `1px solid ${T.brd}`,
              borderRadius: 16,
              padding: "0 14px",
              height: 52,
            }}
          >
            <Icon name="search" size={17} style={{ color: T.sub }} />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Pesquisar documentos…"
              style={{
                flex: 1,
                border: "none",
                outline: "none",
                background: "transparent",
                color: T.text,
                fontSize: 15,
                fontFamily: "'DM Sans',sans-serif",
              }}
            />
            {query ? (
              <button
                onClick={() => setQuery("")}
                className="pressable"
                style={{ border: "none", background: "transparent", color: T.sub, padding: 6 }}
              >
                <Icon name="x" size={16} />
              </button>
            ) : null}
          </div>
        </div>

        <div style={{ display: "flex", gap: 8, overflowX: "auto", padding: "2px 0 10px" }}>
          <button
            onClick={() => setActiveTag(null)}
            className="pressable"
            style={{
              flexShrink: 0,
              padding: "6px 14px",
              borderRadius: 9999,
              fontSize: 13,
              fontWeight: 700,
              border: `1.5px solid ${!activeTag ? T.accent : T.chipBrd}`,
              background: !activeTag ? T.accent : T.chip,
              color: !activeTag ? (isDark ? "#1c1c1e" : "#fff") : T.text,
              fontFamily: "'DM Sans',sans-serif",
            }}
          >
            Todos
          </button>

          {TAGS.map((t) => (
            <button
              key={t.id}
              onClick={() => setActiveTag(activeTag === t.id ? null : t.id)}
              className="pressable"
              style={{
                flexShrink: 0,
                padding: "6px 14px",
                borderRadius: 9999,
                fontSize: 13,
                fontWeight: 700,
                border: `1.5px solid ${activeTag === t.id ? t.color : t.bg}`,
                background: activeTag === t.id ? t.color : T.chip,
                color: activeTag === t.id ? "#fff" : t.color,
                fontFamily: "'DM Sans',sans-serif",
              }}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div style={{ fontSize: 14, fontWeight: 700, color: T.sub, margin: "6px 0 10px" }}>Recentes</div>

        {visibleDocs.length === 0 ? (
          <div
            style={{
              marginTop: 34,
              padding: 22,
              borderRadius: 18,
              background: T.card,
              border: `1px solid ${T.brd}`,
              textAlign: "center",
              color: T.sub,
            }}
          >
            Nenhum documento
          </div>
        ) : (
          <div style={{ display: "grid", gap: 10 }}>
            {visibleDocs.map((doc, idx) => {
              const tag = TAGS.find((t) => t.id === doc.tag);
              const isFirst = idx === 0;
              const isLast = idx === visibleDocs.length - 1;
              const borderRadius = isFirst ? "16px 16px 6px 6px" : isLast ? "6px 6px 16px 16px" : 12;

              return (
                <div
                  key={doc.id}
                  className="doc-row"
                  onClick={() => handleDocOpen(doc)}
                  style={{
                    padding: "14px 14px",
                    background: T.card,
                    borderRadius,
                    border: `1px solid ${T.brd}`,
                    boxShadow: "0 1px 2px rgba(0,0,0,.05)",
                    cursor: "pointer",
                  }}
                >
                  <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setEmojiPicker({ target: "doc", id: doc.id });
                      }}
                      className="pressable"
                      style={{
                        width: 42,
                        height: 42,
                        borderRadius: 12,
                        background: T.bg,
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        flexShrink: 0,
                        cursor: "pointer",
                        border: "none",
                      }}
                    >
                      <TwEmoji cp={doc.emoji || "1f4c4"} size={22} />
                    </button>

                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: "flex", alignItems: "flex-start", gap: 8 }}>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ fontSize: 15, fontWeight: 800, lineHeight: 1.2, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                            {doc.title || "Sem título"}
                          </div>
                          <div style={{ fontSize: 12, color: T.sub, marginTop: 4, display: "flex", gap: 8, alignItems: "center" }}>
                            {tag ? <span style={{ color: tag.color, fontWeight: 700 }}>{tag.label}</span> : null}
                            <span>{doc.date || ""}</span>
                          </div>
                        </div>

                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            onOpenEditor?.(doc);
                          }}
                          className="pressable"
                          style={{ border: "none", background: "transparent", color: T.sub, padding: 6, flexShrink: 0, borderRadius: 8 }}
                        >
                          <Icon name="pencil" size={16} />
                        </button>

                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            haptic();
                            const r = e.currentTarget.getBoundingClientRect();
                            setCtxMenu({
                              docId: doc.id,
                              x: Math.min(r.right - 200, window.innerWidth - 215),
                              y: r.bottom + 6,
                            });
                          }}
                          className="pressable"
                          style={{ border: "none", background: "transparent", color: T.sub, padding: 6, flexShrink: 0, borderRadius: 8 }}
                        >
                          <Icon name="more-horizontal" size={16} />
                        </button>
                      </div>

                      <div style={{ marginTop: 10, fontSize: 13, color: T.sub, lineHeight: 1.45, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>
                        {doc.preview || "Sem pré-visualização"}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        <button
          onClick={() => {
            haptic();
            setAiOpen(true);
          }}
          className="pressable"
          style={{
            position: "fixed",
            left: 16,
            right: 16,
            bottom: 18,
            zIndex: 5,
            display: "flex",
            alignItems: "center",
            gap: 12,
            padding: "0 18px",
            height: 56,
            background: T.pill,
            borderRadius: 9999,
            border: `1px solid ${T.brd}`,
            boxShadow: "0 6px 24px rgba(0,0,0,.12),0 1px 4px rgba(0,0,0,.06)",
            color: T.text,
          }}
        >
          <Sparkles size={18} />
          <span style={{ fontSize: 15, fontWeight: 700, flex: 1, textAlign: "left" }}>Criar com IA…</span>
          <Send size={18} />
        </button>
      </main>
    </div>
  );
}