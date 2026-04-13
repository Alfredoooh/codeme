import { useState, useEffect, useRef } from "react";

/* ─── ICONS ─────────────────────────────────────────────────────── */
const IC = {
  menu:`<line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/>`,
  "file-text":`<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8M16 13H8M16 17H8"/>`,
  book:`<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>`,
  settings:`<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>`,
  users:`<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`,
  trash:`<polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/>`,
  plus:`<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>`,
  send:`<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>`,
  search:`<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>`,
  bot:`<path d="M12 8V4H8"/><rect x="8" y="8" width="8" height="8" rx="1"/><path d="M19 8h2v8h-2M3 8h2v8H3M9 19v2M15 19v2"/>`,
  "chevron-right":`<polyline points="9 18 15 12 9 6"/>`,
  "chevron-down":`<polyline points="6 9 12 15 18 9"/>`,
  x:`<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>`,
  "more-horizontal":`<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>`,
  folder:`<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>`,
  "folder-plus":`<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/><line x1="12" y1="11" x2="12" y2="17"/><line x1="9" y1="14" x2="15" y2="14"/>`,
  "arrow-up-right":`<line x1="7" y1="17" x2="17" y2="7"/><polyline points="7 7 17 7 17 17"/>`,
  bell:`<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>`,
  palette:`<circle cx="13.5" cy="6.5" r=".5"/><circle cx="17.5" cy="10.5" r=".5"/><circle cx="8.5" cy="7.5" r=".5"/><circle cx="6.5" cy="12.5" r=".5"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"/>`,
  lock:`<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>`,
  "help-circle":`<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/>`,
  restore:`<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>`,
};
const Icon = ({ name, size=20, sw=1.8, color, style }) => (
  <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24"
    fill="none" stroke={color||"currentColor"} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
    style={style} dangerouslySetInnerHTML={{ __html: IC[name]||"" }}/>
);

/* ─── DATA ───────────────────────────────────────────────────────── */
const DOCS_INIT = [
  { id:1, title:"Relatório Trimestral Q1", preview:"Análise de desempenho do primeiro trimestre, incluindo métricas de crescimento e projeções.", date:"Hoje, 14:32", tag:"Trabalho", trashed:false },
  { id:2, title:"Notas de Reunião — Equipa", preview:"Pontos discutidos: roadmap do produto, prioridades para o sprint 12, feedback dos clientes.", date:"Hoje, 09:15", tag:"Reuniões", trashed:false },
  { id:3, title:"Proposta de Projeto Alpha", preview:"Descrição do âmbito, objetivos, cronograma e orçamento estimado para o projeto Alpha.", date:"Ontem, 18:44", tag:"Projetos", trashed:false },
  { id:4, title:"Ideias para Newsletter", preview:"Tópicos possíveis: tendências do setor, entrevista com especialistas, dicas práticas.", date:"Ontem, 11:20", tag:"Marketing", trashed:false },
  { id:5, title:"Manual de Onboarding", preview:"Guia completo para novos colaboradores: política interna, ferramentas e primeiros passos.", date:"2 Jan, 10:00", tag:"RH", trashed:false },
  { id:6, title:"Análise de Concorrentes", preview:"Estudo comparativo de 5 concorrentes diretos, com foco em preços e funcionalidades.", date:"30 Dez, 15:30", tag:"Estratégia", trashed:false },
];

const PROJECTS_INIT = [
  { id:"school", label:"School", children:[
    { id:"school-notes", label:"Apontamentos", children:[] },
    { id:"school-projects", label:"Projetos", children:[] },
  ]},
  { id:"church", label:"Church", children:[
    { id:"church-sermons", label:"Sermões", children:[] },
  ]},
  { id:"business", label:"Business", children:[
    { id:"business-finance", label:"Finanças", children:[
      { id:"business-finance-q1", label:"Q1 2025", children:[] },
    ]},
    { id:"business-ops", label:"Operações", children:[] },
  ]},
];

const TAG_COLORS = { "Trabalho":"#dbeafe","Reuniões":"#f3e8ff","Projetos":"#dcfce7","Marketing":"#fef9c3","RH":"#ffe4e6","Estratégia":"#ffedd5","IA":"#e0f2fe" };
const TAG_TEXT   = { "Trabalho":"#1d4ed8","Reuniões":"#7c3aed","Projetos":"#15803d","Marketing":"#a16207","RH":"#be123c","Estratégia":"#c2410c","IA":"#0369a1" };

