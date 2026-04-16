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
  menu: ``,
  "chevron-right": ``,
  "chevron-down": ``,
  plus: ``,
  send: ``,
  x: ``,
  search: ``,
  "more-horizontal": ``,
  pencil: ``,
  "trash-2": ``,
  "folder-plus": ``,
  move: ``,
  users: ``,
  book: ``,
  settings: ``,
  sparkles: ``,
  bell: ``,
  lock: ``,
  palette: ``,
  "log-out": ``,
  sun: ``,
  moon: ``,
  monitor: ``,
  "layout-template": ``,
  check: ``,
  "arrow-left": ``,
};

const Icon = ({ name, size = 18, sw = 2, style }) => (
  
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
    

      

        
          
        
        
Lixo

        {trashedDocs.length > 0 && (
          
            Esvaziar
          
        )}
      

      

        {trashedDocs.length === 0 ? (
          

            
            
Lixo vazio

            
Documentos eliminados aparecem aqui

          

        ) : (
          

            {trashedDocs.map((doc, idx) => (
              

                

                  
                  

                    
{doc.title}

                    
{doc.date}

                  

                   onRestore(doc.id)} style={{
                    border: "none", background: "rgba(0,122,255,.1)",
                    color: "#007aff", fontSize: 12, fontWeight: 600,
                    padding: "5px 10px", borderRadius: 8,
                  }}>Restaurar
                   handleDelete(doc.id)} style={{
                    border: "none", background: "rgba(255,59,48,.1)",
                    color: "#ff3b30", fontSize: 12, fontWeight: 600,
                    padding: "5px 10px", borderRadius: 8,
                  }}>Apagar
                

              

            ))}
          

        )}
      

    

  );
}

/* ── Drawer item ── */
function DrawerItem({ icon, label, textColor, subColor, iconColor, right, onClick, customIcon }) {
  return (
     e.currentTarget.style.background = "rgba(128,128,128,.07)"}
      onPointerOut={e => e.currentTarget.style.background = "transparent"}>
      {customIcon
        ? {customIcon}
        : }
      {label}
      {right}
    
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
      content: `
${tmpl.label}
${tmpl.desc}

`,
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
       setShowTrash(false)} T={T} Icon={Icon}
      />
    );
  }

  return (
    


      {/* ── Overlays from widgets ── */}
      {emojiPicker && (
         setEmojiPicker(null)} T={T} Icon={Icon}
        />
      )}
      {ctxMenu && (
         { onOpenEditor(docs.find(d => d.id === ctxMenu.docId)); setCtxMenu(null); }}
          onMove={() => { setFolderSheet(ctxMenu.docId); setCtxMenu(null); }}
          onTrash={() => handleTrashDoc(ctxMenu.docId)}
          onClose={() => setCtxMenu(null)}
          T={T} Icon={Icon}
        />
      )}
      {folderSheet && (
         moveToFolder(folderSheet, fId, pId)}
          onClose={() => setFolderSheet(null)}
          T={T} Icon={Icon}
        />
      )}
      {newFolderDlg && (
         setNewFolderDlg(null)}
          T={T} Icon={Icon}
        />
      )}
      {themeDlg && (
         setThemeDlg(false)}
          T={T} Icon={Icon} isDark={isDark}
        />
      )}
      {aiOpen && (
         setAiOpen(false)} T={T} Icon={Icon}
        />
      )}
      {templatesOpen && (
         setTemplatesOpen(false)}
          T={T} Icon={Icon}
        />
      )}

      {/* ── DRAWER MASK ── */}
      {drawerOpen && (
        
 setDrawerOpen(false)} />
      )}

      {/* ── DRAWER ── */}
      

        

          
          

            
Docu

            
Espaço de trabalho

          

        


        

           setDrawerOpen(false)} />

          }
            onClick={() => setSettingsOpen(v => !v)} />

          {settingsOpen && (
            

              {[
                { icon: "bell",    label: "Notificações" },
                { icon: "lock",    label: "Privacidade" },
                { icon: "palette", label: "Tema",            action: "theme" },
                { icon: "users",   label: "Conta" },
                { icon: "log-out", label: "Terminar sessão", danger: true },
              ].map(s => (
                 {
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
                  
                  {s.label}
                
              ))}
            

          )}

           setDrawerOpen(false)} />

          
              {trashedCount > 0 && (
                {trashedCount}
              )}
              
            }
            onClick={() => { setShowTrash(true); setDrawerOpen(false); }} />

          


          

            Projetos
            
              
            
          


          {projects.map(proj => (
            

               { e.stopPropagation(); setEmojiPicker({ target: "proj", id: proj.id }); }}>
                    
                  
                }
                right={}
                onClick={() => setProjExp(p => ({ ...p, [proj.id]: !p[proj.id] }))} />

              {projExp[proj.id] && (
                

                  {proj.folders.map(folder => (
                    

                      
                         { e.stopPropagation(); setEmojiPicker({ target: "folder", id: folder.id }); }}>
                          
                        
                        {folder.name}
                         { e.stopPropagation(); setNewFolderDlg({ projId: proj.id, parentFolderId: folder.id }); setNewFolderName(""); }}
                          style={{ border: "none", background: "transparent", color: T.sub, padding: 4, borderRadius: 8 }}>
                          
                        
                        
                      
                      {(folder.subFolders || []).map(sf => (
                        
                          
                          {sf.name}
                        
                      ))}
                    

                  ))}
                   { setNewFolderDlg({ projId: proj.id }); setNewFolderName(""); }}
                    style={{
                      display: "flex", alignItems: "center", gap: 10,
                      padding: "10px 18px 10px 16px", fontSize: 13, color: T.sub,
                      fontWeight: 400, border: "none",
                      background: "transparent", width: "100%", textAlign: "left",
                      fontFamily: "'DM Sans',sans-serif",
                    }}>
                     Nova pasta
                  
                

              )}
            

          ))}
        

      


      {/* ── TOPBAR ── */}
      

         { haptic(); setDrawerOpen(true); }} style={{
          width: 44, height: 44, border: "none", background: "transparent",
          display: "flex", alignItems: "center",
          justifyContent: "center", borderRadius: 12, color: T.sub,
        }}>
          
        
        
