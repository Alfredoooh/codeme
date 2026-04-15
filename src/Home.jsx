import { useState, useRef, useEffect } from "react";

/* ── Twemoji ── */
const twSrc = (cp) => `https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/svg/${cp}.svg`;
const TwEmoji = ({ cp, size = 20 }) => (
  <img src={twSrc(cp)} width={size} height={size}
    style={{ display:"inline-block", verticalAlign:"middle", flexShrink:0 }} alt="" />
);

/* ── App logo SVG (imported inline) ── */
const AppLogo = ({ size = 32 }) => (
  <svg width={size} height={size} viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="32" height="32" rx="8" fill="#007aff"/>
    <path d="M9 10h9a4 4 0 0 1 0 8H9V10Z" fill="#fff" opacity=".9"/>
    <path d="M9 18h10a5 5 0 0 1 0 10" stroke="#fff" strokeWidth="2" strokeLinecap="round" fill="none" opacity=".6"/>
    <circle cx="9" cy="24" r="2" fill="#fff" opacity=".6"/>
  </svg>
);

/* ── Lucide-style icons ── */
const IC = {
  menu:`<line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/>`,
  "chevron-right":`<polyline points="9 18 15 12 9 6"/>`,
  "chevron-down":`<path d="m6 9 6 6 6-6"/>`,
  plus:`<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>`,
  send:`<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>`,
  x:`<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>`,
  search:`<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>`,
  "more-horizontal":`<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>`,
  pencil:`<path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>`,
  "trash-2":`<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>`,
  "folder-plus":`<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/><line x1="12" y1="11" x2="12" y2="17"/><line x1="9" y1="14" x2="15" y2="14"/>`,
  folder:`<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>`,
  move:`<polyline points="5 9 2 12 5 15"/><polyline points="9 5 12 2 15 5"/><line x1="2" y1="12" x2="22" y2="12"/><polyline points="19 9 22 12 19 15"/><polyline points="15 19 12 22 9 19"/>`,
  users:`<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`,
  book:`<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>`,
  settings:`<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>`,
  sparkles:`<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/><path d="M5 3v4"/><path d="M19 17v4"/><path d="M3 5h4"/><path d="M17 19h4"/>`,
  bell:`<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>`,
  lock:`<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>`,
  palette:`<circle cx="13.5" cy="6.5" r=".5"/><circle cx="17.5" cy="10.5" r=".5"/><circle cx="8.5" cy="7.5" r=".5"/><circle cx="6.5" cy="12.5" r=".5"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"/>`,
  "log-out":`<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>`,
  sun:`<circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>`,
  moon:`<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>`,
  monitor:`<rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>`,
  "layout-template":`<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><path d="M9 21V9"/>`,
  check:`<polyline points="20 6 9 12 4 9"/>`,
  "arrow-left":`<line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/>`,
};
const Icon = ({ name, size = 18, sw = 2, style }) => (
  <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
    style={style} dangerouslySetInnerHTML={{ __html: IC[name] || "" }} />
);

/* ── Emoji list ── */
const EMOJI_LIST = [
  {cp:"1f4c4",lbl:"Doc"},{cp:"1f4dd",lbl:"Nota"},{cp:"1f4ca",lbl:"Gráfico"},
  {cp:"1f4bc",lbl:"Trabalho"},{cp:"1f393",lbl:"Escola"},{cp:"26ea",lbl:"Igreja"},
  {cp:"1f3e2",lbl:"Empresa"},{cp:"1f4bb",lbl:"Código"},{cp:"1f3a8",lbl:"Arte"},
  {cp:"1f4d6",lbl:"Livro"},{cp:"2705",lbl:"Feito"},{cp:"1f4e7",lbl:"Email"},
  {cp:"1f4c5",lbl:"Data"},{cp:"1f9ea",lbl:"Ciência"},{cp:"1f3af",lbl:"Meta"},
  {cp:"1f4b0",lbl:"Finanças"},{cp:"2764",lbl:"Amor"},{cp:"1f525",lbl:"Fogo"},
  {cp:"1f31f",lbl:"Estrela"},{cp:"1f4f1",lbl:"Mobile"},{cp:"1f3d7",lbl:"Projeto"},
  {cp:"1f9e0",lbl:"Ideia"},{cp:"270f",lbl:"Editar"},{cp:"1f50d",lbl:"Pesquisa"},
  {cp:"1f4c1",lbl:"Pasta"},{cp:"1f4c2",lbl:"Pasta2"},{cp:"1f5c2",lbl:"Arquivo"},
  {cp:"2795",lbl:"Plus"},{cp:"1f64f",lbl:"Orar"},{cp:"1f4af",lbl:"100"},
  {cp:"1f680",lbl:"Foguete"},{cp:"1f4a1",lbl:"Ideia"},{cp:"1f3c6",lbl:"Troféu"},
  {cp:"1f48e",lbl:"Gema"},{cp:"1f510",lbl:"Seguro"},{cp:"1f4e6",lbl:"Caixa"},
  {cp:"1f4cb",lbl:"Lista"},{cp:"1f4cc",lbl:"Pin"},{cp:"1f4ce",lbl:"Clipe"},
  {cp:"2764",lbl:"Amor"},{cp:"1f499",lbl:"Azul"},{cp:"1f49a",lbl:"Verde"},
  {cp:"1f49b",lbl:"Amarelo"},{cp:"1f49c",lbl:"Roxo"},{cp:"1f5a4",lbl:"Preto"},
  {cp:"2b50",lbl:"Estrela"},{cp:"26a1",lbl:"Raio"},{cp:"1f4a5",lbl:"Boom"},
  {cp:"1f4ab",lbl:"Tontura"},{cp:"1f4a7",lbl:"Gota"},{cp:"1f32a",lbl:"Tornado"},
  {cp:"1f9f2",lbl:"Íman"},{cp:"1f9f0",lbl:"Kit"},{cp:"1f527",lbl:"Chave"},
  {cp:"1f528",lbl:"Martelo"},{cp:"2696",lbl:"Balança"},{cp:"1f3db",lbl:"Banco"},
];

