import { useState, useEffect, useRef, useCallback } from "react";
import { useCustomSelection } from "./hooks/useCustomSelection";  // ← NOVO

// ── INLINE SVG ICONS ──────────────────────────────────────
const IC = {
  menu:`<line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/>`,
  "undo-2":`<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>`,
  "redo-2":`<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>`,
  keyboard:`<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8"/>`,
  bot:`<path d="M12 8V4H8"/><rect x="8" y="8" width="8" height="8" rx="1"/><path d="M19 8h2v8h-2M3 8h2v8H3M9 19v2M15 19v2"/>`,
  check:`<path d="M20 6 9 17l-5-5"/>`,
  send:`<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>`,
  "chevron-down":`<path d="m6 9 6 6 6-6"/>`,
  "align-left":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="15" y1="12" x2="3" y2="12"/><line x1="17" y1="18" x2="3" y2="18"/>`,
  "align-center":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="17" y1="12" x2="7" y2="12"/><line x1="19" y1="18" x2="5" y2="18"/>`,
  "align-right":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="12" x2="9" y2="12"/><line x1="21" y1="18" x2="7" y2="18"/>`,
  "align-justify":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="12" x2="3" y2="12"/><line x1="21" y1="18" x2="3" y2="18"/>`,
  list:`<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>`,
  "list-ordered":`<line x1="10" y1="6" x2="21" y2="6"/><line x1="10" y1="12" x2="21" y2="12"/><line x1="10" y1="18" x2="21" y2="18"/><path d="M4 6h1v4M4 10h2M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/>`,
  indent:`<polyline points="3 8 7 12 3 16"/><line x1="21" y1="12" x2="11" y2="12"/><line x1="21" y1="6" x2="11" y2="6"/><line x1="21" y1="18" x2="11" y2="18"/>`,
  outdent:`<polyline points="7 8 3 12 7 16"/><line x1="21" y1="12" x2="11" y2="12"/><line x1="21" y1="6" x2="11" y2="6"/><line x1="21" y1="18" x2="11" y2="18"/>`,
  plus:`<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>`,
  "settings-2":`<path d="M20 7h-9M14 17H5"/><circle cx="17" cy="17" r="3"/><circle cx="7" cy="7" r="3"/>`,
  scissors:`<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><line x1="20" y1="4" x2="8.12" y2="15.88"/><line x1="14.47" y1="14.48" x2="20" y2="20"/><line x1="8.12" y1="8.12" x2="12" y2="12"/>`,
  copy:`<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>`,
  clipboard:`<rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>`,
  "check-square":`<polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>`,
  bold:`<path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/>`,
  italic:`<line x1="19" y1="4" x2="10" y2="4"/><line x1="14" y1="20" x2="5" y2="20"/><line x1="15" y1="4" x2="9" y2="20"/>`,
  underline:`<path d="M6 4v6a6 6 0 0 0 12 0V4"/><line x1="4" y1="20" x2="20" y2="20"/>`,
  "case-upper":`<path d="m3 15 4-8 4 8"/><path d="M4 13h6"/><path d="M15 11h4.5a2 2 0 0 1 0 4H15V7h4a2 2 0 0 1 0 4"/>`,
  link:`<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>`,
  "trash-2":`<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/>`,
  "maximize-2":`<polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/>`,
  x:`<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>`,
  pilcrow:`<path d="M13 4v16"/><path d="M17 4v16"/><path d="M19 4H9.5a4.5 4.5 0 0 0 0 9H13"/>`,
  "heading-1":`<path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M21 18v-7l-2 2"/>`,
  "heading-2":`<path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M21 7c0-1.657-1.343-3-3-3s-3 1.343-3 3c0 4 6 6 6 6"/><path d="M15 18h6"/>`,
  "heading-3":`<path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M17.5 10.5c1.667-1 5.5 0 5.5 2.5s-2 3-3.5 3c1.5 0 3.5 1.5 3.5 3s-3.333 3.5-5 2.5"/>`,
  "heading-4":`<path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M17 10v4h4"/><path d="M21 10v12"/>`,
  quote:`<path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V20c0 1 0 1 1 1z"/><path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z"/>`,
  code:`<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>`,
  "alert-triangle":`<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>`,
  info:`<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>`,
  "check-circle":`<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>`,
  "x-circle":`<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>`,
  minus:`<line x1="5" y1="12" x2="19" y2="12"/>`,
  calendar:`<rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>`,
  "case-lower":`<path d="M7 20v-4a4 4 0 0 1 8 0v4"/><path d="M3 20a2 2 0 0 0 2-2V4"/><path d="M21 20a2 2 0 0 1-2-2V4"/>`,
  "case-sensitive":`<path d="m3 15 4-8 4 8"/><path d="M4 13h6"/><path d="M15 8h4.5a2 2 0 0 1 0 4H15V4"/><path d="M19 20v.01"/><path d="M19 17a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"/>`,
  superscript:`<path d="m4 19 8-8"/><path d="m12 19-8-8"/><path d="M20 12h-4c0-1.5.442-2 1.5-2.5S20 8.334 20 7.002c0-.472-.17-.93-.484-1.29a2.105 2.105 0 0 0-2.617-.436c-.42.239-.738.614-.899 1.06"/>`,
  subscript:`<path d="m4 5 8 8"/><path d="m12 5-8 8"/><path d="M20 19h-4c0-1.5.44-2 1.5-2.5S20 15.33 20 14c0-.47-.17-.93-.484-1.29a2.1 2.1 0 0 0-2.617-.436c-.42.24-.738.614-.899 1.06"/>`,
  "align-vertical-justify-start":`<rect x="2" y="2" width="20" height="5" rx="2"/><rect x="2" y="12" width="20" height="5" rx="2"/><path d="M2 22h20"/>`,
  table:`<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/>`,
  "file-text":`<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8M16 13H8M16 17H8"/>`,
  layout:`<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 21V9"/>`,
};

const Icon = ({ name, size=18, sw=2, style, className }) => (
  <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
    style={style} className={className}
    dangerouslySetInnerHTML={{ __html: IC[name] || "" }}
  />
);

