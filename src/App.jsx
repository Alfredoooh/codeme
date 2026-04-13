import { useState, useEffect, useRef, useCallback } from "react";

/* ── TWEMOJI helper ─────────────────────────────────────── */
const twSrc = (cp) =>
  `https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/svg/${cp}.svg`;
const EMOJI_LIST = [
  {cp:"1f4c4",lbl:"Doc"},{cp:"1f4dd",lbl:"Nota"},{cp:"1f4ca",lbl:"Gráfico"},
  {cp:"1f4bc",lbl:"Trabalho"},{cp:"1f393",lbl:"Escola"},{cp:"26ea",lbl:"Igreja"},
  {cp:"1f3e2",lbl:"Empresa"},{cp:"1f4bb",lbl:"Código"},{cp:"1f3a8",lbl:"Arte"},
  {cp:"1f4d6",lbl:"Livro"},{cp:"2705",lbl:"Feito"},{cp:"1f4e7",lbl:"Email"},
  {cp:"1f4c5",lbl:"Data"},{cp:"1f9ea",lbl:"Ciência"},{cp:"1f3af",lbl:"Meta"},
  {cp:"1f4b0",lbl:"Finanças"},{cp:"2764",lbl:"Amor"},{cp:"1f525",lbl:"Fogo"},
  {cp:"1f31f",lbl:"Estrela"},{cp:"1f4f1",lbl:"Mobile"},{cp:"1f3d7",lbl:"Projeto"},
  {cp:"1f9e0",lbl:"Ideia"},{cp:"270f",lbl:"Editar"},{cp:"1f50d",lbl:"Pesquisa"},
];
const TwEmoji = ({ cp, size = 20 }) => (
  <img src={twSrc(cp)} width={size} height={size} style={{ display:"inline-block", verticalAlign:"middle", flexShrink:0 }} alt="" />
);

/* ── ICONS ──────────────────────────────────────────────── */
const IC = {
  menu:`<line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/>`,
  "arrow-left":`<line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/>`,
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
  "move":`<polyline points="5 9 2 12 5 15"/><polyline points="9 5 12 2 15 5"/><line x1="2" y1="12" x2="22" y2="12"/><polyline points="19 9 22 12 19 15"/><polyline points="15 19 12 22 9 19"/>`,
  users:`<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>`,
  book:`<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>`,
  settings:`<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>`,
  "projects":`<rect x="2" y="3" width="8" height="8" rx="1"/><rect x="14" y="3" width="8" height="8" rx="1"/><rect x="2" y="14" width="8" height="8" rx="1"/><path d="M14 18h8M18 14v8"/>`,
  check:`<path d="M20 6 9 17l-5-5"/>`,
  sparkles:`<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/><path d="M5 3v4"/><path d="M19 17v4"/><path d="M3 5h4"/><path d="M17 19h4"/>`,
  bell:`<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>`,
  lock:`<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>`,
  palette:`<circle cx="13.5" cy="6.5" r=".5"/><circle cx="17.5" cy="10.5" r=".5"/><circle cx="8.5" cy="7.5" r=".5"/><circle cx="6.5" cy="12.5" r=".5"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"/>`,
  "log-out":`<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>`,
  "undo-2":`<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>`,
  "redo-2":`<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>`,
  bold:`<path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/>`,
  italic:`<line x1="19" y1="4" x2="10" y2="4"/><line x1="14" y1="20" x2="5" y2="20"/><line x1="15" y1="4" x2="9" y2="20"/>`,
  underline:`<path d="M6 4v6a6 6 0 0 0 12 0V4"/><line x1="4" y1="20" x2="20" y2="20"/>`,
  link:`<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>`,
  "align-left":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="15" y1="12" x2="3" y2="12"/><line x1="17" y1="18" x2="3" y2="18"/>`,
  "align-center":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="17" y1="12" x2="7" y2="12"/><line x1="19" y1="18" x2="5" y2="18"/>`,
  "align-right":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="12" x2="9" y2="12"/><line x1="21" y1="18" x2="7" y2="18"/>`,
  list:`<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>`,
  "list-ordered":`<line x1="10" y1="6" x2="21" y2="6"/><line x1="10" y1="12" x2="21" y2="12"/><line x1="10" y1="18" x2="21" y2="18"/><path d="M4 6h1v4M4 10h2M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/>`,
  "settings-2":`<path d="M20 7h-9M14 17H5"/><circle cx="17" cy="17" r="3"/><circle cx="7" cy="7" r="3"/>`,
  "trash-open":`<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/>`,
  rotate:`<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>`,
  pilcrow:`<path d="M13 4v16"/><path d="M17 4v16"/><path d="M19 4H9.5a4.5 4.5 0 0 0 0 9H13"/>`,
  "heading-1":`<path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M21 18v-7l-2 2"/>`,
  "heading-2":`<path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M21 7c0-1.657-1.343-3-3-3s-3 1.343-3 3c0 4 6 6 6 6"/><path d="M15 18h6"/>`,
  quote:`<path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V20c0 1 0 1 1 1z"/><path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z"/>`,
  code:`<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>`,
  maximize:`<polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/>`,
  clipboard:`<rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>`,
  copy:`<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>`,
  scissors:`<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><line x1="20" y1="4" x2="8.12" y2="15.88"/><line x1="14.47" y1="14.48" x2="20" y2="20"/><line x1="8.12" y1="8.12" x2="12" y2="12"/>`,
  "check-square":`<polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>`,
  "case-upper":`<path d="m3 15 4-8 4 8"/><path d="M4 13h6"/><path d="M15 11h4.5a2 2 0 0 1 0 4H15V7h4a2 2 0 0 1 0 4"/>`,
  minus:`<line x1="5" y1="12" x2="19" y2="12"/>`,
  calendar:`<rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>`,
  table:`<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/>`,
  image:`<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/>`,
  indent:`<polyline points="3 8 7 12 3 16"/><line x1="21" y1="12" x2="11" y2="12"/><line x1="21" y1="6" x2="11" y2="6"/><line x1="21" y1="18" x2="11" y2="18"/>`,
  outdent:`<polyline points="7 8 3 12 7 16"/><line x1="21" y1="12" x2="11" y2="12"/><line x1="21" y1="6" x2="11" y2="6"/><line x1="21" y1="18" x2="11" y2="18"/>`,
  "align-justify":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="12" x2="3" y2="12"/><line x1="21" y1="18" x2="3" y2="18"/>`,
  layers:`<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>`,
  "alert-triangle":`<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>`,
  info:`<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>`,
  "check-circle":`<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>`,
  "x-circle":`<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>`,
};
const Icon = ({ name, size=18, sw=2, style, cls }) => (
  <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
    style={style} className={cls} dangerouslySetInnerHTML={{ __html: IC[name]||"" }}/>
);

/* ── FONTS & COLORS ─────────────────────────────────────── */
const FONTS=[
  {l:"Lora",v:"'Lora',Georgia,serif",g:"Serif"},{l:"Playfair Display",v:"'Playfair Display',serif",g:"Serif"},
  {l:"Merriweather",v:"'Merriweather',serif",g:"Serif"},{l:"Georgia",v:"Georgia,serif",g:"Serif"},
  {l:"Inter",v:"'Inter',sans-serif",g:"Sans-serif"},{l:"Open Sans",v:"'Open Sans',sans-serif",g:"Sans-serif"},
  {l:"Montserrat",v:"'Montserrat',sans-serif",g:"Sans-serif"},{l:"DM Sans",v:"'DM Sans',sans-serif",g:"Sans-serif"},
  {l:"Courier New",v:"'Courier New',monospace",g:"Monospace"},{l:"Fira Code",v:"'Fira Code',monospace",g:"Monospace"},
  {l:"Dancing Script",v:"'Dancing Script',cursive",g:"Manuscrita"},{l:"Caveat",v:"'Caveat',cursive",g:"Manuscrita"},
];
const COLORS=["#000","#34322d","#5e5e5b","#858481","#d1d5db","#fff","#dc2626","#ea580c","#d97706","#65a30d","#16a34a","#0891b2","#2563eb","#7c3aed","#db2777","#fca5a5","#fdba74","#fcd34d","#86efac","#93c5fd","#c4b5fd"];
const SZP=[8,10,12,13,14,15,16,18,20,22,24,28,32,36,48,64];

/* ── TAGS ───────────────────────────────────────────────── */
const TAGS = [
  {id:"work",   label:"Trabalho", color:"#2563eb", bg:"#dbeafe"},
  {id:"school", label:"Escola",   color:"#7c3aed", bg:"#f3e8ff"},
  {id:"church", label:"Igreja",   color:"#059669", bg:"#d1fae5"},
  {id:"biz",    label:"Negócios", color:"#d97706", bg:"#fef3c7"},
  {id:"personal",label:"Pessoal", color:"#db2777", bg:"#fce7f3"},
];

/* ── INITIAL DATA ───────────────────────────────────────── */
const INIT_PROJECTS = [
  { id:"p1", name:"School", emoji:"1f393", folders:[
    {id:"f1",name:"Matemática",emoji:"2795"},{id:"f2",name:"História",emoji:"1f4d6"},
  ]},
  { id:"p2", name:"Church", emoji:"26ea", folders:[
    {id:"f3",name:"Sermões",emoji:"1f64f"},
  ]},
  { id:"p3", name:"Business", emoji:"1f3e2", folders:[
    {id:"f4",name:"Finanças",emoji:"1f4b0"},{id:"f5",name:"Contratos",emoji:"1f4c4"},
  ]},
];

const INIT_DOCS = [
  { id:1, title:"Relatório Trimestral Q1", emoji:"1f4ca", preview:"Análise de desempenho Q1 com métricas e projeções para Q2.", date:"Hoje, 14:32", tag:"work",
    content:`<h1>Relatório Trimestral Q1</h1><p>Este relatório apresenta os resultados do primeiro trimestre.</p><h2>Resumo Executivo</h2><p>O trimestre foi marcado por crescimento consistente em todas as áreas.</p><h2>Métricas Principais</h2><p>• Receita: +12% vs Q4<br>• Clientes novos: 340<br>• Retenção: 94%</p><h2>Próximos Passos</h2><p>Foco em expansão do mercado e melhoria dos processos internos.</p>`},
  { id:2, title:"Notas de Reunião", emoji:"1f4dd", preview:"Roadmap do produto, sprint 12, feedback dos clientes.", date:"Hoje, 09:15", tag:"work",
    content:`<h1>Notas de Reunião — Equipa</h1><p><strong>Data:</strong> Hoje<br><strong>Participantes:</strong> Equipa de produto</p><h2>Pontos Discutidos</h2><p>1. Roadmap do produto para Q2<br>2. Prioridades do sprint 12<br>3. Feedback dos clientes</p><h2>Decisões</h2><p>• Avançar com feature X na próxima semana<br>• Rever UI do dashboard</p><h2>Próxima Reunião</h2><p>Segunda-feira às 10h</p>`},
  { id:3, title:"Plano de Negócios", emoji:"1f3e2", preview:"Âmbito, objetivos e orçamento estimado.", date:"Ontem, 18:44", tag:"biz",
    content:`<h1>Plano de Negócios</h1><h2>Visão</h2><p>Criar a melhor plataforma de gestão documental para pequenas empresas.</p><h2>Mercado Alvo</h2><p>PMEs com 10–50 colaboradores que precisam de organização digital eficiente.</p><h2>Modelo de Receita</h2><p>• Subscrição mensal: €15/utilizador<br>• Plano empresarial: €199/mês</p><h2>Objetivos Ano 1</h2><p>Atingir 1.000 clientes pagantes até dezembro.</p>`},
  { id:4, title:"Notas de Estudo", emoji:"1f393", preview:"Resumos, fórmulas e pontos-chave.", date:"Ontem, 11:20", tag:"school",
    content:`<h1>Notas de Estudo</h1><h2>Matemática</h2><p>Derivadas: f'(x) = lim(h→0) [f(x+h) - f(x)] / h</p><h2>Física</h2><p>F = ma | E = mc² | P = mv</p><h2>Dicas de Estudo</h2><p>• Fazer pausas de 5 min a cada 25 min (Pomodoro)<br>• Rever matéria no dia seguinte<br>• Fazer resumos após cada aula</p>`},
  { id:5, title:"Sermão — Domingo", emoji:"26ea", preview:"Texto base, pontos principais e ilustrações.", date:"2 Jan, 10:00", tag:"church",
    content:`<h1>Sermão — Domingo</h1><h2>Texto Base</h2><p>João 3:16 — "Porque Deus amou o mundo de tal maneira..."</p><h2>Introdução</h2><p>Contextualizar o amor de Deus no mundo contemporâneo.</p><h2>Pontos Principais</h2><p>1. O amor incondicional<br>2. A fé como resposta<br>3. A vida em abundância</p><h2>Conclusão</h2><p>Convite à reflexão e à ação na vida quotidiana.</p>`},
];

