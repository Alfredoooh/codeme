import { useState, useEffect, useRef, useCallback } from "react";

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
  "more-horizontal":`<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>`,
  "move-horizontal":`<polyline points="18 8 22 12 18 16"/><polyline points="6 8 2 12 6 16"/><line x1="2" y1="12" x2="22" y2="12"/>`,
  image:`<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/>`,
  "align-vertical-justify-center":`<rect x="2" y="7" width="20" height="10" rx="2"/><path d="M22 2H2M22 22H2"/>`,
  "layers":`<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>`,
  insert:`<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>`,
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

// Haptic helper
const haptic = (style = "light") => {
  try {
    if (navigator.vibrate) {
      navigator.vibrate(style === "light" ? 8 : style === "medium" ? 20 : 40);
    }
  } catch(_) {}
};

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=Lora:ital,wght@0,400;0,600;1,400&family=Inter:wght@400;500;600&family=Playfair+Display:wght@400;700&family=Merriweather:wght@400;700&family=Open+Sans:wght@400;600&family=Montserrat:wght@400;600&family=Roboto:wght@400;500&family=Poppins:wght@400;500;600&family=EB+Garamond:ital,wght@0,400;1,400&family=Dancing+Script:wght@400;700&family=Caveat:wght@400;700&family=Cinzel:wght@400;600&family=Pacifico&family=Fira+Code:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap');
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
html,body,#root{width:100%;height:100%;overflow:hidden;background:#f0f0ef}
.er{width:100%;height:100%;display:flex;flex-direction:column;font-family:'DM Sans',sans-serif;background:#f0f0ef;-webkit-user-select:none;user-select:none;overflow:hidden}
.topbar{position:relative;height:52px;flex-shrink:0;display:flex;align-items:center;padding:0 6px;background:#fff;border-bottom:1px solid rgba(0,0,0,.10);z-index:10}
.canvas{flex:1;overflow-y:auto;overflow-x:hidden;-webkit-overflow-scrolling:touch;background:#f0f0ef;padding:24px 16px 220px;display:flex;flex-direction:column;align-items:center}
.canvas::-webkit-scrollbar{width:5px}
.canvas::-webkit-scrollbar-track{background:transparent}
.canvas::-webkit-scrollbar-thumb{background:rgba(0,0,0,.18);border-radius:3px}
.pw{width:794px;transform-origin:top center;transition:transform .3s cubic-bezier(.22,1,.36,1),margin-bottom .3s}
.page{width:794px;background:#fff;border-radius:6px;border:1.5px solid #c8c8c8;box-shadow:0 1px 4px rgba(0,0,0,.06),0 4px 16px rgba(0,0,0,.06);padding:96px 88px 120px;min-height:1123px;transition:box-shadow .25s,border-color .25s}
.page.focused{box-shadow:0 2px 10px rgba(0,0,0,.09),0 8px 32px rgba(0,0,0,.11);border-color:#b0b0b0}
.pw.a4{display:flex;flex-direction:column;align-items:center;gap:24px}
.a4page{width:794px;height:1123px;background:#fff;border-radius:6px;border:1.5px solid #c8c8c8;box-shadow:0 1px 4px rgba(0,0,0,.06),0 4px 16px rgba(0,0,0,.06);padding:96px 88px;overflow:hidden;position:relative;flex-shrink:0}
.a4page::after{content:'';position:absolute;bottom:0;left:0;right:0;height:3px;background:linear-gradient(to bottom,transparent,rgba(0,0,0,.05));pointer-events:none}
.a4num{position:absolute;bottom:14px;right:20px;font-size:10px;font-weight:600;color:#858481;pointer-events:none}
.pc{outline:none;font-family:'Lora',Georgia,serif;font-size:16px;line-height:1.85;color:#34322d;min-height:600px;word-break:break-word;caret-color:#2563eb;-webkit-user-select:text;user-select:text;cursor:text}
.a4page .pc{min-height:unset;height:100%}
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
.sm{position:fixed;z-index:9999;background:#1c1c1e;border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,.5),0 2px 8px rgba(0,0,0,.3);overflow:visible;pointer-events:auto}
.sm.show{animation:selIn .15s cubic-bezier(.34,1.56,.64,1) both}
.sm-inner{display:flex;align-items:stretch;overflow-x:auto;border-radius:14px;scrollbar-width:none}
.sm-inner::-webkit-scrollbar{display:none}
.sm::after{content:'';position:absolute;width:0;height:0;left:var(--ax,50%);transform:translateX(-50%);pointer-events:none}
.sm.adown::after{top:100%;border-left:6px solid transparent;border-right:6px solid transparent;border-top:7px solid #1c1c1e}
.sm.aup::after{bottom:100%;border-left:6px solid transparent;border-right:6px solid transparent;border-bottom:7px solid #1c1c1e}
.pop{position:fixed;background:#fff;border:1px solid rgba(0,0,0,.09);border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,.13),0 2px 8px rgba(0,0,0,.07);z-index:100;overflow:visible;animation:popIn .2s cubic-bezier(.34,1.56,.64,1) both}
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
/* Image wrapper */
.img-wrap{display:inline-block;position:relative;cursor:pointer;-webkit-user-select:none;user-select:none;line-height:0}
.img-wrap img{display:block;max-width:100%;height:auto;border-radius:3px}
.img-wrap.selected img{outline:2px solid #2563eb;outline-offset:2px;border-radius:3px}
.img-dots-btn{position:absolute;top:6px;right:6px;width:28px;height:28px;background:rgba(0,0,0,.55);backdrop-filter:blur(6px);border-radius:8px;display:flex;align-items:center;justify-content:center;cursor:pointer;z-index:5;border:none;padding:0;color:#fff;animation:popIn .15s both}
.resize-handle{position:absolute;bottom:4px;right:4px;width:18px;height:18px;cursor:se-resize;z-index:6;display:flex;align-items:center;justify-content:center;opacity:.7}
.resize-handle::before{content:'';display:block;width:10px;height:10px;border-right:2.5px solid rgba(255,255,255,.9);border-bottom:2.5px solid rgba(255,255,255,.9);border-radius:1px}
/* Image context menu */
.img-menu{position:fixed;background:#1c1c1e;border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,.5);z-index:9999;overflow:hidden;min-width:200px;animation:selIn .15s cubic-bezier(.34,1.56,.64,1) both}
.img-menu-item{display:flex;align-items:center;gap:10px;padding:11px 16px;color:#fff;font-size:13.5px;font-weight:500;font-family:'DM Sans',sans-serif;cursor:pointer;border:none;background:transparent;width:100%;text-align:left}
.img-menu-item:active{background:rgba(255,255,255,.08)}
.img-menu-item.danger{color:#ff6b6b}
.img-menu-sep{height:1px;background:rgba(255,255,255,.10);margin:2px 0}
/* Alert boxes — redesigned */
.alert-box{display:flex;align-items:flex-start;gap:12px;padding:14px 16px;margin:10px 0;border-radius:10px;font-size:14px;line-height:1.6;border:1.5px solid transparent;-webkit-user-select:text;user-select:text}
.alert-box .alert-icon{flex-shrink:0;width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:800;margin-top:1px}
.alert-box .alert-body{flex:1;min-width:0}
.alert-box .alert-title{font-weight:700;font-size:13px;margin-bottom:2px;letter-spacing:.01em}
.alert-box .alert-text{font-size:13px;opacity:.85}
.alert-warn{background:#fffbeb;border-color:#f59e0b;color:#78350f}
.alert-warn .alert-icon{background:#f59e0b;color:#fff}
.alert-info{background:#eff6ff;border-color:#3b82f6;color:#1e3a5f}
.alert-info .alert-icon{background:#3b82f6;color:#fff}
.alert-ok{background:#f0fdf4;border-color:#22c55e;color:#14532d}
.alert-ok .alert-icon{background:#22c55e;color:#fff}
.alert-err{background:#fff1f2;border-color:#f43f5e;color:#4c0519}
.alert-err .alert-icon{background:#f43f5e;color:#fff}
@keyframes popIn{from{opacity:0;transform:scale(.5)}to{opacity:1;transform:scale(1)}}
@keyframes selIn{from{opacity:0;transform:scale(.88) translateY(4px)}to{opacity:1;transform:scale(1) translateY(0)}}
@keyframes aiDot{0%,80%,100%{transform:scale(.6);opacity:.4}40%{transform:scale(1);opacity:1}}
`;

const S = (obj) => Object.entries(obj).reduce((a,[k,v])=>(a[k]=v,a),{});
const TbBtn = ({children,active,onMouseDown,onClick,style})=>(
  <button onMouseDown={onMouseDown} onClick={onClick}
    style={S({height:38,minWidth:38,padding:"0 7px",border:"none",background:active?"#eff6ff":"transparent",borderRadius:9999,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",flexDirection:"column",gap:2,flexShrink:0,color:active?"#2563eb":"#5e5e5b",transition:"background .15s",...style})}>
    {children}
  </button>
);
const TbChip = ({children,active,onMouseDown,onClick,style})=>(
  <button onMouseDown={onMouseDown} onClick={onClick}
    style={S({height:32,border:`1.5px solid ${active?"#2563eb":"rgba(0,0,0,.08)"}`,borderRadius:9999,padding:"0 11px",fontFamily:"inherit",fontSize:12,fontWeight:600,color:active?"#2563eb":"#34322d",background:active?"#eff6ff":"transparent",cursor:"pointer",display:"flex",alignItems:"center",gap:4,whiteSpace:"nowrap",flexShrink:0,transition:"all .15s",...style})}>
    {children}
  </button>
);
const Div=()=><div style={{width:1,height:20,background:"rgba(0,0,0,.08)",flexShrink:0,margin:"0 4px"}}/>;
const PH=({title})=><div style={{padding:"11px 14px",fontSize:10.5,fontWeight:700,color:"#858481",textTransform:"uppercase",letterSpacing:".07em",borderBottom:"1px solid rgba(0,0,0,.08)"}}>{title}</div>;
const PI=({icon,label,danger,onClick})=>(
  <button onMouseDown={e=>e.preventDefault()} onClick={onClick}
    style={S({display:"flex",alignItems:"center",gap:10,padding:"9px 14px",fontSize:13,fontWeight:500,color:danger?"#dc2626":"#34322d",cursor:"pointer",border:"none",background:"transparent",width:"100%",textAlign:"left",fontFamily:"inherit"})}
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
  const alertBoxes = [
    {id:"warn", cls:"alert-warn", icon:"⚠", iconBg:"#f59e0b", title:"Aviso", text:"Conteúdo importante que requer atenção."},
    {id:"info", cls:"alert-info", icon:"i", iconBg:"#3b82f6", title:"Informação", text:"Uma nota ou detalhe informativo."},
    {id:"ok",   cls:"alert-ok",   icon:"✓", iconBg:"#22c55e", title:"Sucesso", text:"Operação concluída com êxito."},
    {id:"err",  cls:"alert-err",  icon:"✕", iconBg:"#f43f5e", title:"Erro", text:"Algo correu mal. Tenta novamente."},
  ];
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
      {alertBoxes.map(a=>(
        <PI key={a.id} icon={a.id==="warn"?"alert-triangle":a.id==="info"?"info":a.id==="ok"?"check-circle":"x-circle"} label={a.title} onClick={()=>{
          exec("insertHTML",`<div class="alert-box alert-${a.id}" contenteditable="true"><div class="alert-icon" style="background:${a.iconBg};color:#fff">${a.icon}</div><div class="alert-body"><div class="alert-title">${a.title}</div><div class="alert-text">${a.text}</div></div></div><p></p>`);
          onClose();
        }}/>
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

// ── IMAGE MENU ─────────────────────────────────────────────
function ImageMenu({ pos, onClose, onAction }) {
  const items = [
    { label: "Acima do texto", icon: "layers", action: "above" },
    { label: "Atrás do texto", icon: "layers", action: "behind" },
    { label: "Em linha", icon: "align-left", action: "inline" },
    { label: "Centrado", icon: "align-center", action: "center" },
    { label: "Flutua à esquerda", icon: "align-left", action: "float-left" },
    { label: "Flutua à direita", icon: "align-right", action: "float-right" },
    null,
    { label: "Eliminar imagem", icon: "trash-2", action: "delete", danger: true },
  ];
  return (
    <div className="img-menu" style={{ left: pos.x, top: pos.y }}
      onMouseDown={e => e.stopPropagation()}>
      {items.map((item, i) =>
        item === null
          ? <div key={i} className="img-menu-sep" />
          : <button key={i} className={`img-menu-item${item.danger ? " danger" : ""}`}
              onClick={() => { onAction(item.action); onClose(); }}>
              <Icon name={item.icon} size={15} style={{ color: item.danger ? "#ff6b6b" : "rgba(255,255,255,.6)", flexShrink: 0 }} />
              {item.label}
            </button>
      )}
    </div>
  );
}

// ── MAIN ──────────────────────────────────────────────────
export default function App() {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [aiMode, setAiMode] = useState(false);
  const [aiLoading, setAiLoading] = useState(false);
  const [aiInput, setAiInput] = useState("");
  const [curFont, setCurFont] = useState("'Lora',Georgia,serif");
  const [fontLabel, setFontLabel] = useState("Lora");
  const [curSz, setCurSz] = useState(16);
  const [szPv, setSzPv] = useState(16);
  const [colorBar, setColorBar] = useState("#f0a500");
  const [focused, setFocused] = useState(false);
  const [a4Mode, setA4Mode] = useState(false);
  const [activePopup, setActivePopup] = useState(null);
  const [popupPos, setPopupPos] = useState({ left: 0, bottom: 0, origX: 0, w: 240, arrLeft: 0 });
  const [selVisible, setSelVisible] = useState(false);
  const [selPos, setSelPos] = useState({ left: 0, top: 0, ax: 0, dir: "down" });
  const [emptyLineMenu, setEmptyLineMenu] = useState(null); // {left,top,ax,dir,mw}
  const [ffOpen, setFfOpen] = useState(false);
  const [ffSearch, setFfSearch] = useState("");
  const [ffCat, setFfCat] = useState("Todas");
  const [ffSel, setFfSel] = useState(null);
  const [fontSearch, setFontSearch] = useState("");
  const [fontPreview, setFontPreview] = useState(null);
  const [hexIn, setHexIn] = useState("#34322d");
  const [hexPv, setHexPv] = useState("#34322d");
  const [alignActive, setAlignActive] = useState("L");
  const [a4Html, setA4Html] = useState("");
  const [imgMenu, setImgMenu] = useState(null); // {pos, el}
  const [selectedImg, setSelectedImg] = useState(null);

  const edRef = useRef(null);
  const savedRange = useRef(null);
  const popTrigRef = useRef(null);
  const canvasRef = useRef(null);
  const wrapRef = useRef(null);
  const aiRef = useRef(null);
  const resizeState = useRef(null);
  const pinchState = useRef(null);

  useEffect(() => {
    const s = document.createElement("style");
    s.textContent = CSS;
    document.head.appendChild(s);
    return () => document.head.removeChild(s);
  }, []);

  const zoom = useCallback(() => {
    if (!canvasRef.current || !wrapRef.current) return;
    const avail = canvasRef.current.clientWidth - 32;
    const sc = avail < 794 ? avail / 794 : 1;
    if (sc < 1) {
      wrapRef.current.style.transform = `scale(${sc})`;
      wrapRef.current.style.transformOrigin = "top center";
      wrapRef.current.style.marginBottom = `${(sc - 1) * 1123}px`;
    } else {
      wrapRef.current.style.transform = "none";
      wrapRef.current.style.marginBottom = "0";
    }
  }, []);
  useEffect(() => { zoom(); window.addEventListener("resize", zoom); return () => window.removeEventListener("resize", zoom); }, [zoom]);
  useEffect(() => {
    if (!canvasRef.current) return;
    const ro = new ResizeObserver(zoom);
    ro.observe(canvasRef.current);
    return () => ro.disconnect();
  }, [zoom]);

  const saveSel = useCallback(() => {
    const s = window.getSelection();
    if (s && s.rangeCount > 0 && !s.isCollapsed) savedRange.current = s.getRangeAt(0).cloneRange();
  }, []);
  const restoreSel = useCallback(() => {
    if (!savedRange.current) { edRef.current?.focus(); return; }
    edRef.current?.focus();
    try { const s = window.getSelection(); s.removeAllRanges(); s.addRange(savedRange.current); } catch (_) {}
  }, []);
  const exec = useCallback((cmd, val) => {
    restoreSel();
    document.execCommand(cmd, false, val || null);
    saveSel();
  }, [restoreSel, saveSel]);

  const tryShowSel = useCallback(() => {
    const s = window.getSelection();
    if (!s || s.isCollapsed || !s.toString().trim()) { setSelVisible(false); return; }
    const r = s.getRangeAt(0).getBoundingClientRect();
    if (!r.width && !r.height) { setSelVisible(false); return; }
    const GAP = 10, AH = 7, MH = 44, vw = window.innerWidth, vh = window.innerHeight;
    const mw = Math.min(vw - 16, 480);
    let left = r.left + r.width / 2 - mw / 2;
    left = Math.max(8, Math.min(vw - mw - 8, left));
    const ax = Math.max(16, Math.min(mw - 16, r.left + r.width / 2 - left));
    const spaceAbove = r.top - GAP - AH - MH;
    const spaceBelow = vh - r.bottom - GAP - AH - MH;
    let top, dir;
    if (spaceAbove >= 0) { top = r.top - MH - GAP - AH; dir = "down"; }
    else if (spaceBelow >= 0) { top = r.bottom + GAP + AH; dir = "up"; }
    else if (spaceAbove > spaceBelow) { top = Math.max(8, r.top - MH - GAP - AH); dir = "down"; }
    else { top = r.bottom + GAP + AH; dir = "up"; }
    setSelPos({ left, top, ax, dir, mw });
    setSelVisible(true);
  }, []);

  // Detect empty line tap → show mini menu (Colar + Inserir)
  const handleEditorClick = useCallback((e) => {
    const target = e.target;
    // If clicking an image wrapper, skip
    if (target.closest && target.closest(".img-wrap")) return;
    setTimeout(() => {
      const s = window.getSelection();
      if (!s || !s.isCollapsed) return;
      // Get the block element
      let node = s.anchorNode;
      if (!node) return;
      let block = node.nodeType === 3 ? node.parentElement : node;
      while (block && block !== edRef.current && !["P","DIV","H1","H2","H3","H4","LI","BLOCKQUOTE","PRE"].includes(block.tagName)) {
        block = block.parentElement;
      }
      const text = block?.innerText?.trim() || node?.textContent?.trim() || "";
      if (text.length > 0) return; // not empty
      // Position menu near caret
      const range = s.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      const caretX = rect.left || e.clientX;
      const caretY = rect.top || e.clientY;
      const vw = window.innerWidth, vh = window.innerHeight;
      const mw = 200;
      let left = caretX - mw / 2;
      left = Math.max(8, Math.min(vw - mw - 8, left));
      const ax = Math.max(16, Math.min(mw - 16, caretX - left));
      const MH = 44, GAP = 10, AH = 7;
      const spaceAbove = caretY - GAP - AH - MH;
      const spaceBelow = vh - caretY - GAP - AH - MH;
      let top, dir;
      if (spaceBelow >= 0) { top = caretY + GAP + AH; dir = "up"; }
      else { top = Math.max(8, caretY - MH - GAP - AH); dir = "down"; }
      haptic("light");
      setEmptyLineMenu({ left, top, ax, dir, mw });
    }, 60);
  }, []);

  const closePopup = useCallback(() => {
    setActivePopup(null);
    setFontPreview(null);
    setFontSearch("");
  }, []);

  const openPopup = useCallback((type, trig) => {
    if (activePopup === type) { closePopup(); return; }
    saveSel();
    const wMap = { "color-text": 254, font: 240, size: 220, styles: 200, insert: 240, format: 240 };
    const w = wMap[type] || 240;
    const r = trig.getBoundingClientRect();
    let left = r.left + r.width / 2 - w / 2;
    left = Math.max(8, Math.min(window.innerWidth - w - 8, left));
    const bottom = window.innerHeight - r.top + 12;
    const origX = Math.max(20, Math.min(w - 20, r.left + r.width / 2 - left));
    const arrLeft = Math.max(12, Math.min(w - 24, r.left + r.width / 2 - left - 7));
    setPopupPos({ left, bottom, origX, w, arrLeft });
    setActivePopup(type);
    popTrigRef.current = trig;
  }, [activePopup, closePopup, saveSel]);

  useEffect(() => { if (aiMode && aiRef.current) setTimeout(() => aiRef.current?.focus(), 80); }, [aiMode]);

  const doAI = async () => {
    const p = aiInput.trim(); if (!p) return;
    setAiInput(""); setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "claude-sonnet-4-20250514", max_tokens: 1000, system: "Responde APENAS com o texto a inserir no editor, sem explicações nem markdown extra. Responde em português.", messages: [{ role: "user", content: p }] })
      });
      const d = await r.json();
      restoreSel();
      exec("insertText", d.content?.map(i => i.text || "").join("") || "(sem resposta)");
    } catch { restoreSel(); exec("insertText", "[Erro IA]"); }
    setAiLoading(false);
    setTimeout(() => aiRef.current?.focus(), 50);
  };

  // ── IMAGE handling ─────────────────────────────────────
  const wrapImage = useCallback((img) => {
    if (img.parentElement?.classList.contains("img-wrap")) return;
    const wrap = document.createElement("span");
    wrap.className = "img-wrap";
    wrap.contentEditable = "false";
    wrap.style.cssText = "display:inline-block;position:relative;cursor:pointer;line-height:0;max-width:100%";
    img.parentNode.insertBefore(wrap, img);
    wrap.appendChild(img);

    // dots button
    const btn = document.createElement("button");
    btn.className = "img-dots-btn";
    btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>`;
    btn.style.display = "none";
    wrap.appendChild(btn);

    // resize handle
    const rh = document.createElement("div");
    rh.className = "resize-handle";
    rh.style.display = "none";
    wrap.appendChild(rh);

    const showControls = () => { btn.style.display = "flex"; rh.style.display = "flex"; };
    const hideControls = () => { btn.style.display = "none"; rh.style.display = "none"; };

    // Single tap/click → select & show dots
    wrap.addEventListener("click", (e) => {
      e.stopPropagation();
      e.preventDefault();
      haptic("light");
      // deselect others
      document.querySelectorAll(".img-wrap.selected").forEach(w => {
        if (w !== wrap) { w.classList.remove("selected"); }
      });
      if (wrap.classList.contains("selected")) {
        // Already selected → show menu on dots click
      } else {
        wrap.classList.add("selected");
        setSelectedImg(wrap);
        showControls();
      }
    });

    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      haptic("medium");
      const rect = btn.getBoundingClientRect();
      const x = Math.min(rect.right + 8, window.innerWidth - 210);
      const y = rect.bottom + 6;
      setImgMenu({ pos: { x, y }, el: wrap, img });
    });

    // Mouse-based resize (desktop)
    rh.addEventListener("mousedown", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const startX = e.clientX, startW = img.offsetWidth;
      const onMove = (me) => {
        const newW = Math.max(40, startW + (me.clientX - startX));
        img.style.width = newW + "px";
        img.style.height = "auto";
      };
      const onUp = () => { window.removeEventListener("mousemove", onMove); window.removeEventListener("mouseup", onUp); };
      window.addEventListener("mousemove", onMove);
      window.addEventListener("mouseup", onUp);
    });

    // Touch pinch-to-resize
    wrap.addEventListener("touchstart", (e) => {
      if (e.touches.length === 2) {
        e.preventDefault();
        const d = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY);
        pinchState.current = { startDist: d, startW: img.offsetWidth };
      }
    }, { passive: false });
    wrap.addEventListener("touchmove", (e) => {
      if (e.touches.length === 2 && pinchState.current) {
        e.preventDefault();
        const d = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY);
        const ratio = d / pinchState.current.startDist;
        const newW = Math.max(40, Math.min(pinchState.current.startW * ratio, edRef.current?.offsetWidth || 600));
        img.style.width = newW + "px";
        img.style.height = "auto";
      }
    }, { passive: false });
    wrap.addEventListener("touchend", () => { pinchState.current = null; });
  }, []);

  // Observe new images
  useEffect(() => {
    const ed = edRef.current; if (!ed) return;
    const obs = new MutationObserver(() => {
      ed.querySelectorAll("img").forEach(img => wrapImage(img));
    });
    obs.observe(ed, { childList: true, subtree: true });
    return () => obs.disconnect();
  }, [wrapImage]);

  // Click outside → deselect image
  useEffect(() => {
    const handler = (e) => {
      if (!e.target.closest(".img-wrap") && !e.target.closest(".img-menu")) {
        document.querySelectorAll(".img-wrap.selected").forEach(w => w.classList.remove("selected"));
        document.querySelectorAll(".img-dots-btn,.resize-handle").forEach(el => el.style.display = "none");
        setSelectedImg(null);
        setImgMenu(null);
      }
    };
    document.addEventListener("click", handler);
    return () => document.removeEventListener("click", handler);
  }, []);

  const handleImgAction = (action, el, img) => {
    if (!el || !img) return;
    haptic("light");
    switch (action) {
      case "delete":
        el.parentNode?.removeChild(el);
        break;
      case "inline":
        img.style.float = "none"; img.style.display = "inline"; img.style.position = "static"; break;
      case "center":
        img.style.float = "none"; img.style.display = "block"; img.style.margin = "8px auto"; break;
      case "float-left":
        img.style.float = "left"; img.style.margin = "4px 12px 4px 0"; break;
      case "float-right":
        img.style.float = "right"; img.style.margin = "4px 0 4px 12px"; break;
      case "above":
        el.style.zIndex = "10"; el.style.position = "relative"; break;
      case "behind":
        el.style.zIndex = "-1"; el.style.position = "relative"; break;
    }
  };

  const insertImg = () => {
    closePopup();
    const fi = document.createElement("input");
    fi.type = "file"; fi.accept = "image/*";
    fi.onchange = e => {
      const f = e.target.files[0]; if (!f) return;
      const rd = new FileReader();
      rd.onload = ev => exec("insertHTML", `<img src="${ev.target.result}" style="max-width:100%;height:auto"/>`);
      rd.readAsDataURL(f);
    };
    fi.click();
  };
  const insertTable = () => {
    let h = '<table style="border-collapse:collapse;width:100%;margin:8px 0"><tbody>';
    for (let i = 0; i < 3; i++) { h += "<tr>"; for (let j = 0; j < 3; j++) h += '<td style="border:1.5px solid #ccc;padding:6px 10px;min-width:40px">&nbsp;</td>'; h += "</tr>"; }
    h += "</tbody></table><p></p>";
    exec("insertHTML", h); closePopup();
  };

  const applySize = sz => {
    setSzPv(sz); setCurSz(sz);
    restoreSel();
    const s = window.getSelection(); if (!s || !s.rangeCount) return;
    const r = s.getRangeAt(0);
    if (s.isCollapsed) { if (edRef.current) edRef.current.style.fontSize = sz + "px"; return; }
    const fr = r.extractContents(); const sp = document.createElement("span");
    sp.style.fontSize = sz + "px"; sp.appendChild(fr); r.insertNode(sp);
    const nr = document.createRange(); nr.selectNodeContents(sp);
    s.removeAllRanges(); s.addRange(nr); savedRange.current = nr.cloneRange();
  };

  const enableA4 = () => { const html = edRef.current?.innerHTML || ""; setA4Html(html); setA4Mode(true); };
  const disableA4 = () => { setA4Mode(false); requestAnimationFrame(() => { if (edRef.current && a4Html) edRef.current.innerHTML = a4Html; }); };

  const renderPopup = () => {
    switch (activePopup) {
      case "color-text": return <ColorPopup colors={COLORS} hexIn={hexIn} setHexIn={setHexIn} hexPv={hexPv} setHexPv={setHexPv} onApply={c => { exec("foreColor", c); setColorBar(c); closePopup(); }} />;
      case "font": return <FontPopup fonts={FONTS} curFont={curFont} search={fontSearch} setSearch={setFontSearch} preview={fontPreview} setPreview={setFontPreview} onExpand={() => { closePopup(); setFfOpen(true); }} onApply={f => { setCurFont(f.v); setFontLabel(f.l); exec("fontName", f.l); closePopup(); }} />;
      case "size": return <SizePopup szPv={szPv} onApply={sz => { applySize(sz); closePopup(); }} onStep={d => { const n = Math.max(6, Math.min(200, szPv + d)); applySize(n); }} />;
      case "styles": return <StylesPopup exec={exec} onClose={closePopup} />;
      case "insert": return <InsertPopup exec={exec} onClose={closePopup} insertImg={insertImg} insertTable={insertTable} />;
      case "format": return <FormatPopup exec={exec} onClose={closePopup} edRef={edRef} restoreSel={restoreSel} />;
      default: return null;
    }
  };

  const selActions = [
    { l: "Cortar", ic: "scissors", fn: async () => { const s = window.getSelection(); if (s && !s.isCollapsed) { try { await navigator.clipboard.writeText(s.toString()) } catch (_) {} exec("delete"); } setSelVisible(false); } },
    { l: "Copiar", ic: "copy", fn: async () => { const s = window.getSelection(); if (s && !s.isCollapsed) { try { await navigator.clipboard.writeText(s.toString()) } catch (_) { document.execCommand("copy"); } } setSelVisible(false); } },
    { l: "Colar", ic: "clipboard", fn: async () => { setSelVisible(false); try { const t = await navigator.clipboard.readText(); restoreSel(); exec("insertText", t); } catch (_) { edRef.current?.focus(); } } },
    { l: "Sel. tudo", ic: "check-square", fn: () => { edRef.current?.focus(); document.execCommand("selectAll"); setSelVisible(false); setTimeout(tryShowSel, 80); } },
    { l: "Negrito", ic: "bold", fn: () => { exec("bold"); setSelVisible(false); } },
    { l: "Itálico", ic: "italic", fn: () => { exec("italic"); setSelVisible(false); } },
    { l: "Sublinhado", ic: "underline", fn: () => { exec("underline"); setSelVisible(false); } },
    { l: "MAIÚSC.", ic: "case-upper", fn: () => { restoreSel(); const s = window.getSelection(); if (s && !s.isCollapsed) document.execCommand("insertText", false, s.toString().toUpperCase()); setSelVisible(false); } },
    { l: "Link", ic: "link", fn: () => { setSelVisible(false); const u = prompt("URL:"); if (u) exec("createLink", u); } },
    { l: "Apagar", ic: "trash-2", fn: () => { exec("delete"); setSelVisible(false); }, danger: true },
  ];

  const emptyLineActions = [
    {
      l: "Colar", ic: "clipboard", fn: async () => {
        setEmptyLineMenu(null);
        try { const t = await navigator.clipboard.readText(); restoreSel(); exec("insertText", t); }
        catch (_) { edRef.current?.focus(); }
      }
    },
    {
      l: "Inserir", ic: "plus", fn: (e) => {
        setEmptyLineMenu(null);
        // open insert popup from toolbar — find the insert chip
        const chip = document.querySelector("[data-insert-chip]");
        if (chip) openPopup("insert", chip);
      }
    },
  ];

  return (
    <div className="er">
      {/* DRAWER */}
      <div className={`drawer${drawerOpen ? " open" : ""}`}>
        <div style={{ padding: "52px 20px 14px", borderBottom: "1px solid rgba(0,0,0,.08)" }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: "#858481", textTransform: "uppercase", letterSpacing: ".06em" }}>Funcionalidades</div>
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: 10 }}>
          <div style={{ paddingTop: 8, paddingBottom: 8, borderBottom: "1px solid rgba(0,0,0,.08)" }}>
            <button onClick={() => { setAiMode(v => !v); setDrawerOpen(false); }}
              style={{ display: "flex", alignItems: "center", gap: 12, width: "100%", padding: "11px 14px", fontSize: 14, fontWeight: 500, color: aiMode ? "#2563eb" : "#34322d", background: aiMode ? "#eff6ff" : "transparent", borderRadius: 10, border: "none", cursor: "pointer", fontFamily: "inherit" }}>
              <Icon name={aiMode ? "bot" : "keyboard"} size={18} style={{ color: "#5e5e5b", flexShrink: 0 }} />
              <span>{aiMode ? "IA activa" : "Toolbar / IA"}</span>
            </button>
            <button onClick={() => { a4Mode ? disableA4() : enableA4(); setDrawerOpen(false); }}
              style={{ display: "flex", alignItems: "center", gap: 12, width: "100%", padding: "11px 14px", fontSize: 14, fontWeight: 500, color: a4Mode ? "#2563eb" : "#34322d", background: a4Mode ? "#eff6ff" : "transparent", borderRadius: 10, border: "none", cursor: "pointer", fontFamily: "inherit" }}>
              <Icon name={a4Mode ? "layout" : "file-text"} size={18} style={{ color: "#5e5e5b", flexShrink: 0 }} />
              <span>{a4Mode ? "Formato: A4" : "Formato: Scroll"}</span>
            </button>
          </div>
        </div>
      </div>
      {drawerOpen && <div onClick={() => setDrawerOpen(false)} style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,.18)", zIndex: 15 }} />}

      {/* TOPBAR */}
      <div className="topbar" style={{ transform: drawerOpen ? "translateX(110px)" : "none", transition: "transform 400ms cubic-bezier(.22,1,.36,1)" }}>
        <div style={{ position: "absolute", left: 6, display: "flex", gap: 2 }}>
          <button onClick={() => setDrawerOpen(v => !v)} style={{ width: 44, height: 44, border: "none", background: "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", borderRadius: 10, color: "#5e5e5b" }}>
            <Icon name="menu" size={20} />
          </button>
        </div>
        <div contentEditable spellCheck={false} data-placeholder="Sem título" className="tt"
          style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", fontSize: 15, fontWeight: 600, color: "#34322d", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", maxWidth: "calc(100% - 160px)", cursor: "text", padding: "4px 8px", borderRadius: 6, border: "1.5px solid transparent", outline: "none", transition: "all .15s", fontFamily: "inherit", WebkitUserSelect: "text", userSelect: "text" }}
          onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); e.currentTarget.blur(); } }} />
        <div style={{ position: "absolute", right: 6, display: "flex", gap: 2 }}>
          {[["undo-2", "undo"], ["redo-2", "redo"]].map(([ic, cmd]) => (
            <button key={cmd} onClick={() => exec(cmd)} style={{ width: 44, height: 44, border: "none", background: "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", borderRadius: 10, color: "#5e5e5b" }}>
              <Icon name={ic} size={20} />
            </button>
          ))}
        </div>
      </div>

      {/* CANVAS */}
      <div ref={canvasRef} className="canvas noscroll"
        style={{ transform: drawerOpen ? "translateX(110px)" : "none", transition: "transform 400ms cubic-bezier(.22,1,.36,1)" }}
        onClick={e => {
          if (!e.target.closest(".pc")) {
            savedRange.current = null;
            window.getSelection()?.removeAllRanges();
            setSelVisible(false);
            setEmptyLineMenu(null);
          }
        }}>
        <div ref={wrapRef} className={`pw${a4Mode ? " a4" : ""}`}>
          {a4Mode ? (
            <div className="a4page">
              <div className="pc" contentEditable spellCheck data-placeholder="Começa a escrever…"
                style={{ minHeight: "unset", height: "100%" }}
                dangerouslySetInnerHTML={{ __html: a4Html }}
                onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
                onMouseUp={() => setTimeout(() => { saveSel(); tryShowSel(); }, 20)}
                onTouchEnd={() => setTimeout(() => { saveSel(); tryShowSel(); }, 120)}
                onKeyUp={saveSel}
                onClick={handleEditorClick}
                onContextMenu={e => { e.preventDefault(); saveSel(); tryShowSel(); }}
              />
              <div className="a4num">1</div>
            </div>
          ) : (
            <div className={`page${focused ? " focused" : ""}`}>
              <div ref={edRef} className="pc" contentEditable spellCheck data-placeholder="Começa a escrever…"
                onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
                onMouseUp={() => setTimeout(() => { saveSel(); tryShowSel(); }, 20)}
                onTouchEnd={() => setTimeout(() => { saveSel(); tryShowSel(); }, 120)}
                onKeyUp={saveSel}
                onClick={handleEditorClick}
                onContextMenu={e => { e.preventDefault(); saveSel(); tryShowSel(); }}
              />
            </div>
          )}
        </div>
      </div>

      {/* FLOATING TOOLBAR */}
      <nav className="ftb" style={{ transform: drawerOpen ? "translateX(55px)" : "translateX(-50%)", left: drawerOpen ? "calc(50% + 0px)" : "50%", transition: "transform 400ms cubic-bezier(.22,1,.36,1)" }}>
        <div className={`pill${aiMode ? " ai" : ""}`}>
          {aiMode ? (
            <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "0 16px", flex: 1, minWidth: 0 }}>
              <input ref={aiRef} value={aiInput} onChange={e => setAiInput(e.target.value)}
                onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); doAI(); } }}
                placeholder="Pergunta à IA…"
                style={{ flex: 1, border: "none", background: "transparent", fontFamily: "'DM Sans',sans-serif", fontSize: 14, color: "#34322d", outline: "none", WebkitUserSelect: "text", userSelect: "text" }} />
            </div>
          ) : (
            <div className="tbtrack noscroll">
              <TbBtn onMouseDown={e => e.preventDefault()} onClick={e => openPopup("color-text", e.currentTarget)}>
                <span style={{ fontSize: 16, fontWeight: 900, lineHeight: 1 }}>A</span>
                <div style={{ width: 16, height: 3, borderRadius: 2, background: colorBar }} />
              </TbBtn>
              <Div />
              {[["bold", "B", 900, "normal", "none"], ["italic", "I", 600, "italic", "none"], ["underline", "U", 600, "normal", "underline"], ["strikeThrough", "S", 600, "normal", "line-through"]].map(([cmd, lbl, fw, fs, td]) => (
                <TbBtn key={cmd} onMouseDown={e => e.preventDefault()} onClick={() => exec(cmd)}>
                  <span style={{ fontSize: 16, fontWeight: fw, fontStyle: fs, textDecoration: td, lineHeight: 1 }}>{lbl}</span>
                </TbBtn>
              ))}
              <Div />
              <TbChip onMouseDown={e => e.preventDefault()} onClick={e => openPopup("font", e.currentTarget)} active={activePopup === "font"}>
                {fontLabel}<Icon name="chevron-down" size={11} />
              </TbChip>
              <TbChip style={{ marginLeft: 3 }} onMouseDown={e => e.preventDefault()} onClick={e => openPopup("size", e.currentTarget)} active={activePopup === "size"}>
                {curSz}<Icon name="chevron-down" size={11} />
              </TbChip>
              <Div />
              <TbChip onMouseDown={e => e.preventDefault()} onClick={e => openPopup("styles", e.currentTarget)} active={activePopup === "styles"}>
                Estilos<Icon name="chevron-down" size={11} />
              </TbChip>
              <Div />
              {[["L", "align-left", "justifyLeft"], ["C", "align-center", "justifyCenter"], ["R", "align-right", "justifyRight"], ["J", "align-justify", "justifyFull"]].map(([id, ic, cmd]) => (
                <TbBtn key={id} active={alignActive === id} onMouseDown={e => e.preventDefault()} onClick={() => { setAlignActive(id); exec(cmd); }}>
                  <Icon name={ic} size={17} />
                </TbBtn>
              ))}
              <Div />
              {[["list", "insertUnorderedList"], ["list-ordered", "insertOrderedList"], ["indent", "indent"], ["outdent", "outdent"]].map(([ic, cmd]) => (
                <TbBtn key={ic} onMouseDown={e => e.preventDefault()} onClick={() => exec(cmd)}><Icon name={ic} size={17} /></TbBtn>
              ))}
              <Div />
              <TbChip data-insert-chip onMouseDown={e => e.preventDefault()} onClick={e => openPopup("insert", e.currentTarget)} active={activePopup === "insert"}>
                Inserir<Icon name="plus" size={11} />
              </TbChip>
              <Div />
              <TbChip onMouseDown={e => e.preventDefault()} onClick={e => openPopup("format", e.currentTarget)} active={activePopup === "format"}>
                Formatar<Icon name="settings-2" size={11} />
              </TbChip>
            </div>
          )}
          <button onMouseDown={e => e.preventDefault()}
            onClick={() => { if (aiMode) { if (!aiLoading) doAI(); } else { closePopup(); edRef.current?.focus(); } }}
            style={{ width: 40, height: 40, flexShrink: 0, borderRadius: "50%", border: aiMode && !aiLoading ? "none" : "1.5px solid rgba(0,0,0,.08)", background: aiMode && !aiLoading ? "#2563eb" : "#fff", color: aiMode && !aiLoading ? "#fff" : "#5e5e5b", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", marginRight: 6, marginLeft: 2, zIndex: 3, transition: "all .2s" }}>
            {aiLoading
              ? <div style={{ display: "flex", gap: 3, alignItems: "center" }}><div className="aidot" /><div className="aidot" /><div className="aidot" /></div>
              : aiMode ? <Icon name="send" size={16} /> : <Icon name="check" size={16} sw={2.6} />}
          </button>
        </div>
      </nav>

      {/* SELECTION MENU */}
      {selVisible && (
        <div className={`sm${selPos.dir === "down" ? " adown" : " aup"} show`}
          style={{ left: selPos.left, top: selPos.top, width: selPos.mw, "--ax": selPos.ax + "px" }}
          onMouseDown={e => e.preventDefault()}>
          <div className="sm-inner noscroll">
            {selActions.map(a => (
              <button key={a.l} onClick={a.fn} onMouseDown={e => e.preventDefault()}
                style={{ flexShrink: 0, padding: "10px 13px", border: "none", background: "transparent", color: a.danger ? "#ff6b6b" : "#fff", fontFamily: "'DM Sans',sans-serif", fontSize: 12.5, fontWeight: 500, cursor: "pointer", borderRight: "1px solid rgba(255,255,255,.1)", whiteSpace: "nowrap", display: "flex", alignItems: "center", gap: 5 }}>
                <Icon name={a.ic} size={13} />{a.l}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* EMPTY LINE MENU — only Colar + Inserir */}
      {emptyLineMenu && (
        <div className={`sm${emptyLineMenu.dir === "down" ? " adown" : " aup"} show`}
          style={{ left: emptyLineMenu.left, top: emptyLineMenu.top, width: emptyLineMenu.mw, "--ax": emptyLineMenu.ax + "px" }}
          onMouseDown={e => e.preventDefault()}>
          <div className="sm-inner noscroll">
            {emptyLineActions.map(a => (
              <button key={a.l} onClick={a.fn} onMouseDown={e => e.preventDefault()}
                style={{ flexShrink: 0, padding: "11px 18px", border: "none", background: "transparent", color: "#fff", fontFamily: "'DM Sans',sans-serif", fontSize: 13.5, fontWeight: 500, cursor: "pointer", borderRight: "1px solid rgba(255,255,255,.12)", whiteSpace: "nowrap", display: "flex", alignItems: "center", gap: 7 }}>
                <Icon name={a.ic} size={14} />{a.l}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* IMAGE CONTEXT MENU */}
      {imgMenu && (
        <>
          <div style={{ position: "fixed", inset: 0, zIndex: 9998 }} onClick={() => setImgMenu(null)} />
          <ImageMenu pos={imgMenu.pos} onClose={() => setImgMenu(null)}
            onAction={(action) => handleImgAction(action, imgMenu.el, imgMenu.img)} />
        </>
      )}

      {/* POPUP MASK */}
      {activePopup && <div onMouseDown={closePopup} style={{ position: "fixed", inset: 0, zIndex: 99, background: "transparent" }} />}

      {/* POPUP */}
      {activePopup && (
        <div className="pop" style={{ width: popupPos.w, left: popupPos.left, bottom: popupPos.bottom, transformOrigin: `${popupPos.origX}px calc(100% + 14px)` }}>
          <div className="pop-inner">{renderPopup()}</div>
          <div className="pop-arrow" style={{ left: popupPos.arrLeft }} />
        </div>
      )}

      {/* FULLSCREEN FONT BROWSER */}
      {ffOpen && (
        <div className="ff">
          <div style={{ height: 54, display: "flex", alignItems: "center", gap: 10, padding: "0 14px", borderBottom: "1px solid rgba(0,0,0,.08)", flexShrink: 0 }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: "#34322d", flexShrink: 0 }}>Fontes</span>
            <input value={ffSearch} onChange={e => setFfSearch(e.target.value)} placeholder="Pesquisar fonte…"
              onMouseDown={e => e.stopPropagation()}
              style={{ flex: 1, height: 34, border: "1.5px solid rgba(0,0,0,.08)", borderRadius: 9999, padding: "0 14px", fontSize: 13, fontFamily: "inherit", outline: "none", background: "#f8f8f7", color: "#34322d", minWidth: 0, WebkitUserSelect: "text", userSelect: "text" }} />
            <button onClick={() => setFfOpen(false)} style={{ width: 36, height: 36, border: "none", background: "transparent", cursor: "pointer", borderRadius: 9, display: "flex", alignItems: "center", justifyContent: "center", color: "#5e5e5b" }}><Icon name="x" size={17} /></button>
          </div>
          <div className="noscroll" style={{ display: "flex", gap: 6, padding: "10px 14px", borderBottom: "1px solid rgba(0,0,0,.08)", overflowX: "auto", flexShrink: 0 }}>
            {["Todas", ...new Set(FONTS.map(f => f.g))].map(cat => (
              <button key={cat} onClick={() => setFfCat(cat)}
                style={{ flexShrink: 0, padding: "5px 13px", border: `1.5px solid ${ffCat === cat ? "#2563eb" : "rgba(0,0,0,.08)"}`, borderRadius: 9999, fontFamily: "inherit", fontSize: 12, fontWeight: 600, cursor: "pointer", background: ffCat === cat ? "#eff6ff" : "transparent", color: ffCat === cat ? "#2563eb" : "#5e5e5b" }}>
                {cat}
              </button>
            ))}
          </div>
          <div className="noscroll" style={{ flex: 1, overflowY: "auto", display: "grid", gap: 8, padding: 14, gridTemplateColumns: "repeat(auto-fill,minmax(140px,1fr))" }}>
            {FONTS.filter(f => (!ffSearch || f.l.toLowerCase().includes(ffSearch.toLowerCase())) && (ffCat === "Todas" || f.g === ffCat)).map(f => (
              <div key={f.v} onClick={() => setFfSel(f.v)}
                style={{ border: `1.5px solid ${ffSel === f.v ? "#2563eb" : "rgba(0,0,0,.08)"}`, borderRadius: 10, padding: "10px 12px", cursor: "pointer", background: ffSel === f.v ? "#eff6ff" : "#fff", transition: "all .15s" }}>
                <div style={{ fontSize: 10, fontWeight: 700, color: "#858481", textTransform: "uppercase", letterSpacing: ".05em", marginBottom: 4, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{f.g}</div>
                <div style={{ fontSize: 20, color: "#34322d", lineHeight: 1.2, fontFamily: f.v, overflow: "hidden", whiteSpace: "nowrap", textOverflow: "ellipsis" }}>Aa Bb</div>
                <div style={{ fontSize: 10, color: "#5e5e5b", marginTop: 4, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{f.l}</div>
              </div>
            ))}
          </div>
          <div style={{ padding: "10px 14px", borderTop: "1px solid rgba(0,0,0,.08)", flexShrink: 0 }}>
            <button disabled={!ffSel} onClick={() => { const f = FONTS.find(x => x.v === ffSel); if (f) { setCurFont(f.v); setFontLabel(f.l); exec("fontName", f.l); setFfOpen(false); } }}
              style={{ width: "100%", padding: "12px 0", background: ffSel ? "#2563eb" : "rgba(0,0,0,.08)", color: ffSel ? "#fff" : "#858481", border: "none", borderRadius: 10, cursor: ffSel ? "pointer" : "default", fontFamily: "inherit", fontSize: 13.5, fontWeight: 600 }}>
              {ffSel ? `Aplicar "${FONTS.find(f => f.v === ffSel)?.l}"` : "Aplicar fonte"}
            </button>
          </div>
        </div>
      )}

      {/* close empty line menu on scroll/click outside */}
      {emptyLineMenu && (
        <div style={{ position: "fixed", inset: 0, zIndex: 9990, pointerEvents: "none" }}
          onClick={() => setEmptyLineMenu(null)} />
      )}
    </div>
  );
}