const TAGS = [
  {id:"work",    label:"Trabalho", color:"#2563eb", bg:"#dbeafe"},
  {id:"school",  label:"Escola",   color:"#7c3aed", bg:"#f3e8ff"},
  {id:"church",  label:"Igreja",   color:"#059669", bg:"#d1fae5"},
  {id:"biz",     label:"Negócios", color:"#d97706", bg:"#fef3c7"},
  {id:"personal",label:"Pessoal",  color:"#db2777", bg:"#fce7f3"},
];

const haptic = () => { try { if(navigator.vibrate) navigator.vibrate(8); } catch(_){} };

/* ══════════════════════════════════════════════
   TRASH SCREEN (separate component / "file")
══════════════════════════════════════════════ */
function TrashScreen({ docs, onRestore, onDelete, onBack, theme }) {
  const trashedDocs = docs.filter(d => d.trashed);
  const bg   = theme === "light" ? "#f5f5f7" : "#0a0a0a";
  const card = theme === "light" ? "#ffffff"  : "#1c1c1e";
  const text = theme === "light" ? "#1c1c1e"  : "#f2f2f7";
  const sub  = theme === "light" ? "#8e8e93"  : "#636366";
  const brd  = theme === "light" ? "rgba(0,0,0,.06)" : "rgba(255,255,255,.07)";
  const bar  = theme === "light" ? "#ffffff"  : "#1c1c1e";

  return (
    <div style={{ position:"absolute", inset:0, display:"flex", flexDirection:"column", background:bg, fontFamily:"'DM Sans',system-ui,sans-serif" }}>
      {/* AppBar */}
      <div style={{ height:56, flexShrink:0, display:"flex", alignItems:"center", padding:"0 8px", background:bar, borderBottom:`1px solid ${brd}`, position:"relative", zIndex:10 }}>
        <button onClick={onBack} style={{ width:44, height:44, border:"none", background:"transparent", cursor:"pointer", display:"flex", alignItems:"center", justifyContent:"center", borderRadius:12, color:sub }}>
          <Icon name="arrow-left" size={22}/>
        </button>
        <div style={{ position:"absolute", left:"50%", transform:"translateX(-50%)", fontSize:17, fontWeight:700, color:text }}>Lixo</div>
        {trashedDocs.length > 0 && (
          <button onClick={() => trashedDocs.forEach(d => onDelete(d.id))}
            style={{ position:"absolute", right:12, border:"none", background:"transparent", cursor:"pointer", fontSize:13, fontWeight:600, color:"#ff3b30", padding:"6px 8px" }}>
            Esvaziar
          </button>
        )}
      </div>

      {/* Content */}
      <div style={{ flex:1, overflowY:"auto", padding:"16px", scrollbarWidth:"none" }}>
        {trashedDocs.length === 0 ? (
          <div style={{ display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center", height:"60%", gap:14, color:sub }}>
            <div style={{ width:72, height:72, borderRadius:20, background:theme==="light"?"#f2f2f7":"#2c2c2e", display:"flex", alignItems:"center", justifyContent:"center" }}>
              <Icon name="trash-2" size={32} style={{ color:sub }} sw={1.5}/>
            </div>
            <div style={{ fontSize:17, fontWeight:600, color:text }}>Lixo vazio</div>
            <div style={{ fontSize:14, color:sub }}>Documentos eliminados aparecem aqui</div>
          </div>
        ) : (
          <div style={{ background:card, borderRadius:16, overflow:"hidden", boxShadow:`0 1px 3px rgba(0,0,0,.07),0 4px 16px rgba(0,0,0,.05)` }}>
            {trashedDocs.map((doc, idx) => (
              <div key={doc.id} style={{ padding:"14px 16px", borderBottom: idx < trashedDocs.length-1 ? `1px solid ${brd}` : "none" }}>
                <div style={{ display:"flex", alignItems:"center", gap:10 }}>
                  <TwEmoji cp={doc.emoji||"1f4c4"} size={22}/>
                  <div style={{ flex:1, minWidth:0 }}>
                    <div style={{ fontSize:14, fontWeight:600, color:text, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{doc.title}</div>
                    <div style={{ fontSize:12, color:sub }}>{doc.date}</div>
                  </div>
                  <button onClick={() => onRestore(doc.id)}
                    style={{ border:"none", background:"rgba(0,122,255,.1)", cursor:"pointer", color:"#007aff", fontSize:12, fontWeight:600, padding:"5px 10px", borderRadius:8 }}>
                    Restaurar
                  </button>
                  <button onClick={() => onDelete(doc.id)}
                    style={{ border:"none", background:"rgba(255,59,48,.1)", cursor:"pointer", color:"#ff3b30", fontSize:12, fontWeight:600, padding:"5px 10px", borderRadius:8 }}>
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

/* ══════════════════════════════════════════════
   MAIN HOME SCREEN
══════════════════════════════════════════════ */
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
  const [newFolderDlg,  setNewFolderDlg]  = useState(null); // {projId, parentFolderId?}
  const [newFolderName, setNewFolderName] = useState("");
  const [themeDlg,      setThemeDlg]      = useState(false);
  const [theme,         setTheme]         = useState("system"); // light | dark | system
  const aiRef   = useRef(null);
  const scrollRef = useRef(null);
  const folderNameRef = useRef(null);

  /* ── CSS injection ── */
  useEffect(() => {
    const s = document.createElement("style");
    s.textContent = CSS;
    document.head.appendChild(s);
    return () => document.head.removeChild(s);
  }, []);

  /* ── Theme resolution ── */
  const [sysDark, setSysDark] = useState(() => window.matchMedia("(prefers-color-scheme:dark)").matches);
  useEffect(() => {
    const mq = window.matchMedia("(prefers-color-scheme:dark)");
    const h = (e) => setSysDark(e.matches);
    mq.addEventListener("change", h);
    return () => mq.removeEventListener("change", h);
  }, []);
  const isDark = theme === "dark" || (theme === "system" && sysDark);

  /* ── Derived theme colours ── */
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
  };

  useEffect(() => { if (aiOpen) setTimeout(() => aiRef.current?.focus(), 80); }, [aiOpen]);
  useEffect(() => { if (newFolderDlg) setTimeout(() => folderNameRef.current?.focus(), 80); }, [newFolderDlg]);

  const visibleDocs  = (activeTag ? docs.filter(d => d.tag === activeTag) : docs).filter(d => !d.trashed);
  const trashedCount = docs.filter(d => d.trashed).length;

  const trashDoc   = (id) => { setDocs(p => p.map(d => d.id===id ? {...d,trashed:true}  : d)); setCtxMenu(null); };
  const restoreDoc = (id) => setDocs(p => p.map(d => d.id===id ? {...d,trashed:false} : d));
  const permDelete = (id) => setDocs(p => p.filter(d => d.id!==id));

  const moveToFolder = (docId, folderId, projId) => {
    setDocs(p => p.map(d => d.id===docId ? {...d,folderId,projId} : d));
    setFolderSheet(null);
  };

  /* Create folder inside a project (or sub-folder) */
  const confirmNewFolder = () => {
    if (!newFolderName.trim() || !newFolderDlg) return;
    setProjects(prev => prev.map(p => {
      if (p.id !== newFolderDlg.projId) return p;
      const newFolder = { id:"f"+Date.now(), name:newFolderName.trim(), emoji:"1f4c2", subFolders:[], files:[] };
      if (!newFolderDlg.parentFolderId) {
        return { ...p, folders:[...p.folders, newFolder] };
      }
      return {
        ...p,
        folders: p.folders.map(f =>
          f.id === newFolderDlg.parentFolderId
            ? { ...f, subFolders:[...(f.subFolders||[]), newFolder] }
            : f
        )
      };
    }));
    setNewFolderName("");
    setNewFolderDlg(null);
  };

  const setEmojiFor = (target, id, cp) => {
    if (target==="proj")   setProjects(p => p.map(pr => pr.id===id ? {...pr,emoji:cp} : pr));
    if (target==="folder") setProjects(p => p.map(pr => ({...pr, folders:pr.folders.map(f => f.id===id ? {...f,emoji:cp} : f)})));
    if (target==="doc")    setDocs(p => p.map(d => d.id===id ? {...d,emoji:cp} : d));
    setEmojiPicker(null);
  };

  const doAI = async () => {
    const prompt = aiInput.trim(); if (!prompt) return;
    setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method:"POST", headers:{"Content-Type":"application/json"},
        body:JSON.stringify({ model:"claude-sonnet-4-20250514", max_tokens:900,
          system:"Cria um documento em português com HTML semântico (h1,h2,p). Responde APENAS com o HTML.",
          messages:[{role:"user",content:prompt}] })
      });
      const d = await r.json();
      const html = d.content?.map(i=>i.text||"").join("")||"";
      const nd = { id:Date.now(), title:prompt.slice(0,40), emoji:"1f9e0", preview:prompt.slice(0,90)+"…", date:"Agora", tag:"work", content:html };
      setDocs(p => [nd,...p]);
      setAiInput(""); setAiOpen(false);
      onOpenEditor(nd);
    } catch(_) {}
    setAiLoading(false);
  };

  /* ── Render Trash as full-screen overlay ── */
  if (showTrash) {
    return (
      <TrashScreen
        docs={docs}
        onRestore={restoreDoc}
        onDelete={permDelete}
        onBack={() => setShowTrash(false)}
        theme={isDark ? "dark" : "light"}
      />
    );
  }

  return (
    <div className={`home-screen ${visible?"vis":"hid"}`} style={{ background:T.bg }}>

      {/* ── EMOJI FULLSCREEN ── */}
      {emojiPicker && (
        <div style={{ position:"fixed", inset:0, zIndex:300, background:T.card, display:"flex", flexDirection:"column" }}>
          <div style={{ height:56, display:"flex", alignItems:"center", padding:"0 16px", borderBottom:`1px solid ${T.brd}`, flexShrink:0, background:T.bar }}>
            <div style={{ flex:1, fontSize:16, fontWeight:700, color:T.text }}>Escolher ícone</div>
            <button onClick={() => setEmojiPicker(null)} style={{ width:36, height:36, border:"none", background:"transparent", cursor:"pointer", display:"flex", alignItems:"center", justifyContent:"center", borderRadius:10, color:T.sub }}>
              <Icon name="x" size={20}/>
            </button>
          </div>
          {/* Scrollable grid — no containers */}
          <div style={{ flex:1, overflowY:"auto", padding:"16px 12px", scrollbarWidth:"none" }}>
            <div style={{ display:"flex", flexWrap:"wrap", gap:8 }}>
              {EMOJI_LIST.map(e => (
                <button key={e.cp} onClick={() => setEmojiFor(emojiPicker.target, emojiPicker.id, e.cp)}
                  style={{ width:60, height:60, borderRadius:16, border:`1.5px solid ${T.brd}`, background:"transparent", cursor:"pointer", display:"flex", flexDirection:"column", alignItems:"center", justifyContent:"center", gap:4, transition:"background .1s" }}
                  onPointerOver={e2=>e2.currentTarget.style.background=isDark?"rgba(255,255,255,.08)":"#e8f0fe"}
                  onPointerOut={e2=>e2.currentTarget.style.background="transparent"}>
                  <TwEmoji cp={e.cp} size={28}/>
                  <span style={{ fontSize:9, color:T.sub, fontWeight:500, lineHeight:1 }}>{e.lbl}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ── DRAWER MASK ── */}
      {drawerOpen && <div style={{ position:"fixed", inset:0, zIndex:49, background:"rgba(0,0,0,.25)" }} onClick={() => setDrawerOpen(false)}/>}

      {/* ── DRAWER ── */}
      <div style={{
        position:"fixed", top:0, left:0, width:272, height:"100%",
        background:T.card, zIndex:50, display:"flex", flexDirection:"column",
        transform: drawerOpen ? "translateX(0)" : "translateX(-100%)",
        transition:"transform .36s cubic-bezier(.32,1,.56,1)",
        boxShadow: drawerOpen ? "4px 0 32px rgba(0,0,0,.15)" : "none",
        borderRight:`1px solid ${T.brd}`,
      }}>

        {/* Drawer header — logo imported, no "D" letter */}
        <div style={{ paddingTop:48, paddingBottom:16, paddingLeft:18, paddingRight:18, borderBottom:`1px solid ${T.brd}`, display:"flex", alignItems:"center", gap:12 }}>
          <AppLogo size={36}/>
          <div>
            <div style={{ fontSize:17, fontWeight:700, color:T.text }}>Docu</div>
            <div style={{ fontSize:12, color:T.sub }}>Espaço de trabalho</div>
          </div>
        </div>

        {/* Drawer items — scrollable from top */}
        <div style={{ flex:1, overflowY:"auto", scrollbarWidth:"none", paddingTop:6 }}>

          <DrawerItem icon="book" label="Biblioteca" textColor={T.text} subColor={T.sub} onClick={() => setDrawerOpen(false)}/>

          <DrawerItem icon="settings" label="Configurações" textColor={T.text} subColor={T.sub}
            right={<Icon name={settingsOpen?"chevron-down":"chevron-right"} size={15} style={{ color:T.sub }}/>}
            onClick={() => setSettingsOpen(v=>!v)}/>

          {settingsOpen && (
            <div style={{ borderLeft:`2px solid ${T.brd}`, marginLeft:38 }}>
              {[
                {icon:"bell",    label:"Notificações"},
                {icon:"lock",    label:"Privacidade"},
                {icon:"palette", label:"Tema",         action:"theme"},
                {icon:"users",   label:"Conta"},
                {icon:"log-out", label:"Terminar sessão", danger:true},
              ].map(s => (
                <button key={s.label} onClick={() => {
                    if (s.action==="theme") { setThemeDlg(true); return; }
                    setDrawerOpen(false);
                  }}
                  style={{ display:"flex", alignItems:"center", gap:13, padding:"11px 18px 11px 16px", fontSize:14, fontWeight:500, color:s.danger?"#ff3b30":T.text, cursor:"pointer", border:"none", background:"transparent", width:"100%", textAlign:"left", fontFamily:"'DM Sans',sans-serif" }}>
                  <Icon name={s.icon} size={16} style={{ color:s.danger?"#ff3b30":T.sub, flexShrink:0 }}/>{s.label}
                </button>
              ))}
            </div>
          )}

          <DrawerItem icon="users" label="Membros" textColor={T.text} subColor={T.sub} onClick={() => setDrawerOpen(false)}/>

          <DrawerItem icon="trash-2" label="Lixo" textColor="#ff3b30" subColor={T.sub}
            iconColor="#ff3b30"
            right={<>
              {trashedCount>0 && <span style={{ fontSize:11, fontWeight:700, background:"#ff3b30", color:"#fff", borderRadius:9999, padding:"1px 7px", marginRight:4 }}>{trashedCount}</span>}
              <Icon name="chevron-right" size={15} style={{ color:"#ffb3b0" }}/>
            </>}
            onClick={() => { setShowTrash(true); setDrawerOpen(false); }}/>

          <div style={{ height:1, background:T.brd, margin:"6px 0" }}/>

          {/* Projects */}
          <div style={{ padding:"8px 18px 4px", fontSize:11, fontWeight:700, color:T.sub, textTransform:"uppercase", letterSpacing:".07em", display:"flex", alignItems:"center", justifyContent:"space-between" }}>
            <span>Projetos</span>
            <button onClick={() => { const n=prompt("Nome do projeto:");if(n) setProjects(p=>[...p,{id:"p"+Date.now(),name:n.trim(),emoji:"1f4c1",folders:[]}]); }}
              style={{ border:"none", background:"transparent", cursor:"pointer", color:T.sub, padding:2 }}>
              <Icon name="plus" size={15}/>
            </button>
          </div>

          {projects.map(proj => (
            <div key={proj.id}>
              <DrawerItem
                label={proj.name} textColor={T.text} subColor={T.sub}
                customIcon={<span onClick={e=>{e.stopPropagation();setEmojiPicker({target:"proj",id:proj.id});}}><TwEmoji cp={proj.emoji} size={20}/></span>}
                right={<Icon name={projExp[proj.id]?"chevron-down":"chevron-right"} size={14} style={{ color:T.sub }}/>}
                onClick={() => setProjExp(p=>({...p,[proj.id]:!p[proj.id]}))}/>

              {projExp[proj.id] && (
                <div style={{ borderLeft:`2px solid ${T.brd}`, marginLeft:38 }}>
                  {proj.folders.map(folder => (
                    <div key={folder.id}>
                      <button style={{ display:"flex", alignItems:"center", gap:13, padding:"10px 18px 10px 16px", fontSize:14, fontWeight:400, color:T.text, cursor:"pointer", border:"none", background:"transparent", width:"100%", textAlign:"left", fontFamily:"'DM Sans',sans-serif" }}>
                        <span onClick={e=>{e.stopPropagation();setEmojiPicker({target:"folder",id:folder.id});}}><TwEmoji cp={folder.emoji} size={16}/></span>
                        <span style={{ flex:1 }}>{folder.name}</span>
                        <button onClick={e=>{e.stopPropagation();setNewFolderDlg({projId:proj.id,parentFolderId:folder.id});setNewFolderName("");}}
                          style={{ border:"none", background:"transparent", cursor:"pointer", color:T.sub, padding:4, borderRadius:8 }}>
                          <Icon name="folder-plus" size={14}/>
                        </button>
                        <Icon name="chevron-right" size={13} style={{ color:T.sub }}/>
                      </button>
                      {/* Sub-folders */}
                      {(folder.subFolders||[]).map(sf => (
                        <button key={sf.id} style={{ display:"flex", alignItems:"center", gap:10, padding:"8px 18px 8px 28px", fontSize:13, fontWeight:400, color:T.text, cursor:"pointer", border:"none", background:"transparent", width:"100%", textAlign:"left", fontFamily:"'DM Sans',sans-serif" }}>
                          <TwEmoji cp={sf.emoji} size={14}/>
                          <span style={{ flex:1 }}>{sf.name}</span>
                        </button>
                      ))}
                    </div>
                  ))}
                  {/* Create folder in project */}
                  <button style={{ display:"flex", alignItems:"center", gap:10, padding:"10px 18px 10px 16px", fontSize:13, color:T.sub, fontWeight:400, cursor:"pointer", border:"none", background:"transparent", width:"100%", textAlign:"left", fontFamily:"'DM Sans',sans-serif" }}
                    onClick={() => { setNewFolderDlg({projId:proj.id}); setNewFolderName(""); }}>
                    <Icon name="folder-plus" size={15} style={{ color:T.sub }}/> Nova pasta
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* ── TOPBAR ── */}
      <div style={{
        height:56, flexShrink:0, display:"flex", alignItems:"center", padding:"0 8px",
        background:T.bar, position:"relative", zIndex:10,
        boxShadow: scrolled ? `0 1px 0 ${T.brd},0 2px 8px rgba(0,0,0,.06)` : "none",
        transition:"transform .36s cubic-bezier(.32,1,.56,1),box-shadow .2s",
        transform: drawerOpen ? "translateX(272px)" : "none",
      }}>
        <button style={{ width:44, height:44, border:"none", background:"transparent", cursor:"pointer", display:"flex", alignItems:"center", justifyContent:"center", borderRadius:12, color:T.sub }}
          onClick={() => setDrawerOpen(true)}>
          <Icon name="menu" size={22}/>
        </button>
        <div style={{ position:"absolute", left:"50%", transform:"translateX(-50%)", fontSize:17, fontWeight:700, color:T.text }}>Documentos</div>
        {/* AppBar right buttons — no container */}
        <div style={{ marginLeft:"auto", display:"flex", alignItems:"center", gap:4 }}>
          <button style={{ width:40, height:40, border:"none", background:"transparent", cursor:"pointer", display:"flex", alignItems:"center", justifyContent:"center", borderRadius:12, color:T.sub }}
            onClick={() => setNewFolderDlg({ projId: projects[0]?.id })}>
            <Icon name="layout-template" size={20}/>
          </button>
          <button style={{ width:40, height:40, border:"none", background:"transparent", cursor:"pointer", display:"flex", alignItems:"center", justifyContent:"center", borderRadius:12, color:T.sub }}
            onClick={() => onOpenEditor({ id:Date.now(), title:"", emoji:"1f4c4", content:"" })}>
            <Icon name="plus" size={22}/>
          </button>
        </div>
      </div>

      {/* ── SCROLL CONTENT ── */}
      <div ref={scrollRef} onScroll={() => setScrolled(scrollRef.current?.scrollTop>4)}
        style={{ flex:1, overflowY:"auto", overflowX:"hidden", WebkitOverflowScrolling:"touch", padding:"16px 16px 180px", scrollbarWidth:"none",
          transform: drawerOpen?"translateX(272px)":"none", transition:"transform .36s cubic-bezier(.32,1,.56,1)" }}>

        {/* Search */}
        <div style={{ display:"flex", alignItems:"center", gap:10, background:T.card, borderRadius:14, boxShadow:"0 1px 3px rgba(0,0,0,.07)", padding:"11px 14px", marginBottom:16 }}>
          <Icon name="search" size={16} style={{ color:T.sub, flexShrink:0 }}/>
          <input placeholder="Pesquisar documentos…"
            style={{ flex:1, border:"none", outline:"none", fontSize:15, color:T.text, background:"transparent", fontFamily:"'DM Sans',sans-serif", WebkitUserSelect:"text", userSelect:"text" }}/>
        </div>

        {/* Tags */}
        <div style={{ display:"flex", gap:8, overflowX:"auto", paddingBottom:4, marginBottom:16, scrollbarWidth:"none", WebkitOverflowScrolling:"touch" }}>
          <button style={{ flexShrink:0, padding:"6px 14px", borderRadius:9999, fontSize:13, fontWeight:600, cursor:"pointer", border:`1.5px solid ${!activeTag?"#1c1c1e":T.chipBrd}`, background:!activeTag?(isDark?"#f2f2f7":"#1c1c1e"):T.chip, color:!activeTag?(isDark?"#1c1c1e":"#fff"):T.text, fontFamily:"'DM Sans',sans-serif" }}
            onClick={() => setActiveTag(null)}>Todos</button>
          {TAGS.map(t => (
            <button key={t.id} style={{ flexShrink:0, padding:"6px 14px", borderRadius:9999, fontSize:13, fontWeight:600, cursor:"pointer", border:`1.5px solid ${activeTag===t.id?t.color:t.bg}`, background:activeTag===t.id?t.color:T.chip, color:activeTag===t.id?"#fff":t.color, fontFamily:"'DM Sans',sans-serif" }}
              onClick={() => setActiveTag(activeTag===t.id?null:t.id)}>{t.label}</button>
          ))}
        </div>

        <div style={{ fontSize:13, fontWeight:700, color:T.sub, marginBottom:10, padding:"0 2px" }}>Recentes</div>

        {visibleDocs.length === 0 ? (
          <div style={{ textAlign:"center", padding:"40px 20px", color:T.sub, fontSize:15 }}>Nenhum documento</div>
        ) : (
          <div style={{ background:T.card, borderRadius:14, overflow:"hidden", boxShadow:"0 1px 3px rgba(0,0,0,.07),0 4px 16px rgba(0,0,0,.05)", marginBottom:20 }}>
            {visibleDocs.map((doc, idx) => {
              const tag  = TAGS.find(t => t.id===doc.tag);
              const isLast = idx === visibleDocs.length-1;
              return (
                <div key={doc.id} onClick={() => onOpenEditor(doc)} style={{ padding:"14px 16px", cursor:"pointer", borderBottom: isLast ? "none" : `1px solid ${T.brd}`, transition:"background .1s" }}
                  onPointerOver={e=>e.currentTarget.style.background=isDark?"rgba(255,255,255,.04)":"rgba(0,0,0,.02)"}
                  onPointerOut={e=>e.currentTarget.style.background="transparent"}>
                  <div style={{ display:"flex", alignItems:"flex-start", gap:12 }}>
                    <div onClick={e=>{e.stopPropagation();setEmojiPicker({target:"doc",id:doc.id});}}
                      style={{ width:42, height:42, borderRadius:11, background:T.bg, display:"flex", alignItems:"center", justifyContent:"center", flexShrink:0, cursor:"pointer" }}>
                      <TwEmoji cp={doc.emoji||"1f4c4"} size={26}/>
                    </div>
                    <div style={{ flex:1, minWidth:0 }}>
                      <div style={{ display:"flex", alignItems:"center", gap:4, marginBottom:3 }}>
                        <div style={{ fontSize:15, fontWeight:600, color:T.text, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap", flex:1 }}>{doc.title}</div>
                        <button onClick={e=>{e.stopPropagation();onOpenEditor(doc);}}
                          style={{ border:"none", background:"transparent", cursor:"pointer", color:T.sub, padding:6, flexShrink:0, borderRadius:8 }}>
                          <Icon name="pencil" size={15}/>
                        </button>
                        <button onClick={e=>{e.stopPropagation();haptic();const r=e.currentTarget.getBoundingClientRect();setCtxMenu({docId:doc.id,x:Math.min(r.right-200,window.innerWidth-215),y:r.bottom+6});}}
                          style={{ border:"none", background:"transparent", cursor:"pointer", color:T.sub, padding:6, flexShrink:0, borderRadius:8 }}>
                          <Icon name="more-horizontal" size={16}/>
                        </button>
                      </div>
                      <div style={{ fontSize:13, color:T.sub, marginBottom:8, overflow:"hidden", textOverflow:"ellipsis", whiteSpace:"nowrap" }}>{doc.preview}</div>
                      <div style={{ display:"flex", alignItems:"center", gap:8 }}>
                        {tag && <span style={{ padding:"2px 9px", borderRadius:9999, fontSize:11, fontWeight:600, background:tag.bg, color:tag.color }}>{tag.label}</span>}
                        <span style={{ fontSize:11, color:T.sub }}>{doc.date}</span>
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
        position:"fixed", left:"50%", transform: drawerOpen?"translateX(calc(-50% + 136px))":"translateX(-50%)",
        bottom:"max(20px,env(safe-area-inset-bottom,20px))", width:"min(92vw,460px)", zIndex:20,
        transition:"transform .36s cubic-bezier(.32,1,.56,1)",
      }}>
        <div onClick={() => setAiOpen(true)} style={{
          display:"flex", alignItems:"center", gap:12, padding:"0 20px",
          height:60, background:T.pill, borderRadius:9999,
          border:`1px solid ${T.brd}`,
          boxShadow:"0 6px 24px rgba(0,0,0,.12),0 1px 4px rgba(0,0,0,.06)",
          cursor:"text",
        }}>
          <Icon name="sparkles" size={20} style={{ color:"#007aff", flexShrink:0 }}/>
          <span style={{ fontSize:15, color:T.sub, flex:1 }}>Criar com IA…</span>
        </div>
      </div>

      {/* ── CTX MENU ── */}
      {ctxMenu && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:9998 }} onClick={() => setCtxMenu(null)}/>
          <div style={{ position:"fixed", background:T.card, borderRadius:14, boxShadow:"0 4px 24px rgba(0,0,0,.15),0 1px 4px rgba(0,0,0,.08)", border:`1px solid ${T.brd}`, zIndex:9999, overflow:"hidden", minWidth:200, left:ctxMenu.x, top:ctxMenu.y }}>
            <button className="ctx-item" style={{ color:T.text }} onClick={() => { onOpenEditor(docs.find(d=>d.id===ctxMenu.docId)); setCtxMenu(null); }}>
              <Icon name="pencil" size={15} style={{ color:T.sub }}/> Editar
            </button>
            <div style={{ height:1, background:T.brd, margin:"2px 0" }}/>
            <button className="ctx-item" style={{ color:T.text }} onClick={() => { setFolderSheet(ctxMenu.docId); setCtxMenu(null); }}>
              <Icon name="move" size={15} style={{ color:T.sub }}/> Mover para pasta
            </button>
            <div style={{ height:1, background:T.brd, margin:"2px 0" }}/>
            <button className="ctx-item danger" onClick={() => trashDoc(ctxMenu.docId)}>
              <Icon name="trash-2" size={15} style={{ color:"#ff3b30" }}/> Enviar ao lixo
            </button>
          </div>
        </>
      )}

      {/* ── FOLDER SHEET ── */}
      {folderSheet && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:199, background:"rgba(0,0,0,.25)", animation:"fadeIn .2s both" }} onClick={() => setFolderSheet(null)}/>
          <div style={{ position:"fixed", bottom:0, left:0, right:0, background:T.card, borderRadius:"24px 24px 0 0", padding:"20px 0 max(28px,env(safe-area-inset-bottom,28px))", zIndex:200, animation:"slideUp .3s cubic-bezier(.32,1,.56,1) both", maxHeight:"70vh", display:"flex", flexDirection:"column" }}>
            <div style={{ width:36, height:4, background:T.brd, borderRadius:2, margin:"0 auto 14px" }}/>
            <div style={{ fontSize:16, fontWeight:700, color:T.text, padding:"0 20px 12px", borderBottom:`1px solid ${T.brd}` }}>Mover para pasta</div>
            <div style={{ flex:1, overflowY:"auto", scrollbarWidth:"none" }}>
              {projects.map(proj => (
                <div key={proj.id}>
                  <div style={{ padding:"10px 20px 4px", fontSize:12, fontWeight:700, color:T.sub, textTransform:"uppercase", letterSpacing:".06em", display:"flex", alignItems:"center", gap:8 }}>
                    <TwEmoji cp={proj.emoji} size={14}/> {proj.name}
                  </div>
                  {proj.folders.map(f => (
                    <button key={f.id} onClick={() => moveToFolder(folderSheet,f.id,proj.id)}
                      style={{ display:"flex", alignItems:"center", gap:12, padding:"13px 20px", border:"none", background:"transparent", width:"100%", cursor:"pointer", fontFamily:"'DM Sans',sans-serif", fontSize:14, color:T.text }}>
                      <TwEmoji cp={f.emoji} size={18}/> {f.name}
                      <Icon name="chevron-right" size={14} style={{ color:T.sub, marginLeft:"auto" }}/>
                    </button>
                  ))}
                </div>
              ))}
            </div>
          </div>
        </>
      )}

      {/* ── NEW FOLDER DIALOG ── */}
      {newFolderDlg && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:299, background:"rgba(0,0,0,.35)" }} onClick={() => setNewFolderDlg(null)}/>
          <div style={{
            position:"fixed", top:"50%", left:"50%", transform:"translate(-50%,-50%)",
            width:"min(88vw,340px)", background:T.card,
            borderRadius:20, zIndex:300, overflow:"hidden",
            boxShadow:"0 20px 60px rgba(0,0,0,.3),0 4px 16px rgba(0,0,0,.15)",
          }}>
            <div style={{ padding:"24px 24px 8px" }}>
              <div style={{ width:48, height:48, borderRadius:14, background:"#eff6ff", display:"flex", alignItems:"center", justifyContent:"center", marginBottom:16 }}>
                <Icon name="folder-plus" size={24} style={{ color:"#007aff" }}/>
              </div>
              <div style={{ fontSize:18, fontWeight:700, color:T.text, marginBottom:4 }}>Nova pasta</div>
              <div style={{ fontSize:13, color:T.sub, marginBottom:20 }}>
                {newFolderDlg.parentFolderId ? "Criar sub-pasta dentro da pasta selecionada" : "Criar pasta no projeto"}
              </div>
              <input ref={folderNameRef} value={newFolderName} onChange={e=>setNewFolderName(e.target.value)}
                onKeyDown={e=>{if(e.key==="Enter")confirmNewFolder();if(e.key==="Escape")setNewFolderDlg(null);}}
                placeholder="Nome da pasta…"
                style={{ width:"100%", padding:"13px 16px", border:`1.5px solid ${T.brd}`, borderRadius:12, fontSize:15, outline:"none", fontFamily:"'DM Sans',sans-serif", background:T.bg, color:T.text, WebkitUserSelect:"text", userSelect:"text" }}/>
            </div>
            <div style={{ display:"flex", borderTop:`1px solid ${T.brd}`, marginTop:16 }}>
              <button onClick={() => setNewFolderDlg(null)}
                style={{ flex:1, padding:"15px 0", border:"none", background:"transparent", cursor:"pointer", fontFamily:"'DM Sans',sans-serif", fontSize:16, fontWeight:500, color:T.sub }}>
                Cancelar
              </button>
              <div style={{ width:1, background:T.brd }}/>
              <button onClick={confirmNewFolder}
                style={{ flex:1, padding:"15px 0", border:"none", background:"transparent", cursor:"pointer", fontFamily:"'DM Sans',sans-serif", fontSize:16, fontWeight:700, color: newFolderName.trim() ? "#007aff" : T.sub }}>
                Criar
              </button>
            </div>
          </div>
        </>
      )}

      {/* ── THEME DIALOG ── */}
      {themeDlg && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:399, background:"rgba(0,0,0,.35)" }} onClick={() => setThemeDlg(false)}/>
          <div style={{
            position:"fixed", top:"50%", left:"50%", transform:"translate(-50%,-50%)",
            width:"min(88vw,320px)", background:T.card,
            borderRadius:20, zIndex:400, overflow:"hidden",
            boxShadow:"0 20px 60px rgba(0,0,0,.3),0 4px 16px rgba(0,0,0,.15)",
          }}>
            <div style={{ padding:"24px 24px 16px" }}>
              <div style={{ width:48, height:48, borderRadius:14, background:"#f5f0ff", display:"flex", alignItems:"center", justifyContent:"center", marginBottom:16 }}>
                <Icon name="palette" size={24} style={{ color:"#7c3aed" }}/>
              </div>
              <div style={{ fontSize:18, fontWeight:700, color:T.text, marginBottom:4 }}>Aparência</div>
              <div style={{ fontSize:13, color:T.sub, marginBottom:20 }}>Escolhe o tema da aplicação</div>
              {[
                { id:"light",  icon:"sun",     label:"Claro",     desc:"Fundo branco brilhante" },
                { id:"dark",   icon:"moon",    label:"Escuro",    desc:"Fundo escuro confortável" },
                { id:"system", icon:"monitor", label:"Sistema",   desc:"Segue o tema do dispositivo" },
              ].map(t => (
                <button key={t.id} onClick={() => setTheme(t.id)}
                  style={{ display:"flex", alignItems:"center", gap:14, width:"100%", padding:"13px 14px", border:`1.5px solid ${theme===t.id?"#007aff":T.brd}`, borderRadius:14, background:theme===t.id ? (isDark?"rgba(0,122,255,.12)":"#eff6ff") : "transparent", cursor:"pointer", marginBottom:10, fontFamily:"'DM Sans',sans-serif", textAlign:"left", transition:"all .15s" }}>
                  <div style={{ width:36, height:36, borderRadius:10, background:theme===t.id?"#007aff":T.bg, display:"flex", alignItems:"center", justifyContent:"center", flexShrink:0 }}>
                    <Icon name={t.icon} size={18} style={{ color: theme===t.id?"#fff":T.sub }}/>
                  </div>
                  <div style={{ flex:1 }}>
                    <div style={{ fontSize:15, fontWeight:600, color:T.text }}>{t.label}</div>
                    <div style={{ fontSize:12, color:T.sub }}>{t.desc}</div>
                  </div>
                  {theme===t.id && <Icon name="check" size={18} style={{ color:"#007aff" }}/>}
                </button>
              ))}
            </div>
            <div style={{ borderTop:`1px solid ${T.brd}` }}>
              <button onClick={() => setThemeDlg(false)}
                style={{ width:"100%", padding:"15px 0", border:"none", background:"transparent", cursor:"pointer", fontFamily:"'DM Sans',sans-serif", fontSize:16, fontWeight:700, color:"#007aff" }}>
                Feito
              </button>
            </div>
          </div>
        </>
      )}

      {/* ── AI SHEET ── */}
      {aiOpen && (
        <>
          <div style={{ position:"fixed", inset:0, zIndex:60, background:"rgba(0,0,0,.3)", animation:"fadeIn .2s both" }} onClick={() => setAiOpen(false)}/>
          <div style={{ position:"fixed", bottom:0, left:0, right:0, background:T.card, borderRadius:"24px 24px 0 0", padding:"20px 20px max(32px,env(safe-area-inset-bottom,32px))", zIndex:61, animation:"slideUp .3s cubic-bezier(.32,1,.56,1) both" }}>
            <div style={{ width:36, height:4, background:T.brd, borderRadius:2, margin:"0 auto 18px" }}/>
            <div style={{ display:"flex", alignItems:"center", gap:12, marginBottom:16 }}>
              <div style={{ width:40, height:40, borderRadius:12, background:"#eff6ff", display:"flex", alignItems:"center", justifyContent:"center" }}>
                <Icon name="sparkles" size={20} style={{ color:"#007aff" }}/>
              </div>
              <div style={{ flex:1 }}>
                <div style={{ fontSize:16, fontWeight:700, color:T.text }}>Criar com IA</div>
                <div style={{ fontSize:13, color:T.sub }}>Descreve o que queres criar</div>
              </div>
              <button onClick={() => setAiOpen(false)} style={{ border:"none", background:"transparent", cursor:"pointer", color:T.sub, padding:6, borderRadius:9 }}>
                <Icon name="x" size={18}/>
              </button>
            </div>
            <textarea ref={aiRef} value={aiInput} onChange={e=>setAiInput(e.target.value)}
              placeholder="Ex: Plano de aula sobre fotossíntese, relatório de vendas, resumo de livro…" rows={5}
              style={{ width:"100%", padding:"15px 16px", border:`1.5px solid ${T.brd}`, borderRadius:16, fontSize:15, fontFamily:"'DM Sans',sans-serif", outline:"none", resize:"none", color:T.text, background:T.bg, lineHeight:1.65, WebkitUserSelect:"text", userSelect:"text" }}/>
            <button onClick={doAI} disabled={!aiInput.trim()||aiLoading}
              style={{ width:"100%", marginTop:14, padding:"15px 0", background:aiInput.trim()&&!aiLoading?"#007aff":"rgba(0,0,0,.07)", color:aiInput.trim()&&!aiLoading?"#fff":T.sub, border:"none", borderRadius:14, cursor:aiInput.trim()&&!aiLoading?"pointer":"default", fontFamily:"'DM Sans',sans-serif", fontSize:16, fontWeight:600, display:"flex", alignItems:"center", justifyContent:"center", gap:8, transition:"background .2s" }}>
              {aiLoading ? "A criar…" : <><Icon name="send" size={16}/>Criar documento</>}
            </button>
          </div>
        </>
      )}
    </div>
  );
}

/* ── Small reusable drawer button ── */
function DrawerItem({ icon, label, textColor, subColor, iconColor, right, onClick, customIcon }) {
  return (
    <button onClick={onClick}
      style={{ display:"flex", alignItems:"center", gap:13, padding:"12px 18px", fontSize:15, fontWeight:500, color:textColor, cursor:"pointer", border:"none", background:"transparent", width:"100%", textAlign:"left", fontFamily:"'DM Sans',sans-serif", transition:"background .1s" }}
      onPointerOver={e=>e.currentTarget.style.background="rgba(128,128,128,.07)"}
      onPointerOut={e=>e.currentTarget.style.background="transparent"}>
      {customIcon
        ? <span style={{ flexShrink:0, display:"flex", alignItems:"center" }}>{customIcon}</span>
        : <Icon name={icon} size={20} style={{ color: iconColor || textColor, flexShrink:0 }}/>}
      <span style={{ flex:1 }}>{label}</span>
      {right}
    </button>
  );
}

/* ── Global CSS ── */
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
@keyframes slideUp{from{transform:translateY(60px);opacity:0}to{transform:translateY(0);opacity:1}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
`;