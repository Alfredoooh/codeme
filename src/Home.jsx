import { useState, useEffect, useRef } from "react";

const IC = {
  menu:`<line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/>`,
  "file-text":`<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8M16 13H8M16 17H8"/>`,
  book:`<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>`,
  settings:`<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>`,
  users:`<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`,
  plus:`<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>`,
  send:`<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>`,
  search:`<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>`,
  bot:`<path d="M12 8V4H8"/><rect x="8" y="8" width="8" height="8" rx="1"/><path d="M19 8h2v8h-2M3 8h2v8H3M9 19v2M15 19v2"/>`,
  "chevron-right":`<polyline points="9 18 15 12 9 6"/>`,
  x:`<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>`,
  "more-horizontal":`<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>`,
  clock:`<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>`,
  folder:`<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>`,
};
const Icon = ({ name, size=20, sw=2, style }) => (
  <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
    style={style} dangerouslySetInnerHTML={{ __html: IC[name]||"" }}/>
);

const DOCS = [
  { id:1, title:"Relatório Trimestral Q1", preview:"Análise de desempenho do primeiro trimestre, incluindo métricas de crescimento e projeções para o segundo trimestre.", date:"Hoje, 14:32", tag:"Trabalho" },
  { id:2, title:"Notas de Reunião — Equipa", preview:"Pontos discutidos: roadmap do produto, prioridades para o sprint 12, feedback dos clientes.", date:"Hoje, 09:15", tag:"Reuniões" },
  { id:3, title:"Proposta de Projeto Alpha", preview:"Descrição do âmbito, objetivos, cronograma e orçamento estimado para o projeto Alpha.", date:"Ontem, 18:44", tag:"Projetos" },
  { id:4, title:"Ideias para Newsletter", preview:"Tópicos possíveis: tendências do setor, entrevista com especialistas, dicas práticas para a equipa.", date:"Ontem, 11:20", tag:"Marketing" },
  { id:5, title:"Manual de Onboarding", preview:"Guia completo para novos colaboradores: política interna, ferramentas, contactos e primeiros passos.", date:"2 Jan, 10:00", tag:"RH" },
  { id:6, title:"Análise de Concorrentes", preview:"Estudo comparativo de 5 concorrentes diretos, com foco em preços, funcionalidades e posicionamento.", date:"30 Dez, 15:30", tag:"Estratégia" },
];