/* ── HAPTIC ─────────────────────────────────────────────── */
const haptic = (s="light") => { try { if(navigator.vibrate) navigator.vibrate(s==="light"?8:s==="medium"?20:40); } catch(_){} };

/* ── CSS ─────────────────────────────────────────────────── */
const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,500;0,9..40,600;0,9..40,700;1,9..40,400&family=Lora:ital,wght@0,400;0,600;1,400&family=Inter:wght@400;500;600&family=Playfair+Display:wght@400;700&family=Merriweather:wght@400;700&family=Open+Sans:wght@400;600&family=Montserrat:wght@400;600&family=Fira+Code:wght@400;500&family=Dancing+Script:wght@400;700&family=Caveat:wght@400;700&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;-webkit-font-smoothing:antialiased}
html,body,#root{width:100%;height:100%;overflow:hidden;background:#f2f2f7}
:root{--bg:#f2f2f7;--card:#fff;--sep:rgba(0,0,0,.06);--txt:#1c1c1e;--sub:#8e8e93;--accent:#007aff;--danger:#ff3b30;--radius-card:14px;--font:'DM Sans',system-ui,sans-serif}
/* screens */
.screen{position:absolute;inset:0;display:flex;flex-direction:column;font-family:var(--font);background:var(--bg);-webkit-user-select:none;user-select:none;overflow:hidden;will-change:transform}
.screen.home-vis{transform:translateX(0);opacity:1;transition:transform .4s cubic-bezier(.32,1,.56,1),opacity .3s}
.screen.home-hid{transform:translateX(-30%);opacity:0;pointer-events:none;transition:transform .4s cubic-bezier(.32,1,.56,1),opacity .3s}
.screen.edit-vis{transform:translateX(0);opacity:1;transition:transform .42s cubic-bezier(.32,1,.56,1),opacity .3s}
.screen.edit-hid{transform:translateX(100%);opacity:0;pointer-events:none;transition:transform .42s cubic-bezier(.32,1,.56,1),opacity .3s}
/* topbar */
.topbar{height:56px;flex-shrink:0;display:flex;align-items:center;padding:0 8px;background:rgba(242,242,247,.82);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);position:relative;z-index:10;transition:box-shadow .2s}
.topbar.scrolled{box-shadow:0 1px 0 rgba(0,0,0,.12),0 2px 12px rgba(0,0,0,.07)}
.tbtn{width:44px;height:44px;border:none;background:transparent;cursor:pointer;display:flex;align-items:center;justify-content:center;border-radius:12px;color:var(--sub);transition:background .12s,transform .1s}
.tbtn:active{background:rgba(0,0,0,.06);transform:scale(.93)}
/* drawer */
.drawer{position:fixed;top:0;left:0;width:272px;height:100%;background:#fff;z-index:50;display:flex;flex-direction:column;transform:translateX(-100%);transition:transform .36s cubic-bezier(.32,1,.56,1);will-change:transform}
.drawer.open{transform:translateX(0)}
.drawer-mask{position:fixed;inset:0;z-index:49;transition:background .3s,backdrop-filter .3s}
.drawer-mask.vis{background:rgba(0,0,0,.22);backdrop-filter:blur(2px);-webkit-backdrop-filter:blur(2px)}
/* drawer items */
.d-item{display:flex;align-items:center;gap:13px;padding:12px 16px;font-size:15px;font-weight:500;color:var(--txt);cursor:pointer;border:none;background:transparent;width:100%;text-align:left;font-family:var(--font);border-radius:0;transition:background .12s;-webkit-user-select:none;user-select:none}
.d-item:active{background:rgba(0,0,0,.05)}
.d-item.danger{color:var(--danger)}
.d-sub{font-size:14px;font-weight:400;color:var(--sub)}
/* scroll area */
.hscroll{flex:1;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;padding:16px 16px 180px;scrollbar-width:none}
.hscroll::-webkit-scrollbar{display:none}
/* tags row */
.tags-row{display:flex;gap:8px;overflow-x:auto;padding-bottom:4px;margin-bottom:18px;scrollbar-width:none;-webkit-overflow-scrolling:touch}
.tags-row::-webkit-scrollbar{display:none}
.tag-chip{flex-shrink:0;padding:6px 14px;border-radius:9999px;font-size:13px;font-weight:600;cursor:pointer;border:1.5px solid transparent;transition:all .15s}
/* doc cards — grouped */
.card-group{background:#fff;border-radius:var(--radius-card);overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.07),0 4px 16px rgba(0,0,0,.05);margin-bottom:20px}
.doc-card{padding:14px 16px;cursor:pointer;transition:background .12s;position:relative;border-bottom:1px solid var(--sep)}
.doc-card:last-child{border-bottom:none}
.doc-card:active{background:rgba(0,0,0,.04)}
/* floating bar */
.ftb{position:fixed;left:50%;transform:translateX(-50%);bottom:max(20px,env(safe-area-inset-bottom,20px));width:min(92vw,440px);z-index:20;display:flex;align-items:center;gap:10px}
.pill-wrap{flex:1;height:56px;background:rgba(255,255,255,.96);border:1px solid rgba(0,0,0,.08);border-radius:9999px;box-shadow:0 8px 32px rgba(0,0,0,.12),0 2px 8px rgba(0,0,0,.06);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);display:flex;align-items:center;padding:0 16px;gap:10px;cursor:text;transition:box-shadow .2s}
.circ-btn{width:56px;height:56px;border-radius:50%;border:1px solid rgba(0,0,0,.08);background:rgba(255,255,255,.96);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);box-shadow:0 8px 32px rgba(0,0,0,.12),0 2px 8px rgba(0,0,0,.06);cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;color:var(--sub);transition:transform .12s,box-shadow .12s;-webkit-user-select:none}
.circ-btn:active{transform:scale(.9);box-shadow:0 2px 8px rgba(0,0,0,.08)}
/* editor pill */
.ed-pill{height:54px;background:rgba(255,255,255,.97);border:1px solid rgba(0,0,0,.08);border-radius:9999px;box-shadow:0 4px 20px rgba(0,0,0,.10);backdrop-filter:blur(20px);display:flex;align-items:center;overflow:hidden;position:relative}
.ed-pill::before{content:'';position:absolute;left:0;top:0;bottom:0;width:18px;background:linear-gradient(to right,rgba(255,255,255,.97),transparent);border-radius:9999px 0 0 9999px;z-index:2;pointer-events:none}
.ed-pill::after{content:'';position:absolute;right:50px;top:0;bottom:0;width:14px;background:linear-gradient(to left,rgba(255,255,255,.97),transparent);z-index:2;pointer-events:none}
.ed-pill.ai-mode::before,.ed-pill.ai-mode::after{display:none}
.tbtrack{display:flex;align-items:center;gap:1px;padding:0 6px;overflow-x:auto;flex:1;min-width:0;-webkit-overflow-scrolling:touch;scrollbar-width:none}
.tbtrack::-webkit-scrollbar{display:none}
/* AI sheet */
.ai-overlay{position:fixed;inset:0;z-index:60;background:rgba(0,0,0,.4);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px);animation:fadeIn .2s both}
.ai-sheet{position:fixed;bottom:0;left:0;right:0;background:#fff;border-radius:24px 24px 0 0;padding:24px 20px max(32px,env(safe-area-inset-bottom,32px));z-index:61;animation:slideUp .3s cubic-bezier(.32,1,.56,1) both}
.ai-handle{width:36px;height:4px;background:#e5e5ea;border-radius:2px;margin:0 auto 20px}
/* context menu */
.ctx-menu{position:fixed;background:#1c1c1e;border-radius:16px;box-shadow:0 16px 48px rgba(0,0,0,.5),0 4px 16px rgba(0,0,0,.3);z-index:9999;overflow:hidden;min-width:220px;animation:popIn .18s cubic-bezier(.34,1.56,.64,1) both}
.ctx-item{display:flex;align-items:center;gap:12px;padding:13px 18px;color:#fff;font-size:14px;font-weight:500;font-family:var(--font);cursor:pointer;border:none;background:transparent;width:100%;text-align:left;justify-content:space-between}
.ctx-item:active{background:rgba(255,255,255,.09)}
.ctx-item.danger{color:#ff453a}
.ctx-sep{height:1px;background:rgba(255,255,255,.12);margin:2px 0}
/* selection menu */
.sel-menu{position:fixed;z-index:9999;background:#1c1c1e;border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,.5);overflow:visible;pointer-events:auto;animation:popIn .15s cubic-bezier(.34,1.56,.64,1) both}
.sel-inner{display:flex;align-items:stretch;overflow-x:auto;border-radius:16px;scrollbar-width:none}
.sel-inner::-webkit-scrollbar{display:none}
.sel-menu::after{content:'';position:absolute;width:0;height:0;left:var(--ax,50%);transform:translateX(-50%);pointer-events:none}
.sel-menu.adown::after{top:100%;border-left:6px solid transparent;border-right:6px solid transparent;border-top:7px solid #1c1c1e}
.sel-menu.aup::after{bottom:100%;border-left:6px solid transparent;border-right:6px solid transparent;border-bottom:7px solid #1c1c1e}
/* popup */
.pop{position:fixed;background:#fff;border:1px solid rgba(0,0,0,.08);border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,.13);z-index:100;overflow:visible;animation:popIn .2s cubic-bezier(.34,1.56,.64,1) both}
.pop-inner{border-radius:16px;overflow:hidden}
.pop-arrow{position:absolute;bottom:-9px;width:18px;height:9px;overflow:hidden;pointer-events:none;z-index:101}
.pop-arrow::after{content:'';position:absolute;top:-7px;left:50%;transform:translateX(-50%) rotate(45deg);width:13px;height:13px;background:#fff;border:1px solid rgba(0,0,0,.08);border-radius:3px 0 0 0}
/* editor page */
.canvas{flex:1;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;background:#f0f0ef;padding:24px 16px 220px;display:flex;flex-direction:column;align-items:center}
.canvas::-webkit-scrollbar{width:5px}
.canvas::-webkit-scrollbar-thumb{background:rgba(0,0,0,.15);border-radius:3px}
.pw{width:794px;transform-origin:top center}
.page{width:794px;background:#fff;border-radius:0;border:1.5px solid #c8c8c8;box-shadow:0 1px 4px rgba(0,0,0,.06),0 4px 16px rgba(0,0,0,.06);padding:80px 80px 120px;min-height:1000px;transition:border-color .25s}
.page.focused{border-color:#b0b0b0}
.pc{outline:none;font-family:'Lora',Georgia,serif;font-size:16px;line-height:1.85;color:#34322d;min-height:500px;word-break:break-word;caret-color:#007aff;-webkit-user-select:text;user-select:text;cursor:text}
.pc::selection,.pc *::selection{background:#bfdbfe}
.pc:empty::before{content:attr(data-placeholder);color:#858481;pointer-events:none}
.pc h1{font-size:2em;font-weight:700;margin-bottom:.5em;line-height:1.2}
.pc h2{font-size:1.4em;font-weight:700;margin:1em 0 .4em;line-height:1.3}
.pc h3{font-size:1.15em;font-weight:600;margin:1em 0 .3em}
.pc p{margin-bottom:.6em}
.pc blockquote{border-left:3px solid #d1d5db;padding-left:1em;color:#6b7280;margin:.5em 0}
.pc pre{background:#f5f5f4;border-radius:8px;padding:12px;font-family:monospace;font-size:.88em;overflow-x:auto;margin:.5em 0}
/* tt — title in topbar */
.tt:empty::before{content:'Sem título';color:#858481;pointer-events:none}
.tt:focus{border-color:#007aff!important}
/* fullscreen font */
.ff{position:fixed;inset:0;z-index:500;background:#fff;display:flex;flex-direction:column;animation:slideUp .25s cubic-bezier(.32,1,.56,1) both}
.fgl{padding:6px 16px 2px;font-size:10px;font-weight:700;color:#c7c7cc;text-transform:uppercase;letter-spacing:.06em;border-top:1px solid var(--sep);margin-top:2px}
/* img wrap */
.img-wrap{display:inline-block;position:relative;cursor:pointer;-webkit-user-select:none;user-select:none;line-height:0}
.img-wrap img{display:block;max-width:100%;height:auto}
.img-wrap.selected img{outline:2px solid #007aff;outline-offset:2px}
.img-dots-btn{position:absolute;top:6px;right:6px;width:30px;height:30px;background:rgba(0,0,0,.5);backdrop-filter:blur(8px);border-radius:9px;display:flex;align-items:center;justify-content:center;cursor:pointer;z-index:5;border:none;color:#fff;animation:popIn .15s both}
.resize-handle{position:absolute;bottom:4px;right:4px;width:20px;height:20px;cursor:se-resize;z-index:6;opacity:.8}
.resize-handle::before{content:'';display:block;width:10px;height:10px;border-right:2.5px solid rgba(255,255,255,.9);border-bottom:2.5px solid rgba(255,255,255,.9);border-radius:1px}
/* folder picker sheet */
.sheet{position:fixed;bottom:0;left:0;right:0;background:#fff;border-radius:24px 24px 0 0;padding:20px 0 max(28px,env(safe-area-inset-bottom,28px));z-index:200;animation:slideUp .3s cubic-bezier(.32,1,.56,1) both;max-height:70vh;display:flex;flex-direction:column}
/* ai dots */
.aidot{width:5px;height:5px;border-radius:50%;background:var(--accent);animation:aiDot .9s ease infinite}
.aidot:nth-child(2){animation-delay:.2s}.aidot:nth-child(3){animation-delay:.4s}
/* misc */
.noscroll{scrollbar-width:none}.noscroll::-webkit-scrollbar{display:none}
.section-lbl{font-size:13px;font-weight:700;color:var(--sub);margin-bottom:10px;padding:0 2px}
/* lixo screen */
.trash-empty{display:flex;flex-direction:column;align-items:center;justify-content:center;flex:1;gap:12px;color:var(--sub);padding-bottom:80px}
/* search bar */
.search-bar{display:flex;align-items:center;gap:10px;background:#fff;border-radius:12px;box-shadow:0 1px 3px rgba(0,0,0,.07);padding:10px 14px;margin-bottom:18px}
/* alert boxes */
.alert-box{display:flex;align-items:flex-start;gap:12px;padding:14px 16px;margin:10px 0;border-radius:10px;font-size:14px;line-height:1.6;border:1.5px solid transparent}
.alert-icon-c{flex-shrink:0;width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:800;margin-top:1px}
.alert-warn{background:#fffbeb;border-color:#f59e0b;color:#78350f}
.alert-warn .alert-icon-c{background:#f59e0b;color:#fff}
.alert-info-box{background:#eff6ff;border-color:#3b82f6;color:#1e3a5f}
.alert-info-box .alert-icon-c{background:#3b82f6;color:#fff}
.alert-ok{background:#f0fdf4;border-color:#22c55e;color:#14532d}
.alert-ok .alert-icon-c{background:#22c55e;color:#fff}
.alert-err{background:#fff1f2;border-color:#f43f5e;color:#4c0519}
.alert-err .alert-icon-c{background:#f43f5e;color:#fff}
@keyframes popIn{from{opacity:0;transform:scale(.82)}to{opacity:1;transform:scale(1)}}
@keyframes slideUp{from{transform:translateY(60px);opacity:0}to{transform:translateY(0);opacity:1}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
@keyframes aiDot{0%,80%,100%{transform:scale(.6);opacity:.4}40%{transform:scale(1);opacity:1}}
`;

/* ── HELPERS ────────────────────────────────────────────── */
const PH = ({title}) => (
  <div style={{padding:"10px 16px",fontSize:10.5,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",letterSpacing:".08em",borderBottom:"1px solid rgba(0,0,0,.06)"}}>{title}</div>
);
const PI = ({icon,label,danger,right,onClick}) => (
  <button onMouseDown={e=>e.preventDefault()} onClick={onClick}
    style={{display:"flex",alignItems:"center",gap:10,padding:"10px 16px",fontSize:13.5,fontWeight:500,color:danger?"#dc2626":"#34322d",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"var(--font)",justifyContent:"space-between"}}
    onPointerOver={e=>e.currentTarget.style.background="rgba(0,0,0,.03)"} onPointerOut={e=>e.currentTarget.style.background="transparent"}>
    <span style={{display:"flex",alignItems:"center",gap:10}}><Icon name={icon} size={15} style={{color:danger?"#ef4444":"#858481",flexShrink:0}}/>{label}</span>
    {right&&<span style={{fontSize:12,color:"#8e8e93"}}>{right}</span>}
  </button>
);
const TbBtn = ({children,active,onMouseDown,onClick,style:st}) => (
  <button onMouseDown={onMouseDown} onClick={onClick}
    style={{height:38,minWidth:38,padding:"0 7px",border:"none",background:active?"#eff6ff":"transparent",borderRadius:9999,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",flexDirection:"column",gap:2,flexShrink:0,color:active?"#007aff":"#5e5e5b",transition:"background .12s",...st}}>
    {children}
  </button>
);
const TbChip = ({children,active,onMouseDown,onClick,"data-chip":dc,style:st}) => (
  <button onMouseDown={onMouseDown} onClick={onClick} data-chip={dc}
    style={{height:32,border:`1.5px solid ${active?"#007aff":"rgba(0,0,0,.08)"}`,borderRadius:9999,padding:"0 11px",fontFamily:"var(--font)",fontSize:12,fontWeight:600,color:active?"#007aff":"#34322d",background:active?"#e8f0fe":"transparent",cursor:"pointer",display:"flex",alignItems:"center",gap:4,whiteSpace:"nowrap",flexShrink:0,transition:"all .15s",...st}}>
    {children}
  </button>
);
const Div2 = () => <div style={{width:1,height:20,background:"rgba(0,0,0,.08)",flexShrink:0,margin:"0 3px"}}/>;

/* ── EMOJI PICKER ───────────────────────────────────────── */
function EmojiPicker({onPick,onClose}){
  return(
    <div style={{position:"fixed",inset:0,zIndex:300,display:"flex",alignItems:"flex-end",background:"rgba(0,0,0,.35)",backdropFilter:"blur(4px)",animation:"fadeIn .2s both"}} onClick={onClose}>
      <div onClick={e=>e.stopPropagation()} style={{width:"100%",background:"#fff",borderRadius:"24px 24px 0 0",padding:"20px 20px 40px",animation:"slideUp .28s cubic-bezier(.32,1,.56,1) both"}}>
        <div style={{width:36,height:4,background:"#e5e5ea",borderRadius:2,margin:"0 auto 20px"}}/>
        <div style={{fontSize:15,fontWeight:700,color:"#1c1c1e",marginBottom:16}}>Escolher ícone</div>
        <div style={{display:"grid",gridTemplateColumns:"repeat(6,1fr)",gap:8}}>
          {EMOJI_LIST.map(e=>(
            <button key={e.cp} onClick={()=>onPick(e.cp)}
              style={{aspectRatio:"1",borderRadius:12,border:"1.5px solid rgba(0,0,0,.06)",background:"#f9f9f9",cursor:"pointer",display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",gap:4,padding:6,transition:"background .12s"}}
              onPointerOver={e2=>e2.currentTarget.style.background="#e8f0fe"} onPointerOut={e2=>e2.currentTarget.style.background="#f9f9f9"}>
              <TwEmoji cp={e.cp} size={28}/>
              <span style={{fontSize:9,color:"#8e8e93",fontWeight:500,lineHeight:1}}>{e.lbl}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ── EDITOR POPUP CONTENTS ──────────────────────────────── */
function ColorPopup({colors,hexIn,setHexIn,hexPv,setHexPv,onApply}){
  return<><PH title="Cor do texto"/>
    <div style={{display:"grid",gridTemplateColumns:"repeat(7,1fr)",gap:5,padding:"10px 14px"}}>
      {colors.map(c=><div key={c} onMouseDown={e=>e.preventDefault()} onClick={()=>onApply(c)}
        style={{width:26,height:26,borderRadius:6,background:c,cursor:"pointer",border:c==="#fff"?"2px solid rgba(0,0,0,.15)":"2px solid transparent",transition:"transform .1s"}}
        onMouseOver={e=>e.currentTarget.style.transform="scale(1.22)"} onMouseOut={e=>e.currentTarget.style.transform="scale(1)"}/>)}
    </div>
    <div style={{display:"flex",gap:6,alignItems:"center",padding:"0 14px 12px"}}>
      <div style={{width:26,height:26,background:hexPv,borderRadius:6,border:"1.5px solid rgba(0,0,0,.12)",flexShrink:0}}/>
      <input value={hexIn} onChange={e=>{setHexIn(e.target.value);if(/^#[0-9a-f]{6}$/i.test(e.target.value))setHexPv(e.target.value);}}
        maxLength={7} onMouseDown={e=>e.stopPropagation()}
        style={{flex:1,padding:"7px 10px",border:"1.5px solid rgba(0,0,0,.08)",borderRadius:8,fontSize:12,fontWeight:600,fontFamily:"monospace",outline:"none",background:"#fafafa",WebkitUserSelect:"text",userSelect:"text"}}/>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>{if(/^#[0-9a-f]{6}$/i.test(hexIn))onApply(hexIn);}}
        style={{width:32,height:32,borderRadius:8,border:"none",background:hexPv,color:"#fff",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center"}}>✓</button>
    </div>
  </>;
}
function FontPopup({fonts,curFont,search,setSearch,preview,setPreview,onExpand,onApply}){
  const groups=[...new Set(fonts.map(f=>f.g))];
  const filtered=fonts.filter(f=>f.l.toLowerCase().includes(search.toLowerCase()));
  return<>
    <div style={{display:"flex",alignItems:"center",borderBottom:"1px solid rgba(0,0,0,.06)"}}>
      <div style={{flex:1,padding:"11px 16px",fontSize:10.5,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",letterSpacing:".07em"}}>Tipo de letra</div>
      <button onMouseDown={e=>e.preventDefault()} onClick={onExpand} style={{width:34,height:34,border:"none",background:"transparent",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",color:"#8e8e93",marginRight:8,borderRadius:8}}><Icon name="maximize" size={14}/></button>
    </div>
    <div style={{padding:"8px 10px 6px",borderBottom:"1px solid rgba(0,0,0,.06)"}}>
      <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Pesquisar…" onMouseDown={e=>e.stopPropagation()}
        style={{width:"100%",padding:"7px 10px",border:"1.5px solid rgba(0,0,0,.08)",borderRadius:9,fontSize:12.5,outline:"none",background:"#fafafa",fontFamily:"var(--font)",WebkitUserSelect:"text",userSelect:"text"}}/>
    </div>
    <div className="noscroll" style={{maxHeight:180,overflowY:"auto"}}>
      {!search?groups.map((g,gi)=>{const gf=filtered.filter(f=>f.g===g);if(!gf.length)return null;
        return[<div key={g} className="fgl" style={gi===0?{borderTop:"none"}:{}}>{g}</div>,
          ...gf.map(f=><button key={f.v} onMouseDown={e=>e.preventDefault()} onClick={()=>setPreview(f)}
            style={{padding:"9px 16px",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"var(--font)",display:"flex",alignItems:"center",color:f.v===curFont?"#007aff":"#34322d"}}>
            <span style={{fontFamily:f.v,fontSize:14,flex:1}}>{f.l}</span></button>)];
      }):filtered.map(f=><button key={f.v} onMouseDown={e=>e.preventDefault()} onClick={()=>setPreview(f)}
        style={{padding:"9px 16px",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"var(--font)",color:f.v===curFont?"#007aff":"#34322d"}}>
        <span style={{fontFamily:f.v,fontSize:14}}>{f.l}</span></button>)}
    </div>
    {preview&&<div style={{borderTop:"1px solid rgba(0,0,0,.06)",padding:"10px 14px 12px",background:"#fafafa"}}>
      <div style={{fontSize:10,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",marginBottom:4}}>{preview.l}</div>
      <div style={{fontSize:26,color:"#34322d",marginBottom:8,lineHeight:1.2,fontFamily:preview.v}}>Aa Bb Cc</div>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>onApply(preview)}
        style={{width:"100%",padding:"8px 0",background:"#007aff",color:"#fff",border:"none",borderRadius:9,cursor:"pointer",fontFamily:"var(--font)",fontSize:13,fontWeight:600}}>Aplicar</button>
    </div>}
  </>;
}
function SizePopup({szPv,onApply,onStep}){
  return<><PH title="Tamanho"/>
    <div style={{display:"flex",alignItems:"center",gap:8,padding:"12px 14px"}}>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>onStep(-1)} style={{width:36,height:36,borderRadius:9,border:"1.5px solid rgba(0,0,0,.08)",background:"#fff",cursor:"pointer",fontSize:18,color:"#5e5e5b",display:"flex",alignItems:"center",justifyContent:"center"}}>−</button>
      <div style={{flex:1,textAlign:"center",fontSize:20,fontWeight:700,color:"#34322d"}}>{szPv}</div>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>onStep(1)} style={{width:36,height:36,borderRadius:9,border:"1.5px solid rgba(0,0,0,.08)",background:"#fff",cursor:"pointer",fontSize:18,color:"#5e5e5b",display:"flex",alignItems:"center",justifyContent:"center"}}>+</button>
    </div>
    <div style={{display:"flex",flexWrap:"wrap",gap:5,padding:"10px 14px 12px",borderTop:"1px solid rgba(0,0,0,.06)"}}>
      {SZP.map(s=><button key={s} onMouseDown={e=>e.preventDefault()} onClick={()=>onApply(s)}
        style={{padding:"4px 10px",borderRadius:9999,border:`1.5px solid ${s===szPv?"#007aff":"rgba(0,0,0,.08)"}`,background:s===szPv?"#e8f0fe":"transparent",color:s===szPv?"#007aff":"#5e5e5b",fontSize:12,fontWeight:600,cursor:"pointer",fontFamily:"var(--font)"}}>{s}</button>)}
    </div>
  </>;
}
function StylesPopup({exec,onClose}){
  const stls=[{l:"Parágrafo",c:()=>exec("formatBlock","<p>"),i:"pilcrow"},{l:"Título 1",c:()=>exec("formatBlock","<h1>"),i:"heading-1"},{l:"Título 2",c:()=>exec("formatBlock","<h2>"),i:"heading-2"},{l:"Título 3",c:()=>exec("formatBlock","<h3>"),i:"heading-2"},{l:"Citação",c:()=>exec("formatBlock","<blockquote>"),i:"quote"},{l:"Código",c:()=>exec("formatBlock","<pre>"),i:"code"}];
  return<><PH title="Estilo"/>{stls.map(s=><PI key={s.l} icon={s.i} label={s.l} onClick={()=>{s.c();onClose();}}/>)}</>;
}
function InsertPopup({exec,onClose,insertImg,insertTable}){
  const alerts=[
    {id:"warn",icon:"alert-triangle",ch:"⚠",bg:"#f59e0b",cls:"alert-warn",title:"Aviso",text:"Conteúdo que requer atenção."},
    {id:"info",icon:"info",ch:"i",bg:"#3b82f6",cls:"alert-info-box",title:"Informação",text:"Uma nota informativa."},
    {id:"ok",icon:"check-circle",ch:"✓",bg:"#22c55e",cls:"alert-ok",title:"Sucesso",text:"Operação concluída."},
    {id:"err",icon:"x-circle",ch:"✕",bg:"#f43f5e",cls:"alert-err",title:"Erro",text:"Algo correu mal."},
  ];
  return<><PH title="Inserir"/>
    <div style={{borderBottom:"1px solid rgba(0,0,0,.06)"}}>
      <PI icon="link" label="Link" onClick={()=>{onClose();const u=prompt("URL:");if(u)exec("createLink",u);}}/>
      <PI icon="image" label="Imagem" onClick={insertImg}/>
      <PI icon="table" label="Tabela 3×3" onClick={insertTable}/>
      <PI icon="minus" label="Linha divisória" onClick={()=>{exec("insertHorizontalRule");onClose();}}/>
      <PI icon="calendar" label="Data e hora" onClick={()=>{exec("insertText",new Date().toLocaleString("pt-PT"));onClose();}}/>
    </div>
    <div>
      <div style={{padding:"4px 16px 2px",fontSize:10,fontWeight:700,color:"#c7c7cc",textTransform:"uppercase",letterSpacing:".06em"}}>Caixas de destaque</div>
      {alerts.map(a=><PI key={a.id} icon={a.icon} label={a.title} onClick={()=>{
        exec("insertHTML",`<div class="alert-box ${a.cls}" contenteditable="true"><div class="alert-icon-c" style="background:${a.bg};color:#fff">${a.ch}</div><div><div style="font-weight:700;font-size:13px;margin-bottom:2px">${a.title}</div><div style="font-size:13px;opacity:.85">${a.text}</div></div></div><p></p>`);
        onClose();
      }}/>)}
    </div>
  </>;
}
function FormatPopup({exec,onClose,edRef,restoreSel}){
  const getSel=()=>{restoreSel();const s=window.getSelection();return s&&!s.isCollapsed?s:null;};
  return<><PH title="Formatar"/>
    <div style={{borderBottom:"1px solid rgba(0,0,0,.06)"}}>
      <PI icon="case-upper" label="MAIÚSCULAS" onClick={()=>{const s=getSel();if(s)exec("insertText",s.toString().toUpperCase());onClose();}}/>
      <PI icon="code" label="Código inline" onClick={()=>{exec("insertHTML",'<code style="background:#f0eeeb;padding:1px 5px;font-family:monospace;font-size:.88em;border-radius:4px">código</code>');onClose();}}/>
    </div>
    <div style={{borderBottom:"1px solid rgba(0,0,0,.06)"}}>
      {[["1.0","1"],["1.5","1.5"],["2.0","2"]].map(([lbl,val])=>(
        <PI key={val} icon="align-left" label={`Espaçamento ${lbl}`} onClick={()=>{if(edRef.current)edRef.current.style.lineHeight=val;onClose();}}/>
      ))}
    </div>
    <PI icon="trash-2" label="Limpar formatação" danger onClick={()=>{exec("removeFormat");onClose();}}/>
  </>;
}
function ImgCtxMenu({pos,onClose,onAction}){
  const items=[
    {label:"Em linha",icon:"align-left",action:"inline"},
    {label:"Centrado",icon:"align-center",action:"center"},
    {label:"Flutua à esquerda",icon:"align-left",action:"float-left"},
    {label:"Flutua à direita",icon:"align-right",action:"float-right"},
    null,
    {label:"Eliminar",icon:"trash-2",action:"delete",danger:true},
  ];
  return(
    <div className="ctx-menu" style={{left:pos.x,top:pos.y}} onMouseDown={e=>e.stopPropagation()}>
      {items.map((item,i)=>item===null?<div key={i} className="ctx-sep"/>:
        <button key={i} className={`ctx-item${item.danger?" danger":""}`} onClick={()=>{onAction(item.action);onClose();}}>
          <span style={{display:"flex",alignItems:"center",gap:10}}><Icon name={item.icon} size={15} style={{color:item.danger?"#ff453a":"rgba(255,255,255,.5)",flexShrink:0}}/>{item.label}</span>
        </button>)}
    </div>
  );
}

/* ══════════════════════════════════════════════════════════
   HOME SCREEN
═══════════════════════════════════════════════════════════ */
function HomeScreen({visible,docs,setDocs,projects,setProjects,trash,setTrash,onOpenEditor}){
  const [drawerOpen,setDrawerOpen]=useState(false);
  const [drawerMask,setDrawerMask]=useState(false);
  const [settingsOpen,setSettingsOpen]=useState(false);
  const [projExp,setProjExp]=useState({});
  const [activeTag,setActiveTag]=useState(null);
  const [aiOpen,setAiOpen]=useState(false);
  const [aiInput,setAiInput]=useState("");
  const [aiLoading,setAiLoading]=useState(false);
  const [scrolled,setScrolled]=useState(false);
  const [screen,setScreen]=useState("home"); // home | trash
  const [ctxMenu,setCtxMenu]=useState(null); // {docId,x,y}
  const [folderSheet,setFolderSheet]=useState(null); // docId to move
  const [newProjName,setNewProjName]=useState("");
  const [newFolderName,setNewFolderName]=useState("");
  const [newFolderParent,setNewFolderParent]=useState(null);
  const [emojiPicker,setEmojiPicker]=useState(null); // {target:'proj'|'folder'|'doc', id}
  const aiRef=useRef(null);
  const scrollRef=useRef(null);

  // Drawer open/close with mask animation
  const openDrawer=()=>{setDrawerMask(true);requestAnimationFrame(()=>setDrawerOpen(true));};
  const closeDrawer=()=>{setDrawerOpen(false);setTimeout(()=>setDrawerMask(false),380);};

  useEffect(()=>{if(aiOpen)setTimeout(()=>aiRef.current?.focus(),80);},[aiOpen]);

  const handleScroll=()=>{
    if(scrollRef.current) setScrolled(scrollRef.current.scrollTop>4);
  };

  const visibleDocs = (activeTag ? docs.filter(d=>d.tag===activeTag) : docs).filter(d=>!d.trashed);
  const trashedDocs = docs.filter(d=>d.trashed);

  const trashDoc=(id)=>{
    setDocs(prev=>prev.map(d=>d.id===id?{...d,trashed:true}:d));
    setCtxMenu(null);
  };
  const restoreDoc=(id)=>setDocs(prev=>prev.map(d=>d.id===id?{...d,trashed:false}:d));
  const permDelete=(id)=>setDocs(prev=>prev.filter(d=>d.id!==id));

  const moveToFolder=(docId,folderId,projId)=>{
    setDocs(prev=>prev.map(d=>d.id===docId?{...d,folderId,projId}:d));
    setFolderSheet(null);
  };

  const doAI=async()=>{
    const p=aiInput.trim();if(!p)return;
    setAiLoading(true);
    try{
      const r=await fetch("https://api.anthropic.com/v1/messages",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:"claude-sonnet-4-20250514",max_tokens:900,system:"Cria um documento em português com HTML semântico (h1,h2,p,ul). Responde APENAS com o HTML do conteúdo, sem tags html/body/head.",messages:[{role:"user",content:p}]})});
      const d=await r.json();
      const html=d.content?.map(i=>i.text||"").join("")||"";
      const nd={id:Date.now(),title:p.slice(0,40),emoji:"1f9e0",preview:p.slice(0,90)+"…",date:"Agora",tag:"work",content:html,aiContent:html};
      setDocs(prev=>[nd,...prev]);
      setAiInput("");setAiOpen(false);
      onOpenEditor(nd);
    }catch(_){}
    setAiLoading(false);
  };

  const addProject=()=>{
    if(!newProjName.trim())return;
    setProjects(prev=>[...prev,{id:"p"+Date.now(),name:newProjName.trim(),emoji:"1f4c1",folders:[]}]);
    setNewProjName("");
  };
  const addFolder=(projId)=>{
    if(!newFolderName.trim())return;
    setProjects(prev=>prev.map(p=>p.id===projId?{...p,folders:[...p.folders,{id:"f"+Date.now(),name:newFolderName.trim(),emoji:"1f4c2"}]}:p));
    setNewFolderName("");setNewFolderParent(null);
  };
  const setEmojiFor=(target,id,cp)=>{
    if(target==="proj") setProjects(prev=>prev.map(p=>p.id===id?{...p,emoji:cp}:p));
    else if(target==="folder") setProjects(prev=>prev.map(p=>({...p,folders:p.folders.map(f=>f.id===id?{...f,emoji:cp}:f)})));
    else if(target==="doc") setDocs(prev=>prev.map(d=>d.id===id?{...d,emoji:cp}:d));
    setEmojiPicker(null);
  };

  const cardCount = visibleDocs.length;

  return(
    <div className={`screen ${visible?"home-vis":"home-hid"}`}>
      {/* Drawer */}
      {drawerMask&&<div className={`drawer-mask${drawerOpen?" vis":""}`} onClick={closeDrawer}/>}
      <div className={`drawer${drawerOpen?" open":""}`} style={{boxShadow:drawerOpen?"4px 0 40px rgba(0,0,0,.18)":"none"}}>
        {/* Header */}
        <div style={{padding:"56px 20px 16px 20px",borderBottom:"1px solid rgba(0,0,0,.06)",display:"flex",alignItems:"center",gap:12}}>
          <div style={{width:40,height:40,borderRadius:10,background:"#1c1c1e",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>
            <span style={{color:"#fff",fontWeight:800,fontSize:18,fontFamily:"Georgia,serif"}}>D</span>
          </div>
          <div>
            <div style={{fontSize:17,fontWeight:700,color:"#1c1c1e"}}>Menu</div>
            <div style={{fontSize:12,color:"#8e8e93"}}>Espaço de trabalho</div>
          </div>
        </div>
        <div style={{flex:1,overflowY:"auto",paddingBottom:20}} className="noscroll">
          {/* Biblioteca */}
          <button className="d-item" onClick={closeDrawer}>
            <Icon name="book" size={20} style={{color:"#1c1c1e",flexShrink:0}}/>
            <span style={{flex:1}}>Biblioteca</span>
          </button>
          {/* Configurações */}
          <button className="d-item" onClick={()=>setSettingsOpen(v=>!v)}>
            <Icon name="settings" size={20} style={{color:"#1c1c1e",flexShrink:0}}/>
            <span style={{flex:1}}>Configurações</span>
            <Icon name={settingsOpen?"chevron-down":"chevron-right"} size={15} style={{color:"#c7c7cc",transition:"transform .25s",transform:settingsOpen?"rotate(0deg)":"rotate(0deg)"}}/>
          </button>
          {settingsOpen&&(
            <div style={{overflow:"hidden",animation:"slideUp .2s cubic-bezier(.32,1,.56,1) both"}}>
              {[
                {icon:"bell",label:"Notificações"},{icon:"lock",label:"Privacidade"},
                {icon:"palette",label:"Aparência"},{icon:"users",label:"Conta"},
                {icon:"log-out",label:"Terminar sessão",danger:true},
              ].map(s=>(
                <button key={s.label} className={`d-item d-sub${s.danger?" danger":""}`}
                  style={{paddingLeft:52,fontSize:14,color:s.danger?"#ff3b30":"#3a3a3c"}} onClick={closeDrawer}>
                  <Icon name={s.icon} size={16} style={{color:s.danger?"#ff3b30":"#8e8e93",flexShrink:0}}/>{s.label}
                </button>
              ))}
            </div>
          )}
          {/* Membros */}
          <button className="d-item" onClick={closeDrawer}>
            <Icon name="users" size={20} style={{color:"#1c1c1e",flexShrink:0}}/>
            <span style={{flex:1}}>Membros</span>
          </button>
          {/* Lixo */}
          <button className="d-item danger" onClick={()=>{setScreen("trash");closeDrawer();}}>
            <Icon name="trash-2" size={20} style={{color:"#ff3b30",flexShrink:0}}/>
            <span style={{flex:1,color:"#ff3b30"}}>Lixo</span>
            {trashedDocs.length>0&&<span style={{fontSize:11,fontWeight:700,background:"#ff3b30",color:"#fff",borderRadius:9999,padding:"1px 7px"}}>{trashedDocs.length}</span>}
            <Icon name="chevron-right" size={15} style={{color:"#ffb3b0"}}/>
          </button>
          {/* Divisor */}
          <div style={{height:1,background:"rgba(0,0,0,.06)",margin:"8px 0"}}/>
          {/* Projects */}
          <div style={{padding:"8px 16px 4px",fontSize:11,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",letterSpacing:".07em",display:"flex",alignItems:"center",justifyContent:"space-between"}}>
            <span>Projetos</span>
            <button onClick={()=>{const n=prompt("Nome do projeto:");if(n)setProjects(prev=>[...prev,{id:"p"+Date.now(),name:n.trim(),emoji:"1f4c1",folders:[]}]);}}
              style={{border:"none",background:"transparent",cursor:"pointer",color:"#8e8e93",padding:2}}><Icon name="plus" size={14}/></button>
          </div>
          {projects.map(proj=>(
            <div key={proj.id}>
              <button className="d-item" style={{paddingLeft:16}}
                onClick={()=>setProjExp(prev=>({...prev,[proj.id]:!prev[proj.id]}))}>
                <span onClick={e=>{e.stopPropagation();setEmojiPicker({target:"proj",id:proj.id});}}>
                  <TwEmoji cp={proj.emoji} size={20}/>
                </span>
                <span style={{flex:1,fontWeight:500}}>{proj.name}</span>
                <Icon name={projExp[proj.id]?"chevron-down":"chevron-right"} size={14} style={{color:"#c7c7cc",transition:"transform .2s"}}/>
                <button onPointerDown={e=>e.stopPropagation()} onClick={e=>{e.stopPropagation();window.open&&alert("Abrir");}}
                  style={{border:"none",background:"transparent",cursor:"pointer",color:"#c7c7cc",padding:2,marginLeft:2}}>
                  <Icon name="arrow-up-right" size={13}/>
                </button>
              </button>
              {projExp[proj.id]&&(
                <div style={{borderLeft:"2px solid #e5e5ea",marginLeft:36,paddingLeft:0,animation:"slideUp .2s cubic-bezier(.32,1,.56,1) both"}}>
                  {proj.folders.map(folder=>(
                    <button key={folder.id} className="d-item" style={{paddingLeft:16,fontSize:14,fontWeight:400,color:"#3a3a3c"}}>
                      <span onClick={e=>{e.stopPropagation();setEmojiPicker({target:"folder",id:folder.id});}}><TwEmoji cp={folder.emoji} size={16}/></span>
                      <span style={{flex:1}}>{folder.name}</span>
                      <Icon name="chevron-right" size={13} style={{color:"#c7c7cc"}}/>
                    </button>
                  ))}
                  {newFolderParent===proj.id?(
                    <div style={{padding:"6px 12px",display:"flex",gap:6}}>
                      <input autoFocus value={newFolderName} onChange={e=>setNewFolderName(e.target.value)}
                        onKeyDown={e=>{if(e.key==="Enter")addFolder(proj.id);if(e.key==="Escape")setNewFolderParent(null);}}
                        placeholder="Nome da pasta…"
                        style={{flex:1,padding:"6px 10px",border:"1.5px solid rgba(0,0,0,.1)",borderRadius:8,fontSize:13,outline:"none",fontFamily:"var(--font)",WebkitUserSelect:"text",userSelect:"text"}}/>
                      <button onClick={()=>addFolder(proj.id)} style={{border:"none",background:"#007aff",color:"#fff",borderRadius:8,padding:"6px 10px",cursor:"pointer",fontSize:12,fontWeight:600}}>OK</button>
                    </div>
                  ):(
                    <button className="d-item" style={{paddingLeft:16,fontSize:13,color:"#8e8e93",fontWeight:400}}
                      onClick={()=>{setNewFolderParent(proj.id);setNewFolderName("");}}>
                      <Icon name="folder-plus" size={15} style={{color:"#c7c7cc"}}/> Nova pasta
                    </button>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Topbar */}
      <div className={`topbar${scrolled?" scrolled":""}`}
        style={{transform:drawerOpen?"translateX(272px)":"none",transition:"transform .36s cubic-bezier(.32,1,.56,1), box-shadow .2s"}}>
        <button className="tbtn" onClick={openDrawer}><Icon name="menu" size={22}/></button>
        <div style={{position:"absolute",left:"50%",transform:"translateX(-50%)",fontSize:17,fontWeight:700,color:"#1c1c1e"}}>
          {screen==="trash"?"Lixo":"Documentos"}
        </div>
        {screen==="trash"&&(
          <button className="tbtn" style={{position:"absolute",right:8}} onClick={()=>setScreen("home")}><Icon name="x" size={20}/></button>
        )}
      </div>

      {/* TRASH SCREEN */}
      {screen==="trash"?(
        <div ref={scrollRef} onScroll={handleScroll} className="hscroll noscroll">
          {trashedDocs.length===0?(
            <div className="trash-empty">
              <Icon name="trash-2" size={48} style={{color:"#d1d5db"}} sw={1.5}/>
              <div style={{fontSize:16,fontWeight:600}}>Lixo vazio</div>
              <div style={{fontSize:14}}>Nenhum documento eliminado</div>
            </div>
          ):(
            <>
              <div className="section-lbl">Eliminados recentemente</div>
              <div className="card-group">
                {trashedDocs.map((doc,idx)=>(
                  <div key={doc.id} className="doc-card">
                    <div style={{display:"flex",alignItems:"center",gap:10}}>
                      <TwEmoji cp={doc.emoji||"1f4c4"} size={22}/>
                      <div style={{flex:1,minWidth:0}}>
                        <div style={{fontSize:14,fontWeight:600,color:"#1c1c1e",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{doc.title}</div>
                        <div style={{fontSize:12,color:"#8e8e93"}}>{doc.date}</div>
                      </div>
                      <button onClick={()=>restoreDoc(doc.id)} style={{border:"none",background:"transparent",cursor:"pointer",color:"#007aff",fontSize:13,fontWeight:600,padding:"4px 8px"}}>Restaurar</button>
                      <button onClick={()=>permDelete(doc.id)} style={{border:"none",background:"transparent",cursor:"pointer",color:"#ff3b30",fontSize:13,fontWeight:600,padding:"4px 8px"}}>Apagar</button>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      ):(
      /* HOME CONTENT */
      <div ref={scrollRef} onScroll={handleScroll} className="hscroll noscroll"
        style={{transform:drawerOpen?"translateX(272px)":"none",transition:"transform .36s cubic-bezier(.32,1,.56,1)"}}>

        {/* Search */}
        <div className="search-bar">
          <Icon name="search" size={16} style={{color:"#8e8e93",flexShrink:0}}/>
          <input placeholder="Pesquisar documentos…"
            style={{flex:1,border:"none",outline:"none",fontSize:15,color:"#1c1c1e",background:"transparent",fontFamily:"var(--font)",WebkitUserSelect:"text",userSelect:"text"}}/>
        </div>

        {/* Tags */}
        <div className="tags-row">
          <button className="tag-chip" onClick={()=>setActiveTag(null)}
            style={{background:!activeTag?"#1c1c1e":"#fff",color:!activeTag?"#fff":"#3a3a3c",borderColor:!activeTag?"#1c1c1e":"rgba(0,0,0,.1)"}}>
            Todos
          </button>
          {TAGS.map(t=>(
            <button key={t.id} className="tag-chip" onClick={()=>setActiveTag(activeTag===t.id?null:t.id)}
              style={{background:activeTag===t.id?t.color:"#fff",color:activeTag===t.id?"#fff":t.color,borderColor:activeTag===t.id?t.color:t.bg}}>
              {t.label}
            </button>
          ))}
        </div>

        {/* Doc list */}
        <div className="section-lbl">Recentes</div>
        {visibleDocs.length===0?(
          <div style={{textAlign:"center",padding:"40px 20px",color:"#8e8e93",fontSize:15}}>Nenhum documento</div>
        ):(
          <div className="card-group">
            {visibleDocs.map((doc,idx)=>{
              const isFirst=idx===0, isLast=idx===visibleDocs.length-1;
              const tag=TAGS.find(t=>t.id===doc.tag);
              return(
                <div key={doc.id} className="doc-card" onClick={()=>onOpenEditor(doc)}
                  style={{borderRadius:isFirst&&isLast?"14px":isFirst?"14px 14px 2px 2px":isLast?"2px 2px 14px 14px":"2px"}}>
                  <div style={{display:"flex",alignItems:"flex-start",gap:12}}>
                    {/* Emoji — tap to change */}
                    <div onClick={e=>{e.stopPropagation();setEmojiPicker({target:"doc",id:doc.id});}}
                      style={{width:40,height:40,borderRadius:10,background:"#f2f2f7",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0,cursor:"pointer"}}>
                      <TwEmoji cp={doc.emoji||"1f4c4"} size={24}/>
                    </div>
                    <div style={{flex:1,minWidth:0}}>
                      <div style={{display:"flex",alignItems:"center",gap:6,marginBottom:3}}>
                        <div style={{fontSize:15,fontWeight:600,color:"#1c1c1e",overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap",flex:1}}>{doc.title}</div>
                        {/* Pencil */}
                        <button onClick={e=>{e.stopPropagation();onOpenEditor(doc);}}
                          style={{border:"none",background:"transparent",cursor:"pointer",color:"#8e8e93",padding:4,flexShrink:0,borderRadius:8,transition:"background .12s"}}
                          onPointerOver={e=>e.currentTarget.style.background="rgba(0,0,0,.06)"} onPointerOut={e=>e.currentTarget.style.background="transparent"}>
                          <Icon name="pencil" size={15}/>
                        </button>
                        {/* 3 dots */}
                        <button onClick={e=>{e.stopPropagation();haptic("light");const rect=e.currentTarget.getBoundingClientRect();setCtxMenu({docId:doc.id,x:Math.min(rect.right-220,window.innerWidth-230),y:rect.bottom+6});}}
                          style={{border:"none",background:"transparent",cursor:"pointer",color:"#8e8e93",padding:4,flexShrink:0,borderRadius:8,transition:"background .12s"}}
                          onPointerOver={e=>e.currentTarget.style.background="rgba(0,0,0,.06)"} onPointerOut={e=>e.currentTarget.style.background="transparent"}>
                          <Icon name="more-horizontal" size={16}/>
                        </button>
                      </div>
                      <div style={{fontSize:13,color:"#8e8e93",marginBottom:8,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{doc.preview}</div>
                      <div style={{display:"flex",alignItems:"center",gap:8}}>
                        {tag&&<span style={{padding:"2px 9px",borderRadius:9999,fontSize:11,fontWeight:600,background:tag.bg,color:tag.color}}>{tag.label}</span>}
                        <span style={{fontSize:11,color:"#c7c7cc"}}>{doc.date}</span>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
        <div style={{height:20}}/>
      </div>
      )}

      {/* Context menu */}
      {ctxMenu&&(
        <>
          <div style={{position:"fixed",inset:0,zIndex:9998}} onClick={()=>setCtxMenu(null)}/>
          <div className="ctx-menu" style={{left:ctxMenu.x,top:ctxMenu.y}}>
            <button className="ctx-item" onClick={()=>{onOpenEditor(docs.find(d=>d.id===ctxMenu.docId));setCtxMenu(null);}}>
              <span style={{display:"flex",alignItems:"center",gap:10}}><Icon name="pencil" size={15} style={{color:"rgba(255,255,255,.5)"}}/> Editar</span>
            </button>
            <div className="ctx-sep"/>
            <button className="ctx-item" onClick={()=>{setFolderSheet(ctxMenu.docId);setCtxMenu(null);}}>
              <span style={{display:"flex",alignItems:"center",gap:10}}><Icon name="move" size={15} style={{color:"rgba(255,255,255,.5)"}}/> Mover para pasta</span>
            </button>
            <div className="ctx-sep"/>
            <button className="ctx-item danger" onClick={()=>trashDoc(ctxMenu.docId)}>
              <span style={{display:"flex",alignItems:"center",gap:10}}><Icon name="trash-2" size={15} style={{color:"#ff453a"}}/> Enviar ao lixo</span>
            </button>
          </div>
        </>
      )}

      {/* Folder picker sheet */}
      {folderSheet&&(
        <>
          <div style={{position:"fixed",inset:0,zIndex:199,background:"rgba(0,0,0,.35)",backdropFilter:"blur(4px)",animation:"fadeIn .2s both"}} onClick={()=>setFolderSheet(null)}/>
          <div className="sheet">
            <div style={{width:36,height:4,background:"#e5e5ea",borderRadius:2,margin:"0 auto 16px"}}/>
            <div style={{fontSize:16,fontWeight:700,color:"#1c1c1e",padding:"0 20px 12px",borderBottom:"1px solid rgba(0,0,0,.06)"}}>Mover para pasta</div>
            <div style={{flex:1,overflowY:"auto"}} className="noscroll">
              {projects.map(proj=>(
                <div key={proj.id}>
                  <div style={{padding:"10px 20px 4px",fontSize:12,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",letterSpacing:".06em",display:"flex",alignItems:"center",gap:8}}>
                    <TwEmoji cp={proj.emoji} size={14}/> {proj.name}
                  </div>
                  {proj.folders.map(f=>(
                    <button key={f.id} onClick={()=>moveToFolder(folderSheet,f.id,proj.id)}
                      style={{display:"flex",alignItems:"center",gap:12,padding:"12px 20px",border:"none",background:"transparent",width:"100%",cursor:"pointer",fontFamily:"var(--font)",fontSize:14,color:"#1c1c1e"}}
                      onPointerOver={e=>e.currentTarget.style.background="rgba(0,0,0,.04)"} onPointerOut={e=>e.currentTarget.style.background="transparent"}>
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

      {/* Emoji picker */}
      {emojiPicker&&<EmojiPicker onPick={cp=>setEmojiFor(emojiPicker.target,emojiPicker.id,cp)} onClose={()=>setEmojiPicker(null)}/>}

      {/* Floating bar */}
      <div className="ftb" style={{transform:drawerOpen?"translateX(136px)":"translateX(-50%)",left:drawerOpen?"calc(50% + 0px)":"50%",transition:"transform .36s cubic-bezier(.32,1,.56,1)"}}>
        <button className="circ-btn" onClick={()=>{}}>
          <Icon name="folder" size={21}/>
        </button>
        <div className="pill-wrap" onClick={()=>setAiOpen(true)}>
          <Icon name="sparkles" size={19} style={{color:"#007aff",flexShrink:0}}/>
          <span style={{fontSize:14.5,color:"#8e8e93",flex:1}}>Criar com IA…</span>
        </div>
        <button className="circ-btn" onClick={()=>onOpenEditor({id:Date.now(),title:"",emoji:"1f4c4",aiContent:"",content:""})}>
          <Icon name="plus" size={22}/>
        </button>
      </div>

      {/* AI Sheet */}
      {aiOpen&&(
        <>
          <div className="ai-overlay" onClick={()=>setAiOpen(false)}/>
          <div className="ai-sheet">
            <div className="ai-handle"/>
            <div style={{display:"flex",alignItems:"center",gap:12,marginBottom:16}}>
              <div style={{width:36,height:36,borderRadius:10,background:"#eff6ff",display:"flex",alignItems:"center",justifyContent:"center"}}>
                <Icon name="sparkles" size={18} style={{color:"#007aff"}}/>
              </div>
              <div style={{flex:1}}>
                <div style={{fontSize:15,fontWeight:700,color:"#1c1c1e"}}>Criar com IA</div>
                <div style={{fontSize:13,color:"#8e8e93"}}>Descreve o documento</div>
              </div>
              <button onClick={()=>setAiOpen(false)} style={{border:"none",background:"transparent",cursor:"pointer",color:"#8e8e93",padding:6,borderRadius:9}}>
                <Icon name="x" size={18}/>
              </button>
            </div>
            <textarea ref={aiRef} value={aiInput} onChange={e=>setAiInput(e.target.value)}
              placeholder="Ex: Plano de aula sobre fotossíntese…" rows={4}
              style={{width:"100%",padding:"13px 15px",border:"1.5px solid rgba(0,0,0,.09)",borderRadius:14,fontSize:14.5,fontFamily:"var(--font)",outline:"none",resize:"none",color:"#1c1c1e",background:"#fafaf9",lineHeight:1.6,WebkitUserSelect:"text",userSelect:"text"}}/>
            <button onClick={doAI} disabled={!aiInput.trim()||aiLoading}
              style={{width:"100%",marginTop:12,padding:"14px 0",background:aiInput.trim()&&!aiLoading?"#007aff":"rgba(0,0,0,.07)",color:aiInput.trim()&&!aiLoading?"#fff":"#8e8e93",border:"none",borderRadius:14,cursor:aiInput.trim()&&!aiLoading?"pointer":"default",fontFamily:"var(--font)",fontSize:15,fontWeight:600,display:"flex",alignItems:"center",justifyContent:"center",gap:8,transition:"background .2s"}}>
              {aiLoading?"A criar…":<><Icon name="send" size={15}/>Criar documento</>}
            </button>
          </div>
        </>
      )}
    </div>
  );
}

/* ══════════════════════════════════════════════════════════
   EDITOR SCREEN
═══════════════════════════════════════════════════════════ */
function EditorScreen({visible,doc,onBack}){
  const [aiMode,setAiMode]=useState(false);
  const [aiLoading,setAiLoading]=useState(false);
  const [aiInput,setAiInput]=useState("");
  const [curFont,setCurFont]=useState("'Lora',Georgia,serif");
  const [fontLabel,setFontLabel]=useState("Lora");
  const [curSz,setCurSz]=useState(16);
  const [szPv,setSzPv]=useState(16);
  const [colorBar,setColorBar]=useState("#d97706");
  const [focused,setFocused]=useState(false);
  const [activePopup,setActivePopup]=useState(null);
  const [popupPos,setPopupPos]=useState({left:0,bottom:0,origX:0,w:240,arrLeft:0});
  const [selVisible,setSelVisible]=useState(false);
  const [selPos,setSelPos]=useState({left:0,top:0,ax:0,dir:"down",mw:480});
  const [emptyMenu,setEmptyMenu]=useState(null);
  const [ffOpen,setFfOpen]=useState(false);
  const [ffSearch,setFfSearch]=useState("");
  const [ffCat,setFfCat]=useState("Todas");
  const [ffSel,setFfSel]=useState(null);
  const [fontSearch,setFontSearch]=useState("");
  const [fontPreview,setFontPreview]=useState(null);
  const [hexIn,setHexIn]=useState("#34322d");
  const [hexPv,setHexPv]=useState("#34322d");
  const [alignActive,setAlignActive]=useState("L");
  const [imgMenu,setImgMenu]=useState(null);
  const [scrolled,setScrolled]=useState(false);

  const edRef=useRef(null);
  const savedRange=useRef(null);
  const canvasRef=useRef(null);
  const wrapRef=useRef(null);
  const aiRef=useRef(null);
  const longPressTimer=useRef(null);
  const pinchState=useRef(null);
  const initDone=useRef(false);

  useEffect(()=>{
    if(edRef.current&&doc&&visible&&!initDone.current){
      if(doc.content){edRef.current.innerHTML=doc.content;}
      else if(doc.aiContent){edRef.current.innerHTML=doc.aiContent;}
      initDone.current=true;
    }
    if(!visible) initDone.current=false;
  },[doc,visible]);

  const zoom=useCallback(()=>{
    if(!canvasRef.current||!wrapRef.current)return;
    const avail=canvasRef.current.clientWidth-32;
    const sc=avail<794?avail/794:1;
    if(sc<1){wrapRef.current.style.transform=`scale(${sc})`;wrapRef.current.style.transformOrigin="top center";wrapRef.current.style.marginBottom=`${(sc-1)*1123}px`;}
    else{wrapRef.current.style.transform="none";wrapRef.current.style.marginBottom="0";}
  },[]);
  useEffect(()=>{zoom();window.addEventListener("resize",zoom);return()=>window.removeEventListener("resize",zoom);},[zoom]);
  useEffect(()=>{if(!canvasRef.current)return;const ro=new ResizeObserver(zoom);ro.observe(canvasRef.current);return()=>ro.disconnect();},[zoom]);

  const saveSel=useCallback(()=>{const s=window.getSelection();if(s&&s.rangeCount>0&&!s.isCollapsed)savedRange.current=s.getRangeAt(0).cloneRange();},[]);
  const restoreSel=useCallback(()=>{if(!savedRange.current){edRef.current?.focus();return;}edRef.current?.focus();try{const s=window.getSelection();s.removeAllRanges();s.addRange(savedRange.current);}catch(_){};},[]);
  const exec=useCallback((cmd,val)=>{restoreSel();document.execCommand(cmd,false,val||null);saveSel();},[restoreSel,saveSel]);

  const tryShowSel=useCallback(()=>{
    const s=window.getSelection();
    if(!s||s.isCollapsed||!s.toString().trim()){setSelVisible(false);return;}
    const r=s.getRangeAt(0).getBoundingClientRect();
    if(!r.width&&!r.height){setSelVisible(false);return;}
    const GAP=10,AH=7,MH=44,vw=window.innerWidth,vh=window.innerHeight;
    const mw=Math.min(vw-16,480);
    let left=r.left+r.width/2-mw/2;left=Math.max(8,Math.min(vw-mw-8,left));
    const ax=Math.max(16,Math.min(mw-16,r.left+r.width/2-left));
    const spA=r.top-GAP-AH-MH,spB=vh-r.bottom-GAP-AH-MH;
    let top,dir;
    if(spA>=0){top=r.top-MH-GAP-AH;dir="down";}
    else if(spB>=0){top=r.bottom+GAP+AH;dir="up";}
    else if(spA>spB){top=Math.max(8,r.top-MH-GAP-AH);dir="down";}
    else{top=r.bottom+GAP+AH;dir="up";}
    setSelPos({left,top,ax,dir,mw});setSelVisible(true);
  },[]);

  const handlePointerDown=useCallback((e)=>{
    if(e.target.closest&&e.target.closest(".img-wrap"))return;
    const cx=e.clientX??e.touches?.[0]?.clientX;
    const cy=e.clientY??e.touches?.[0]?.clientY;
    clearTimeout(longPressTimer.current);
    longPressTimer.current=setTimeout(()=>{
      const s=window.getSelection();
      let mx=cx,my=cy;
      if(s&&s.rangeCount>0&&s.isCollapsed){const rect=s.getRangeAt(0).getBoundingClientRect();if(rect.width||rect.height){mx=rect.left;my=rect.bottom;}}
      haptic("medium");
      const vw=window.innerWidth,vh=window.innerHeight,mw=200;
      let left=mx-mw/2;left=Math.max(8,Math.min(vw-mw-8,left));
      const ax=Math.max(16,Math.min(mw-16,mx-left));
      const MH=44,GAP=10,AH=7,spB=vh-my-GAP-AH-MH;
      let top,dir;
      if(spB>=0){top=my+GAP+AH;dir="up";}else{top=Math.max(8,my-MH-GAP-AH);dir="down";}
      setEmptyMenu({left,top,ax,dir,mw});
    },800);
  },[]);
  const handlePointerUp=useCallback(()=>clearTimeout(longPressTimer.current),[]);

  const closePopup=useCallback(()=>{setActivePopup(null);setFontPreview(null);setFontSearch("");},[]);
  const openPopup=useCallback((type,trig)=>{
    if(activePopup===type){closePopup();return;}
    saveSel();
    const wMap={"color-text":250,font:240,size:220,styles:200,insert:240,format:220};
    const w=wMap[type]||240;
    const r=trig.getBoundingClientRect();
    let left=r.left+r.width/2-w/2;left=Math.max(8,Math.min(window.innerWidth-w-8,left));
    const bottom=window.innerHeight-r.top+12;
    const origX=Math.max(20,Math.min(w-20,r.left+r.width/2-left));
    const arrLeft=Math.max(12,Math.min(w-24,r.left+r.width/2-left-7));
    setPopupPos({left,bottom,origX,w,arrLeft});setActivePopup(type);
  },[activePopup,closePopup,saveSel]);

  useEffect(()=>{if(aiMode&&aiRef.current)setTimeout(()=>aiRef.current?.focus(),80);},[aiMode]);

  const doAI=async()=>{
    const p=aiInput.trim();if(!p)return;
    setAiInput("");setAiLoading(true);
    try{const r=await fetch("https://api.anthropic.com/v1/messages",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:"claude-sonnet-4-20250514",max_tokens:1000,system:"Responde APENAS com o texto a inserir no editor, sem explicações. Responde em português.",messages:[{role:"user",content:p}]})});const d=await r.json();restoreSel();exec("insertText",d.content?.map(i=>i.text||"").join("")||"");}catch{restoreSel();exec("insertText","[Erro IA]");}
    setAiLoading(false);setTimeout(()=>aiRef.current?.focus(),50);
  };

  const wrapImage=useCallback((img)=>{
    if(img.parentElement?.classList.contains("img-wrap"))return;
    const wrap=document.createElement("span");wrap.className="img-wrap";wrap.contentEditable="false";wrap.style.cssText="display:inline-block;position:relative;cursor:pointer;line-height:0;max-width:100%";
    img.parentNode.insertBefore(wrap,img);wrap.appendChild(img);
    const btn=document.createElement("button");btn.className="img-dots-btn";btn.innerHTML=`<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>`;btn.style.display="none";wrap.appendChild(btn);
    const rh=document.createElement("div");rh.className="resize-handle";rh.style.display="none";wrap.appendChild(rh);
    wrap.addEventListener("click",e=>{e.stopPropagation();e.preventDefault();haptic("light");document.querySelectorAll(".img-wrap.selected").forEach(w=>{if(w!==wrap){w.classList.remove("selected");const b=w.querySelector(".img-dots-btn"),r=w.querySelector(".resize-handle");if(b)b.style.display="none";if(r)r.style.display="none";}});wrap.classList.add("selected");btn.style.display="flex";rh.style.display="flex";});
    btn.addEventListener("click",e=>{e.stopPropagation();haptic("medium");const rect=btn.getBoundingClientRect();setImgMenu({pos:{x:Math.min(rect.right+8,window.innerWidth-210),y:rect.bottom+6},el:wrap,img});});
    rh.addEventListener("mousedown",e=>{e.preventDefault();e.stopPropagation();const startX=e.clientX,startW=img.offsetWidth;const mv=me=>{img.style.width=Math.max(40,startW+(me.clientX-startX))+"px";img.style.height="auto";};const up=()=>{window.removeEventListener("mousemove",mv);window.removeEventListener("mouseup",up);};window.addEventListener("mousemove",mv);window.addEventListener("mouseup",up);});
    wrap.addEventListener("touchstart",e=>{if(e.touches.length===2){e.preventDefault();const d=Math.hypot(e.touches[0].clientX-e.touches[1].clientX,e.touches[0].clientY-e.touches[1].clientY);pinchState.current={startDist:d,startW:img.offsetWidth};}},{passive:false});
    wrap.addEventListener("touchmove",e=>{if(e.touches.length===2&&pinchState.current){e.preventDefault();const d=Math.hypot(e.touches[0].clientX-e.touches[1].clientX,e.touches[0].clientY-e.touches[1].clientY);img.style.width=Math.max(40,pinchState.current.startW*(d/pinchState.current.startDist))+"px";img.style.height="auto";}},{passive:false});
    wrap.addEventListener("touchend",()=>{pinchState.current=null;});
  },[]);
  useEffect(()=>{const ed=edRef.current;if(!ed)return;const obs=new MutationObserver(()=>ed.querySelectorAll("img").forEach(img=>wrapImage(img)));obs.observe(ed,{childList:true,subtree:true});return()=>obs.disconnect();},[wrapImage]);
  useEffect(()=>{const h=e=>{if(!e.target.closest(".img-wrap")&&!e.target.closest(".ctx-menu")){document.querySelectorAll(".img-wrap.selected").forEach(w=>{w.classList.remove("selected");const b=w.querySelector(".img-dots-btn"),r=w.querySelector(".resize-handle");if(b)b.style.display="none";if(r)r.style.display="none";});setImgMenu(null);}};document.addEventListener("click",h);return()=>document.removeEventListener("click",h);},[]);

  const handleImgAction=(action,el,img)=>{haptic("light");if(action==="delete"){el.parentNode?.removeChild(el);}else if(action==="inline"){img.style.float="none";img.style.display="inline";img.style.margin="";}else if(action==="center"){img.style.float="none";img.style.display="block";img.style.margin="8px auto";}else if(action==="float-left"){img.style.float="left";img.style.margin="4px 12px 4px 0";}else if(action==="float-right"){img.style.float="right";img.style.margin="4px 0 4px 12px";}};
  const insertImg=()=>{closePopup();const fi=document.createElement("input");fi.type="file";fi.accept="image/*";fi.onchange=e=>{const f=e.target.files[0];if(!f)return;const rd=new FileReader();rd.onload=ev=>exec("insertHTML",`<img src="${ev.target.result}" style="max-width:100%;height:auto"/>`);rd.readAsDataURL(f);};fi.click();};
  const insertTable=()=>{let h='<table style="border-collapse:collapse;width:100%;margin:8px 0"><tbody>';for(let i=0;i<3;i++){h+="<tr>";for(let j=0;j<3;j++)h+='<td style="border:1.5px solid #ccc;padding:6px 10px;min-width:40px">&nbsp;</td>';h+="</tr>";}h+="</tbody></table><p></p>";exec("insertHTML",h);closePopup();};
  const applySize=sz=>{setSzPv(sz);setCurSz(sz);restoreSel();const s=window.getSelection();if(!s||!s.rangeCount)return;const r=s.getRangeAt(0);if(s.isCollapsed){if(edRef.current)edRef.current.style.fontSize=sz+"px";return;}const fr=r.extractContents();const sp=document.createElement("span");sp.style.fontSize=sz+"px";sp.appendChild(fr);r.insertNode(sp);const nr=document.createRange();nr.selectNodeContents(sp);s.removeAllRanges();s.addRange(nr);savedRange.current=nr.cloneRange();};

  const renderPopup=()=>{
    switch(activePopup){
      case"color-text":return<ColorPopup colors={COLORS} hexIn={hexIn} setHexIn={setHexIn} hexPv={hexPv} setHexPv={setHexPv} onApply={c=>{exec("foreColor",c);setColorBar(c);closePopup();}}/>;
      case"font":return<FontPopup fonts={FONTS} curFont={curFont} search={fontSearch} setSearch={setFontSearch} preview={fontPreview} setPreview={setFontPreview} onExpand={()=>{closePopup();setFfOpen(true);}} onApply={f=>{setCurFont(f.v);setFontLabel(f.l);exec("fontName",f.l);closePopup();}}/>;
      case"size":return<SizePopup szPv={szPv} onApply={sz=>{applySize(sz);closePopup();}} onStep={d=>{const n=Math.max(6,Math.min(200,szPv+d));applySize(n);}}/>;
      case"styles":return<StylesPopup exec={exec} onClose={closePopup}/>;
      case"insert":return<InsertPopup exec={exec} onClose={closePopup} insertImg={insertImg} insertTable={insertTable}/>;
      case"format":return<FormatPopup exec={exec} onClose={closePopup} edRef={edRef} restoreSel={restoreSel}/>;
      default:return null;
    }
  };

  const selActions=[
    {l:"Cortar",ic:"scissors",fn:async()=>{const s=window.getSelection();if(s&&!s.isCollapsed){try{await navigator.clipboard.writeText(s.toString())}catch(_){}exec("delete");}setSelVisible(false);}},
    {l:"Copiar",ic:"copy",fn:async()=>{const s=window.getSelection();if(s&&!s.isCollapsed){try{await navigator.clipboard.writeText(s.toString())}catch(_){document.execCommand("copy");}}setSelVisible(false);}},
    {l:"Colar",ic:"clipboard",fn:async()=>{setSelVisible(false);try{const t=await navigator.clipboard.readText();restoreSel();exec("insertText",t);}catch(_){edRef.current?.focus();}}},
    {l:"Sel. tudo",ic:"check-square",fn:()=>{edRef.current?.focus();document.execCommand("selectAll");setSelVisible(false);setTimeout(tryShowSel,80);}},
    {l:"Negrito",ic:"bold",fn:()=>{exec("bold");setSelVisible(false);}},
    {l:"Itálico",ic:"italic",fn:()=>{exec("italic");setSelVisible(false);}},
    {l:"Sublinhado",ic:"underline",fn:()=>{exec("underline");setSelVisible(false);}},
    {l:"Link",ic:"link",fn:()=>{setSelVisible(false);const u=prompt("URL:");if(u)exec("createLink",u);}},
    {l:"Apagar",ic:"trash-2",fn:()=>{exec("delete");setSelVisible(false);},danger:true},
  ];
  const emptyActions=[
    {l:"Colar",ic:"clipboard",fn:async()=>{setEmptyMenu(null);try{const t=await navigator.clipboard.readText();restoreSel();exec("insertText",t);}catch(_){edRef.current?.focus();}}},
    {l:"Inserir",ic:"plus",fn:()=>{setEmptyMenu(null);const chip=document.querySelector("[data-chip='insert']");if(chip)openPopup("insert",chip);}},
  ];

  return(
    <div className={`screen ${visible?"edit-vis":"edit-hid"}`}>
      {/* Topbar */}
      <div className={`topbar${scrolled?" scrolled":""}`}>
        <button className="tbtn" onClick={onBack}><Icon name="arrow-left" size={22}/></button>
        <div contentEditable spellCheck={false} suppressContentEditableWarning className="tt"
          style={{position:"absolute",left:"50%",transform:"translateX(-50%)",fontSize:16,fontWeight:700,color:"#1c1c1e",whiteSpace:"nowrap",overflow:"hidden",textOverflow:"ellipsis",maxWidth:"calc(100% - 160px)",cursor:"text",padding:"4px 8px",borderRadius:8,border:"1.5px solid transparent",outline:"none",transition:"all .15s",fontFamily:"var(--font)",WebkitUserSelect:"text",userSelect:"text"}}
          onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();e.currentTarget.blur();}}}
          dangerouslySetInnerHTML={{__html:doc?.title||""}}/>
        <div style={{position:"absolute",right:6,display:"flex",gap:2}}>
          {[["undo-2","undo"],["redo-2","redo"]].map(([ic,cmd])=>(
            <button key={cmd} className="tbtn" onClick={()=>exec(cmd)}><Icon name={ic} size={19}/></button>
          ))}
        </div>
      </div>

      {/* Canvas */}
      <div ref={canvasRef} className="canvas noscroll"
        onScroll={e=>setScrolled(e.currentTarget.scrollTop>4)}
        onClick={e=>{setEmptyMenu(null);if(!e.target.closest(".pc")){savedRange.current=null;window.getSelection()?.removeAllRanges();setSelVisible(false);}}}>
        <div ref={wrapRef} className="pw">
          <div className={`page${focused?" focused":""}`}>
            <div ref={edRef} className="pc" contentEditable spellCheck data-placeholder="Começa a escrever…"
              onFocus={()=>setFocused(true)} onBlur={()=>setFocused(false)}
              onMouseUp={()=>setTimeout(()=>{saveSel();tryShowSel();},20)}
              onTouchEnd={()=>setTimeout(()=>{saveSel();tryShowSel();},120)}
              onKeyUp={saveSel}
              onPointerDown={handlePointerDown} onPointerUp={handlePointerUp} onPointerCancel={handlePointerUp}
              onContextMenu={e=>{e.preventDefault();saveSel();tryShowSel();}}
            />
          </div>
        </div>
      </div>

      {/* Editor floating toolbar */}
      <nav style={{position:"fixed",left:"50%",transform:"translateX(-50%)",bottom:"max(14px,env(safe-area-inset-bottom,14px))",width:"min(96vw,490px)",zIndex:20}}>
        <div className={`ed-pill${aiMode?" ai-mode":""}`}>
          {aiMode?(
            <div style={{display:"flex",alignItems:"center",gap:8,padding:"0 16px",flex:1,minWidth:0}}>
              <Icon name="sparkles" size={17} style={{color:"#007aff",flexShrink:0}}/>
              <input ref={aiRef} value={aiInput} onChange={e=>setAiInput(e.target.value)}
                onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();doAI();}}}
                placeholder="Pergunta à IA…"
                style={{flex:1,border:"none",background:"transparent",fontFamily:"var(--font)",fontSize:14,color:"#1c1c1e",outline:"none",WebkitUserSelect:"text",userSelect:"text"}}/>
            </div>
          ):(
            <div className="tbtrack noscroll">
              <TbBtn onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("color-text",e.currentTarget)}>
                <span style={{fontSize:16,fontWeight:900,lineHeight:1}}>A</span>
                <div style={{width:16,height:3,borderRadius:2,background:colorBar}}/>
              </TbBtn>
              <Div2/>
              {[["bold","B",900,"normal","none"],["italic","I",600,"italic","none"],["underline","U",600,"normal","underline"],["strikeThrough","S",600,"normal","line-through"]].map(([cmd,lbl,fw,fs,td])=>(
                <TbBtn key={cmd} onMouseDown={e=>e.preventDefault()} onClick={()=>exec(cmd)}>
                  <span style={{fontSize:16,fontWeight:fw,fontStyle:fs,textDecoration:td,lineHeight:1}}>{lbl}</span>
                </TbBtn>
              ))}
              <Div2/>
              <TbChip onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("font",e.currentTarget)} active={activePopup==="font"}>{fontLabel}<Icon name="chevron-down" size={11}/></TbChip>
              <TbChip style={{marginLeft:3}} onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("size",e.currentTarget)} active={activePopup==="size"}>{curSz}<Icon name="chevron-down" size={11}/></TbChip>
              <Div2/>
              <TbChip onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("styles",e.currentTarget)} active={activePopup==="styles"}>Estilos<Icon name="chevron-down" size={11}/></TbChip>
              <Div2/>
              {[["L","align-left","justifyLeft"],["C","align-center","justifyCenter"],["R","align-right","justifyRight"],["J","align-justify","justifyFull"]].map(([id,ic,cmd])=>(
                <TbBtn key={id} active={alignActive===id} onMouseDown={e=>e.preventDefault()} onClick={()=>{setAlignActive(id);exec(cmd);}}><Icon name={ic} size={17}/></TbBtn>
              ))}
              <Div2/>
              {[["list","insertUnorderedList"],["list-ordered","insertOrderedList"],["indent","indent"],["outdent","outdent"]].map(([ic,cmd])=>(
                <TbBtn key={ic} onMouseDown={e=>e.preventDefault()} onClick={()=>exec(cmd)}><Icon name={ic} size={17}/></TbBtn>
              ))}
              <Div2/>
              <TbChip data-chip="insert" onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("insert",e.currentTarget)} active={activePopup==="insert"}>Inserir<Icon name="plus" size={11}/></TbChip>
              <Div2/>
              <TbChip onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("format",e.currentTarget)} active={activePopup==="format"}>Formatar<Icon name="settings-2" size={11}/></TbChip>
              <Div2/>
              <TbBtn onMouseDown={e=>e.preventDefault()} onClick={()=>setAiMode(true)} style={{background:"#eff6ff",color:"#007aff"}}>
                <Icon name="sparkles" size={16}/>
              </TbBtn>
            </div>
          )}
          <button onMouseDown={e=>e.preventDefault()}
            onClick={()=>{if(aiMode){if(!aiLoading)doAI();}else{closePopup();edRef.current?.focus();}}}
            style={{width:40,height:40,flexShrink:0,borderRadius:"50%",border:aiMode&&!aiLoading?"none":"1.5px solid rgba(0,0,0,.08)",background:aiMode&&!aiLoading?"#007aff":"#fff",color:aiMode&&!aiLoading?"#fff":"#5e5e5b",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",marginRight:6,marginLeft:2,zIndex:3,transition:"all .2s"}}>
            {aiLoading?<div style={{display:"flex",gap:3}}><div className="aidot"/><div className="aidot"/><div className="aidot"/></div>:aiMode?<Icon name="send" size={15}/>:<Icon name="check" size={15} sw={2.6}/>}
          </button>
        </div>
        {aiMode&&<button onMouseDown={e=>e.preventDefault()} onClick={()=>{setAiMode(false);setAiInput("");}}
          style={{position:"absolute",right:-44,top:"50%",transform:"translateY(-50%)",width:36,height:36,borderRadius:"50%",border:"1.5px solid rgba(0,0,0,.08)",background:"#fff",color:"#5e5e5b",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",boxShadow:"0 2px 8px rgba(0,0,0,.08)"}}>
          <Icon name="x" size={15}/>
        </button>}
      </nav>

      {/* Selection menu */}
      {selVisible&&(
        <div className={`sel-menu${selPos.dir==="down"?" adown":" aup"}`} style={{left:selPos.left,top:selPos.top,width:selPos.mw,"--ax":selPos.ax+"px"}} onMouseDown={e=>e.preventDefault()}>
          <div className="sel-inner noscroll">
            {selActions.map(a=><button key={a.l} onClick={a.fn} onMouseDown={e=>e.preventDefault()}
              style={{flexShrink:0,padding:"10px 13px",border:"none",background:"transparent",color:a.danger?"#ff453a":"#fff",fontFamily:"var(--font)",fontSize:12.5,fontWeight:500,cursor:"pointer",borderRight:"1px solid rgba(255,255,255,.1)",whiteSpace:"nowrap",display:"flex",alignItems:"center",gap:5}}>
              <Icon name={a.ic} size={13}/>{a.l}
            </button>)}
          </div>
        </div>
      )}

      {/* Long press menu */}
      {emptyMenu&&(
        <div className={`sel-menu${emptyMenu.dir==="down"?" adown":" aup"}`} style={{left:emptyMenu.left,top:emptyMenu.top,width:emptyMenu.mw,"--ax":emptyMenu.ax+"px"}} onMouseDown={e=>e.preventDefault()}>
          <div className="sel-inner noscroll">
            {emptyActions.map(a=><button key={a.l} onClick={a.fn} onMouseDown={e=>e.preventDefault()}
              style={{flexShrink:0,padding:"11px 20px",border:"none",background:"transparent",color:"#fff",fontFamily:"var(--font)",fontSize:13.5,fontWeight:500,cursor:"pointer",borderRight:"1px solid rgba(255,255,255,.12)",whiteSpace:"nowrap",display:"flex",alignItems:"center",gap:7}}>
              <Icon name={a.ic} size={14}/>{a.l}
            </button>)}
          </div>
        </div>
      )}

      {/* Image menu */}
      {imgMenu&&(<><div style={{position:"fixed",inset:0,zIndex:9998}} onClick={()=>setImgMenu(null)}/><ImgCtxMenu pos={imgMenu.pos} onClose={()=>setImgMenu(null)} onAction={action=>handleImgAction(action,imgMenu.el,imgMenu.img)}/></>)}

      {/* Popup */}
      {activePopup&&<div onMouseDown={closePopup} style={{position:"fixed",inset:0,zIndex:99,background:"transparent"}}/>}
      {activePopup&&(
        <div className="pop" style={{width:popupPos.w,left:popupPos.left,bottom:popupPos.bottom,transformOrigin:`${popupPos.origX}px calc(100% + 14px)`}}>
          <div className="pop-inner">{renderPopup()}</div>
          <div className="pop-arrow" style={{left:popupPos.arrLeft}}/>
        </div>
      )}

      {/* Fullscreen font */}
      {ffOpen&&(
        <div className="ff">
          <div style={{height:56,display:"flex",alignItems:"center",gap:10,padding:"0 16px",borderBottom:"1px solid rgba(0,0,0,.06)",flexShrink:0}}>
            <span style={{fontSize:16,fontWeight:700,color:"#1c1c1e",flexShrink:0}}>Fontes</span>
            <input value={ffSearch} onChange={e=>setFfSearch(e.target.value)} placeholder="Pesquisar fonte…" onMouseDown={e=>e.stopPropagation()}
              style={{flex:1,height:36,border:"1.5px solid rgba(0,0,0,.08)",borderRadius:9999,padding:"0 14px",fontSize:13,fontFamily:"var(--font)",outline:"none",background:"#f2f2f7",WebkitUserSelect:"text",userSelect:"text"}}/>
            <button onClick={()=>setFfOpen(false)} style={{width:36,height:36,border:"none",background:"transparent",cursor:"pointer",borderRadius:9,display:"flex",alignItems:"center",justifyContent:"center",color:"#8e8e93"}}><Icon name="x" size={17}/></button>
          </div>
          <div className="noscroll" style={{display:"flex",gap:6,padding:"10px 16px",borderBottom:"1px solid rgba(0,0,0,.06)",overflowX:"auto",flexShrink:0}}>
            {["Todas",...new Set(FONTS.map(f=>f.g))].map(cat=>(
              <button key={cat} onClick={()=>setFfCat(cat)} style={{flexShrink:0,padding:"5px 13px",border:`1.5px solid ${ffCat===cat?"#007aff":"rgba(0,0,0,.08)"}`,borderRadius:9999,fontFamily:"var(--font)",fontSize:12,fontWeight:600,cursor:"pointer",background:ffCat===cat?"#e8f0fe":"transparent",color:ffCat===cat?"#007aff":"#5e5e5b"}}>{cat}</button>
            ))}
          </div>
          <div className="noscroll" style={{flex:1,overflowY:"auto",display:"grid",gap:8,padding:16,gridTemplateColumns:"repeat(auto-fill,minmax(140px,1fr))"}}>
            {FONTS.filter(f=>(!ffSearch||f.l.toLowerCase().includes(ffSearch.toLowerCase()))&&(ffCat==="Todas"||f.g===ffCat)).map(f=>(
              <div key={f.v} onClick={()=>setFfSel(f.v)} style={{border:`1.5px solid ${ffSel===f.v?"#007aff":"rgba(0,0,0,.08)"}`,borderRadius:12,padding:"10px 12px",cursor:"pointer",background:ffSel===f.v?"#e8f0fe":"#fff"}}>
                <div style={{fontSize:10,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",marginBottom:4}}>{f.g}</div>
                <div style={{fontSize:20,color:"#34322d",lineHeight:1.2,fontFamily:f.v}}>Aa Bb</div>
                <div style={{fontSize:10,color:"#5e5e5b",marginTop:4}}>{f.l}</div>
              </div>
            ))}
          </div>
          <div style={{padding:"12px 16px",borderTop:"1px solid rgba(0,0,0,.06)",flexShrink:0}}>
            <button disabled={!ffSel} onClick={()=>{const f=FONTS.find(x=>x.v===ffSel);if(f){setCurFont(f.v);setFontLabel(f.l);exec("fontName",f.l);setFfOpen(false);}}}
              style={{width:"100%",padding:"14px 0",background:ffSel?"#007aff":"rgba(0,0,0,.07)",color:ffSel?"#fff":"#8e8e93",border:"none",borderRadius:14,cursor:ffSel?"pointer":"default",fontFamily:"var(--font)",fontSize:15,fontWeight:600}}>
              {ffSel?`Aplicar "${FONTS.find(f=>f.v===ffSel)?.l}"`:"Aplicar fonte"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/* ══════════════════════════════════════════════════════════
   ROOT
═══════════════════════════════════════════════════════════ */
export default function App(){
  const [screen,setScreen]=useState("home");
  const [activeDoc,setActiveDoc]=useState(null);
  const [docs,setDocs]=useState(INIT_DOCS);
  const [projects,setProjects]=useState(INIT_PROJECTS);
  const [trash,setTrash]=useState([]);

  useEffect(()=>{
    const s=document.createElement("style");
    s.textContent=CSS;
    document.head.appendChild(s);
    return()=>document.head.removeChild(s);
  },[]);

  const openEditor=(doc)=>{setActiveDoc(doc);setScreen("editor");};
  const goHome=()=>setScreen("home");

  return(
    <div style={{position:"relative",width:"100%",height:"100%",overflow:"hidden",background:"#f2f2f7"}}>
      <HomeScreen visible={screen==="home"} docs={docs} setDocs={setDocs}
        projects={projects} setProjects={setProjects}
        trash={trash} setTrash={setTrash} onOpenEditor={openEditor}/>
      <EditorScreen visible={screen==="editor"} doc={activeDoc} onBack={goHome}/>
    </div>
  );
}