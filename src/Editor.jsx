import { useState, useEffect, useRef, useCallback } from "react";

const IC = {
  "arrow-left":`<line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/>`,
  "undo-2":`<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>`,
  "redo-2":`<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>`,
  check:`<path d="M20 6 9 17l-5-5"/>`,
  send:`<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>`,
  x:`<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>`,
  sparkles:`<path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/><path d="M5 3v4"/><path d="M19 17v4"/><path d="M3 5h4"/><path d="M17 19h4"/>`,
  "chevron-down":`<path d="m6 9 6 6 6-6"/>`,
  plus:`<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>`,
  "settings-2":`<path d="M20 7h-9M14 17H5"/><circle cx="17" cy="17" r="3"/><circle cx="7" cy="7" r="3"/>`,
  "align-left":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="15" y1="12" x2="3" y2="12"/><line x1="17" y1="18" x2="3" y2="18"/>`,
  "align-center":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="17" y1="12" x2="7" y2="12"/><line x1="19" y1="18" x2="5" y2="18"/>`,
  "align-right":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="12" x2="9" y2="12"/><line x1="21" y1="18" x2="7" y2="18"/>`,
  "align-justify":`<line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="12" x2="3" y2="12"/><line x1="21" y1="18" x2="3" y2="18"/>`,
  list:`<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>`,
  "list-ordered":`<line x1="10" y1="6" x2="21" y2="6"/><line x1="10" y1="12" x2="21" y2="12"/><line x1="10" y1="18" x2="21" y2="18"/><path d="M4 6h1v4M4 10h2M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/>`,
  indent:`<polyline points="3 8 7 12 3 16"/><line x1="21" y1="12" x2="11" y2="12"/><line x1="21" y1="6" x2="11" y2="6"/><line x1="21" y1="18" x2="11" y2="18"/>`,
  outdent:`<polyline points="7 8 3 12 7 16"/><line x1="21" y1="12" x2="11" y2="12"/><line x1="21" y1="6" x2="11" y2="6"/><line x1="21" y1="18" x2="11" y2="18"/>`,
  bold:`<path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/>`,
  italic:`<line x1="19" y1="4" x2="10" y2="4"/><line x1="14" y1="20" x2="5" y2="20"/><line x1="15" y1="4" x2="9" y2="20"/>`,
  underline:`<path d="M6 4v6a6 6 0 0 0 12 0V4"/><line x1="4" y1="20" x2="20" y2="20"/>`,
  link:`<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>`,
  "trash-2":`<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>`,
  maximize:`<polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/>`,
  pilcrow:`<path d="M13 4v16"/><path d="M17 4v16"/><path d="M19 4H9.5a4.5 4.5 0 0 0 0 9H13"/>`,
  "heading-1":`<path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M21 18v-7l-2 2"/>`,
  "heading-2":`<path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M21 7c0-1.657-1.343-3-3-3s-3 1.343-3 3c0 4 6 6 6 6"/><path d="M15 18h6"/>`,
  quote:`<path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V20c0 1 0 1 1 1z"/><path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z"/>`,
  code:`<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>`,
  minus:`<line x1="5" y1="12" x2="19" y2="12"/>`,
  calendar:`<rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>`,
  table:`<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/>`,
  image:`<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/>`,
  scissors:`<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><line x1="20" y1="4" x2="8.12" y2="15.88"/><line x1="14.47" y1="14.48" x2="20" y2="20"/><line x1="8.12" y1="8.12" x2="12" y2="12"/>`,
  copy:`<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>`,
  clipboard:`<rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>`,
  "check-square":`<polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>`,
  "case-upper":`<path d="m3 15 4-8 4 8"/><path d="M4 13h6"/><path d="M15 11h4.5a2 2 0 0 1 0 4H15V7h4a2 2 0 0 1 0 4"/>`,
  "alert-triangle":`<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>`,
  info:`<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>`,
  "check-circle":`<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>`,
  "x-circle":`<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>`,
  layers:`<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>`,
  "more-horizontal":`<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>`,
};
const Icon = ({name,size=18,sw=2,style}) => (
  <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24"
    fill="none" stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
    style={style} dangerouslySetInnerHTML={{__html:IC[name]||""}}/>
);

const FONTS = [
  {l:"Lora",v:"'Lora',Georgia,serif",g:"Serif"},{l:"Playfair Display",v:"'Playfair Display',serif",g:"Serif"},
  {l:"Merriweather",v:"'Merriweather',serif",g:"Serif"},{l:"Georgia",v:"Georgia,serif",g:"Serif"},
  {l:"Inter",v:"'Inter',sans-serif",g:"Sans-serif"},{l:"Open Sans",v:"'Open Sans',sans-serif",g:"Sans-serif"},
  {l:"Montserrat",v:"'Montserrat',sans-serif",g:"Sans-serif"},{l:"DM Sans",v:"'DM Sans',sans-serif",g:"Sans-serif"},
  {l:"Courier New",v:"'Courier New',monospace",g:"Monospace"},{l:"Fira Code",v:"'Fira Code',monospace",g:"Monospace"},
  {l:"Dancing Script",v:"'Dancing Script',cursive",g:"Manuscrita"},{l:"Caveat",v:"'Caveat',cursive",g:"Manuscrita"},
];
const COLORS = ["#000","#34322d","#5e5e5b","#858481","#d1d5db","#fff","#dc2626","#ea580c","#d97706","#65a30d","#16a34a","#0891b2","#2563eb","#7c3aed","#db2777","#fca5a5","#fdba74","#fcd34d","#86efac","#93c5fd","#c4b5fd"];
const SZP = [8,10,12,13,14,15,16,18,20,22,24,28,32,36,48,64];