const FONTS = [
  {l:"Lora",v:"'Lora',Georgia,serif",g:"Serif"},{l:"Playfair Display",v:"'Playfair Display',serif",g:"Serif"},
  {l:"Merriweather",v:"'Merriweather',serif",g:"Serif"},{l:"Georgia",v:"Georgia,serif",g:"Serif"},
  {l:"Times New Roman",v:"'Times New Roman',serif",g:"Serif"},{l:"EB Garamond",v:"'EB Garamond',serif",g:"Serif"},
  {l:"Inter",v:"'Inter',sans-serif",g:"Sans-serif"},{l:"Open Sans",v:"'Open Sans',sans-serif",g:"Sans-serif"},
  {l:"Montserrat",v:"'Montserrat',sans-serif",g:"Sans-serif"},{l:"DM Sans",v:"'DM Sans',sans-serif",g:"Sans-serif"},
  {l:"Roboto",v:"'Roboto',sans-serif",g:"Sans-serif"},{l:"Poppins",v:"'Poppins',sans-serif",g:"Sans-serif"},
  {l:"Courier New",v:"'Courier New',monospace",g:"Monospace"},{l:"Fira Code",v:"'Fira Code',monospace",g:"Monospace"},
  {l:"JetBrains Mono",v:"'JetBrains Mono',monospace",g:"Monospace"},
  {l:"Cinzel",v:"'Cinzel',serif",g:"Decorativa"},{l:"Pacifico",v:"'Pacifico',cursive",g:"Decorativa"},
  {l:"Dancing Script",v:"'Dancing Script',cursive",g:"Manuscrita"},{l:"Caveat",v:"'Caveat',cursive",g:"Manuscrita"},
];
const COLORS = ["#000000","#34322d","#5e5e5b","#858481","#d1d5db","#ffffff","#dc2626","#ea580c","#d97706","#65a30d","#16a34a","#0891b2","#2563eb","#7c3aed","#9333ea","#db2777","#fca5a5","#fdba74","#fcd34d","#86efac","#93c5fd","#c4b5fd","#f9a8d4","#fde68a","#6ee7b7","#a5b4fc","#fbcfe8","#e9d5ff","#f3f4f6","#e5e7eb","#d1fae5","#dbeafe"];
const SZP = [8,10,12,13,14,15,16,18,20,22,24,28,32,36,48,64,72];

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Lora:ital,wght@0,400;0,600;1,400&family=Inter:wght@400;500;600&family=Playfair+Display:wght@400;700&family=Merriweather:wght@400;700&family=Open+Sans:wght@400;600&family=Montserrat:wght@400;600&family=Roboto:wght@400;500&family=Poppins:wght@400;500;600&family=EB+Garamond:ital,wght@0,400;1,400&family=Dancing+Script:wght@400;700&family=Caveat:wght@400;700&family=Cinzel:wght@400;600&family=Pacifico&family=Fira+Code:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
html,body,#root{width:100%;height:100%;overflow:hidden;background:#f8f8f7}
.er{width:100%;height:100%;display:flex;flex-direction:column;font-family:'DM Sans',sans-serif;background:#f8f8f7;-webkit-user-select:none;user-select:none;overflow:hidden}
.topbar{position:relative;height:52px;flex-shrink:0;display:flex;align-items:center;padding:0 6px;background:#fff;border-bottom:1px solid rgba(0,0,0,.08);z-index:10}
.canvas{flex:1;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;background:#f8f8f7;padding:28px 16px 220px;display:flex;flex-direction:column;align-items:center}
.canvas::-webkit-scrollbar{width:6px}
.canvas::-webkit-scrollbar-thumb{background:rgba(0,0,0,.15);border-radius:3px}
.pw{width:794px;transform-origin:top center;transition:transform .3s cubic-bezier(.22,1,.36,1),margin-bottom .3s}
.page{width:794px;background:#fff;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.06),0 4px 20px rgba(0,0,0,.06);padding:96px 88px 120px;min-height:1123px;transition:box-shadow .25s}
.page.focused{box-shadow:0 2px 8px rgba(0,0,0,.08),0 8px 36px rgba(0,0,0,.12)}
.a4page{width:794px;height:1123px;background:#fff;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.06),0 4px 20px rgba(0,0,0,.06);padding:96px 88px;overflow:hidden;position:relative;flex-shrink:0}
.a4num{position:absolute;bottom:14px;right:20px;font-size:10px;font-weight:600;color:#858481;pointer-events:none}
.pc{outline:none;font-family:'Lora',Georgia,serif;font-size:16px;line-height:1.85;color:#34322d;min-height:600px;word-break:break-word;caret-color:#2563eb;-webkit-user-select:text;user-select:text;cursor:text}
.pc::selection,.pc *::selection{background:#bfdbfe}
.pc:empty::before{content:attr(data-placeholder);color:#858481;pointer-events:none}
.tt:empty::before{content:'Sem título';color:#858481;pointer-events:none}
.tt:focus{border-color:#2563eb!important;background:#eff6ff!important}
.ftb{position:fixed;left:50%;transform:translateX(-50%);bottom:max(14px,env(safe-area-inset-bottom,14px));width:min(96vw,460px);z-index:20}
.pill{height:54px;background:rgba(255,255,255,.97);border:1px solid rgba(0,0,0,.08);border-radius:9999px;box-shadow:0 4px 20px rgba(0,0,0,.10),0 1px 4px rgba(0,0,0,.05);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);display:flex;align-items:center;overflow:hidden;position:relative;transition:all 220ms}
.pill::before{content:'';position:absolute;left:0;top:0;bottom:0;width:20px;background:linear-gradient(to right,rgba(255,255,255,.97),transparent);border-radius:9999px 0 0 9999px;z-index:2;pointer-events:none}
.pill::after{content:'';position:absolute;right:52px;top:0;bottom:0;width:14px;background:linear-gradient(to left,rgba(255,255,255,.97),transparent);z-index:2;pointer-events:none}
.pill.ai::before,.pill.ai::after{display:none}
.tbtrack{display:flex;align-items:center;gap:1px;padding:0 6px;overflow-x:auto;overflow-y:hidden;flex:1;min-width:0;-webkit-overflow-scrolling:touch;scrollbar-width:none}
.tbtrack::-webkit-scrollbar{display:none}
.pop{position:fixed;background:#fff;border:1px solid rgba(0,0,0,.08);border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,.13),0 2px 8px rgba(0,0,0,.07);z-index:100;overflow:visible;animation:popIn .2s cubic-bezier(.34,1.56,.64,1) both}
.pop-inner{border-radius:14px;overflow:hidden}
.pop-arrow{position:absolute;bottom:-9px;width:18px;height:9px;overflow:hidden;pointer-events:none;z-index:101}
.pop-arrow::after{content:'';position:absolute;top:-7px;left:50%;transform:translateX(-50%) rotate(45deg);width:13px;height:13px;background:#fff;border:1px solid rgba(0,0,0,.08);border-radius:3px 0 0 0}
.ff{position:fixed;inset:0;z-index:500;background:#fff;display:flex;flex-direction:column;animation:popIn .2s cubic-bezier(.34,1.56,.64,1) both}
.drawer{position:fixed;top:0;left:0;width:260px;height:100%;background:#fff;z-index:30;box-shadow:2px 0 20px rgba(0,0,0,.10);display:flex;flex-direction:column;transform:translateX(-100%);transition:transform 400ms cubic-bezier(.22,1,.36,1)}
.drawer.open{transform:translateX(0)}
.fgl{padding:6px 14px 2px;font-size:10px;font-weight:700;color:#ccc;text-transform:uppercase;letter-spacing:.06em;border-top:1px solid rgba(0,0,0,.08);margin-top:2px}
.aidot{width:5px;height:5px;border-radius:50%;background:#2563eb;animation:aiDot .9s ease infinite}
.aidot:nth-child(2){animation-delay:.2s}.aidot:nth-child(3){animation-delay:.4s}
.noscroll{scrollbar-width:none}
.noscroll::-webkit-scrollbar{display:none}
@keyframes popIn{from{opacity:0;transform:scale(.5)}to{opacity:1;transform:scale(1)}}
@keyframes aiDot{0%,80%,100%{transform:scale(.6);opacity:.4}40%{transform:scale(1);opacity:1}}
`;

const TbBtn=({children,active,onMouseDown,onClick,style})=>(
  <button onMouseDown={onMouseDown} onClick={onClick}
    style={{height:38,minWidth:38,padding:"0 7px",border:"none",background:active?"#eff6ff":"transparent",borderRadius:9999,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",flexDirection:"column",gap:2,flexShrink:0,color:active?"#2563eb":"#5e5e5b",transition:"background .15s",...style}}>
    {children}
  </button>
);
const TbChip=({children,active,onMouseDown,onClick,style})=>(
  <button onMouseDown={onMouseDown} onClick={onClick}
    style={{height:32,border:`1.5px solid ${active?"#2563eb":"rgba(0,0,0,.08)"}`,borderRadius:9999,padding:"0 11px",fontFamily:"inherit",fontSize:12,fontWeight:600,color:active?"#2563eb":"#34322d",background:active?"#eff6ff":"transparent",cursor:"pointer",display:"flex",alignItems:"center",gap:4,whiteSpace:"nowrap",flexShrink:0,transition:"all .15s",...style}}>
    {children}
  </button>
);
const Div=()=><div style={{width:1,height:20,background:"rgba(0,0,0,.08)",flexShrink:0,margin:"0 4px"}}/>;
const PH=({title})=><div style={{padding:"11px 14px",fontSize:10.5,fontWeight:700,color:"#858481",textTransform:"uppercase",letterSpacing:".07em",borderBottom:"1px solid rgba(0,0,0,.08)"}}>{title}</div>;
const PI=({icon,label,danger,onClick})=>(
  <button onMouseDown={e=>e.preventDefault()} onClick={onClick}
    style={{display:"flex",alignItems:"center",gap:10,padding:"9px 14px",fontSize:13,fontWeight:500,color:danger?"#dc2626":"#34322d",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"inherit"}}
    onMouseOver={e=>e.currentTarget.style.background="rgba(0,0,0,.04)"} onMouseOut={e=>e.currentTarget.style.background="transparent"}>
    <Icon name={icon} size={15} style={{color:danger?"#ef4444":"#858481",flexShrink:0}}/>{label}
  </button>
);

function ColorPopup({colors,hexIn,setHexIn,hexPv,setHexPv,onApply}){
  return<><PH title="Cor do texto"/>
    <div style={{display:"grid",gridTemplateColumns:"repeat(8,1fr)",gap:5,padding:"10px 14px"}}>
      {colors.map(c=><div key={c} onMouseDown={e=>e.preventDefault()} onClick={()=>onApply(c)}
        style={{width:24,height:24,borderRadius:4,background:c,cursor:"pointer",border:c==="#ffffff"?"2px solid rgba(0,0,0,.15)":"2px solid transparent",transition:"transform .1s"}}
        onMouseOver={e=>e.currentTarget.style.transform="scale(1.25)"} onMouseOut={e=>e.currentTarget.style.transform="scale(1)"}/>)}
    </div>
    <div style={{display:"flex",gap:6,alignItems:"center",padding:"0 14px 12px"}}>
      <div style={{width:26,height:26,background:hexPv,borderRadius:6,border:"1.5px solid rgba(0,0,0,.12)",flexShrink:0}}/>
      <input value={hexIn} onChange={e=>{setHexIn(e.target.value);if(/^#[0-9a-f]{6}$/i.test(e.target.value))setHexPv(e.target.value);}}
        maxLength={7} onMouseDown={e=>e.stopPropagation()}
        style={{flex:1,padding:"7px 10px",border:"1.5px solid rgba(0,0,0,.08)",borderRadius:8,fontSize:12,fontWeight:600,fontFamily:"monospace",outline:"none",background:"#fafafa",color:"#34322d",WebkitUserSelect:"text",userSelect:"text"}}/>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>{if(/^#[0-9a-f]{6}$/i.test(hexIn))onApply(hexIn);}}
        style={{width:32,height:32,borderRadius:8,border:"none",background:hexPv,color:"#fff",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0,fontSize:14}}>✓</button>
    </div>
  </>;
}

function FontPopup({fonts,curFont,search,setSearch,preview,setPreview,onExpand,onApply}){
  const groups=[...new Set(fonts.map(f=>f.g))];
  const filtered=fonts.filter(f=>f.l.toLowerCase().includes(search.toLowerCase()));
  return<>
    <div style={{display:"flex",alignItems:"center",borderBottom:"1px solid rgba(0,0,0,.08)"}}>
      <div style={{flex:1,padding:"11px 14px",fontSize:10.5,fontWeight:700,color:"#858481",textTransform:"uppercase",letterSpacing:".07em"}}>Tipo de letra</div>
      <button onMouseDown={e=>e.preventDefault()} onClick={onExpand}
        style={{width:32,height:32,border:"none",background:"transparent",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",color:"#858481",borderRadius:7,marginRight:8}}><Icon name="maximize-2" size={14}/></button>
    </div>
    <div style={{padding:"10px 10px 6px",borderBottom:"1px solid rgba(0,0,0,.08)"}}>
      <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Pesquisar…"
        onMouseDown={e=>e.stopPropagation()}
        style={{width:"100%",padding:"7px 10px",border:"1.5px solid rgba(0,0,0,.08)",borderRadius:8,fontSize:12.5,outline:"none",background:"#fafafa",fontFamily:"inherit",WebkitUserSelect:"text",userSelect:"text"}}/>
    </div>
    <div className="noscroll" style={{maxHeight:190,overflowY:"auto"}}>
      {!search?groups.map((g,gi)=>{
        const gf=filtered.filter(f=>f.g===g);if(!gf.length)return null;
        return[<div key={g} className="fgl" style={gi===0?{borderTop:"none"}:{}}>{g}</div>,
          ...gf.map(f=>(
            <button key={f.v} onMouseDown={e=>e.preventDefault()} onClick={()=>setPreview(f)}
              style={{padding:"9px 14px",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"inherit",display:"flex",alignItems:"center",color:f.v===curFont?"#2563eb":"#34322d",fontWeight:f.v===curFont?600:400}}>
              <span style={{fontFamily:f.v,fontSize:14,flex:1}}>{f.l}</span>
            </button>
          ))];
      }):filtered.map(f=>(
        <button key={f.v} onMouseDown={e=>e.preventDefault()} onClick={()=>setPreview(f)}
          style={{padding:"9px 14px",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"inherit",display:"flex",alignItems:"center",color:f.v===curFont?"#2563eb":"#34322d"}}>
          <span style={{fontFamily:f.v,fontSize:14,flex:1}}>{f.l}</span>
        </button>
      ))}
    </div>
    {preview&&<div style={{borderTop:"1px solid rgba(0,0,0,.08)",padding:"10px 14px 12px",background:"#fafafa"}}>
      <div style={{fontSize:10,fontWeight:700,color:"#858481",textTransform:"uppercase",letterSpacing:".06em",marginBottom:4}}>{preview.l}</div>
      <div style={{fontSize:26,color:"#34322d",marginBottom:8,lineHeight:1.2,fontFamily:preview.v}}>Aa Bb Cc</div>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>onApply(preview)}
        style={{width:"100%",padding:"8px 0",background:"#2563eb",color:"#fff",border:"none",borderRadius:8,cursor:"pointer",fontFamily:"inherit",fontSize:12.5,fontWeight:600}}>Aplicar</button>
    </div>}
  </>;
}

function SizePopup({szPv,onApply,onStep}){
  return<><PH title="Tamanho"/>
    <div style={{display:"flex",alignItems:"center",gap:8,padding:"12px 14px"}}>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>onStep(-1)}
        style={{width:36,height:36,borderRadius:9,border:"1.5px solid rgba(0,0,0,.08)",background:"#fff",cursor:"pointer",fontSize:18,color:"#5e5e5b",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>−</button>
      <div style={{flex:1,textAlign:"center",fontSize:20,fontWeight:700,color:"#34322d"}}>{szPv}</div>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>onStep(1)}
        style={{width:36,height:36,borderRadius:9,border:"1.5px solid rgba(0,0,0,.08)",background:"#fff",cursor:"pointer",fontSize:18,color:"#5e5e5b",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>+</button>
    </div>
    <div style={{display:"flex",flexWrap:"wrap",gap:5,padding:"10px 14px 12px",borderTop:"1px solid rgba(0,0,0,.08)"}}>
      {SZP.map(s=>(
        <button key={s} onMouseDown={e=>e.preventDefault()} onClick={()=>onApply(s)}
          style={{padding:"4px 10px",borderRadius:9999,border:`1.5px solid ${s===szPv?"#2563eb":"rgba(0,0,0,.08)"}`,background:s===szPv?"#eff6ff":"transparent",color:s===szPv?"#2563eb":"#5e5e5b",fontSize:12,fontWeight:600,cursor:"pointer",fontFamily:"inherit"}}>{s}</button>
      ))}
    </div>
  </>;
}

function StylesPopup({exec,onClose}){
  const stls=[{l:"Parágrafo",c:()=>exec("formatBlock","<p>"),i:"pilcrow"},{l:"Título 1",c:()=>exec("formatBlock","<h1>"),i:"heading-1"},{l:"Título 2",c:()=>exec("formatBlock","<h2>"),i:"heading-2"},{l:"Título 3",c:()=>exec("formatBlock","<h3>"),i:"heading-3"},{l:"Título 4",c:()=>exec("formatBlock","<h4>"),i:"heading-4"},{l:"Citação",c:()=>exec("formatBlock","<blockquote>"),i:"quote"},{l:"Código",c:()=>exec("formatBlock","<pre>"),i:"code"}];
  return<><PH title="Estilo"/>{stls.map(s=><PI key={s.l} icon={s.i} label={s.l} onClick={()=>{s.c();onClose();}}/>)}</>;
}

function InsertPopup({exec,onClose,insertImg,insertTable}){
  const cx={iCw:["#fef3c7","#f59e0b","▲"],iCi:["#eff6ff","#3b82f6","i"],iCo:["#f0fdf4","#22c55e","✓"],iCe:["#fef2f2","#ef4444","✕"]};
  return<><PH title="Inserir"/>
    <div style={{borderBottom:"1px solid rgba(0,0,0,.08)"}}>
      <PI icon="link" label="Link" onClick={()=>{onClose();const u=prompt("URL:");if(u)exec("createLink",u);}}/>
      <PI icon="image" label="Imagem" onClick={insertImg}/>
      <PI icon="table" label="Tabela 3×3" onClick={insertTable}/>
    </div>
    <div style={{borderBottom:"1px solid rgba(0,0,0,.08)"}}>
      <PI icon="minus" label="Linha divisória" onClick={()=>{exec("insertHorizontalRule");onClose();}}/>
      <PI icon="calendar" label="Data e hora" onClick={()=>{exec("insertText",new Date().toLocaleString("pt-PT"));onClose();}}/>
    </div>
    <div>
      <div style={{padding:"4px 14px 2px",fontSize:10,fontWeight:700,color:"#ccc",textTransform:"uppercase",letterSpacing:".06em"}}>Caixas de destaque</div>
      {[["iCw","alert-triangle","Aviso"],["iCi","info","Informação"],["iCo","check-circle","Sucesso"],["iCe","x-circle","Erro"]].map(([id,ic,lbl])=>(
        <PI key={id} icon={ic} label={lbl} onClick={()=>{const[bg,br,ico]=cx[id];exec("insertHTML",`<div style="background:${bg};border-left:4px solid ${br};padding:12px 16px;margin:8px 0;font-size:.9em;border-radius:6px">${ico} Escreve aqui.</div><p></p>`);onClose();}}/>
      ))}
    </div>
  </>;
}

function FormatPopup({exec,onClose,edRef,restoreSel}){
  const getSel=()=>{restoreSel();const s=window.getSelection();return s&&!s.isCollapsed?s:null;};
  return<><PH title="Formatar"/>
    <div style={{borderBottom:"1px solid rgba(0,0,0,.08)"}}>
      <div style={{padding:"4px 14px 2px",fontSize:10,fontWeight:700,color:"#ccc",textTransform:"uppercase",letterSpacing:".06em"}}>Maiúsculas</div>
      <PI icon="case-upper" label="MAIÚSCULAS" onClick={()=>{const s=getSel();if(s)exec("insertText",s.toString().toUpperCase());onClose();}}/>
      <PI icon="case-lower" label="minúsculas" onClick={()=>{const s=getSel();if(s)exec("insertText",s.toString().toLowerCase());onClose();}}/>
      <PI icon="case-sensitive" label="Primeira Maiúscula" onClick={()=>{const s=getSel();if(s)exec("insertText",s.toString().replace(/\b\w/g,c=>c.toUpperCase()));onClose();}}/>
    </div>
    <div style={{borderBottom:"1px solid rgba(0,0,0,.08)"}}>
      <div style={{padding:"4px 14px 2px",fontSize:10,fontWeight:700,color:"#ccc",textTransform:"uppercase",letterSpacing:".06em"}}>Inline</div>
      <PI icon="superscript" label="Sobrescrito" onClick={()=>{exec("superscript");onClose();}}/>
      <PI icon="subscript" label="Subscrito" onClick={()=>{exec("subscript");onClose();}}/>
      <PI icon="code" label="Código inline" onClick={()=>{exec("insertHTML",'<code style="background:#f0eeeb;padding:1px 5px;font-family:monospace;font-size:.88em;border-radius:4px">código</code>');onClose();}}/>
    </div>
    <div style={{borderBottom:"1px solid rgba(0,0,0,.08)"}}>
      <div style={{padding:"4px 14px 2px",fontSize:10,fontWeight:700,color:"#ccc",textTransform:"uppercase",letterSpacing:".06em"}}>Espaçamento</div>
      {[["1.0 — Compacto","1"],["1.5 — Normal","1.5"],["2.0 — Espaçado","2"]].map(([lbl,val])=>(
        <PI key={val} icon="align-vertical-justify-start" label={lbl} onClick={()=>{if(edRef.current)edRef.current.style.lineHeight=val;onClose();}}/>
      ))}
    </div>
    <PI icon="trash-2" label="Limpar formatação" danger onClick={()=>{exec("removeFormat");onClose();}}/>
  </>;
}

// ── MAIN ──────────────────────────────────────────────────
export default function App(){
  const [drawerOpen,setDrawerOpen]=useState(false);
  const [aiMode,setAiMode]=useState(false);
  const [aiLoading,setAiLoading]=useState(false);
  const [aiInput,setAiInput]=useState("");
  const [curFont,setCurFont]=useState("'Lora',Georgia,serif");
  const [fontLabel,setFontLabel]=useState("Lora");
  const [curSz,setCurSz]=useState(16);
  const [szPv,setSzPv]=useState(16);
  const [colorBar,setColorBar]=useState("#f0a500");
  const [focused,setFocused]=useState(false);
  const [a4Mode,setA4Mode]=useState(false);
  const [activePopup,setActivePopup]=useState(null);
  const [popupPos,setPopupPos]=useState({left:0,bottom:0,origX:0,w:240,arrLeft:0});
  const [ffOpen,setFfOpen]=useState(false);
  const [ffSearch,setFfSearch]=useState("");
  const [ffCat,setFfCat]=useState("Todas");
  const [ffSel,setFfSel]=useState(null);
  const [fontSearch,setFontSearch]=useState("");
  const [fontPreview,setFontPreview]=useState(null);
  const [hexIn,setHexIn]=useState("#34322d");
  const [hexPv,setHexPv]=useState("#34322d");
  const [szPvState,setSzPvState]=useState(16);
  const [alignActive,setAlignActive]=useState("L");
  const [a4Html,setA4Html]=useState("");

  const edRef=useRef(null);
  const savedRange=useRef(null);
  const popTrigRef=useRef(null);
  const canvasRef=useRef(null);
  const wrapRef=useRef(null);
  const aiRef=useRef(null);

  // ── CUSTOM SELECTION SYSTEM ──  ← NOVO (1 linha)
  const { Overlay: SelectionOverlay } = useCustomSelection(edRef);

  useEffect(()=>{
    const s=document.createElement("style"); s.textContent=CSS;
    document.head.appendChild(s);
    return()=>document.head.removeChild(s);
  },[]);

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

  const closePopup=useCallback(()=>{setActivePopup(null);setFontPreview(null);setFontSearch("");},[]);
  const openPopup=useCallback((type,trig)=>{
    if(activePopup===type){closePopup();return;}
    saveSel();
    const wMap={"color-text":254,font:240,size:220,styles:200,insert:240,format:240};
    const w=wMap[type]||240;
    const r=trig.getBoundingClientRect();
    let left=r.left+r.width/2-w/2;
    left=Math.max(8,Math.min(window.innerWidth-w-8,left));
    const bottom=window.innerHeight-r.top+12;
    const origX=Math.max(20,Math.min(w-20,r.left+r.width/2-left));
    const arrLeft=Math.max(12,Math.min(w-24,r.left+r.width/2-left-7));
    setPopupPos({left,bottom,origX,w,arrLeft});
    setActivePopup(type);
    popTrigRef.current=trig;
  },[activePopup,closePopup,saveSel]);

  useEffect(()=>{if(aiMode&&aiRef.current)setTimeout(()=>aiRef.current?.focus(),80);},[aiMode]);

  const doAI=async()=>{
    const p=aiInput.trim();if(!p)return;
    setAiInput("");setAiLoading(true);
    try{
      const r=await fetch("https://api.anthropic.com/v1/messages",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:"claude-sonnet-4-20250514",max_tokens:1000,system:"Responde APENAS com o texto a inserir no editor, sem explicações nem markdown extra. Responde em português.",messages:[{role:"user",content:p}]})});
      const d=await r.json();
      restoreSel();exec("insertText",d.content?.map(i=>i.text||"").join("")||"(sem resposta)");
    }catch{restoreSel();exec("insertText","[Erro IA]");}
    setAiLoading(false);setTimeout(()=>aiRef.current?.focus(),50);
  };

  const insertImg=()=>{
    closePopup();
    const fi=document.createElement("input");fi.type="file";fi.accept="image/*";
    fi.onchange=e=>{const f=e.target.files[0];if(!f)return;const rd=new FileReader();rd.onload=ev=>exec("insertHTML",`<img src="${ev.target.result}" style="max-width:100%;height:auto"/>`);rd.readAsDataURL(f);};
    fi.click();
  };
  const insertTable=()=>{
    let h='<table style="border-collapse:collapse;width:100%;margin:8px 0"><tbody>';
    for(let i=0;i<3;i++){h+="<tr>";for(let j=0;j<3;j++)h+='<td style="border:1.5px solid #ccc;padding:6px 10px;min-width:40px">&nbsp;</td>';h+="</tr>";}
    h+="</tbody></table><p></p>";exec("insertHTML",h);closePopup();
  };
  const applySize=sz=>{
    setSzPv(sz);setSzPvState(sz);
    restoreSel();
    const s=window.getSelection();if(!s||!s.rangeCount)return;
    const r=s.getRangeAt(0);
    if(s.isCollapsed){if(edRef.current)edRef.current.style.fontSize=sz+"px";return;}
    const fr=r.extractContents();const sp=document.createElement("span");sp.style.fontSize=sz+"px";sp.appendChild(fr);r.insertNode(sp);
    const nr=document.createRange();nr.selectNodeContents(sp);s.removeAllRanges();s.addRange(nr);savedRange.current=nr.cloneRange();
  };

  const enableA4=()=>{setA4Html(edRef.current?.innerHTML||"");setA4Mode(true);};
  const disableA4=()=>{setA4Mode(false);requestAnimationFrame(()=>{if(edRef.current&&a4Html)edRef.current.innerHTML=a4Html;});};

  const renderPopup=()=>{
    switch(activePopup){
      case"color-text":return<ColorPopup colors={COLORS} hexIn={hexIn} setHexIn={setHexIn} hexPv={hexPv} setHexPv={setHexPv} onApply={c=>{exec("foreColor",c);setColorBar(c);closePopup();}}/>;
      case"font":return<FontPopup fonts={FONTS} curFont={curFont} search={fontSearch} setSearch={setFontSearch} preview={fontPreview} setPreview={setFontPreview} onExpand={()=>{closePopup();setFfOpen(true);}} onApply={f=>{setCurFont(f.v);setFontLabel(f.l);exec("fontName",f.l);closePopup();}}/>;
      case"size":return<SizePopup szPv={szPvState} onApply={sz=>{applySize(sz);closePopup();}} onStep={d=>{const n=Math.max(6,Math.min(200,szPvState+d));applySize(n);}}/>;
      case"styles":return<StylesPopup exec={exec} onClose={closePopup}/>;
      case"insert":return<InsertPopup exec={exec} onClose={closePopup} insertImg={insertImg} insertTable={insertTable}/>;
      case"format":return<FormatPopup exec={exec} onClose={closePopup} edRef={edRef} restoreSel={restoreSel}/>;
      default:return null;
    }
  };

  return(
    <div className="er">
      {/* DRAWER */}
      <div className={`drawer${drawerOpen?" open":""}`}>
        <div style={{padding:"52px 20px 14px",borderBottom:"1px solid rgba(0,0,0,.08)"}}>
          <div style={{fontSize:13,fontWeight:700,color:"#858481",textTransform:"uppercase",letterSpacing:".06em"}}>Funcionalidades</div>
        </div>
        <div style={{flex:1,overflowY:"auto",padding:10}}>
          <div style={{paddingTop:8,paddingBottom:8,borderBottom:"1px solid rgba(0,0,0,.08)"}}>
            <button onClick={()=>{setAiMode(v=>!v);setDrawerOpen(false);}}
              style={{display:"flex",alignItems:"center",gap:12,width:"100%",padding:"11px 14px",fontSize:14,fontWeight:500,color:aiMode?"#2563eb":"#34322d",background:aiMode?"#eff6ff":"transparent",borderRadius:10,border:"none",cursor:"pointer",fontFamily:"inherit"}}>
              <Icon name={aiMode?"bot":"keyboard"} size={18} style={{color:"#5e5e5b",flexShrink:0}}/>
              <span>{aiMode?"IA activa":"Toolbar / IA"}</span>
            </button>
            <button onClick={()=>{a4Mode?disableA4():enableA4();setDrawerOpen(false);}}
              style={{display:"flex",alignItems:"center",gap:12,width:"100%",padding:"11px 14px",fontSize:14,fontWeight:500,color:a4Mode?"#2563eb":"#34322d",background:a4Mode?"#eff6ff":"transparent",borderRadius:10,border:"none",cursor:"pointer",fontFamily:"inherit"}}>
              <Icon name={a4Mode?"layout":"file-text"} size={18} style={{color:"#5e5e5b",flexShrink:0}}/>
              <span>{a4Mode?"Formato: A4":"Formato: Scroll"}</span>
            </button>
          </div>
        </div>
      </div>
      {drawerOpen&&<div onClick={()=>setDrawerOpen(false)} style={{position:"fixed",inset:0,background:"rgba(0,0,0,.18)",zIndex:15}}/>}

      {/* TOPBAR */}
      <div className="topbar" style={{transform:drawerOpen?"translateX(110px)":"none",transition:"transform 400ms cubic-bezier(.22,1,.36,1)"}}>
        <div style={{position:"absolute",left:6,display:"flex",gap:2}}>
          <button onClick={()=>setDrawerOpen(v=>!v)} style={{width:44,height:44,border:"none",background:"transparent",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",borderRadius:10,color:"#5e5e5b"}}>
            <Icon name="menu" size={20}/>
          </button>
        </div>
        <div contentEditable spellCheck={false} data-placeholder="Sem título" className="tt"
          style={{position:"absolute",left:"50%",transform:"translateX(-50%)",fontSize:15,fontWeight:600,color:"#34322d",whiteSpace:"nowrap",overflow:"hidden",textOverflow:"ellipsis",maxWidth:"calc(100% - 160px)",cursor:"text",padding:"4px 8px",borderRadius:6,border:"1.5px solid transparent",outline:"none",transition:"all .15s",fontFamily:"inherit",WebkitUserSelect:"text",userSelect:"text"}}
          onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();e.currentTarget.blur();}}}/>
        <div style={{position:"absolute",right:6,display:"flex",gap:2}}>
          {[["undo-2","undo"],["redo-2","redo"]].map(([ic,cmd])=>(
            <button key={cmd} onClick={()=>exec(cmd)} style={{width:44,height:44,border:"none",background:"transparent",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",borderRadius:10,color:"#5e5e5b"}}>
              <Icon name={ic} size={20}/>
            </button>
          ))}
        </div>
      </div>

      {/* CANVAS */}
      <div ref={canvasRef} className="canvas noscroll"
        style={{transform:drawerOpen?"translateX(110px)":"none",transition:"transform 400ms cubic-bezier(.22,1,.36,1)"}}
        onClick={e=>{if(!e.target.closest(".pc"))window.getSelection()?.removeAllRanges();}}>
        <div ref={wrapRef} className={`pw${a4Mode?" a4":""}`}>
          {a4Mode?(
            <div className="a4page">
              <div className="pc" contentEditable spellCheck data-placeholder="Começa a escrever…"
                style={{minHeight:"unset",height:"100%"}} dangerouslySetInnerHTML={{__html:a4Html}}
                onFocus={()=>setFocused(true)} onBlur={()=>setFocused(false)} onKeyUp={saveSel}/>
              <div className="a4num">1</div>
            </div>
          ):(
            <div className={`page${focused?" focused":""}`}>
              <div ref={edRef} className="pc" contentEditable spellCheck data-placeholder="Começa a escrever…"
                onFocus={()=>setFocused(true)} onBlur={()=>setFocused(false)} onKeyUp={saveSel}/>
            </div>
          )}
        </div>
      </div>

      {/* FLOATING TOOLBAR */}
      <nav className="ftb" style={{transform:drawerOpen?"translateX(55px)":"translateX(-50%)",left:"50%",transition:"transform 400ms cubic-bezier(.22,1,.36,1)"}}>
        <div className={`pill${aiMode?" ai":""}`}>
          {aiMode?(
            <div style={{display:"flex",alignItems:"center",gap:8,padding:"0 16px",flex:1,minWidth:0}}>
              <input ref={aiRef} value={aiInput} onChange={e=>setAiInput(e.target.value)}
                onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();doAI();}}}
                placeholder="Pergunta à IA…"
                style={{flex:1,border:"none",background:"transparent",fontFamily:"'DM Sans',sans-serif",fontSize:14,color:"#34322d",outline:"none",WebkitUserSelect:"text",userSelect:"text"}}/>
            </div>
          ):(
            <div className="tbtrack noscroll">
              <TbBtn onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("color-text",e.currentTarget)}>
                <span style={{fontSize:16,fontWeight:900,lineHeight:1}}>A</span>
                <div style={{width:16,height:3,borderRadius:2,background:colorBar}}/>
              </TbBtn>
              <Div/>
              {[["bold","B",900,"normal","none"],["italic","I",600,"italic","none"],["underline","U",600,"normal","underline"],["strikeThrough","S",600,"normal","line-through"]].map(([cmd,lbl,fw,fs,td])=>(
                <TbBtn key={cmd} onMouseDown={e=>e.preventDefault()} onClick={()=>exec(cmd)}>
                  <span style={{fontSize:16,fontWeight:fw,fontStyle:fs,textDecoration:td,lineHeight:1}}>{lbl}</span>
                </TbBtn>
              ))}
              <Div/>
              <TbChip onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("font",e.currentTarget)} active={activePopup==="font"}>
                {fontLabel}<Icon name="chevron-down" size={11}/>
              </TbChip>
              <TbChip style={{marginLeft:3}} onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("size",e.currentTarget)} active={activePopup==="size"}>
                {curSz}<Icon name="chevron-down" size={11}/>
              </TbChip>
              <Div/>
              <TbChip onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("styles",e.currentTarget)} active={activePopup==="styles"}>
                Estilos<Icon name="chevron-down" size={11}/>
              </TbChip>
              <Div/>
              {[["L","align-left","justifyLeft"],["C","align-center","justifyCenter"],["R","align-right","justifyRight"],["J","align-justify","justifyFull"]].map(([id,ic,cmd])=>(
                <TbBtn key={id} active={alignActive===id} onMouseDown={e=>e.preventDefault()} onClick={()=>{setAlignActive(id);exec(cmd);}}>
                  <Icon name={ic} size={17}/>
                </TbBtn>
              ))}
              <Div/>
              {[["list","insertUnorderedList"],["list-ordered","insertOrderedList"],["indent","indent"],["outdent","outdent"]].map(([ic,cmd])=>(
                <TbBtn key={ic} onMouseDown={e=>e.preventDefault()} onClick={()=>exec(cmd)}><Icon name={ic} size={17}/></TbBtn>
              ))}
              <Div/>
              <TbChip onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("insert",e.currentTarget)} active={activePopup==="insert"}>
                Inserir<Icon name="plus" size={11}/>
              </TbChip>
              <Div/>
              <TbChip onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("format",e.currentTarget)} active={activePopup==="format"}>
                Formatar<Icon name="settings-2" size={11}/>
              </TbChip>
            </div>
          )}
          <button onMouseDown={e=>e.preventDefault()}
            onClick={()=>{if(aiMode){if(!aiLoading)doAI();}else{closePopup();edRef.current?.focus();}}}
            style={{width:40,height:40,flexShrink:0,borderRadius:"50%",border:aiMode&&!aiLoading?"none":"1.5px solid rgba(0,0,0,.08)",background:aiMode&&!aiLoading?"#2563eb":"#fff",color:aiMode&&!aiLoading?"#fff":"#5e5e5b",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",marginRight:6,marginLeft:2,zIndex:3,transition:"all .2s"}}>
            {aiLoading?<div style={{display:"flex",gap:3,alignItems:"center"}}><div className="aidot"/><div className="aidot"/><div className="aidot"/></div>:aiMode?<Icon name="send" size={16}/>:<Icon name="check" size={16} sw={2.6}/>}
          </button>
        </div>
      </nav>

      {/* POPUP MASK */}
      {activePopup&&<div onMouseDown={closePopup} style={{position:"fixed",inset:0,zIndex:99,background:"transparent"}}/>}

      {/* POPUP */}
      {activePopup&&(
        <div className="pop" style={{width:popupPos.w,left:popupPos.left,bottom:popupPos.bottom,transformOrigin:`${popupPos.origX}px calc(100% + 14px)`}}>
          <div className="pop-inner">{renderPopup()}</div>
          <div className="pop-arrow" style={{left:popupPos.arrLeft}}/>
        </div>
      )}

      {/* FONT FULLSCREEN */}
      {ffOpen&&(
        <div className="ff">
          <div style={{height:54,display:"flex",alignItems:"center",gap:10,padding:"0 14px",borderBottom:"1px solid rgba(0,0,0,.08)",flexShrink:0}}>
            <span style={{fontSize:14,fontWeight:700,color:"#34322d",flexShrink:0}}>Fontes</span>
            <input value={ffSearch} onChange={e=>setFfSearch(e.target.value)} placeholder="Pesquisar fonte…"
              onMouseDown={e=>e.stopPropagation()}
              style={{flex:1,height:34,border:"1.5px solid rgba(0,0,0,.08)",borderRadius:9999,padding:"0 14px",fontSize:13,fontFamily:"inherit",outline:"none",background:"#f8f8f7",color:"#34322d",minWidth:0,WebkitUserSelect:"text",userSelect:"text"}}/>
            <button onClick={()=>setFfOpen(false)} style={{width:36,height:36,border:"none",background:"transparent",cursor:"pointer",borderRadius:9,display:"flex",alignItems:"center",justifyContent:"center",color:"#5e5e5b"}}><Icon name="x" size={17}/></button>
          </div>
          <div className="noscroll" style={{display:"flex",gap:6,padding:"10px 14px",borderBottom:"1px solid rgba(0,0,0,.08)",overflowX:"auto",flexShrink:0}}>
            {["Todas",...new Set(FONTS.map(f=>f.g))].map(cat=>(
              <button key={cat} onClick={()=>setFfCat(cat)}
                style={{flexShrink:0,padding:"5px 13px",border:`1.5px solid ${ffCat===cat?"#2563eb":"rgba(0,0,0,.08)"}`,borderRadius:9999,fontFamily:"inherit",fontSize:12,fontWeight:600,cursor:"pointer",background:ffCat===cat?"#eff6ff":"transparent",color:ffCat===cat?"#2563eb":"#5e5e5b"}}>
                {cat}
              </button>
            ))}
          </div>
          <div className="noscroll" style={{flex:1,overflowY:"auto",display:"grid",gap:8,padding:14,gridTemplateColumns:"repeat(auto-fill,minmax(140px,1fr))"}}>
            {FONTS.filter(f=>(!ffSearch||f.l.toLowerCase().includes(ffSearch.toLowerCase()))&&(ffCat==="Todas"||f.g===ffCat)).map(f=>(
              <div key={f.v} onClick={()=>setFfSel(f.v)}
                style={{border:`1.5px solid ${ffSel===f.v?"#2563eb":"rgba(0,0,0,.08)"}`,borderRadius:10,padding:"10px 12px",cursor:"pointer",background:ffSel===f.v?"#eff6ff":"#fff",transition:"all .15s"}}>
                <div style={{fontSize:10,fontWeight:700,color:"#858481",textTransform:"uppercase",letterSpacing:".05em",marginBottom:4,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{f.g}</div>
                <div style={{fontSize:20,color:"#34322d",lineHeight:1.2,fontFamily:f.v,overflow:"hidden",whiteSpace:"nowrap",textOverflow:"ellipsis"}}>Aa Bb</div>
                <div style={{fontSize:10,color:"#5e5e5b",marginTop:4,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{f.l}</div>
              </div>
            ))}
          </div>
          <div style={{padding:"10px 14px",borderTop:"1px solid rgba(0,0,0,.08)",flexShrink:0}}>
            <button disabled={!ffSel} onClick={()=>{const f=FONTS.find(x=>x.v===ffSel);if(f){setCurFont(f.v);setFontLabel(f.l);exec("fontName",f.l);setFfOpen(false);}}}
              style={{width:"100%",padding:"12px 0",background:ffSel?"#2563eb":"rgba(0,0,0,.08)",color:ffSel?"#fff":"#858481",border:"none",borderRadius:10,cursor:ffSel?"pointer":"default",fontFamily:"inherit",fontSize:13.5,fontWeight:600}}>
              {ffSel?`Aplicar "${FONTS.find(f=>f.v===ffSel)?.l}"` : "Aplicar fonte"}
            </button>
          </div>
        </div>
      )}

      {/* SELECTION OVERLAY — handles, lupa, menu ← NOVO (1 linha) */}
      <SelectionOverlay />
    </div>
  );
}