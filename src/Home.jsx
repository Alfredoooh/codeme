import { useState, useRef, useEffect } from "react";

const twSrc = (cp) => `https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/svg/${cp}.svg`;
const TwEmoji = ({ cp, size=20 }) => (
  <img src={twSrc(cp)} width={size} height={size} style={{display:"inline-block",verticalAlign:"middle",flexShrink:0}} alt=""/>
);

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
];

const IC = {
  menu:`<line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/>`,
  "chevron-right":`<polyline points="9 18 15 12 9 6"/>`,
  "chevron-down":`<path d="m6 9 6 6 6-6"/>`,
  "arrow-up-right":`<polyline points="7 7 17 7 17 17"/><line x1="7" y1="17" x2="17" y2="7"/>`,
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
  rotate:`<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>`,
};
const Icon = ({name,size=18,sw=2,style}) => (
  <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
    style={style} dangerouslySetInnerHTML={{__html:IC[name]||""}}/>
);

const TAGS = [
  {id:"work",   label:"Trabalho", color:"#2563eb", bg:"#dbeafe"},
  {id:"school", label:"Escola",   color:"#7c3aed", bg:"#f3e8ff"},
  {id:"church", label:"Igreja",   color:"#059669", bg:"#d1fae5"},
  {id:"biz",    label:"Negócios", color:"#d97706", bg:"#fef3c7"},
  {id:"personal",label:"Pessoal", color:"#db2777", bg:"#fce7f3"},
];