const haptic = (s="light") => { try { if(navigator.vibrate) navigator.vibrate(s==="light"?8:20); } catch(_){} };

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Lora:ital,wght@0,400;0,600;1,400&family=Inter:wght@400;500;600&family=Playfair+Display:wght@400;700&family=Merriweather:wght@400;700&family=Open+Sans:wght@400;600&family=Montserrat:wght@400;600&family=Fira+Code:wght@400;500&family=Dancing+Script:wght@400;700&family=Caveat:wght@400;700&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;-webkit-font-smoothing:antialiased}
.ed-screen{position:absolute;inset:0;display:flex;flex-direction:column;font-family:'DM Sans',system-ui,sans-serif;background:#f0f0ef;overflow:hidden;will-change:transform}
.ed-screen.vis{transform:translateX(0);opacity:1;transition:transform .42s cubic-bezier(.32,1,.56,1),opacity .3s}
.ed-screen.hid{transform:translateX(100%);opacity:0;pointer-events:none;transition:transform .42s cubic-bezier(.32,1,.56,1),opacity .3s}
.topbar{height:56px;flex-shrink:0;display:flex;align-items:center;padding:0 8px;background:#fff;position:relative;z-index:10;transition:box-shadow .2s}
.topbar.scrolled{box-shadow:0 1px 0 rgba(0,0,0,.1),0 2px 8px rgba(0,0,0,.06)}
.tbtn{width:44px;height:44px;border:none;background:transparent;cursor:pointer;display:flex;align-items:center;justify-content:center;border-radius:12px;color:#8e8e93;transition:background .12s}
.tbtn:active{background:rgba(0,0,0,.06)}
.canvas{flex:1;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;background:#f0f0ef;padding:28px 16px 220px;display:flex;flex-direction:column;align-items:center}
.canvas::-webkit-scrollbar{width:5px}
.canvas::-webkit-scrollbar-thumb{background:rgba(0,0,0,.15);border-radius:3px}
.pw{width:794px;transform-origin:top center}
.page{width:794px;background:#fff;border-radius:0;border:1.5px solid #c8c8c8;box-shadow:0 1px 4px rgba(0,0,0,.06),0 4px 16px rgba(0,0,0,.06);padding:96px 88px 120px;min-height:1123px;transition:border-color .25s}
.page.focused{border-color:#b0b0b0}
.pc{outline:none;font-family:'Lora',Georgia,serif;font-size:16px;line-height:1.85;color:#34322d;min-height:600px;word-break:break-word;caret-color:#007aff;-webkit-user-select:text;user-select:text;cursor:text}
.pc::selection,.pc *::selection{background:#bfdbfe}
.pc:empty::before{content:attr(data-placeholder);color:#858481;pointer-events:none}
.pc h1{font-size:2em;font-weight:700;margin-bottom:.5em;line-height:1.2}
.pc h2{font-size:1.4em;font-weight:700;margin:1em 0 .4em;line-height:1.3}
.pc h3{font-size:1.15em;font-weight:600;margin:1em 0 .3em}
.pc p{margin-bottom:.6em}
.pc blockquote{border-left:3px solid #d1d5db;padding-left:1em;color:#6b7280;margin:.5em 0}
.pc pre{background:#f5f5f4;border-radius:8px;padding:12px;font-family:monospace;font-size:.88em;margin:.5em 0}
.tt:empty::before{content:'Sem título';color:#858481;pointer-events:none}
.tt:focus{border-color:#007aff!important}
.ftb-ed{position:fixed;left:50%;transform:translateX(-50%);bottom:max(14px,env(safe-area-inset-bottom,14px));width:min(96vw,490px);z-index:20}
.pill{height:54px;background:#fff;border:1px solid rgba(0,0,0,.1);border-radius:9999px;box-shadow:0 4px 20px rgba(0,0,0,.1),0 1px 4px rgba(0,0,0,.05);display:flex;align-items:center;overflow:hidden;position:relative}
.pill::before{content:'';position:absolute;left:0;top:0;bottom:0;width:18px;background:linear-gradient(to right,#fff,transparent);border-radius:9999px 0 0 9999px;z-index:2;pointer-events:none}
.pill::after{content:'';position:absolute;right:50px;top:0;bottom:0;width:14px;background:linear-gradient(to left,#fff,transparent);z-index:2;pointer-events:none}
.pill.ai-mode::before,.pill.ai-mode::after{display:none}
.tbtrack{display:flex;align-items:center;gap:1px;padding:0 6px;overflow-x:auto;flex:1;min-width:0;-webkit-overflow-scrolling:touch;scrollbar-width:none}
.tbtrack::-webkit-scrollbar{display:none}
.sel-menu{position:fixed;z-index:9999;background:#1c1c1e;border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,.45);overflow:visible;pointer-events:auto;animation:selIn .15s cubic-bezier(.34,1.56,.64,1) both}
.sel-inner{display:flex;align-items:stretch;overflow-x:auto;border-radius:14px;scrollbar-width:none}
.sel-inner::-webkit-scrollbar{display:none}
.sel-menu::after{content:'';position:absolute;width:0;height:0;left:var(--ax,50%);transform:translateX(-50%);pointer-events:none}
.sel-menu.adown::after{top:100%;border-left:6px solid transparent;border-right:6px solid transparent;border-top:7px solid #1c1c1e}
.sel-menu.aup::after{bottom:100%;border-left:6px solid transparent;border-right:6px solid transparent;border-bottom:7px solid #1c1c1e}
.pop{position:fixed;background:#fff;border:1px solid rgba(0,0,0,.09);border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,.13),0 2px 8px rgba(0,0,0,.07);z-index:100;overflow:visible;animation:popIn .2s cubic-bezier(.34,1.56,.64,1) both}
.pop-inner{border-radius:14px;overflow:hidden}
.pop-arrow{position:absolute;bottom:-9px;width:18px;height:9px;overflow:hidden;pointer-events:none;z-index:101}
.pop-arrow::after{content:'';position:absolute;top:-7px;left:50%;transform:translateX(-50%) rotate(45deg);width:13px;height:13px;background:#fff;border:1px solid rgba(0,0,0,.08);border-radius:3px 0 0 0}
.ff{position:fixed;inset:0;z-index:500;background:#fff;display:flex;flex-direction:column;animation:popIn .2s cubic-bezier(.34,1.56,.64,1) both}
.fgl{padding:6px 16px 2px;font-size:10px;font-weight:700;color:#c7c7cc;text-transform:uppercase;letter-spacing:.06em;border-top:1px solid rgba(0,0,0,.06);margin-top:2px}
.img-wrap{display:inline-block;position:relative;cursor:pointer;-webkit-user-select:none;user-select:none;line-height:0}
.img-wrap img{display:block;max-width:100%;height:auto}
.img-wrap.selected img{outline:2px solid #007aff;outline-offset:2px}
.img-dots-btn{position:absolute;top:6px;right:6px;width:28px;height:28px;background:rgba(0,0,0,.5);border-radius:8px;display:flex;align-items:center;justify-content:center;cursor:pointer;z-index:5;border:none;color:#fff;animation:popIn .15s both}
.resize-handle{position:absolute;bottom:4px;right:4px;width:18px;height:18px;cursor:se-resize;z-index:6;opacity:.8}
.resize-handle::before{content:'';display:block;width:10px;height:10px;border-right:2.5px solid rgba(255,255,255,.9);border-bottom:2.5px solid rgba(255,255,255,.9);border-radius:1px}
.img-ctx{position:fixed;background:#fff;border-radius:14px;box-shadow:0 4px 24px rgba(0,0,0,.15),0 1px 4px rgba(0,0,0,.08);border:1px solid rgba(0,0,0,.08);z-index:9999;overflow:hidden;min-width:190px;animation:popIn .15s cubic-bezier(.34,1.56,.64,1) both}
.img-ctx-item{display:flex;align-items:center;gap:10px;padding:12px 16px;color:#1c1c1e;font-size:14px;font-weight:500;font-family:'DM Sans',sans-serif;cursor:pointer;border:none;background:transparent;width:100%;text-align:left;border-bottom:1px solid rgba(0,0,0,.06)}
.img-ctx-item:last-child{border-bottom:none}
.img-ctx-item:active{background:rgba(0,0,0,.04)}
.img-ctx-item.danger{color:#ff3b30}
.aidot{width:5px;height:5px;border-radius:50%;background:#007aff;animation:aiDot .9s ease infinite}
.aidot:nth-child(2){animation-delay:.2s}.aidot:nth-child(3){animation-delay:.4s}
.noscroll{scrollbar-width:none}.noscroll::-webkit-scrollbar{display:none}
@keyframes popIn{from{opacity:0;transform:scale(.85)}to{opacity:1;transform:scale(1)}}
@keyframes selIn{from{opacity:0;transform:scale(.88) translateY(4px)}to{opacity:1;transform:scale(1) translateY(0)}}
@keyframes aiDot{0%,80%,100%{transform:scale(.6);opacity:.4}40%{transform:scale(1);opacity:1}}
`;

const TbBtn = ({children,active,onMouseDown,onClick,st}) => (
  <button onMouseDown={onMouseDown} onClick={onClick}
    style={{height:38,minWidth:38,padding:"0 7px",border:"none",background:active?"#eff6ff":"transparent",borderRadius:9999,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",flexDirection:"column",gap:2,flexShrink:0,color:active?"#007aff":"#5e5e5b",transition:"background .12s",...st}}>
    {children}
  </button>
);
const TbChip = ({children,active,onMouseDown,onClick,"data-chip":dc,st}) => (
  <button onMouseDown={onMouseDown} onClick={onClick} data-chip={dc}
    style={{height:32,border:`1.5px solid ${active?"#007aff":"rgba(0,0,0,.08)"}`,borderRadius:9999,padding:"0 11px",fontFamily:"'DM Sans',sans-serif",fontSize:12,fontWeight:600,color:active?"#007aff":"#34322d",background:active?"#e8f0fe":"transparent",cursor:"pointer",display:"flex",alignItems:"center",gap:4,whiteSpace:"nowrap",flexShrink:0,transition:"all .15s",...st}}>
    {children}
  </button>
);
const Div2 = () => <div style={{width:1,height:20,background:"rgba(0,0,0,.08)",flexShrink:0,margin:"0 3px"}}/>;
const PH = ({title}) => <div style={{padding:"10px 16px",fontSize:10.5,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",letterSpacing:".08em",borderBottom:"1px solid rgba(0,0,0,.06)"}}>{title}</div>;
const PI = ({icon,label,danger,onClick}) => (
  <button onMouseDown={e=>e.preventDefault()} onClick={onClick}
    style={{display:"flex",alignItems:"center",gap:10,padding:"10px 16px",fontSize:13.5,fontWeight:500,color:danger?"#dc2626":"#34322d",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"'DM Sans',sans-serif"}}
    onPointerOver={e=>e.currentTarget.style.background="rgba(0,0,0,.03)"} onPointerOut={e=>e.currentTarget.style.background="transparent"}>
    <Icon name={icon} size={15} style={{color:danger?"#ef4444":"#858481",flexShrink:0}}/>{label}
  </button>
);

function ColorPopup({colors,hexIn,setHexIn,hexPv,setHexPv,onApply}){
  return<><PH title="Cor do texto"/>
    <div style={{display:"grid",gridTemplateColumns:"repeat(7,1fr)",gap:5,padding:"10px 14px"}}>
      {colors.map(c=><div key={c} onMouseDown={e=>e.preventDefault()} onClick={()=>onApply(c)}
        style={{width:26,height:26,borderRadius:6,background:c,cursor:"pointer",border:c==="#fff"?"2px solid rgba(0,0,0,.15)":"2px solid transparent"}}/>)}
    </div>
    <div style={{display:"flex",gap:6,alignItems:"center",padding:"0 14px 12px"}}>
      <div style={{width:26,height:26,background:hexPv,borderRadius:6,border:"1.5px solid rgba(0,0,0,.12)",flexShrink:0}}/>
      <input value={hexIn} onChange={e=>{setHexIn(e.target.value);if(/^#[0-9a-f]{6}$/i.test(e.target.value))setHexPv(e.target.value);}} maxLength={7} onMouseDown={e=>e.stopPropagation()}
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
        style={{width:"100%",padding:"7px 10px",border:"1.5px solid rgba(0,0,0,.08)",borderRadius:9,fontSize:12.5,outline:"none",background:"#fafafa",fontFamily:"'DM Sans',sans-serif",WebkitUserSelect:"text",userSelect:"text"}}/>
    </div>
    <div className="noscroll" style={{maxHeight:180,overflowY:"auto"}}>
      {!search?groups.map((g,gi)=>{const gf=filtered.filter(f=>f.g===g);if(!gf.length)return null;
        return[<div key={g} className="fgl" style={gi===0?{borderTop:"none"}:{}}>{g}</div>,
          ...gf.map(f=><button key={f.v} onMouseDown={e=>e.preventDefault()} onClick={()=>setPreview(f)}
            style={{padding:"9px 16px",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"'DM Sans',sans-serif",display:"flex",alignItems:"center",color:f.v===curFont?"#007aff":"#34322d"}}>
            <span style={{fontFamily:f.v,fontSize:14,flex:1}}>{f.l}</span></button>)];
      }):filtered.map(f=><button key={f.v} onMouseDown={e=>e.preventDefault()} onClick={()=>setPreview(f)}
        style={{padding:"9px 16px",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"'DM Sans',sans-serif",color:f.v===curFont?"#007aff":"#34322d"}}>
        <span style={{fontFamily:f.v,fontSize:14}}>{f.l}</span></button>)}
    </div>
    {preview&&<div style={{borderTop:"1px solid rgba(0,0,0,.06)",padding:"10px 14px 12px",background:"#fafafa"}}>
      <div style={{fontSize:10,fontWeight:700,color:"#8e8e93",textTransform:"uppercase",marginBottom:4}}>{preview.l}</div>
      <div style={{fontSize:26,color:"#34322d",marginBottom:8,lineHeight:1.2,fontFamily:preview.v}}>Aa Bb Cc</div>
      <button onMouseDown={e=>e.preventDefault()} onClick={()=>onApply(preview)}
        style={{width:"100%",padding:"8px 0",background:"#007aff",color:"#fff",border:"none",borderRadius:9,cursor:"pointer",fontFamily:"'DM Sans',sans-serif",fontSize:13,fontWeight:600}}>Aplicar</button>
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
        style={{padding:"4px 10px",borderRadius:9999,border:`1.5px solid ${s===szPv?"#007aff":"rgba(0,0,0,.08)"}`,background:s===szPv?"#e8f0fe":"transparent",color:s===szPv?"#007aff":"#5e5e5b",fontSize:12,fontWeight:600,cursor:"pointer",fontFamily:"'DM Sans',sans-serif"}}>{s}</button>)}
    </div>
  </>;
}
function StylesPopup({exec,onClose}){
  const stls=[{l:"Parágrafo",c:()=>exec("formatBlock","<p>"),i:"pilcrow"},{l:"Título 1",c:()=>exec("formatBlock","<h1>"),i:"heading-1"},{l:"Título 2",c:()=>exec("formatBlock","<h2>"),i:"heading-2"},{l:"Citação",c:()=>exec("formatBlock","<blockquote>"),i:"quote"},{l:"Código",c:()=>exec("formatBlock","<pre>"),i:"code"}];
  return<><PH title="Estilo"/>{stls.map(s=><PI key={s.l} icon={s.i} label={s.l} onClick={()=>{s.c();onClose();}}/>)}</>;
}
function InsertPopup({exec,onClose,insertImg,insertTable}){
  const alerts=[
    {id:"warn",icon:"alert-triangle",ch:"⚠",bg:"#f59e0b",border:"#f59e0b",bg2:"#fffbeb",color:"#78350f",title:"Aviso"},
    {id:"info",icon:"info",ch:"i",bg:"#3b82f6",border:"#3b82f6",bg2:"#eff6ff",color:"#1e3a5f",title:"Informação"},
    {id:"ok",icon:"check-circle",ch:"✓",bg:"#22c55e",border:"#22c55e",bg2:"#f0fdf4",color:"#14532d",title:"Sucesso"},
    {id:"err",icon:"x-circle",ch:"✕",bg:"#f43f5e",border:"#f43f5e",bg2:"#fff1f2",color:"#4c0519",title:"Erro"},
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
        exec("insertHTML",`<div style="display:flex;align-items:flex-start;gap:12px;padding:14px 16px;margin:10px 0;border-radius:10px;background:${a.bg2};border:1.5px solid ${a.border};color:${a.color}" contenteditable="true"><div style="flex-shrink:0;width:20px;height:20px;border-radius:50%;background:${a.bg};color:#fff;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:800;margin-top:1px">${a.ch}</div><div><div style="font-weight:700;font-size:13px;margin-bottom:2px">${a.title}</div><div style="font-size:13px;opacity:.85">Escreve aqui.</div></div></div><p></p>`);
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

export default function Editor({ visible, doc, onBack }) {
  const [aiMode, setAiMode] = useState(false);
  const [aiLoading, setAiLoading] = useState(false);
  const [aiInput, setAiInput] = useState("");
  const [curFont, setCurFont] = useState("'Lora',Georgia,serif");
  const [fontLabel, setFontLabel] = useState("Lora");
  const [curSz, setCurSz] = useState(16);
  const [szPv, setSzPv] = useState(16);
  const [colorBar, setColorBar] = useState("#d97706");
  const [focused, setFocused] = useState(false);
  const [activePopup, setActivePopup] = useState(null);
  const [popupPos, setPopupPos] = useState({left:0,bottom:0,origX:0,w:240,arrLeft:0});
  const [selVisible, setSelVisible] = useState(false);
  const [selPos, setSelPos] = useState({left:0,top:0,ax:0,dir:"down",mw:480});
  const [emptyMenu, setEmptyMenu] = useState(null);
  const [ffOpen, setFfOpen] = useState(false);
  const [ffSearch, setFfSearch] = useState("");
  const [ffCat, setFfCat] = useState("Todas");
  const [ffSel, setFfSel] = useState(null);
  const [fontSearch, setFontSearch] = useState("");
  const [fontPreview, setFontPreview] = useState(null);
  const [hexIn, setHexIn] = useState("#34322d");
  const [hexPv, setHexPv] = useState("#34322d");
  const [alignActive, setAlignActive] = useState("L");
  const [imgMenu, setImgMenu] = useState(null);
  const [scrolled, setScrolled] = useState(false);

  const edRef = useRef(null);
  const savedRange = useRef(null);
  const canvasRef = useRef(null);
  const wrapRef = useRef(null);
  const aiRef = useRef(null);
  const longPressTimer = useRef(null);
  const pinchState = useRef(null);
  const initDone = useRef(false);

  useEffect(() => {
    const s = document.createElement("style");
    s.textContent = CSS;
    document.head.appendChild(s);
    return () => document.head.removeChild(s);
  }, []);

  useEffect(() => {
    if (edRef.current && doc && visible && !initDone.current) {
      edRef.current.innerHTML = doc.content || "";
      initDone.current = true;
    }
    if (!visible) initDone.current = false;
  }, [doc, visible]);

  const zoom = useCallback(() => {
    if (!canvasRef.current || !wrapRef.current) return;
    const avail = canvasRef.current.clientWidth - 32;
    const sc = avail < 794 ? avail / 794 : 1;
    if (sc < 1) { wrapRef.current.style.transform = `scale(${sc})`; wrapRef.current.style.transformOrigin = "top center"; wrapRef.current.style.marginBottom = `${(sc-1)*1123}px`; }
    else { wrapRef.current.style.transform = "none"; wrapRef.current.style.marginBottom = "0"; }
  }, []);
  useEffect(() => { zoom(); window.addEventListener("resize", zoom); return () => window.removeEventListener("resize", zoom); }, [zoom]);
  useEffect(() => { if (!canvasRef.current) return; const ro = new ResizeObserver(zoom); ro.observe(canvasRef.current); return () => ro.disconnect(); }, [zoom]);

  const saveSel = useCallback(() => { const s = window.getSelection(); if (s && s.rangeCount > 0 && !s.isCollapsed) savedRange.current = s.getRangeAt(0).cloneRange(); }, []);
  const restoreSel = useCallback(() => { if (!savedRange.current) { edRef.current?.focus(); return; } edRef.current?.focus(); try { const s = window.getSelection(); s.removeAllRanges(); s.addRange(savedRange.current); } catch(_) {}; }, []);
  const exec = useCallback((cmd, val) => { restoreSel(); document.execCommand(cmd, false, val||null); saveSel(); }, [restoreSel, saveSel]);

  const tryShowSel = useCallback(() => {
    const s = window.getSelection();
    if (!s || s.isCollapsed || !s.toString().trim()) { setSelVisible(false); return; }
    const r = s.getRangeAt(0).getBoundingClientRect();
    if (!r.width && !r.height) { setSelVisible(false); return; }
    const GAP=10,AH=7,MH=44,vw=window.innerWidth,vh=window.innerHeight;
    const mw = Math.min(vw-16, 480);
    let left = r.left+r.width/2-mw/2; left = Math.max(8, Math.min(vw-mw-8, left));
    const ax = Math.max(16, Math.min(mw-16, r.left+r.width/2-left));
    const spA=r.top-GAP-AH-MH, spB=vh-r.bottom-GAP-AH-MH;
    let top, dir;
    if (spA>=0){top=r.top-MH-GAP-AH;dir="down";}
    else if(spB>=0){top=r.bottom+GAP+AH;dir="up";}
    else if(spA>spB){top=Math.max(8,r.top-MH-GAP-AH);dir="down";}
    else{top=r.bottom+GAP+AH;dir="up";}
    setSelPos({left,top,ax,dir,mw}); setSelVisible(true);
  }, []);

  const handlePointerDown = useCallback((e) => {
    if (e.target.closest && e.target.closest(".img-wrap")) return;
    const cx = e.clientX ?? e.touches?.[0]?.clientX;
    const cy = e.clientY ?? e.touches?.[0]?.clientY;
    clearTimeout(longPressTimer.current);
    longPressTimer.current = setTimeout(() => {
      const s = window.getSelection();
      let mx=cx, my=cy;
      if (s && s.rangeCount>0 && s.isCollapsed) { const rect=s.getRangeAt(0).getBoundingClientRect(); if(rect.width||rect.height){mx=rect.left;my=rect.bottom;} }
      haptic("medium");
      const vw=window.innerWidth,vh=window.innerHeight,mw=200;
      let left=mx-mw/2; left=Math.max(8,Math.min(vw-mw-8,left));
      const ax=Math.max(16,Math.min(mw-16,mx-left));
      const MH=44,GAP=10,AH=7,spB=vh-my-GAP-AH-MH;
      let top,dir;
      if(spB>=0){top=my+GAP+AH;dir="up";}else{top=Math.max(8,my-MH-GAP-AH);dir="down";}
      setEmptyMenu({left,top,ax,dir,mw});
    }, 800);
  }, []);
  const handlePointerUp = useCallback(() => clearTimeout(longPressTimer.current), []);

  const closePopup = useCallback(() => { setActivePopup(null); setFontPreview(null); setFontSearch(""); }, []);
  const openPopup = useCallback((type, trig) => {
    if (activePopup === type) { closePopup(); return; }
    saveSel();
    const wMap={"color-text":250,font:240,size:220,styles:200,insert:240,format:220};
    const w=wMap[type]||240;
    const r=trig.getBoundingClientRect();
    let left=r.left+r.width/2-w/2; left=Math.max(8,Math.min(window.innerWidth-w-8,left));
    const bottom=window.innerHeight-r.top+12;
    const origX=Math.max(20,Math.min(w-20,r.left+r.width/2-left));
    const arrLeft=Math.max(12,Math.min(w-24,r.left+r.width/2-left-7));
    setPopupPos({left,bottom,origX,w,arrLeft}); setActivePopup(type);
  }, [activePopup, closePopup, saveSel]);

  useEffect(() => { if (aiMode && aiRef.current) setTimeout(() => aiRef.current?.focus(), 80); }, [aiMode]);

  const doAI = async () => {
    const p = aiInput.trim(); if (!p) return;
    setAiInput(""); setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({model:"claude-sonnet-4-20250514",max_tokens:1000,system:"Responde APENAS com o texto a inserir no editor. Responde em português.",messages:[{role:"user",content:p}]})});
      const d = await r.json(); restoreSel(); exec("insertText", d.content?.map(i=>i.text||"").join("")||"");
    } catch { restoreSel(); exec("insertText","[Erro IA]"); }
    setAiLoading(false); setTimeout(() => aiRef.current?.focus(), 50);
  };

  const wrapImage = useCallback((img) => {
    if (img.parentElement?.classList.contains("img-wrap")) return;
    const wrap = document.createElement("span"); wrap.className="img-wrap"; wrap.contentEditable="false"; wrap.style.cssText="display:inline-block;position:relative;cursor:pointer;line-height:0;max-width:100%";
    img.parentNode.insertBefore(wrap,img); wrap.appendChild(img);
    const btn = document.createElement("button"); btn.className="img-dots-btn"; btn.innerHTML=`<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>`; btn.style.display="none"; wrap.appendChild(btn);
    const rh = document.createElement("div"); rh.className="resize-handle"; rh.style.display="none"; wrap.appendChild(rh);
    wrap.addEventListener("click",e=>{e.stopPropagation();e.preventDefault();haptic("light");document.querySelectorAll(".img-wrap.selected").forEach(w=>{if(w!==wrap){w.classList.remove("selected");const b=w.querySelector(".img-dots-btn"),r=w.querySelector(".resize-handle");if(b)b.style.display="none";if(r)r.style.display="none";}});wrap.classList.add("selected");btn.style.display="flex";rh.style.display="flex";});
    btn.addEventListener("click",e=>{e.stopPropagation();haptic("medium");const rect=btn.getBoundingClientRect();setImgMenu({pos:{x:Math.min(rect.right+8,window.innerWidth-200),y:rect.bottom+6},el:wrap,img});});
    rh.addEventListener("mousedown",e=>{e.preventDefault();e.stopPropagation();const startX=e.clientX,startW=img.offsetWidth;const mv=me=>{img.style.width=Math.max(40,startW+(me.clientX-startX))+"px";img.style.height="auto";};const up=()=>{window.removeEventListener("mousemove",mv);window.removeEventListener("mouseup",up);};window.addEventListener("mousemove",mv);window.addEventListener("mouseup",up);});
    wrap.addEventListener("touchstart",e=>{if(e.touches.length===2){e.preventDefault();const d=Math.hypot(e.touches[0].clientX-e.touches[1].clientX,e.touches[0].clientY-e.touches[1].clientY);pinchState.current={startDist:d,startW:img.offsetWidth};}},{passive:false});
    wrap.addEventListener("touchmove",e=>{if(e.touches.length===2&&pinchState.current){e.preventDefault();const d=Math.hypot(e.touches[0].clientX-e.touches[1].clientX,e.touches[0].clientY-e.touches[1].clientY);img.style.width=Math.max(40,pinchState.current.startW*(d/pinchState.current.startDist))+"px";img.style.height="auto";}},{passive:false});
    wrap.addEventListener("touchend",()=>{pinchState.current=null;});
  }, []);
  useEffect(() => { const ed=edRef.current; if(!ed)return; const obs=new MutationObserver(()=>ed.querySelectorAll("img").forEach(img=>wrapImage(img))); obs.observe(ed,{childList:true,subtree:true}); return()=>obs.disconnect(); }, [wrapImage]);
  useEffect(() => { const h=e=>{if(!e.target.closest(".img-wrap")&&!e.target.closest(".img-ctx")){document.querySelectorAll(".img-wrap.selected").forEach(w=>{w.classList.remove("selected");const b=w.querySelector(".img-dots-btn"),r=w.querySelector(".resize-handle");if(b)b.style.display="none";if(r)r.style.display="none";});setImgMenu(null);}}; document.addEventListener("click",h); return()=>document.removeEventListener("click",h); }, []);

  const handleImgAction = (action,el,img) => { haptic("light"); if(action==="delete"){el.parentNode?.removeChild(el);}else if(action==="inline"){img.style.float="none";img.style.display="inline";img.style.margin="";}else if(action==="center"){img.style.float="none";img.style.display="block";img.style.margin="8px auto";}else if(action==="float-left"){img.style.float="left";img.style.margin="4px 12px 4px 0";}else if(action==="float-right"){img.style.float="right";img.style.margin="4px 0 4px 12px";} };
  const insertImg = () => { closePopup(); const fi=document.createElement("input"); fi.type="file"; fi.accept="image/*"; fi.onchange=e=>{const f=e.target.files[0];if(!f)return;const rd=new FileReader();rd.onload=ev=>exec("insertHTML",`<img src="${ev.target.result}" style="max-width:100%;height:auto"/>`);rd.readAsDataURL(f);}; fi.click(); };
  const insertTable = () => { let h='<table style="border-collapse:collapse;width:100%;margin:8px 0"><tbody>'; for(let i=0;i<3;i++){h+="<tr>";for(let j=0;j<3;j++)h+='<td style="border:1.5px solid #ccc;padding:6px 10px;min-width:40px">&nbsp;</td>';h+="</tr>";} h+="</tbody></table><p></p>"; exec("insertHTML",h); closePopup(); };
  const applySize = sz => { setSzPv(sz); setCurSz(sz); restoreSel(); const s=window.getSelection(); if(!s||!s.rangeCount)return; const r=s.getRangeAt(0); if(s.isCollapsed){if(edRef.current)edRef.current.style.fontSize=sz+"px";return;} const fr=r.extractContents(); const sp=document.createElement("span"); sp.style.fontSize=sz+"px"; sp.appendChild(fr); r.insertNode(sp); const nr=document.createRange(); nr.selectNodeContents(sp); s.removeAllRanges(); s.addRange(nr); savedRange.current=nr.cloneRange(); };

  const renderPopup = () => {
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

  const selActions = [
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
  const emptyActions = [
    {l:"Colar",ic:"clipboard",fn:async()=>{setEmptyMenu(null);try{const t=await navigator.clipboard.readText();restoreSel();exec("insertText",t);}catch(_){edRef.current?.focus();}}},
    {l:"Inserir",ic:"plus",fn:()=>{setEmptyMenu(null);const chip=document.querySelector("[data-chip='insert']");if(chip)openPopup("insert",chip);}},
  ];

  const IC_SCISSORS = `<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><line x1="20" y1="4" x2="8.12" y2="15.88"/><line x1="14.47" y1="14.48" x2="20" y2="20"/><line x1="8.12" y1="8.12" x2="12" y2="12"/>`;
  const IC_COPY = `<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>`;
  const IC_CLIP = `<rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/>`;
  const IC_CHK = `<polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>`;

  return (
    <div className={`ed-screen ${visible?"vis":"hid"}`}>
      <div className={`topbar${scrolled?" scrolled":""}`}>
        <button className="tbtn" onClick={onBack}><Icon name="arrow-left" size={22}/></button>
        <div contentEditable spellCheck={false} suppressContentEditableWarning className="tt"
          style={{position:"absolute",left:"50%",transform:"translateX(-50%)",fontSize:16,fontWeight:700,color:"#1c1c1e",whiteSpace:"nowrap",overflow:"hidden",textOverflow:"ellipsis",maxWidth:"calc(100% - 160px)",cursor:"text",padding:"4px 8px",borderRadius:8,border:"1.5px solid transparent",outline:"none",transition:"all .15s",fontFamily:"'DM Sans',sans-serif",WebkitUserSelect:"text",userSelect:"text"}}
          onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();e.currentTarget.blur();}}}
          dangerouslySetInnerHTML={{__html:doc?.title||""}}/>
        <div style={{position:"absolute",right:6,display:"flex",gap:2}}>
          {[["undo-2","undo"],["redo-2","redo"]].map(([ic,cmd])=>(
            <button key={cmd} className="tbtn" onClick={()=>exec(cmd)}><Icon name={ic} size={19}/></button>
          ))}
        </div>
      </div>

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

      <nav className="ftb-ed">
        <div className={`pill${aiMode?" ai-mode":""}`}>
          {aiMode ? (
            <div style={{display:"flex",alignItems:"center",gap:8,padding:"0 16px",flex:1,minWidth:0}}>
              <Icon name="sparkles" size={17} style={{color:"#007aff",flexShrink:0}}/>
              <input ref={aiRef} value={aiInput} onChange={e=>setAiInput(e.target.value)}
                onKeyDown={e=>{if(e.key==="Enter"){e.preventDefault();doAI();}}}
                placeholder="Pergunta à IA…"
                style={{flex:1,border:"none",background:"transparent",fontFamily:"'DM Sans',sans-serif",fontSize:14,color:"#1c1c1e",outline:"none",WebkitUserSelect:"text",userSelect:"text"}}/>
            </div>
          ) : (
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
              <TbChip st={{marginLeft:3}} onMouseDown={e=>e.preventDefault()} onClick={e=>openPopup("size",e.currentTarget)} active={activePopup==="size"}>{curSz}<Icon name="chevron-down" size={11}/></TbChip>
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
              <TbBtn onMouseDown={e=>e.preventDefault()} onClick={()=>setAiMode(true)} st={{background:"#eff6ff",color:"#007aff"}}>
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
        {aiMode && <button onMouseDown={e=>e.preventDefault()} onClick={()=>{setAiMode(false);setAiInput("");}}
          style={{position:"absolute",right:-44,top:"50%",transform:"translateY(-50%)",width:36,height:36,borderRadius:"50%",border:"1.5px solid rgba(0,0,0,.08)",background:"#fff",color:"#5e5e5b",display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",boxShadow:"0 2px 8px rgba(0,0,0,.08)"}}>
          <Icon name="x" size={15}/>
        </button>}
      </nav>

      {selVisible && (
        <div className={`sel-menu${selPos.dir==="down"?" adown":" aup"}`} style={{left:selPos.left,top:selPos.top,width:selPos.mw,"--ax":selPos.ax+"px"}} onMouseDown={e=>e.preventDefault()}>
          <div className="sel-inner noscroll">
            {selActions.map(a=><button key={a.l} onClick={a.fn} onMouseDown={e=>e.preventDefault()}
              style={{flexShrink:0,padding:"10px 12px",border:"none",background:"transparent",color:a.danger?"#ff453a":"#fff",fontFamily:"'DM Sans',sans-serif",fontSize:12.5,fontWeight:500,cursor:"pointer",borderRight:"1px solid rgba(255,255,255,.1)",whiteSpace:"nowrap",display:"flex",alignItems:"center",gap:5}}>
              <Icon name={a.ic} size={13}/>{a.l}
            </button>)}
          </div>
        </div>
      )}

      {emptyMenu && (
        <div className={`sel-menu${emptyMenu.dir==="down"?" adown":" aup"}`} style={{left:emptyMenu.left,top:emptyMenu.top,width:emptyMenu.mw,"--ax":emptyMenu.ax+"px"}} onMouseDown={e=>e.preventDefault()}>
          <div className="sel-inner noscroll">
            {emptyActions.map(a=><button key={a.l} onClick={a.fn} onMouseDown={e=>e.preventDefault()}
              style={{flexShrink:0,padding:"11px 20px",border:"none",background:"transparent",color:"#fff",fontFamily:"'DM Sans',sans-serif",fontSize:13.5,fontWeight:500,cursor:"pointer",borderRight:"1px solid rgba(255,255,255,.12)",whiteSpace:"nowrap",display:"flex",alignItems:"center",gap:7}}>
              <Icon name={a.ic} size={14}/>{a.l}
            </button>)}
          </div>
        </div>
      )}

      {imgMenu && (
        <>
          <div style={{position:"fixed",inset:0,zIndex:9998}} onClick={()=>setImgMenu(null)}/>
          <div className="img-ctx" style={{left:imgMenu.pos.x,top:imgMenu.pos.y}}>
            {[{label:"Em linha",icon:"align-left",action:"inline"},{label:"Centrado",icon:"align-center",action:"center"},{label:"Flutua à esquerda",icon:"align-left",action:"float-left"},{label:"Flutua à direita",icon:"align-right",action:"float-right"},{label:"Eliminar",icon:"trash-2",action:"delete",danger:true}].map(item=>(
              <button key={item.action} className={`img-ctx-item${item.danger?" danger":""}`} onClick={()=>{handleImgAction(item.action,imgMenu.el,imgMenu.img);setImgMenu(null);}}>
                <Icon name={item.icon} size={14} style={{color:item.danger?"#ff3b30":"#8e8e93"}}/>{item.label}
              </button>
            ))}
          </div>
        </>
      )}

      {activePopup && <div onMouseDown={closePopup} style={{position:"fixed",inset:0,zIndex:99,background:"transparent"}}/>}
      {activePopup && (
        <div className="pop" style={{width:popupPos.w,left:popupPos.left,bottom:popupPos.bottom,transformOrigin:`${popupPos.origX}px calc(100% + 14px)`}}>
          <div className="pop-inner">{renderPopup()}</div>
          <div className="pop-arrow" style={{left:popupPos.arrLeft}}/>
        </div>
      )}

      {ffOpen && (
        <div className="ff">
          <div style={{height:56,display:"flex",alignItems:"center",gap:10,padding:"0 16px",borderBottom:"1px solid rgba(0,0,0,.06)",flexShrink:0}}>
            <span style={{fontSize:16,fontWeight:700,color:"#1c1c1e",flexShrink:0}}>Fontes</span>
            <input value={ffSearch} onChange={e=>setFfSearch(e.target.value)} placeholder="Pesquisar fonte…" onMouseDown={e=>e.stopPropagation()}
              style={{flex:1,height:36,border:"1.5px solid rgba(0,0,0,.08)",borderRadius:9999,padding:"0 14px",fontSize:13,fontFamily:"'DM Sans',sans-serif",outline:"none",background:"#f2f2f7",WebkitUserSelect:"text",userSelect:"text"}}/>
            <button onClick={()=>setFfOpen(false)} style={{width:36,height:36,border:"none",background:"transparent",cursor:"pointer",borderRadius:9,display:"flex",alignItems:"center",justifyContent:"center",color:"#8e8e93"}}><Icon name="x" size={17}/></button>
          </div>
          <div className="noscroll" style={{display:"flex",gap:6,padding:"10px 16px",borderBottom:"1px solid rgba(0,0,0,.06)",overflowX:"auto",flexShrink:0}}>
            {["Todas",...new Set(FONTS.map(f=>f.g))].map(cat=>(
              <button key={cat} onClick={()=>setFfCat(cat)} style={{flexShrink:0,padding:"5px 13px",border:`1.5px solid ${ffCat===cat?"#007aff":"rgba(0,0,0,.08)"}`,borderRadius:9999,fontFamily:"'DM Sans',sans-serif",fontSize:12,fontWeight:600,cursor:"pointer",background:ffCat===cat?"#e8f0fe":"transparent",color:ffCat===cat?"#007aff":"#5e5e5b"}}>{cat}</button>
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
              style={{width:"100%",padding:"14px 0",background:ffSel?"#007aff":"rgba(0,0,0,.07)",color:ffSel?"#fff":"#8e8e93",border:"none",borderRadius:14,cursor:ffSel?"pointer":"default",fontFamily:"'DM Sans',sans-serif",fontSize:15,fontWeight:600}}>
              {ffSel?`Aplicar "${FONTS.find(f=>f.v===ffSel)?.l}"`:"Aplicar fonte"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}