const TAG_COLORS = { "Trabalho":"#dbeafe","Reuniões":"#f3e8ff","Projetos":"#dcfce7","Marketing":"#fef9c3","RH":"#ffe4e6","Estratégia":"#ffedd5","IA":"#e0f2fe" };
const TAG_TEXT   = { "Trabalho":"#1d4ed8","Reuniões":"#7c3aed","Projetos":"#15803d","Marketing":"#a16207","RH":"#be123c","Estratégia":"#c2410c","IA":"#0369a1" };

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
html,body,#root{width:100%;height:100%;overflow:hidden;background:#f8f8f7}
.home{width:100%;height:100%;display:flex;flex-direction:column;font-family:'DM Sans',sans-serif;background:#f8f8f7;-webkit-user-select:none;user-select:none;overflow:hidden}
.topbar{height:52px;flex-shrink:0;display:flex;align-items:center;padding:0 6px;background:#fff;border-bottom:1px solid rgba(0,0,0,.08);position:relative;z-index:10}
.scroll{flex:1;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;padding:20px 16px 200px}
.scroll::-webkit-scrollbar{display:none}
/* Drawer — same as editor */
.drawer{position:fixed;top:0;left:0;width:260px;height:100%;background:#fff;z-index:30;box-shadow:2px 0 20px rgba(0,0,0,.10);display:flex;flex-direction:column;transform:translateX(-100%);transition:transform 400ms cubic-bezier(.22,1,.36,1)}
.drawer.open{transform:translateX(0)}
.drawer-mask{position:fixed;inset:0;background:rgba(0,0,0,.18);z-index:15;animation:fadeIn .2s both}
.drawer-item{display:flex;align-items:center;gap:12px;padding:11px 14px;font-size:14px;font-weight:500;color:#34322d;cursor:pointer;border:none;background:transparent;width:100%;text-align:left;font-family:inherit;border-radius:10px;transition:background .12s;margin:1px 0}
.drawer-item:active{background:rgba(0,0,0,.04)}
/* Cards */
.doc-card{background:#fff;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,.06),0 2px 8px rgba(0,0,0,.04);padding:14px 16px;margin-bottom:10px;cursor:pointer;transition:transform .1s,box-shadow .1s;-webkit-user-select:none;user-select:none}
.doc-card:active{transform:scale(.985);box-shadow:0 1px 2px rgba(0,0,0,.04)}
/* Floating bottom bar */
.ftb{position:fixed;left:50%;transform:translateX(-50%);bottom:max(20px,env(safe-area-inset-bottom,20px));width:min(92vw,440px);z-index:20;display:flex;align-items:center;gap:10px}
.pill-input{flex:1;height:54px;background:rgba(255,255,255,.97);border:1px solid rgba(0,0,0,.08);border-radius:9999px;box-shadow:0 4px 20px rgba(0,0,0,.10),0 1px 4px rgba(0,0,0,.05);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);display:flex;align-items:center;padding:0 16px;gap:10px;cursor:text}
.circ-btn{width:54px;height:54px;border-radius:50%;border:1px solid rgba(0,0,0,.08);background:rgba(255,255,255,.97);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);box-shadow:0 4px 20px rgba(0,0,0,.10);cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;color:#5e5e5b;transition:transform .12s}
.circ-btn:active{transform:scale(.92)}
/* AI sheet */
.ai-overlay{position:fixed;inset:0;z-index:60;background:rgba(0,0,0,.35);backdrop-filter:blur(3px);animation:fadeIn .2s both}
.ai-sheet{position:fixed;bottom:0;left:0;right:0;background:#fff;border-radius:20px 20px 0 0;padding:20px 18px max(28px,env(safe-area-inset-bottom,28px));animation:slideUp .28s cubic-bezier(.22,1,.36,1) both;z-index:61}
.section-label{font-size:11px;font-weight:700;color:#858481;text-transform:uppercase;letter-spacing:.07em;margin-bottom:10px;margin-top:2px}
.tag{display:inline-flex;align-items:center;padding:2px 9px;border-radius:9999px;font-size:11px;font-weight:600}
.noscroll{scrollbar-width:none}
.noscroll::-webkit-scrollbar{display:none}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes slideUp{from{transform:translateY(60px);opacity:0}to{transform:translateY(0);opacity:1}}
`;

export default function Home({ onOpenEditor }) {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [aiOpen, setAiOpen]         = useState(false);
  const [aiInput, setAiInput]       = useState("");
  const [aiLoading, setAiLoading]   = useState(false);
  const [docs, setDocs]             = useState(DOCS);
  const aiRef = useRef(null);

  useEffect(() => {
    const s = document.createElement("style");
    s.textContent = CSS;
    document.head.appendChild(s);
    return () => document.head.removeChild(s);
  }, []);

  useEffect(() => { if (aiOpen) setTimeout(() => aiRef.current?.focus(), 80); }, [aiOpen]);

  const doAI = async () => {
    const p = aiInput.trim(); if (!p) return;
    setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method:"POST", headers:{"Content-Type":"application/json"},
        body: JSON.stringify({ model:"claude-sonnet-4-20250514", max_tokens:800,
          system:"Cria um documento curto em português com base no pedido. Responde APENAS com o conteúdo do documento, sem explicações.",
          messages:[{ role:"user", content:p }] })
      });
      const d = await r.json();
      const content = d.content?.map(i=>i.text||"").join("") || "";
      const newDoc = { id:Date.now(), title:p.slice(0,40), preview:content.slice(0,110)+"…", date:"Agora", tag:"IA", aiContent:content };
      setDocs(prev => [newDoc, ...prev]);
      setAiInput(""); setAiOpen(false);
      onOpenEditor?.(newDoc);
    } catch(_) {}
    setAiLoading(false);
  };

  return (
    <div className="home">
      {/* DRAWER */}
      <div className={`drawer${drawerOpen?" open":""}`}>
        <div style={{padding:"52px 20px 14px",borderBottom:"1px solid rgba(0,0,0,.08)"}}>
          <div style={{fontSize:13,fontWeight:700,color:"#858481",textTransform:"uppercase",letterSpacing:".06em"}}>Menu</div>
        </div>
        <div style={{flex:1,overflowY:"auto",padding:10}}>
          {[
            {icon:"book",   label:"Biblioteca"},
            {icon:"settings",label:"Definições"},
            {icon:"users",  label:"Membros"},
          ].map(item=>(
            <button key={item.label} className="drawer-item" onClick={()=>setDrawerOpen(false)}>
              <Icon name={item.icon} size={18} style={{color:"#5e5e5b",flexShrink:0}}/>
              {item.label}
            </button>
          ))}
        </div>
      </div>
      {drawerOpen && <div className="drawer-mask" onClick={()=>setDrawerOpen(false)}/>}

      {/* TOPBAR */}
      <div className="topbar" style={{transform:drawerOpen?"translateX(110px)":"none",transition:"transform 400ms cubic-bezier(.22,1,.36,1)"}}>
        <button onClick={()=>setDrawerOpen(v=>!v)}
          style={{width:44,height:44,border:"none",background:"transparent",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",borderRadius:10,color:"#5e5e5b"}}>
          <Icon name="menu" size={20}/>
        </button>
        <div style={{position:"absolute",left:"50%",transform:"translateX(-50%)",fontSize:15,fontWeight:600,color:"#34322d"}}>
          Documentos
        </div>
      </div>

      {/* CONTENT */}
      <div className="scroll noscroll" style={{transform:drawerOpen?"translateX(110px)":"none",transition:"transform 400ms cubic-bezier(.22,1,.36,1)"}}>

        {/* Search bar */}
        <div style={{display:"flex",alignItems:"center",gap:10,background:"#fff",borderRadius:12,boxShadow:"0 1px 3px rgba(0,0,0,.06)",padding:"10px 14px",marginBottom:20}}>
          <Icon name="search" size={16} style={{color:"#858481",flexShrink:0}}/>
          <input placeholder="Pesquisar documentos…"
            style={{flex:1,border:"none",outline:"none",fontSize:14,color:"#34322d",background:"transparent",fontFamily:"inherit",WebkitUserSelect:"text",userSelect:"text"}}/>
        </div>

        <div className="section-label">Recentes</div>

        {docs.map(doc=>(
          <div key={doc.id} className="doc-card" onClick={()=>onOpenEditor?.(doc)}>
            <div style={{display:"flex",alignItems:"flex-start",gap:12}}>
              <div style={{width:36,height:36,background:"#f5f5f4",borderRadius:9,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0,marginTop:1}}>
                <Icon name="file-text" size={17} style={{color:"#5e5e5b"}}/>
              </div>
              <div style={{flex:1,minWidth:0}}>
                <div style={{display:"flex",alignItems:"center",gap:8,marginBottom:3}}>
                  <div style={{fontSize:14,fontWeight:600,color:"#1a1a1a",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",flex:1}}>{doc.title}</div>
                  <button onClick={e=>e.stopPropagation()} style={{border:"none",background:"transparent",cursor:"pointer",padding:0,color:"#d1d5db",flexShrink:0}}>
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

      {/* FLOATING BOTTOM BAR */}
      <div className="ftb" style={{transform:drawerOpen?"translateX(55px)":"translateX(-50%)",left:drawerOpen?"calc(50% + 0px)":"50%",transition:"transform 400ms cubic-bezier(.22,1,.36,1)"}}>
        {/* Left circular btn — folder/browse */}
        <button className="circ-btn" onClick={()=>{}}>
          <Icon name="folder" size={20}/>
        </button>
        {/* AI input pill */}
        <div className="pill-input" onClick={()=>setAiOpen(true)}>
          <Icon name="bot" size={18} style={{color:"#2563eb",flexShrink:0}}/>
          <span style={{fontSize:14,color:"#858481",flex:1}}>Criar com IA…</span>
        </div>
        {/* Right circular btn — new doc */}
        <button className="circ-btn" onClick={()=>onOpenEditor?.({id:Date.now(),title:"",aiContent:""})}>
          <Icon name="plus" size={22}/>
        </button>
      </div>

      {/* AI SHEET */}
      {aiOpen&&(
        <>
          <div className="ai-overlay" onClick={()=>setAiOpen(false)}/>
          <div className="ai-sheet">
            <div style={{display:"flex",alignItems:"center",gap:10,marginBottom:14}}>
              <div style={{width:34,height:34,borderRadius:9,background:"#eff6ff",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>
                <Icon name="bot" size={17} style={{color:"#2563eb"}}/>
              </div>
              <div style={{flex:1}}>
                <div style={{fontSize:14,fontWeight:700,color:"#1a1a1a"}}>Criar com IA</div>
                <div style={{fontSize:12,color:"#858481"}}>Descreve o documento que queres criar</div>
              </div>
              <button onClick={()=>setAiOpen(false)} style={{border:"none",background:"transparent",cursor:"pointer",color:"#858481",padding:4}}>
                <Icon name="x" size={18}/>
              </button>
            </div>
            <textarea ref={aiRef} value={aiInput} onChange={e=>setAiInput(e.target.value)}
              placeholder="Ex: Relatório mensal de vendas com análise de resultados…"
              rows={4}
              style={{width:"100%",padding:"12px 14px",border:"1.5px solid rgba(0,0,0,.08)",borderRadius:12,fontSize:14,fontFamily:"'DM Sans',sans-serif",outline:"none",resize:"none",color:"#34322d",background:"#fafaf9",lineHeight:1.6,WebkitUserSelect:"text",userSelect:"text"}}/>
            <button onClick={doAI} disabled={!aiInput.trim()||aiLoading}
              style={{width:"100%",marginTop:10,padding:"13px 0",background:aiInput.trim()&&!aiLoading?"#2563eb":"rgba(0,0,0,.07)",color:aiInput.trim()&&!aiLoading?"#fff":"#858481",border:"none",borderRadius:12,cursor:aiInput.trim()&&!aiLoading?"pointer":"default",fontFamily:"inherit",fontSize:14,fontWeight:600,display:"flex",alignItems:"center",justifyContent:"center",gap:8,transition:"background .15s"}}>
              {aiLoading?"A criar…":<><Icon name="send" size={15}/>Criar documento</>}
            </button>
          </div>
        </>
      )}
    </div>
  );
}