const haptic = (s="light") => { try { if(navigator.vibrate) navigator.vibrate(s==="light"?8:20); } catch(_){} };

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;-webkit-font-smoothing:antialiased}
html,body,#root{width:100%;height:100%;overflow:hidden;background:#f2f2f7}
.home-screen{position:absolute;inset:0;display:flex;flex-direction:column;font-family:'DM Sans',system-ui,sans-serif;background:#f2f2f7;overflow:hidden;will-change:transform}
.home-screen.vis{transform:translateX(0);opacity:1;transition:transform .38s cubic-bezier(.32,1,.56,1),opacity .3s}
.home-screen.hid{transform:translateX(-30%);opacity:0;pointer-events:none;transition:transform .38s cubic-bezier(.32,1,.56,1),opacity .3s}
.topbar{height:56px;flex-shrink:0;display:flex;align-items:center;padding:0 8px;background:#fff;position:relative;z-index:10;transition:box-shadow .2s}
.topbar.scrolled{box-shadow:0 1px 0 rgba(0,0,0,.1),0 2px 8px rgba(0,0,0,.06)}
.tbtn{width:44px;height:44px;border:none;background:transparent;cursor:pointer;display:flex;align-items:center;justify-content:center;border-radius:12px;color:#8e8e93;transition:background .12s}
.tbtn:active{background:rgba(0,0,0,.06)}
.drawer{position:fixed;top:0;left:0;width:272px;height:100%;background:#fff;z-index:50;display:flex;flex-direction:column;transform:translateX(-100%);transition:transform .36s cubic-bezier(.32,1,.56,1)}
.drawer.open{transform:translateX(0);box-shadow:4px 0 32px rgba(0,0,0,.14)}
.dmask{position:fixed;inset:0;z-index:49;background:rgba(0,0,0,.2)}
.d-item{display:flex;align-items:center;gap:13px;padding:12px 18px;font-size:15px;font-weight:500;color:#1c1c1e;cursor:pointer;border:none;background:transparent;width:100%;text-align:left;font-family:'DM Sans',sans-serif;transition:background .1s}
.d-item:active{background:rgba(0,0,0,.05)}
.hscroll{flex:1;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;padding:16px 16px 180px;scrollbar-width:none}
.hscroll::-webkit-scrollbar{display:none}
.tags-row{display:flex;gap:8px;overflow-x:auto;padding-bottom:4px;margin-bottom:16px;scrollbar-width:none;-webkit-overflow-scrolling:touch}
.tags-row::-webkit-scrollbar{display:none}
.tag-chip{flex-shrink:0;padding:6px 14px;border-radius:9999px;font-size:13px;font-weight:600;cursor:pointer;border:1.5px solid transparent;transition:all .15s;font-family:'DM Sans',sans-serif}
.card-group{background:#fff;border-radius:14px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.07),0 4px 16px rgba(0,0,0,.05);margin-bottom:20px}
.doc-card{padding:14px 16px;cursor:pointer;transition:background .1s;position:relative;border-bottom:1px solid rgba(0,0,0,.06)}
.doc-card:last-child{border-bottom:none}
.doc-card:active{background:rgba(0,0,0,.04)}
.ftb{position:fixed;left:50%;transform:translateX(-50%);bottom:max(20px,env(safe-area-inset-bottom,20px));width:min(92vw,440px);z-index:20;display:flex;align-items:center;gap:10px}
.pill-inp{flex:1;height:56px;background:#fff;border:1px solid rgba(0,0,0,.1);border-radius:9999px;box-shadow:0 4px 20px rgba(0,0,0,.1),0 1px 4px rgba(0,0,0,.05);display:flex;align-items:center;padding:0 18px;gap:10px;cursor:text}
.circ-btn{width:56px;height:56px;border-radius:50%;border:1px solid rgba(0,0,0,.1);background:#fff;box-shadow:0 4px 20px rgba(0,0,0,.1);cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;color:#3a3a3c;transition:transform .12s}
.circ-btn:active{transform:scale(.9)}
.ai-overlay{position:fixed;inset:0;z-index:60;background:rgba(0,0,0,.3);animation:fadeIn .2s both}
.ai-sheet{position:fixed;bottom:0;left:0;right:0;background:#fff;border-radius:24px 24px 0 0;padding:20px 20px max(32px,env(safe-area-inset-bottom,32px));z-index:61;animation:slideUp .3s cubic-bezier(.32,1,.56,1) both}
.ctx-menu{position:fixed;background:#fff;border-radius:14px;box-shadow:0 4px 24px rgba(0,0,0,.15),0 1px 4px rgba(0,0,0,.08);border:1px solid rgba(0,0,0,.08);z-index:9999;overflow:hidden;min-width:200px;animation:popIn .15s cubic-bezier(.34,1.56,.64,1) both}
.ctx-item{display:flex;align-items:center;gap:10px;padding:12px 16px;color:#1c1c1e;font-size:14px;font-weight:500;font-family:'DM Sans',sans-serif;cursor:pointer;border:none;background:transparent;width:100%;text-align:left}
.ctx-item:active{background:rgba(0,0,0,.04)}
.ctx-item.danger{color:#ff3b30}
.ctx-sep{height:1px;background:rgba(0,0,0,.07);margin:2px 0}
.sheet-overlay{position:fixed;inset:0;z-index:199;background:rgba(0,0,0,.25);animation:fadeIn .2s both}
.sheet{position:fixed;bottom:0;left:0;right:0;background:#fff;border-radius:24px 24px 0 0;padding:20px 0 max(28px,env(safe-area-inset-bottom,28px));z-index:200;animation:slideUp .3s cubic-bezier(.32,1,.56,1) both;max-height:70vh;display:flex;flex-direction:column}
.sheet-item{display:flex;align-items:center;gap:12px;padding:13px 20px;border:none;background:transparent;width:100%;cursor:pointer;font-family:'DM Sans',sans-serif;font-size:14px;color:#1c1c1e}
.sheet-item:active{background:rgba(0,0,0,.04)}
.emoji-fs{position:fixed;inset:0;z-index:300;background:#fff;display:flex;flex-direction:column;animation:slideUp .28s cubic-bezier(.32,1,.56,1) both}
.section-lbl{font-size:13px;font-weight:700;color:#8e8e93;margin-bottom:10px;padding:0 2px}
.search-bar{display:flex;align-items:center;gap:10px;background:#fff;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,.07);padding:10px 14px;margin-bottom:16px}
.trash-empty{display:flex;flex-direction:column;align-items:center;justify-content:center;flex:1;gap:12px;color:#8e8e93;padding-bottom:80px}
.noscroll{scrollbar-width:none}.noscroll::-webkit-scrollbar{display:none}
@keyframes popIn{from{opacity:0;transform:scale(.85)}to{opacity:1;transform:scale(1)}}
@keyframes slideUp{from{transform:translateY(60px);opacity:0}to{transform:translateY(0);opacity:1}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
`;

export default function Home({ visible, docs, setDocs, projects, setProjects, onOpenEditor }) {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [projExp, setProjExp] = useState({});
  const [activeTag, setActiveTag] = useState(null);
  const [aiOpen, setAiOpen] = useState(false);
  const [aiInput, setAiInput] = useState("");
  const [aiLoading, setAiLoading] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [subScreen, setSubScreen] = useState("home"); // home | trash
  const [ctxMenu, setCtxMenu] = useState(null);
  const [folderSheet, setFolderSheet] = useState(null);
  const [emojiPicker, setEmojiPicker] = useState(null);
  const [newFolderParent, setNewFolderParent] = useState(null);
  const [newFolderName, setNewFolderName] = useState("");
  const aiRef = useRef(null);
  const scrollRef = useRef(null);

  useEffect(() => {
    const s = document.createElement("style");
    s.textContent = CSS;
    document.head.appendChild(s);
    return () => document.head.removeChild(s);
  }, []);

  useEffect(() => { if (aiOpen) setTimeout(() => aiRef.current?.focus(), 80); }, [aiOpen]);

  const openDrawer = () => setDrawerOpen(true);
  const closeDrawer = () => setDrawerOpen(false);

  const visibleDocs = (activeTag ? docs.filter(d => d.tag === activeTag) : docs).filter(d => !d.trashed);
  const trashedDocs = docs.filter(d => d.trashed);

  const trashDoc = (id) => { setDocs(prev => prev.map(d => d.id === id ? {...d, trashed:true} : d)); setCtxMenu(null); };
  const restoreDoc = (id) => setDocs(prev => prev.map(d => d.id === id ? {...d, trashed:false} : d));
  const permDelete = (id) => setDocs(prev => prev.filter(d => d.id !== id));
  const moveToFolder = (docId, folderId, projId) => { setDocs(prev => prev.map(d => d.id === docId ? {...d, folderId, projId} : d)); setFolderSheet(null); };
  const addFolder = (projId) => {
    if (!newFolderName.trim()) return;
    setProjects(prev => prev.map(p => p.id === projId ? {...p, folders:[...p.folders,{id:"f"+Date.now(),name:newFolderName.trim(),emoji:"1f4c2"}]} : p));
    setNewFolderName(""); setNewFolderParent(null);
  };
  const setEmojiFor = (target, id, cp) => {
    if (target === "proj") setProjects(prev => prev.map(p => p.id === id ? {...p, emoji:cp} : p));
    else if (target === "folder") setProjects(prev => prev.map(p => ({...p, folders:p.folders.map(f => f.id === id ? {...f, emoji:cp} : f)})));
    else if (target === "doc") setDocs(prev => prev.map(d => d.id === id ? {...d, emoji:cp} : d));
    setEmojiPicker(null);
  };

  const doAI = async () => {
    const p = aiInput.trim(); if (!p) return;
    setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages", {method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({model:"claude-sonnet-4-20250514",max_tokens:900,system:"Cria um documento em português com HTML semântico (h1,h2,p). Responde APENAS com o HTML.",messages:[{role:"user",content:p}]})});
      const d = await r.json();
      const html = d.content?.map(i=>i.text||"").join("")||"";
      const nd = {id:Date.now(),title:p.slice(0,40),emoji:"1f9e0",preview:p.slice(0,90)+"…",date:"Agora",tag:"work",content:html};
      setDocs(prev => [nd, ...prev]);
      setAiInput(""); setAiOpen(false);
      onOpenEditor(nd);
    } catch(_) {}
    setAiLoading(false);
  };

  const cardCount = visibleDocs.length;

  return (
    <div className={`home-screen ${visible ? "vis" : "hid"}`}>
      {/* EMOJI FULL SCREEN */}
      {emojiPicker && (
        <div className="emoji-fs">
          <div style={{height:56,display:"flex",alignItems:"center",padding:"0 16px",borderBottom:"1px solid rgba(0,0,0,.07)",flexShrink:0}}>
            <div style={{flex:1,fontSize:16,fontWeight:700,color:"#1c1c1e"}}>Escolher ícone</div>
            <button onClick={() => setEmojiPicker(null)} style={{width:36,height:36,border:"none",background:"transparent",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",borderRadius:10,color:"#8e8e93"}}>
              <Icon name="x" size={20}/>
            </button>
          </div>
          <div style={{flex:1,overflowY:"auto",padding:16}} className="noscroll">
            <div style={{display:"grid",gridTemplateColumns:"repeat(5,1fr)",gap:10}}>
              {EMOJI_LIST.map(e => (
                <button key={e.cp} onClick={() => setEmojiFor(emojiPicker.target, emojiPicker.id, e.cp)}
                  style={{aspectRatio:"1",borderRadius:14,border:"1.5px solid rgba(0,0,0,.06)",background:"#f9f9f9",cursor:"pointer",display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",gap:6,padding:8,transition:"background .1s"}}
                  onPointerOver={e2=>e2.currentTarget.style.background="#e8f0fe"} onPointerOut={e2=>e2.currentTarget.style.background="#f9f9f9"}>
                  <TwEmoji cp={e.cp} size={32}/>
                  <span style={{fontSize:10,color:"#8e8e93",fontWeight:500,lineHeight:1}}>{e.lbl}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* DRAWER */}
      {drawerOpen && <div className="dmask" onClick={closeDrawer}/>}
      <div className={`drawer${drawerOpen ? " open" : ""}`}>
        <div style={{padding:"56px 18px 14px",borderBottom:"1px solid rgba(0,0,0,.07)",display:"flex",alignItems:"center",gap:12}}>
          <div style={{width:42,height:42,borderRadius:11,background:"#1c1c1e",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>
            <span style={{color:"#fff",fontWeight:800,fontSize:19,fontFamily:"Georgia,serif"}}>D</span>
          </div>
          <div>
            <div style={{fontSize:17,fontWeight:700,color:"#1c1c1e"}}>Menu</div>
            <div style={{fontSize:12,color:"#8e8e93"}}>Espaço de trabalho</div>
          </div>
        </div>
        <div style={{flex:1,overflowY:"auto"}} className="noscroll">
          <button className="d-item" onClick={closeDrawer}>
            <Icon name="book" size={20} style={{color:"#1c1c1e",flexShrink:0}}/><span style={{flex:1}}>Biblioteca</span>
          </button>
          <button className="d-item" onClick={() => setSettingsOpen(v=>!v)}>
            <Icon name="settings" size={20} style={{color:"#1c1c1e",flexShrink:0}}/><span style={{flex:1}}>Configurações</span>
            <Icon name={settingsOpen?"chevron-down":"chevron-right"} size={15} style={{color:"#c7c7cc"}}/>
          </button>
          {settingsOpen && (
            <div style={{borderLeft:"2px solid #f0f0f0",marginLeft:38}}>
              {[{icon:"bell",label:"Notificações"},{icon:"lock",label:"Privacidade"},{icon:"palette",label:"Aparência"},{icon:"users",label:"Conta"},{icon:"log-out",label:"Terminar sessão",danger:true}].map(s => (
                <button key={s.label} className="d-item" style={{paddingLeft:16,fontSize:14,color:s.danger?"#ff3b30":"#3a3a3c"}} onClick={closeDrawer}>
                  <Icon name={s.icon} size={16} style={{color:s.danger?"#ff3b30":"#8e8e93",flexShrink:0}}/>{s.label}
                </button>
              ))}
            </div>
          )}
          <button className="d-item" onClick={closeDrawer}>
            <Icon name="users" size={20} style={{color:"#1c1c1e",flexShrink:0}}/><span style={{flex:1}}>Membros</span>
          </button>
          <button className="d-item" onClick={() => {setSubScreen("trash"); closeDrawer();}}>
            <Icon name="trash-2" size={20} style={{color:"#ff3b30",flexShrink:0}}/>
            <span style={{flex:1,color:"#ff3b30"}}>Lixo</span>
            {trashedDocs.length > 0 && <span style={{fontSize:11,fontWeight:700,background:"#ff3b30",color:"#fff",borderRadius:9999,padding:"1px 7px"}}>{trashedDocs.length}</span>}
            <Icon name="chevron-right" size={15} style={{color:"#ffb3b0"}}/>
          </button>
          <div style={{height:1,background:"rgba(0,0,0,.06)",margin:"6px 0"}}/>
          <div style={{padding:"8px 18px 4px",fontSize:11,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",letterSpacing:".07em",display:"flex",alignItems:"center",justifyContent:"space-between"}}>
            <span>Projetos</span>
            <button onClick={() => {const n=prompt("Nome do projeto:");if(n)setProjects(prev=>[...prev,{id:"p"+Date.now(),name:n.trim(),emoji:"1f4c1",folders:[]}]);}}
              style={{border:"none",background:"transparent",cursor:"pointer",color:"#8e8e93",padding:2}}><Icon name="plus" size={15}/></button>
          </div>
          {projects.map(proj => (
            <div key={proj.id}>
              <button className="d-item" onClick={() => setProjExp(prev=>({...prev,[proj.id]:!prev[proj.id]}))}>
                <span onClick={e=>{e.stopPropagation();setEmojiPicker({target:"proj",id:proj.id});}}>
                  <TwEmoji cp={proj.emoji} size={20}/>
                </span>
                <span style={{flex:1,fontWeight:500}}>{proj.name}</span>
                <Icon name={projExp[proj.id]?"chevron-down":"chevron-right"} size={14} style={{color:"#c7c7cc"}}/>
              </button>
              {projExp[proj.id] && (
                <div style={{borderLeft:"2px solid #f0f0f0",marginLeft:38}}>
                  {proj.folders.map(folder => (
                    <button key={folder.id} className="d-item" style={{paddingLeft:16,fontSize:14,fontWeight:400,color:"#3a3a3c"}}>
                      <span onClick={e=>{e.stopPropagation();setEmojiPicker({target:"folder",id:folder.id});}}><TwEmoji cp={folder.emoji} size={16}/></span>
                      <span style={{flex:1}}>{folder.name}</span>
                      <Icon name="chevron-right" size={13} style={{color:"#c7c7cc"}}/>
                    </button>
                  ))}
                  {newFolderParent === proj.id ? (
                    <div style={{padding:"6px 12px",display:"flex",gap:6}}>
                      <input autoFocus value={newFolderName} onChange={e=>setNewFolderName(e.target.value)}
                        onKeyDown={e=>{if(e.key==="Enter")addFolder(proj.id);if(e.key==="Escape")setNewFolderParent(null);}}
                        placeholder="Nome da pasta…"
                        style={{flex:1,padding:"6px 10px",border:"1.5px solid rgba(0,0,0,.1)",borderRadius:8,fontSize:13,outline:"none",fontFamily:"'DM Sans',sans-serif",WebkitUserSelect:"text",userSelect:"text"}}/>
                      <button onClick={() => addFolder(proj.id)} style={{border:"none",background:"#007aff",color:"#fff",borderRadius:8,padding:"6px 10px",cursor:"pointer",fontSize:12,fontWeight:600}}>OK</button>
                    </div>
                  ) : (
                    <button className="d-item" style={{paddingLeft:16,fontSize:13,color:"#8e8e93",fontWeight:400}} onClick={() => {setNewFolderParent(proj.id);setNewFolderName("");}}>
                      <Icon name="folder-plus" size={15} style={{color:"#c7c7cc"}}/> Nova pasta
                    </button>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* TOPBAR */}
      <div className={`topbar${scrolled?" scrolled":""}`}
        style={{transform:drawerOpen?"translateX(272px)":"none",transition:"transform .36s cubic-bezier(.32,1,.56,1), box-shadow .2s"}}>
        <button className="tbtn" onClick={openDrawer}><Icon name="menu" size={22}/></button>
        <div style={{position:"absolute",left:"50%",transform:"translateX(-50%)",fontSize:17,fontWeight:700,color:"#1c1c1e"}}>
          {subScreen==="trash"?"Lixo":"Documentos"}
        </div>
        {subScreen==="trash" && (
          <button className="tbtn" style={{position:"absolute",right:8}} onClick={() => setSubScreen("home")}>
            <Icon name="x" size={20}/>
          </button>
        )}
      </div>

      {/* CONTENT */}
      {subScreen === "trash" ? (
        <div ref={scrollRef} onScroll={() => setScrolled(scrollRef.current?.scrollTop>4)} className="hscroll noscroll">
          {trashedDocs.length === 0 ? (
            <div className="trash-empty">
              <Icon name="trash-2" size={48} style={{color:"#d1d5db"}} sw={1.5}/>
              <div style={{fontSize:16,fontWeight:600}}>Lixo vazio</div>
            </div>
          ) : (
            <div className="card-group">
              {trashedDocs.map(doc => (
                <div key={doc.id} className="doc-card">
                  <div style={{display:"flex",alignItems:"center",gap:10}}>
                    <TwEmoji cp={doc.emoji||"1f4c4"} size={22}/>
                    <div style={{flex:1,minWidth:0}}>
                      <div style={{fontSize:14,fontWeight:600,color:"#1c1c1e",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{doc.title}</div>
                      <div style={{fontSize:12,color:"#8e8e93"}}>{doc.date}</div>
                    </div>
                    <button onClick={() => restoreDoc(doc.id)} style={{border:"none",background:"transparent",cursor:"pointer",color:"#007aff",fontSize:13,fontWeight:600,padding:"4px 8px"}}>Restaurar</button>
                    <button onClick={() => permDelete(doc.id)} style={{border:"none",background:"transparent",cursor:"pointer",color:"#ff3b30",fontSize:13,fontWeight:600,padding:"4px 8px"}}>Apagar</button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      ) : (
        <div ref={scrollRef} onScroll={() => setScrolled(scrollRef.current?.scrollTop>4)} className="hscroll noscroll"
          style={{transform:drawerOpen?"translateX(272px)":"none",transition:"transform .36s cubic-bezier(.32,1,.56,1)"}}>
          <div className="search-bar">
            <Icon name="search" size={16} style={{color:"#8e8e93",flexShrink:0}}/>
            <input placeholder="Pesquisar documentos…"
              style={{flex:1,border:"none",outline:"none",fontSize:15,color:"#1c1c1e",background:"transparent",fontFamily:"'DM Sans',sans-serif",WebkitUserSelect:"text",userSelect:"text"}}/>
          </div>
          <div className="tags-row">
            <button className="tag-chip" onClick={() => setActiveTag(null)}
              style={{background:!activeTag?"#1c1c1e":"#fff",color:!activeTag?"#fff":"#3a3a3c",borderColor:!activeTag?"#1c1c1e":"rgba(0,0,0,.1)"}}>
              Todos
            </button>
            {TAGS.map(t => (
              <button key={t.id} className="tag-chip" onClick={() => setActiveTag(activeTag===t.id?null:t.id)}
                style={{background:activeTag===t.id?t.color:"#fff",color:activeTag===t.id?"#fff":t.color,borderColor:activeTag===t.id?t.color:t.bg}}>
                {t.label}
              </button>
            ))}
          </div>
          <div className="section-lbl">Recentes</div>
          {visibleDocs.length === 0 ? (
            <div style={{textAlign:"center",padding:"40px 20px",color:"#8e8e93",fontSize:15}}>Nenhum documento</div>
          ) : (
            <div className="card-group">
              {visibleDocs.map((doc, idx) => {
                const isFirst = idx === 0, isLast = idx === visibleDocs.length - 1;
                const tag = TAGS.find(t => t.id === doc.tag);
                const br = isFirst && isLast ? "14px" : isFirst ? "14px 14px 3px 3px" : isLast ? "3px 3px 14px 14px" : "3px";
                return (
                  <div key={doc.id} className="doc-card" onClick={() => onOpenEditor(doc)} style={{borderRadius:br}}>
                    <div style={{display:"flex",alignItems:"flex-start",gap:12}}>
                      <div onClick={e=>{e.stopPropagation();setEmojiPicker({target:"doc",id:doc.id});}}
                        style={{width:42,height:42,borderRadius:11,background:"#f2f2f7",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0,cursor:"pointer"}}>
                        <TwEmoji cp={doc.emoji||"1f4c4"} size={26}/>
                      </div>
                      <div style={{flex:1,minWidth:0}}>
                        <div style={{display:"flex",alignItems:"center",gap:4,marginBottom:3}}>
                          <div style={{fontSize:15,fontWeight:600,color:"#1c1c1e",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",flex:1}}>{doc.title}</div>
                          <button onClick={e=>{e.stopPropagation();onOpenEditor(doc);}}
                            style={{border:"none",background:"transparent",cursor:"pointer",color:"#8e8e93",padding:6,flexShrink:0,borderRadius:8}}
                            onPointerOver={e=>e.currentTarget.style.background="rgba(0,0,0,.05)"} onPointerOut={e=>e.currentTarget.style.background="transparent"}>
                            <Icon name="pencil" size={15}/>
                          </button>
                          <button onClick={e=>{e.stopPropagation();haptic("light");const r=e.currentTarget.getBoundingClientRect();setCtxMenu({docId:doc.id,x:Math.min(r.right-200,window.innerWidth-215),y:r.bottom+6});}}
                            style={{border:"none",background:"transparent",cursor:"pointer",color:"#8e8e93",padding:6,flexShrink:0,borderRadius:8}}
                            onPointerOver={e=>e.currentTarget.style.background="rgba(0,0,0,.05)"} onPointerOut={e=>e.currentTarget.style.background="transparent"}>
                            <Icon name="more-horizontal" size={16}/>
                          </button>
                        </div>
                        <div style={{fontSize:13,color:"#8e8e93",marginBottom:8,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{doc.preview}</div>
                        <div style={{display:"flex",alignItems:"center",gap:8}}>
                          {tag && <span style={{padding:"2px 9px",borderRadius:9999,fontSize:11,fontWeight:600,background:tag.bg,color:tag.color}}>{tag.label}</span>}
                          <span style={{fontSize:11,color:"#c7c7cc"}}>{doc.date}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* CTX MENU */}
      {ctxMenu && (
        <>
          <div style={{position:"fixed",inset:0,zIndex:9998}} onClick={() => setCtxMenu(null)}/>
          <div className="ctx-menu" style={{left:ctxMenu.x,top:ctxMenu.y}}>
            <button className="ctx-item" onClick={() => {onOpenEditor(docs.find(d=>d.id===ctxMenu.docId));setCtxMenu(null);}}>
              <Icon name="pencil" size={15} style={{color:"#8e8e93"}}/> Editar
            </button>
            <div className="ctx-sep"/>
            <button className="ctx-item" onClick={() => {setFolderSheet(ctxMenu.docId);setCtxMenu(null);}}>
              <Icon name="move" size={15} style={{color:"#8e8e93"}}/> Mover para pasta
            </button>
            <div className="ctx-sep"/>
            <button className="ctx-item danger" onClick={() => trashDoc(ctxMenu.docId)}>
              <Icon name="trash-2" size={15} style={{color:"#ff3b30"}}/> Enviar ao lixo
            </button>
          </div>
        </>
      )}

      {/* FOLDER SHEET */}
      {folderSheet && (
        <>
          <div className="sheet-overlay" onClick={() => setFolderSheet(null)}/>
          <div className="sheet">
            <div style={{width:36,height:4,background:"#e5e5ea",borderRadius:2,margin:"0 auto 14px"}}/>
            <div style={{fontSize:16,fontWeight:700,color:"#1c1c1e",padding:"0 20px 12px",borderBottom:"1px solid rgba(0,0,0,.06)"}}>Mover para pasta</div>
            <div style={{flex:1,overflowY:"auto"}} className="noscroll">
              {projects.map(proj => (
                <div key={proj.id}>
                  <div style={{padding:"10px 20px 4px",fontSize:12,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",letterSpacing:".06em",display:"flex",alignItems:"center",gap:8}}>
                    <TwEmoji cp={proj.emoji} size={14}/> {proj.name}
                  </div>
                  {proj.folders.map(f => (
                    <button key={f.id} className="sheet-item" onClick={() => moveToFolder(folderSheet,f.id,proj.id)}>
                      <TwEmoji cp={f.emoji} size={18}/> {f.name}
                      <Icon name="chevron-right" size={14} style={{color:"#c7c7cc",marginLeft:"auto"}}/>
                    </button>
                  ))}
                </div>
              ))}
            </div>
          </div>
        </>
      )}

      {/* FLOATING BAR */}
      <div className="ftb" style={{transform:drawerOpen?"translateX(136px)":"translateX(-50%)",left:drawerOpen?"calc(50%)":"50%",transition:"transform .36s cubic-bezier(.32,1,.56,1)"}}>
        <button className="circ-btn" onClick={() => {}}>
          <Icon name="folder" size={21}/>
        </button>
        <div className="pill-inp" onClick={() => setAiOpen(true)}>
          <Icon name="sparkles" size={19} style={{color:"#007aff",flexShrink:0}}/>
          <span style={{fontSize:14.5,color:"#8e8e93",flex:1}}>Criar com IA…</span>
        </div>
        <button className="circ-btn" onClick={() => onOpenEditor({id:Date.now(),title:"",emoji:"1f4c4",content:""})}>
          <Icon name="plus" size={22}/>
        </button>
      </div>

      {/* AI SHEET */}
      {aiOpen && (
        <>
          <div className="ai-overlay" onClick={() => setAiOpen(false)}/>
          <div className="ai-sheet">
            <div style={{width:36,height:4,background:"#e5e5ea",borderRadius:2,margin:"0 auto 18px"}}/>
            <div style={{display:"flex",alignItems:"center",gap:12,marginBottom:16}}>
              <div style={{width:36,height:36,borderRadius:10,background:"#eff6ff",display:"flex",alignItems:"center",justifyContent:"center"}}>
                <Icon name="sparkles" size={18} style={{color:"#007aff"}}/>
              </div>
              <div style={{flex:1}}>
                <div style={{fontSize:15,fontWeight:700,color:"#1c1c1e"}}>Criar com IA</div>
                <div style={{fontSize:13,color:"#8e8e93"}}>Descreve o documento</div>
              </div>
              <button onClick={() => setAiOpen(false)} style={{border:"none",background:"transparent",cursor:"pointer",color:"#8e8e93",padding:6,borderRadius:9}}>
                <Icon name="x" size={18}/>
              </button>
            </div>
            <textarea ref={aiRef} value={aiInput} onChange={e=>setAiInput(e.target.value)}
              placeholder="Ex: Plano de aula sobre fotossíntese…" rows={4}
              style={{width:"100%",padding:"13px 15px",border:"1.5px solid rgba(0,0,0,.09)",borderRadius:14,fontSize:14.5,fontFamily:"'DM Sans',sans-serif",outline:"none",resize:"none",color:"#1c1c1e",background:"#fafaf9",lineHeight:1.6,WebkitUserSelect:"text",userSelect:"text"}}/>
            <button onClick={doAI} disabled={!aiInput.trim()||aiLoading}
              style={{width:"100%",marginTop:12,padding:"14px 0",background:aiInput.trim()&&!aiLoading?"#007aff":"rgba(0,0,0,.07)",color:aiInput.trim()&&!aiLoading?"#fff":"#8e8e93",border:"none",borderRadius:14,cursor:aiInput.trim()&&!aiLoading?"pointer":"default",fontFamily:"'DM Sans',sans-serif",fontSize:15,fontWeight:600,display:"flex",alignItems:"center",justifyContent:"center",gap:8,transition:"background .2s"}}>
              {aiLoading ? "A criar…" : <><Icon name="send" size={15}/>Criar documento</>}
            </button>
          </div>
        </>
      )}
    </div>
  );
}