Documentos

        

           setTemplatesOpen(true)}
            style={{
              width: 40, height: 40, border: "none", background: "transparent",
              display: "flex", alignItems: "center",
              justifyContent: "center", borderRadius: 12, color: T.sub,
            }}>
            
          
           { haptic(); onOpenEditor({ id: Date.now(), title: "", emoji: "1f4c4", content: "" }); }}
            style={{
              width: 40, height: 40, border: "none", background: "transparent",
              display: "flex", alignItems: "center",
              justifyContent: "center", borderRadius: 12, color: T.sub,
            }}>
            
          
        

      


      {/* ── SCROLL CONTENT ── */}
      
 setScrolled(scrollRef.current?.scrollTop > 4)}
        style={{
          flex: 1, overflowY: "auto", overflowX: "hidden",
          WebkitOverflowScrolling: "touch", padding: "16px 16px 180px",
          scrollbarWidth: "none",
          transform: drawerOpen ? "translateX(272px)" : "none",
          transition: "transform .36s cubic-bezier(.32,1,.56,1)",
        }}>

        {/* Search */}
        

          
          
Pesquisar documentos…

        


        {/* Tags */}
        

           setActiveTag(null)}
            style={{
              flexShrink: 0, padding: "6px 14px", borderRadius: 9999, fontSize: 13,
              fontWeight: 600,
              border: `1.5px solid ${!activeTag ? T.accent : T.chipBrd}`,
              background: !activeTag ? T.accent : T.chip,
              color: !activeTag ? (isDark ? "#1c1c1e" : "#fff") : T.text,
              fontFamily: "'DM Sans',sans-serif",
            }}>Todos
          {TAGS.map(t => (
             setActiveTag(activeTag === t.id ? null : t.id)}
              style={{
                flexShrink: 0, padding: "6px 14px", borderRadius: 9999, fontSize: 13,
                fontWeight: 600,
                border: `1.5px solid ${activeTag === t.id ? t.color : t.bg}`,
                background: activeTag === t.id ? t.color : T.chip,
                color: activeTag === t.id ? "#fff" : t.color,
                fontFamily: "'DM Sans',sans-serif",
              }}>{t.label}
          ))}
        


        

          Recentes
        


        {/* Doc list */}
        {visibleDocs.length === 0 ? (
          

            Nenhum documento
          

        ) : (
          

            {visibleDocs.map((doc, idx) => {
              const tag     = TAGS.find(t => t.id === doc.tag);
              const isFirst = idx === 0;
              const isLast  = idx === visibleDocs.length - 1;
              const borderRadius = isFirst ? "12px 12px 3px 3px" : isLast ? "3px 3px 12px 12px" : "3px";

              return (
                
 onOpenEditor(doc)}
                  style={{
                    padding: "14px 16px",
                    background: T.card,
                    borderRadius,
                    boxShadow: "0 1px 2px rgba(0,0,0,.05)",
                    cursor: "pointer",
                  }}>
                  

                    
 { e.stopPropagation(); setEmojiPicker({ target: "doc", id: doc.id }); }}
                      style={{
                        width: 42, height: 42, borderRadius: 11, background: T.bg,
                        display: "flex", alignItems: "center", justifyContent: "center",
                        flexShrink: 0, cursor: "pointer",
                        transition: "transform .12s cubic-bezier(.34,1.56,.64,1)",
                      }}
                      onPointerDown={e => e.currentTarget.style.transform = "scale(.88)"}
                      onPointerUp={e => e.currentTarget.style.transform = "scale(1)"}
                      onPointerLeave={e => e.currentTarget.style.transform = "scale(1)"}>
                      
                    

                    

                      

                        
{doc.title}

                         { e.stopPropagation(); onOpenEditor(doc); }}
                          style={{ border: "none", background: "transparent", color: T.sub, padding: 6, flexShrink: 0, borderRadius: 8 }}>
                          
                        
                         {
                          e.stopPropagation(); haptic();
                          const r = e.currentTarget.getBoundingClientRect();
                          setCtxMenu({ docId: doc.id, x: Math.min(r.right - 200, window.innerWidth - 215), y: r.bottom + 6 });
                        }} style={{ border: "none", background: "transparent", color: T.sub, padding: 6, flexShrink: 0, borderRadius: 8 }}>
                          
                        
                      

                      
{doc.preview}

                      

                        {tag && (
                          {tag.label}
                        )}
                        {doc.date}
                      

                    

                  

                

              );
            })}
          

        )}
      


      {/* ── FLOATING AI BAR ── */}
      

        
 { haptic(); setAiOpen(true); }} style={{
          display: "flex", alignItems: "center", gap: 12, padding: "0 20px",
          height: 56, background: T.pill, borderRadius: 9999,
          border: `1px solid ${T.brd}`,
          boxShadow: "0 6px 24px rgba(0,0,0,.12),0 1px 4px rgba(0,0,0,.06)",
        }}>
          
          Criar com IA…
        

      

    

  );
}