const SETTINGS_OPTIONS = [
  { icon:"bell",    label:"Notificações",  sub:"Alertas e preferências" },
  { icon:"palette", label:"Aparência",     sub:"Tema, tamanho de texto" },
  { icon:"lock",    label:"Privacidade",   sub:"Dados e permissões" },
  { icon:"users",   label:"Conta",         sub:"Perfil e subscrição" },
  { icon:"help-circle", label:"Ajuda",     sub:"FAQ e contacto" },
];

/* ─── CSS ────────────────────────────────────────────────────────── */
const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;1,9..40,400&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
html,body,#root{width:100%;height:100%;overflow:hidden;background:#f7f6f3}
.app{width:100%;height:100%;display:flex;flex-direction:column;font-family:'DM Sans',sans-serif;background:#f7f6f3;overflow:hidden;position:relative}

/* TOPBAR */
.topbar{height:54px;flex-shrink:0;display:flex;align-items:center;padding:0 8px;background:#fff;border-bottom:1px solid rgba(0,0,0,.07);position:relative;z-index:10;transition:transform 420ms cubic-bezier(.22,1,.36,1)}

/* SCROLL */
.scroll{flex:1;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;padding:18px 14px 190px;transition:transform 420ms cubic-bezier(.22,1,.36,1)}
.scroll::-webkit-scrollbar{display:none}

/* DRAWER */
.drawer{position:fixed;top:0;left:0;width:268px;height:100%;background:#fff;z-index:30;display:flex;flex-direction:column;transform:translateX(-100%);transition:transform 420ms cubic-bezier(.22,1,.36,1);will-change:transform}
.drawer.open{transform:translateX(0)}
.drawer-mask{position:fixed;inset:0;background:rgba(0,0,0,.22);z-index:15;animation:fadeIn .22s both}
.drawer-header{padding:52px 18px 14px;border-bottom:1px solid rgba(0,0,0,.07)}
.drawer-logo{display:flex;align-items:center;gap:8px}
.drawer-logo-box{width:32px;height:32px;background:#1a1a1a;border-radius:9px;display:flex;align-items:center;justify-content:center}
.drawer-logo-letter{font-size:17px;font-weight:700;color:#fff;font-family:'DM Sans',sans-serif;line-height:1}
.drawer-logo-title{font-size:16px;font-weight:700;color:#1a1a1a;letter-spacing:-.01em}
.drawer-body{flex:1;overflow-y:auto;padding:10px 10px 20px}
.drawer-body::-webkit-scrollbar{display:none}
.drawer-item{display:flex;align-items:center;gap:11px;padding:9px 12px;font-size:14px;font-weight:500;color:#34322d;cursor:pointer;border:none;background:transparent;width:100%;text-align:left;font-family:inherit;border-radius:10px;transition:background .13s,color .13s;margin:1px 0}
.drawer-item:active{background:rgba(0,0,0,.05)}
.drawer-item.active{background:#f0efec;color:#1a1a1a}
.drawer-item.danger{color:#e03e3e}
.drawer-item.danger:active{background:#fff1f1}
.drawer-sub-item{display:flex;align-items:center;gap:11px;padding:8px 12px 8px 38px;font-size:13px;font-weight:500;color:#5e5e5b;cursor:pointer;border:none;background:transparent;width:100%;text-align:left;font-family:inherit;border-radius:9px;transition:background .13s;margin:.5px 0}
.drawer-sub-item:active{background:rgba(0,0,0,.04)}
.settings-row{display:flex;align-items:center;padding:10px 12px;border-radius:11px;cursor:pointer;transition:background .13s;gap:11px}
.settings-row:active{background:rgba(0,0,0,.04)}
.settings-sub{font-size:12px;color:#aaa;margin-top:1px}
.proj-tree{padding-left:14px;border-left:1.5px solid rgba(0,0,0,.08);margin-left:14px}
.section-divider{font-size:10.5px;font-weight:700;color:#b0aea8;text-transform:uppercase;letter-spacing:.08em;padding:14px 12px 6px;margin-top:4px}

/* CARDS */
.doc-card{background:#fff;border-radius:14px;padding:13px 15px;margin-bottom:9px;cursor:pointer;transition:transform .14s,box-shadow .14s;box-shadow:0 1px 4px rgba(0,0,0,.06),0 2px 10px rgba(0,0,0,.04)}
.doc-card:active{transform:scale(.982);box-shadow:0 1px 2px rgba(0,0,0,.04)}
.doc-icon-wrap{width:36px;height:36px;background:#f5f5f3;border-radius:9px;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin-top:1px}
.tag{display:inline-flex;align-items:center;padding:2px 9px;border-radius:9999px;font-size:11px;font-weight:600}

/* SEARCH */
.search-bar{display:flex;align-items:center;gap:9px;background:#fff;border-radius:13px;box-shadow:0 1px 4px rgba(0,0,0,.06);padding:10px 14px;margin-bottom:18px}

/* SECTION LABEL */
.section-label{font-size:11px;font-weight:700;color:#b0aea8;text-transform:uppercase;letter-spacing:.07em;margin-bottom:10px;margin-top:2px}

/* FLOATING BOTTOM BAR */
.ftb{position:fixed;bottom:max(20px,env(safe-area-inset-bottom,20px));left:50%;transform:translateX(-50%);width:min(92vw,440px);z-index:20;display:flex;align-items:center;gap:10px;transition:left 420ms cubic-bezier(.22,1,.36,1),transform 420ms cubic-bezier(.22,1,.36,1)}
.pill-btn{flex:1;height:54px;background:rgba(255,255,255,.97);border:1px solid rgba(0,0,0,.08);border-radius:9999px;box-shadow:0 4px 22px rgba(0,0,0,.10),0 1px 4px rgba(0,0,0,.06);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);display:flex;align-items:center;padding:0 18px;gap:10px;cursor:pointer;border:none}
.circ-btn{width:54px;height:54px;border-radius:50%;border:1px solid rgba(0,0,0,.09);background:rgba(255,255,255,.97);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);box-shadow:0 4px 22px rgba(0,0,0,.10);cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;color:#5e5e5b;transition:transform .13s,box-shadow .13s}
.circ-btn:active{transform:scale(.91);box-shadow:0 2px 8px rgba(0,0,0,.08)}

/* AI SHEET */
.ai-overlay{position:fixed;inset:0;z-index:60;background:rgba(0,0,0,.32);backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px);animation:fadeIn .2s both}
.ai-sheet{position:fixed;bottom:0;left:0;right:0;background:#fff;border-radius:22px 22px 0 0;padding:20px 18px max(30px,env(safe-area-inset-bottom,30px));animation:slideUp .3s cubic-bezier(.22,1,.36,1) both;z-index:61}

/* TRASH BADGE */
.trash-badge{min-width:18px;height:18px;background:#e03e3e;border-radius:9px;font-size:10px;font-weight:700;color:#fff;display:flex;align-items:center;justify-content:center;padding:0 5px;margin-left:auto}

/* MODALS */
.modal-overlay{position:fixed;inset:0;z-index:70;background:rgba(0,0,0,.28);backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px);animation:fadeIn .18s both;display:flex;align-items:flex-end}
.modal-sheet{background:#fff;border-radius:22px 22px 0 0;padding:22px 18px max(32px,env(safe-area-inset-bottom,32px));width:100%;animation:slideUp .28s cubic-bezier(.22,1,.36,1) both}
.modal-title{font-size:16px;font-weight:700;color:#1a1a1a;margin-bottom:4px}
.modal-sub{font-size:13px;color:#858481;margin-bottom:16px}
.input-field{width:100%;padding:12px 14px;border:1.5px solid rgba(0,0,0,.09);border-radius:12px;font-size:14px;font-family:'DM Sans',sans-serif;outline:none;color:#34322d;background:#fafaf9;transition:border-color .15s}
.input-field:focus{border-color:#2563eb}
.btn-primary{width:100%;padding:13px;background:#1a1a1a;color:#fff;border:none;border-radius:13px;font-size:14.5px;font-weight:600;font-family:inherit;cursor:pointer;transition:background .15s,transform .1s}
.btn-primary:active{transform:scale(.98);background:#333}
.btn-ghost{width:100%;padding:11px;background:transparent;color:#858481;border:none;border-radius:13px;font-size:14px;font-weight:500;font-family:inherit;cursor:pointer;margin-top:6px}
.btn-danger{background:#fff1f1;color:#e03e3e;border:none;border-radius:10px;padding:9px 14px;font-size:13px;font-weight:600;font-family:inherit;cursor:pointer;display:flex;align-items:center;gap:7px;transition:background .13s}
.btn-danger:active{background:#ffe0e0}

@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes slideUp{from{transform:translateY(70px);opacity:0}to{transform:translateY(0);opacity:1}}
@keyframes pop{0%{transform:scale(.94);opacity:0}100%{transform:scale(1);opacity:1}}
`;

/* ─── HELPERS ────────────────────────────────────────────────────── */
function useSpring(open) {
  const [rendered, setRendered] = useState(open);
  useEffect(() => { if (open) setRendered(true); }, [open]);
  const onEnd = () => { if (!open) setRendered(false); };
  return [rendered, onEnd];
}

/* ─── PROJECT TREE NODE ──────────────────────────────────────────── */
function TreeNode({ node, depth=0, onAddChild }) {
  const [open, setOpen] = useState(depth === 0);
  const hasKids = node.children && node.children.length > 0;
  return (
    <div>
      <div style={{display:"flex",alignItems:"center",gap:6,padding:`7px ${depth===0?12:10}px`,borderRadius:9,cursor:"pointer",userSelect:"none",transition:"background .12s"}}
        onClick={()=>setOpen(v=>!v)}>
        <div style={{display:"flex",alignItems:"center",gap:7,flex:1}}>
          <Icon name="folder" size={15} color={depth===0?"#2563eb":"#9ca3af"} sw={1.8}/>
          <span style={{fontSize:13,fontWeight:depth===0?600:500,color:depth===0?"#1a1a1a":"#5e5e5b"}}>{node.label}</span>
        </div>
        <div style={{display:"flex",alignItems:"center",gap:2}}>
          <button onClick={e=>{e.stopPropagation();onAddChild(node.id)}}
            style={{border:"none",background:"transparent",cursor:"pointer",padding:"2px 3px",borderRadius:6,color:"#b0aea8",display:"flex",alignItems:"center"}}>
            <Icon name="plus" size={13} sw={2.2}/>
          </button>
          {hasKids && (
            <div style={{transition:"transform .2s",transform:open?"rotate(90deg)":"rotate(0deg)",display:"flex",alignItems:"center"}}>
              <Icon name="chevron-right" size={13} color="#b0aea8" sw={2}/>
            </div>
          )}
        </div>
      </div>
      {hasKids && open && (
        <div style={{paddingLeft:14,borderLeft:"1.5px solid rgba(0,0,0,.07)",marginLeft:19,overflow:"hidden"}}>
          {node.children.map(child=>(
            <TreeNode key={child.id} node={child} depth={depth+1} onAddChild={onAddChild}/>
          ))}
        </div>
      )}
    </div>
  );
}

/* ─── MAIN APP ───────────────────────────────────────────────────── */
export default function App() {
  const [docs, setDocs]           = useState(DOCS_INIT);
  const [projects, setProjects]   = useState(PROJECTS_INIT);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [view, setView]           = useState("home"); // home | trash | settings
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [projOpen, setProjOpen]   = useState(true);

  const [aiOpen, setAiOpen]       = useState(false);
  const [aiInput, setAiInput]     = useState("");
  const [aiLoading, setAiLoading] = useState(false);

  const [newFolderModal, setNewFolderModal] = useState(null); // parentId or "root"
  const [folderName, setFolderName]         = useState("");

  const [ctxDoc, setCtxDoc]       = useState(null); // doc context menu

  const aiRef    = useRef(null);
  const folderRef= useRef(null);

  useEffect(()=>{
    const s=document.createElement("style");
    s.textContent=CSS;
    document.head.appendChild(s);
    return()=>document.head.removeChild(s);
  },[]);

  useEffect(()=>{ if(aiOpen) setTimeout(()=>aiRef.current?.focus(),80); },[aiOpen]);
  useEffect(()=>{ if(newFolderModal!==null) setTimeout(()=>folderRef.current?.focus(),80); },[newFolderModal]);

  const trashed = docs.filter(d=>d.trashed);
  const active  = docs.filter(d=>!d.trashed);

  /* Add folder to tree */
  const addFolder = (parentId, name) => {
    const id = `folder-${Date.now()}`;
    const newNode = { id, label:name, children:[] };
    const insert = (nodes) => nodes.map(n=>{
      if(n.id===parentId) return {...n, children:[...n.children, newNode]};
      return {...n, children:insert(n.children)};
    });
    if(parentId==="root") setProjects(p=>[...p, newNode]);
    else setProjects(p=>insert(p));
  };

  /* AI create */
  const doAI = async () => {
    const p = aiInput.trim(); if(!p) return;
    setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages",{
        method:"POST",headers:{"Content-Type":"application/json"},
        body:JSON.stringify({ model:"claude-sonnet-4-20250514", max_tokens:800,
          system:"Cria um documento curto em português com base no pedido. Responde APENAS com o conteúdo do documento, sem explicações.",
          messages:[{role:"user",content:p}] })
      });
      const d = await r.json();
      const content = d.content?.map(i=>i.text||"").join("")||"";
      const newDoc = { id:Date.now(), title:p.slice(0,40), preview:content.slice(0,110)+"…", date:"Agora", tag:"IA", trashed:false };
      setDocs(prev=>[newDoc,...prev]);
      setAiInput(""); setAiOpen(false);
    } catch(_){}
    setAiLoading(false);
  };

  /* Trash / restore */
  const trashDoc   = id => setDocs(p=>p.map(d=>d.id===id?{...d,trashed:true}:d));
  const restoreDoc = id => setDocs(p=>p.map(d=>d.id===id?{...d,trashed:false}:d));
  const deleteDoc  = id => setDocs(p=>p.filter(d=>d.id!==id));

  const shiftX = drawerOpen ? "translateX(110px)" : "none";
  const trans  = "transform 420ms cubic-bezier(.22,1,.36,1)";

  /* ── DRAWER ── */
  const Drawer = () => (
    <>
      <div className={`drawer${drawerOpen?" open":""}`}>
        {/* Logo */}
        <div className="drawer-header">
          <div className="drawer-logo">
            <div className="drawer-logo-box">
              <span className="drawer-logo-letter">D</span>
            </div>
            <span className="drawer-logo-title">Menu</span>
          </div>
        </div>

        <div className="drawer-body">
          {/* Main nav */}
          <div className="section-divider">Principal</div>
          <button className={`drawer-item${view==="home"?" active":""}`} onClick={()=>{setView("home");setDrawerOpen(false)}}>
            <Icon name="book" size={17} color={view==="home"?"#2563eb":"#5e5e5b"}/>
            Biblioteca
          </button>

          {/* Settings — expandable */}
          <button className={`drawer-item${settingsOpen?" active":""}`}
            onClick={()=>setSettingsOpen(v=>!v)}>
            <Icon name="settings" size={17} color={settingsOpen?"#2563eb":"#5e5e5b"}/>
            <span style={{flex:1,textAlign:"left"}}>Configurações</span>
            <div style={{transition:"transform .22s",transform:settingsOpen?"rotate(90deg)":"rotate(0)"}}>
              <Icon name="chevron-right" size={14} color="#b0aea8"/>
            </div>
          </button>
          {settingsOpen && (
            <div style={{overflow:"hidden",animation:"pop .2s both"}}>
              {SETTINGS_OPTIONS.map(opt=>(
                <div key={opt.label} className="settings-row" style={{paddingLeft:38}}>
                  <div style={{width:32,height:32,borderRadius:9,background:"#f5f5f3",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>
                    <Icon name={opt.icon} size={15} color="#5e5e5b"/>
                  </div>
                  <div>
                    <div style={{fontSize:13.5,fontWeight:500,color:"#1a1a1a"}}>{opt.label}</div>
                    <div className="settings-sub">{opt.sub}</div>
                  </div>
                </div>
              ))}
            </div>
          )}

          <button className="drawer-item" onClick={()=>{setView("home");setDrawerOpen(false)}}>
            <Icon name="users" size={17} color="#5e5e5b"/>
            Membros
          </button>

          {/* Trash */}
          <button className={`drawer-item danger`} onClick={()=>{setView("trash");setDrawerOpen(false)}}>
            <Icon name="trash" size={17} color="#e03e3e"/>
            <span style={{flex:1,textAlign:"left"}}>Lixo</span>
            {trashed.length>0 && <span className="trash-badge">{trashed.length}</span>}
            <Icon name="chevron-right" size={14} color="#e8a0a0"/>
          </button>

          {/* Projects */}
          <div className="section-divider" style={{display:"flex",alignItems:"center"}}>
            <span style={{flex:1}}>Projects</span>
            <div style={{display:"flex",gap:6,alignItems:"center"}}>
              <button onClick={()=>setNewFolderModal("root")}
                style={{border:"none",background:"transparent",cursor:"pointer",padding:"2px 4px",color:"#b0aea8",display:"flex"}}>
                <Icon name="folder-plus" size={14} sw={2}/>
              </button>
              <button onClick={()=>setProjOpen(v=>!v)}
                style={{border:"none",background:"transparent",cursor:"pointer",padding:"2px 4px",color:"#b0aea8",display:"flex"}}>
                <div style={{transition:"transform .2s",transform:projOpen?"rotate(0)":"rotate(-90deg)"}}>
                  <Icon name="chevron-down" size={14} sw={2}/>
                </div>
              </button>
              <button style={{border:"none",background:"transparent",cursor:"pointer",padding:"2px 4px",color:"#b0aea8",display:"flex"}}>
                <Icon name="arrow-up-right" size={14} sw={2}/>
              </button>
            </div>
          </div>

          {projOpen && projects.map(node=>(
            <TreeNode key={node.id} node={node} depth={0} onAddChild={id=>setNewFolderModal(id)}/>
          ))}
        </div>
      </div>
      {drawerOpen && <div className="drawer-mask" onClick={()=>setDrawerOpen(false)}/>}
    </>
  );

  /* ── TRASH VIEW ── */
  const TrashView = () => (
    <div className="scroll noscroll" style={{transform:shiftX,transition:trans}}>
      <div style={{display:"flex",alignItems:"center",gap:10,marginBottom:20}}>
        <div style={{flex:1}}>
          <div className="section-label" style={{marginBottom:2}}>Lixo</div>
          <div style={{fontSize:12,color:"#b0aea8"}}>{trashed.length} {trashed.length===1?"documento":"documentos"}</div>
        </div>
        {trashed.length>0 &&
          <button className="btn-danger" onClick={()=>trashed.forEach(d=>deleteDoc(d.id))}>
            <Icon name="trash" size={13}/> Esvaziar
          </button>}
      </div>
      {trashed.length===0 ? (
        <div style={{textAlign:"center",padding:"60px 0",color:"#b0aea8"}}>
          <Icon name="trash" size={44} color="#ddd" sw={1.2}/>
          <div style={{marginTop:12,fontSize:14,fontWeight:500}}>Lixo vazio</div>
        </div>
      ) : trashed.map(doc=>(
        <div key={doc.id} className="doc-card" style={{opacity:.75}}>
          <div style={{display:"flex",alignItems:"flex-start",gap:11}}>
            <div className="doc-icon-wrap">
              <Icon name="file-text" size={16} color="#b0aea8"/>
            </div>
            <div style={{flex:1,minWidth:0}}>
              <div style={{fontSize:14,fontWeight:600,color:"#5e5e5b",marginBottom:2,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{doc.title}</div>
              <div style={{fontSize:12.5,color:"#b0aea8",marginBottom:8,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{doc.preview}</div>
              <div style={{display:"flex",gap:8}}>
                <button className="btn-danger" style={{padding:"6px 12px",fontSize:12}}
                  onClick={()=>deleteDoc(doc.id)}>
                  <Icon name="trash" size={12}/>Eliminar
                </button>
                <button onClick={()=>restoreDoc(doc.id)}
                  style={{border:"none",background:"#f0faf0",color:"#16a34a",borderRadius:9,padding:"6px 12px",fontSize:12,fontWeight:600,fontFamily:"inherit",cursor:"pointer",display:"flex",alignItems:"center",gap:6}}>
                  <Icon name="restore" size={12} color="#16a34a"/>Restaurar
                </button>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );

  /* ── HOME VIEW ── */
  const HomeView = () => (
    <div className="scroll noscroll" style={{transform:shiftX,transition:trans}}>
      <div className="search-bar">
        <Icon name="search" size={15} color="#b0aea8"/>
        <input placeholder="Pesquisar documentos…"
          style={{flex:1,border:"none",outline:"none",fontSize:14,color:"#34322d",background:"transparent",fontFamily:"inherit",WebkitUserSelect:"text",userSelect:"text"}}/>
      </div>
      <div className="section-label">Recentes</div>
      {active.map(doc=>(
        <div key={doc.id} className="doc-card">
          <div style={{display:"flex",alignItems:"flex-start",gap:11}}>
            <div className="doc-icon-wrap">
              <Icon name="file-text" size={16} color="#5e5e5b"/>
            </div>
            <div style={{flex:1,minWidth:0}}>
              <div style={{display:"flex",alignItems:"center",gap:7,marginBottom:3}}>
                <div style={{fontSize:14,fontWeight:600,color:"#1a1a1a",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",flex:1}}>{doc.title}</div>
                <button onClick={e=>{e.stopPropagation();setCtxDoc(doc)}}
                  style={{border:"none",background:"transparent",cursor:"pointer",padding:2,color:"#d1d5db",flexShrink:0,display:"flex"}}>
                  <Icon name="more-horizontal" size={16}/>
                </button>
              </div>
              <div style={{fontSize:12.5,color:"#858481",marginBottom:8,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{doc.preview}</div>
              <div style={{display:"flex",alignItems:"center",gap:8}}>
                <span className="tag" style={{background:TAG_COLORS[doc.tag]||"#f3f4f6",color:TAG_TEXT[doc.tag]||"#374151"}}>{doc.tag}</span>
                <span style={{fontSize:11,color:"#c4c4c0"}}>{doc.date}</span>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );

  return (
    <div className="app">
      <style>{CSS}</style>
      <Drawer/>

      {/* TOPBAR */}
      <div className="topbar" style={{transform:shiftX,transition:trans}}>
        <button onClick={()=>setDrawerOpen(v=>!v)}
          style={{width:44,height:44,border:"none",background:"transparent",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",borderRadius:11,color:"#5e5e5b"}}>
          <Icon name="menu" size={20}/>
        </button>
        <div style={{position:"absolute",left:"50%",transform:"translateX(-50%)",fontSize:15,fontWeight:700,color:"#1a1a1a",letterSpacing:"-.01em"}}>
          {view==="home"?"Documentos":"Lixo"}
        </div>
      </div>

      {/* VIEWS */}
      {view==="home" ? <HomeView/> : <TrashView/>}

      {/* FLOATING BOTTOM BAR */}
      {view==="home" && (
        <div className="ftb" style={{
          transform: drawerOpen ? "translateX(calc(-50% + 55px))" : "translateX(-50%)",
        }}>
          <button className="circ-btn" onClick={()=>setNewFolderModal("root")}>
            <Icon name="folder" size={20}/>
          </button>
          <button className="pill-btn" onClick={()=>setAiOpen(true)}>
            <Icon name="bot" size={18} color="#2563eb"/>
            <span style={{fontSize:14,color:"#858481",flex:1,textAlign:"left"}}>Criar com IA…</span>
          </button>
          <button className="circ-btn"
            onClick={()=>setDocs(p=>[{id:Date.now(),title:"Novo documento",preview:"Documento em branco.",date:"Agora",tag:"Trabalho",trashed:false},...p])}>
            <Icon name="plus" size={22}/>
          </button>
        </div>
      )}

      {/* AI SHEET */}
      {aiOpen && (
        <>
          <div className="ai-overlay" onClick={()=>setAiOpen(false)}/>
          <div className="ai-sheet">
            <div style={{display:"flex",alignItems:"center",gap:10,marginBottom:14}}>
              <div style={{width:36,height:36,borderRadius:10,background:"#eff6ff",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>
                <Icon name="bot" size={17} color="#2563eb"/>
              </div>
              <div style={{flex:1}}>
                <div style={{fontSize:14.5,fontWeight:700,color:"#1a1a1a"}}>Criar com IA</div>
                <div style={{fontSize:12,color:"#858481"}}>Descreve o que queres criar</div>
              </div>
              <button onClick={()=>setAiOpen(false)}
                style={{border:"none",background:"transparent",cursor:"pointer",padding:4,color:"#b0aea8",display:"flex"}}>
                <Icon name="x" size={18}/>
              </button>
            </div>
            <textarea ref={aiRef} value={aiInput} onChange={e=>setAiInput(e.target.value)}
              placeholder="Ex: Relatório mensal de vendas com análise de resultados…"
              rows={4}
              style={{width:"100%",padding:"12px 14px",border:"1.5px solid rgba(0,0,0,.09)",borderRadius:12,fontSize:14,fontFamily:"'DM Sans',sans-serif",outline:"none",resize:"none",color:"#34322d",background:"#fafaf9",lineHeight:1.6,WebkitUserSelect:"text",userSelect:"text"}}/>
            <button onClick={doAI} disabled={!aiInput.trim()||aiLoading}
              style={{width:"100%",marginTop:10,padding:"13px 0",background:aiInput.trim()&&!aiLoading?"#1a1a1a":"rgba(0,0,0,.07)",color:aiInput.trim()&&!aiLoading?"#fff":"#b0aea8",border:"none",borderRadius:13,cursor:aiInput.trim()&&!aiLoading?"pointer":"default",fontFamily:"inherit",fontSize:14.5,fontWeight:600,display:"flex",alignItems:"center",justifyContent:"center",gap:8,transition:"background .15s"}}>
              {aiLoading?"A criar documento…":<><Icon name="send" size={15} color="currentColor"/>Criar documento</>}
            </button>
          </div>
        </>
      )}

      {/* NEW FOLDER MODAL */}
      {newFolderModal!==null && (
        <div className="modal-overlay" onClick={()=>setNewFolderModal(null)}>
          <div className="modal-sheet" onClick={e=>e.stopPropagation()}>
            <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:14}}>
              <div>
                <div className="modal-title">Nova pasta</div>
                <div className="modal-sub">Criar {newFolderModal==="root"?"pasta raiz":"subpasta"}</div>
              </div>
              <button onClick={()=>setNewFolderModal(null)}
                style={{border:"none",background:"transparent",cursor:"pointer",color:"#b0aea8",padding:4,display:"flex"}}>
                <Icon name="x" size={20}/>
              </button>
            </div>
            <input ref={folderRef} className="input-field" placeholder="Nome da pasta…"
              value={folderName} onChange={e=>setFolderName(e.target.value)}
              onKeyDown={e=>{ if(e.key==="Enter"&&folderName.trim()){ addFolder(newFolderModal,folderName.trim()); setFolderName(""); setNewFolderModal(null); }}}/>
            <button className="btn-primary" style={{marginTop:12}}
              onClick={()=>{ if(folderName.trim()){ addFolder(newFolderModal,folderName.trim()); setFolderName(""); setNewFolderModal(null); }}}>
              Criar pasta
            </button>
            <button className="btn-ghost" onClick={()=>setNewFolderModal(null)}>Cancelar</button>
          </div>
        </div>
      )}

      {/* DOC CONTEXT MENU */}
      {ctxDoc && (
        <div className="modal-overlay" onClick={()=>setCtxDoc(null)}>
          <div className="modal-sheet" onClick={e=>e.stopPropagation()} style={{padding:"18px 18px max(28px,env(safe-area-inset-bottom,28px))"}}>
            <div style={{display:"flex",alignItems:"center",gap:10,marginBottom:16,paddingBottom:14,borderBottom:"1px solid rgba(0,0,0,.07)"}}>
              <div className="doc-icon-wrap">
                <Icon name="file-text" size={16} color="#5e5e5b"/>
              </div>
              <div style={{flex:1,minWidth:0}}>
                <div style={{fontSize:14,fontWeight:600,color:"#1a1a1a",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{ctxDoc.title}</div>
                <div style={{fontSize:12,color:"#b0aea8"}}>{ctxDoc.date}</div>
              </div>
            </div>
            {[
              {icon:"folder-plus",label:"Mover para pasta",action:()=>setCtxDoc(null)},
              {icon:"restore",label:"Duplicar",action:()=>{ setDocs(p=>[{...ctxDoc,id:Date.now(),title:ctxDoc.title+" (cópia)",date:"Agora"},...p]); setCtxDoc(null); }},
            ].map(opt=>(
              <button key={opt.label} className="drawer-item" style={{borderRadius:10,marginBottom:2}} onClick={opt.action}>
                <Icon name={opt.icon} size={16} color="#5e5e5b"/>
                {opt.label}
              </button>
            ))}
            <button className="drawer-item danger" style={{borderRadius:10,marginTop:4}}
              onClick={()=>{ trashDoc(ctxDoc.id); setCtxDoc(null); }}>
              <Icon name="trash" size={16} color="#e03e3e"/>
              Mover para o lixo
            </button>
          </div>
        </div>
      )}
    </div>
  );
}