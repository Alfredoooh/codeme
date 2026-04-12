import { useState, useEffect, useRef, useCallback } from "react";

// ── LUCIDE ICONS (inline SVG subset) ──────────────────────
const Icon = ({ name, size = 18, strokeWidth = 2, className = "" }) => {
  const icons = {
    menu: <><line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="18" x2="20" y2="18"/></>,
    "undo-2": <><path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5v0a5.5 5.5 0 0 1-5.5 5.5H11"/></>,
    "redo-2": <><path d="m15 14 5-5-5-5"/><path d="M20 9H9.5A5.5 5.5 0 0 0 4 14.5v0A5.5 5.5 0 0 0 9.5 20H13"/></>,
    keyboard: <><rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8"/></>,
    "file-text": <><path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8M16 13H8M16 17H8"/></>,
    layout: <><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 21V9"/></>,
    bot: <><path d="M12 8V4H8"/><rect x="8" y="8" width="8" height="8" rx="1"/><path d="M19 8h2v8h-2M3 8h2v8H3M9 19v2M15 19v2"/></>,
    check: <><path d="M20 6 9 17l-5-5"/></>,
    send: <><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></>,
    "chevron-down": <><path d="m6 9 6 6 6-6"/></>,
    "align-left": <><line x1="21" y1="6" x2="3" y2="6"/><line x1="15" y1="12" x2="3" y2="12"/><line x1="17" y1="18" x2="3" y2="18"/></>,
    "align-center": <><line x1="21" y1="6" x2="3" y2="6"/><line x1="17" y1="12" x2="7" y2="12"/><line x1="19" y1="18" x2="5" y2="18"/></>,
    "align-right": <><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="12" x2="9" y2="12"/><line x1="21" y1="18" x2="7" y2="18"/></>,
    "align-justify": <><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="12" x2="3" y2="12"/><line x1="21" y1="18" x2="3" y2="18"/></>,
    list: <><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></>,
    "list-ordered": <><line x1="10" y1="6" x2="21" y2="6"/><line x1="10" y1="12" x2="21" y2="12"/><line x1="10" y1="18" x2="21" y2="18"/><path d="M4 6h1v4M4 10h2M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"/></>,
    indent: <><polyline points="3 8 7 12 3 16"/><line x1="21" y1="12" x2="11" y2="12"/><line x1="21" y1="6" x2="11" y2="6"/><line x1="21" y1="18" x2="11" y2="18"/></>,
    outdent: <><polyline points="7 8 3 12 7 16"/><line x1="21" y1="12" x2="11" y2="12"/><line x1="21" y1="6" x2="11" y2="6"/><line x1="21" y1="18" x2="11" y2="18"/></>,
    plus: <><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></>,
    "settings-2": <><path d="M20 7h-9M14 17H5"/><circle cx="17" cy="17" r="3"/><circle cx="7" cy="7" r="3"/></>,
    scissors: <><circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><line x1="20" y1="4" x2="8.12" y2="15.88"/><line x1="14.47" y1="14.48" x2="20" y2="20"/><line x1="8.12" y1="8.12" x2="12" y2="12"/></>,
    copy: <><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></>,
    clipboard: <><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/></>,
    "check-square": <><polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></>,
    bold: <><path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/></>,
    italic: <><line x1="19" y1="4" x2="10" y2="4"/><line x1="14" y1="20" x2="5" y2="20"/><line x1="15" y1="4" x2="9" y2="20"/></>,
    underline: <><path d="M6 4v6a6 6 0 0 0 12 0V4"/><line x1="4" y1="20" x2="20" y2="20"/></>,
    "case-upper": <><path d="m3 15 4-8 4 8"/><path d="M4 13h6"/><path d="M15 11h4.5a2 2 0 0 1 0 4H15V7h4a2 2 0 0 1 0 4"/></>,
    link: <><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></>,
    "trash-2": <><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/></>,
    "align-center2": <><line x1="18" y1="10" x2="6" y2="10"/><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="14" x2="3" y2="14"/><line x1="18" y1="18" x2="6" y2="18"/></>,
    layers: <><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></>,
    "more-horizontal": <><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></>,
    square: <><rect x="3" y="3" width="18" height="18" rx="2"/></>,
    circle: <><circle cx="12" cy="12" r="10"/></>,
    eye: <><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></>,
    image: <><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></>,
    "maximize-2": <><polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/></>,
    "minimize-2": <><polyline points="5 15 3 15 3 21"/><polyline points="19 9 21 9 21 3"/><line x1="3" y1="21" x2="10" y2="14"/><line x1="21" y1="3" x2="14" y2="10"/></>,
    x: <><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></>,
    pilcrow: <><path d="M13 4v16"/><path d="M17 4v16"/><path d="M19 4H9.5a4.5 4.5 0 0 0 0 9H13"/></>,
    "heading-1": <><path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M21 18v-7l-2 2"/></>,
    "heading-2": <><path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M21 7c0-1.657-1.343-3-3-3s-3 1.343-3 3c0 4 6 6 6 6"/><path d="M15 18h6"/></>,
    "heading-3": <><path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M17.5 10.5c1.667-1 5.5 0 5.5 2.5s-2 3-3.5 3c1.5 0 3.5 1.5 3.5 3s-3.333 3.5-5 2.5"/></>,
    "heading-4": <><path d="M4 12h8"/><path d="M4 6v12"/><path d="M12 6v12"/><path d="M17 10v4h4"/><path d="M21 10v12"/></>,
    quote: <><path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V20c0 1 0 1 1 1z"/><path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z"/></>,
    code: <><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></>,
    "alert-triangle": <><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></>,
    info: <><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></>,
    "check-circle": <><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></>,
    "x-circle": <><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></>,
    minus: <><line x1="5" y1="12" x2="19" y2="12"/></>,
    calendar: <><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></>,
    "case-lower": <><path d="M7 20v-4a4 4 0 0 1 8 0v4"/><path d="M3 20a2 2 0 0 0 2-2V4"/><path d="M21 20a2 2 0 0 1-2-2V4"/></>,
    "case-sensitive": <><path d="m3 15 4-8 4 8"/><path d="M4 13h6"/><path d="M15 8h4.5a2 2 0 0 1 0 4H15V4"/><path d="M19 20v.01"/><path d="M19 17a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z"/></>,
    superscript: <><path d="m4 19 8-8"/><path d="m12 19-8-8"/><path d="M20 12h-4c0-1.5.442-2 1.5-2.5S20 8.334 20 7.002c0-.472-.17-.93-.484-1.29a2.105 2.105 0 0 0-2.617-.436c-.42.239-.738.614-.899 1.06"/></>,
    subscript: <><path d="m4 5 8 8"/><path d="m12 5-8 8"/><path d="M20 19h-4c0-1.5.44-2 1.5-2.5S20 15.33 20 14c0-.47-.17-.93-.484-1.29a2.1 2.1 0 0 0-2.617-.436c-.42.24-.738.614-.899 1.06"/></>,
    "align-vertical-justify-start": <><rect x="2" y="2" width="20" height="5" rx="2"/><rect x="2" y="12" width="20" height="5" rx="2"/><path d="M2 22h20"/></>,
  };
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" className={className}>
      {icons[name] || null}
    </svg>
  );
};

// ── FONTS DATA ─────────────────────────────────────────────
const FONTS = [
  {l:'Lora',v:"'Lora',Georgia,serif",g:'Serif'},{l:'Playfair Display',v:"'Playfair Display',serif",g:'Serif'},
  {l:'Merriweather',v:"'Merriweather',serif",g:'Serif'},{l:'Georgia',v:'Georgia,serif',g:'Serif'},
  {l:'Times New Roman',v:"'Times New Roman',serif",g:'Serif'},{l:'Source Serif 4',v:"'Source Serif 4',serif",g:'Serif'},
  {l:'PT Serif',v:"'PT Serif',serif",g:'Serif'},{l:'EB Garamond',v:"'EB Garamond',serif",g:'Serif'},
  {l:'Inter',v:"'Inter',sans-serif",g:'Sans-serif'},{l:'Open Sans',v:"'Open Sans',sans-serif",g:'Sans-serif'},
  {l:'Montserrat',v:"'Montserrat',sans-serif",g:'Sans-serif'},{l:'DM Sans',v:"'DM Sans',sans-serif",g:'Sans-serif'},
  {l:'Roboto',v:"'Roboto',sans-serif",g:'Sans-serif'},{l:'Nunito',v:"'Nunito',sans-serif",g:'Sans-serif'},
  {l:'Poppins',v:"'Poppins',sans-serif",g:'Sans-serif'},{l:'Raleway',v:"'Raleway',sans-serif",g:'Sans-serif'},
  {l:'Courier New',v:"'Courier New',monospace",g:'Monospace'},{l:'IBM Plex Mono',v:"'IBM Plex Mono',monospace",g:'Monospace'},
  {l:'Fira Code',v:"'Fira Code',monospace",g:'Monospace'},{l:'JetBrains Mono',v:"'JetBrains Mono',monospace",g:'Monospace'},
  {l:'Cinzel',v:"'Cinzel',serif",g:'Decorativa'},{l:'Abril Fatface',v:"'Abril Fatface',cursive",g:'Decorativa'},
  {l:'Pacifico',v:"'Pacifico',cursive",g:'Decorativa'},
  {l:'Dancing Script',v:"'Dancing Script',cursive",g:'Manuscrita'},{l:'Great Vibes',v:"'Great Vibes',cursive",g:'Manuscrita'},
  {l:'Caveat',v:"'Caveat',cursive",g:'Manuscrita'},{l:'Permanent Marker',v:"'Permanent Marker',cursive",g:'Manuscrita'},
];

const COLORS = ['#000000','#34322d','#5e5e5b','#858481','#d1d5db','#e5e7eb','#f3f4f6','#ffffff','#dc2626','#ea580c','#d97706','#ca8a04','#65a30d','#16a34a','#0891b2','#2563eb','#4f46e5','#7c3aed','#9333ea','#db2777','#fca5a5','#fdba74','#fcd34d','#86efac','#93c5fd','#c4b5fd','#f9a8d4','#fde68a','#6ee7b7','#a5b4fc','#fbcfe8','#e9d5ff'];
const SZP = [8,10,12,13,14,15,16,18,20,22,24,28,32,36,48,64,72];

// ── CSS INJECTION ─────────────────────────────────────────
const CSS = `
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,wght@0,400;0,500;0,600;0,700;1,500&family=Lora:ital,wght@0,400;0,500;0,600;1,400&family=Inter:wght@400;500;600&family=Playfair+Display:wght@400;700&family=Merriweather:wght@400;700&family=Open+Sans:wght@400;600&family=Montserrat:wght@400;600&family=Roboto:wght@400;500;700&family=Nunito:wght@400;600;700&family=Poppins:wght@400;500;600;700&family=Raleway:wght@400;500;600&family=Source+Serif+4:wght@400;600&family=PT+Serif:ital,wght@0,400;0,700;1,400&family=EB+Garamond:ital,wght@0,400;0,500;1,400&family=Dancing+Script:wght@400;600;700&family=Great+Vibes&family=Caveat:wght@400;600;700&family=Permanent+Marker&family=Cinzel:wght@400;600;700&family=Abril+Fatface&family=Pacifico&family=Fira+Code:wght@400;500&family=JetBrains+Mono:wght@400;500&family=IBM+Plex+Mono:wght@400;500&display=swap');

*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
.editor-root{width:100%;height:100%;overflow:hidden;font-family:'DM Sans',sans-serif;background:#f8f8f7;-webkit-user-select:none;user-select:none;display:flex;flex-direction:column}
.page-content{outline:none;font-family:'Lora',Georgia,serif;font-size:16px;line-height:1.85;color:#34322d;min-height:600px;word-break:break-word;caret-color:#2563eb;-webkit-user-select:text;user-select:text;cursor:text}
.page-content::selection,.page-content *::selection{background:#bfdbfe}
.page-content:empty::before{content:attr(data-placeholder);color:#858481;pointer-events:none}
.topbar-title:empty::before{content:'Sem título';color:#858481;pointer-events:none}
.topbar-title:focus{border-color:#2563eb!important;background:#eff6ff!important;white-space:normal;overflow:visible}
.no-scrollbar{scrollbar-width:none}
.no-scrollbar::-webkit-scrollbar{display:none}
.popup-arrow{position:absolute;bottom:-9px;width:18px;height:9px;overflow:hidden;pointer-events:none;z-index:101}
.popup-arrow::after{content:'';position:absolute;top:-7px;left:50%;transform:translateX(-50%) rotate(45deg);width:13px;height:13px;background:#fff;border:1px solid rgba(0,0,0,0.08);border-radius:3px 0 0 0}
.page-wrapper{width:794px;transform-origin:top center;transition:transform .3s cubic-bezier(0.22,1,0.36,1),margin-bottom .3s}
.page{width:794px;background:#fff;border-radius:4px;box-shadow:0 1px 3px rgba(0,0,0,.06),0 4px 20px rgba(0,0,0,.06);padding:96px 88px 120px;min-height:1123px;transition:box-shadow .25s}
.page.focused{box-shadow:0 2px 8px rgba(0,0,0,.08),0 8px 36px rgba(0,0,0,.12)}
.pill-fade-l::before{content:'';position:absolute;left:0;top:0;bottom:0;width:20px;background:linear-gradient(to right,rgba(255,255,255,.97),transparent);border-radius:9999px 0 0 9999px;z-index:2;pointer-events:none}
.pill-fade-r::after{content:'';position:absolute;right:52px;top:0;bottom:0;width:14px;background:linear-gradient(to left,rgba(255,255,255,.97),transparent);z-index:2;pointer-events:none}
.ai-mode.pill-fade-l::before,.ai-mode.pill-fade-r::after{display:none}
.font-group-label{padding:6px 14px 2px;font-size:10px;font-weight:700;color:#ccc;text-transform:uppercase;letter-spacing:.06em;border-top:1px solid rgba(0,0,0,0.08);margin-top:2px}
.font-group-label:first-child{border-top:none}
@keyframes popIn{from{opacity:0;transform:scale(0.5)}to{opacity:1;transform:scale(1)}}
@keyframes popOut{from{opacity:1;transform:scale(1)}to{opacity:0;transform:scale(0.55)}}
@keyframes selIn{from{opacity:0;transform:scale(.88) translateY(6px)}to{opacity:1;transform:scale(1) translateY(0)}}
@keyframes aiDot{0%,80%,100%{transform:scale(.6);opacity:.4}40%{transform:scale(1);opacity:1}}
.popup-card{animation:popIn .22s cubic-bezier(.34,1.56,.64,1) both}
.popup-card.closing{animation:popOut .15s cubic-bezier(.55,0,.45,1) both}
.sel-menu-show{animation:selIn .15s cubic-bezier(.34,1.56,.64,1) both}
.ai-dot{width:5px;height:5px;border-radius:50%;background:#2563eb;animation:aiDot .9s ease infinite}
.ai-dot:nth-child(2){animation-delay:.2s}.ai-dot:nth-child(3){animation-delay:.4s}
@keyframes ffIn{from{opacity:0;transform:scale(0.5)}to{opacity:1;transform:scale(1)}}
.ff-in{animation:ffIn .22s cubic-bezier(.34,1.56,.64,1) both}
`;

// ── MAIN APP ──────────────────────────────────────────────
export default function App() {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [aiMode, setAiMode] = useState(false);
  const [aiLoading, setAiLoading] = useState(false);
  const [curFont, setCurFont] = useState("'Lora',Georgia,serif");
  const [fontLabel, setFontLabel] = useState("Lora");
  const [curSz, setCurSz] = useState(16);
  const [colorBar, setColorBar] = useState("#f0a500");
  const [focused, setFocused] = useState(false);
  const [activePopup, setActivePopup] = useState(null); // 'color-text'|'font'|'size'|'styles'|'insert'|'format'
  const [popupPos, setPopupPos] = useState({ left: 0, bottom: 0, origX: 0 });
  const [selMenuVisible, setSelMenuVisible] = useState(false);
  const [selMenuPos, setSelMenuPos] = useState({ left: 0, top: 0, ax: 0 });
  const [fontFullscreen, setFontFullscreen] = useState(false);
  const [ffSearch, setFfSearch] = useState("");
  const [ffCat, setFfCat] = useState("Todas");
  const [ffSelected, setFfSelected] = useState(null);
  const [fontSearch, setFontSearch] = useState("");
  const [fontPreview, setFontPreview] = useState(null);
  const [hexInput, setHexInput] = useState("#34322d");
  const [hexPreview, setHexPreview] = useState("#34322d");
  const [szPreview, setSzPreview] = useState(16);
  const [alignActive, setAlignActive] = useState("alignLeft");
  const [aiInput, setAiInput] = useState("");

  const edRef = useRef(null);
  const savedRangeRef = useRef(null);
  const popupTrigRef = useRef(null);
  const popupRef = useRef(null);
  const aiInputRef = useRef(null);

  // inject CSS once
  useEffect(() => {
    const s = document.createElement("style");
    s.textContent = CSS;
    document.head.appendChild(s);
    return () => document.head.removeChild(s);
  }, []);

  // zoom
  const canvasRef = useRef(null);
  const wrapperRef = useRef(null);
  const applyZoom = useCallback(() => {
    if (!canvasRef.current || !wrapperRef.current) return;
    const a = canvasRef.current.clientWidth - 32;
    const base = a < 794 ? a / 794 : 1;
    const s = Math.min(base, 1);
    if (s < 1) {
      wrapperRef.current.style.transform = `scale(${s})`;
      wrapperRef.current.style.transformOrigin = "top center";
      wrapperRef.current.style.marginBottom = `${(s - 1) * 1123}px`;
    } else {
      wrapperRef.current.style.transform = "none";
      wrapperRef.current.style.marginBottom = "0";
    }
  }, []);
  useEffect(() => {
    applyZoom();
    window.addEventListener("resize", applyZoom);
    return () => window.removeEventListener("resize", applyZoom);
  }, [applyZoom]);
  useEffect(() => {
    if (!canvasRef.current) return;
    const ro = new ResizeObserver(applyZoom);
    ro.observe(canvasRef.current);
    return () => ro.disconnect();
  }, [applyZoom]);

  // ── SEL ────────────────────────────────────────────────
  const saveSel = useCallback(() => {
    const s = window.getSelection();
    if (s && s.rangeCount > 0 && !s.isCollapsed) savedRangeRef.current = s.getRangeAt(0).cloneRange();
  }, []);

  const restoreSel = useCallback(() => {
    const ed = edRef.current;
    if (!savedRangeRef.current) { if (ed) ed.focus(); return; }
    if (ed) ed.focus();
    try { const s = window.getSelection(); s.removeAllRanges(); s.addRange(savedRangeRef.current); } catch(_) {}
  }, []);

  const exec = useCallback((cmd, val) => {
    restoreSel();
    document.execCommand(cmd, false, val || null);
    saveSel();
  }, [restoreSel, saveSel]);

  const tryShowSel = useCallback(() => {
    const s = window.getSelection();
    if (s && !s.isCollapsed && s.toString().length > 0) {
      const r = s.getRangeAt(0).getBoundingClientRect();
      if (r.width > 0 || r.height > 0) {
        const cx = r.left + r.width / 2;
        const top = Math.max(8, r.top - 6);
        setSelMenuPos({ left: cx, top, ax: 0 });
        setSelMenuVisible(true);
        return true;
      }
    }
    setSelMenuVisible(false);
    return false;
  }, []);

  // ── POPUP ──────────────────────────────────────────────
  const closePopup = useCallback(() => {
    setActivePopup(null);
    setFontPreview(null);
    setFontSearch("");
  }, []);

  const openPopup = useCallback((type, trigEl) => {
    if (activePopup === type) { closePopup(); return; }
    const r = trigEl.getBoundingClientRect();
    const w = { 'color-text': 254, font: 240, size: 220, styles: 200, insert: 240, format: 240 }[type] || 240;
    let left = r.left + r.width / 2 - w / 2;
    left = Math.max(8, Math.min(window.innerWidth - w - 8, left));
    const bottom = window.innerHeight - r.top + 12;
    const origX = Math.max(20, Math.min(w - 20, r.left + r.width / 2 - left));
    setPopupPos({ left, bottom, origX, w });
    setActivePopup(type);
    popupTrigRef.current = trigEl;
  }, [activePopup, closePopup]);

  // ── AI ────────────────────────────────────────────────
  useEffect(() => { if (aiMode && aiInputRef.current) setTimeout(() => aiInputRef.current?.focus(), 80); }, [aiMode]);

  const doAI = async () => {
    const p = aiInput.trim(); if (!p) return;
    setAiInput(""); setAiLoading(true);
    try {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: "claude-sonnet-4-20250514", max_tokens: 1000,
          system: "Responde APENAS com o texto a inserir no editor, sem explicações nem markdown extra. Responde em português.",
          messages: [{ role: "user", content: p }] })
      });
      const d = await r.json();
      const txt = d.content?.map(i => i.text || "").join("") || "(sem resposta)";
      restoreSel(); exec("insertText", txt);
    } catch { restoreSel(); exec("insertText", "[Erro IA]"); }
    setAiLoading(false);
    setTimeout(() => aiInputRef.current?.focus(), 50);
  };

  // ── EDITOR EVENTS ──────────────────────────────────────
  const onEditorMouseUp = () => setTimeout(() => { saveSel(); tryShowSel(); }, 20);
  const onEditorContextMenu = (e) => {
    e.preventDefault(); saveSel();
    const s = window.getSelection();
    if (s && !s.isCollapsed) {
      const r = s.getRangeAt(0).getBoundingClientRect();
      setSelMenuPos({ left: r.left + r.width / 2, top: Math.max(8, r.top - 6), ax: 0 });
    } else {
      setSelMenuPos({ left: e.clientX, top: Math.max(8, e.clientY - 6), ax: 0 });
    }
    setSelMenuVisible(true);
  };

  // ── INSERT helpers ─────────────────────────────────────
  const insertImg = () => {
    closePopup();
    const fi = document.createElement("input"); fi.type = "file"; fi.accept = "image/*";
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
    for (let r = 0; r < 3; r++) { h += '<tr>'; for (let c = 0; c < 3; c++) h += '<td style="border:1.5px solid #ccc;padding:6px 10px;min-width:40px">&nbsp;</td>'; h += '</tr>'; }
    h += '</tbody></table><p></p>';
    exec("insertHTML", h); closePopup();
  };
  const applySize = (sz) => {
    setCurSz(sz); setSzPreview(sz);
    restoreSel();
    const s = window.getSelection();
    if (!s || !s.rangeCount) return;
    const r = s.getRangeAt(0);
    if (s.isCollapsed) { if (edRef.current) edRef.current.style.fontSize = sz + "px"; return; }
    const fr = r.extractContents();
    const sp = document.createElement("span"); sp.style.fontSize = sz + "px"; sp.appendChild(fr); r.insertNode(sp);
    const nr = document.createRange(); nr.selectNodeContents(sp); s.removeAllRanges(); s.addRange(nr);
    savedRangeRef.current = nr.cloneRange();
  };

  // ── RENDER POPUPS ──────────────────────────────────────
  const renderPopupContent = () => {
    if (!activePopup) return null;
    switch (activePopup) {
      case "color-text": return <ColorPopup colors={COLORS} hexInput={hexInput} setHexInput={setHexInput} hexPreview={hexPreview} setHexPreview={setHexPreview}
        onApply={c => { exec("foreColor", c); setColorBar(c); closePopup(); }} />;
      case "font": return <FontPopup fonts={FONTS} curFont={curFont} fontSearch={fontSearch} setFontSearch={setFontSearch}
        fontPreview={fontPreview} setFontPreview={setFontPreview}
        onExpand={() => { closePopup(); setFontFullscreen(true); }}
        onApply={f => { setCurFont(f.v); setFontLabel(f.l); exec("fontName", f.l); closePopup(); }} />;
      case "size": return <SizePopup curSz={curSz} szPreview={szPreview} setSzPreview={setSzPreview}
        onApply={sz => { applySize(sz); closePopup(); }}
        onStep={d => { const n = Math.max(6, Math.min(200, szPreview + d)); setSzPreview(n); applySize(n); }} />;
      case "styles": return <StylesPopup exec={exec} onClose={closePopup} />;
      case "insert": return <InsertPopup exec={exec} onClose={closePopup} insertImg={insertImg} insertTable={insertTable} />;
      case "format": return <FormatPopup exec={exec} onClose={closePopup} edRef={edRef} restoreSel={restoreSel} />;
      default: return null;
    }
  };

  const popW = { 'color-text': 254, font: 240, size: 220, styles: 200, insert: 240, format: 240 }[activePopup] || 240;

  return (
    <div className="editor-root" style={{ fontFamily: "'DM Sans',sans-serif" }}>
      {/* DRAWER */}
      <div style={{
        position: "fixed", top: 0, left: 0, width: 260, height: "100%", background: "#fff",
        transform: drawerOpen ? "translateX(0)" : "translateX(-100%)",
        transition: "transform 400ms cubic-bezier(0.22,1,0.36,1)", zIndex: 30,
        boxShadow: "2px 0 20px rgba(0,0,0,.10)", display: "flex", flexDirection: "column"
      }}>
        <div style={{ padding: "52px 20px 14px", borderBottom: "1px solid rgba(0,0,0,.08)" }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: "#858481", textTransform: "uppercase", letterSpacing: ".06em" }}>Funcionalidades</div>
        </div>
        <div style={{ flex: 1, overflowY: "auto", padding: 10 }}>
          <div style={{ paddingTop: 8, paddingBottom: 8, borderBottom: "1px solid rgba(0,0,0,.08)" }}>
            <button onClick={() => { aiMode ? setAiMode(false) : setAiMode(true); setDrawerOpen(false); }}
              style={{ display: "flex", alignItems: "center", gap: 12, width: "100%", padding: "11px 14px", fontSize: 14, fontWeight: 500, color: aiMode ? "#2563eb" : "#34322d", background: aiMode ? "#eff6ff" : "transparent", borderRadius: 10, border: "none", cursor: "pointer", fontFamily: "inherit" }}>
              <Icon name={aiMode ? "bot" : "keyboard"} size={18} className="flex-shrink-0" style={{ color: "#5e5e5b" }} />
              <span>{aiMode ? "IA activa" : "Toolbar / IA"}</span>
            </button>
          </div>
        </div>
      </div>
      {/* OVERLAY */}
      {drawerOpen && <div onClick={() => setDrawerOpen(false)} style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,.18)", zIndex: 15 }} />}

      {/* APP */}
      <div style={{ width: "100%", height: "100%", background: "#f8f8f7", display: "flex", flexDirection: "column",
        transform: drawerOpen ? "translateX(110px)" : "none",
        transition: "transform 400ms cubic-bezier(0.22,1,0.36,1)" }}>
        {/* TOPBAR */}
        <div style={{ height: 52, flexShrink: 0, display: "flex", alignItems: "center", padding: "0 6px", background: "#fff", borderBottom: "1px solid rgba(0,0,0,.08)", position: "relative" }}>
          <div style={{ position: "absolute", left: 6, display: "flex", alignItems: "center", gap: 2 }}>
            <button onClick={() => setDrawerOpen(!drawerOpen)}
              style={{ width: 44, height: 44, border: "none", background: "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", borderRadius: 10, color: "#5e5e5b" }}>
              <Icon name="menu" size={20} />
            </button>
          </div>
          <div contentEditable spellCheck={false} data-placeholder="Sem título" className="topbar-title"
            style={{ position: "absolute", left: "50%", transform: "translateX(-50%)", fontSize: 15, fontWeight: 600, color: "#34322d", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", maxWidth: "calc(100% - 160px)", cursor: "text", padding: "4px 8px", borderRadius: 6, border: "1.5px solid transparent", outline: "none", transition: "all .15s", fontFamily: "inherit" }}
            onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); e.currentTarget.blur(); } }}
          />
          <div style={{ position: "absolute", right: 6, display: "flex", alignItems: "center", gap: 2 }}>
            {["undo-2","redo-2"].map((ic, i) => (
              <button key={ic} onClick={() => exec(i === 0 ? "undo" : "redo")}
                style={{ width: 44, height: 44, border: "none", background: "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", borderRadius: 10, color: "#5e5e5b" }}>
                <Icon name={ic} size={20} />
              </button>
            ))}
          </div>
        </div>

        {/* CANVAS */}
        <div ref={canvasRef} onClick={e => { if (!e.target.closest(".page-content")) { savedRangeRef.current = null; window.getSelection()?.removeAllRanges(); setSelMenuVisible(false); } }}
          style={{ flex: 1, overflowY: "auto", overflowX: "auto", padding: "28px 16px 200px", display: "flex", flexDirection: "column", alignItems: "center", background: "#f8f8f7" }}
          className="no-scrollbar">
          <div ref={wrapperRef} className="page-wrapper">
            <div className={`page ${focused ? "focused" : ""}`}>
              <div ref={edRef} className="page-content" contentEditable spellCheck data-placeholder="Começa a escrever…"
                onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
                onMouseUp={onEditorMouseUp}
                onTouchEnd={() => setTimeout(() => { saveSel(); tryShowSel(); }, 120)}
                onKeyUp={saveSel}
                onContextMenu={onEditorContextMenu}
              />
            </div>
          </div>
        </div>
      </div>

      {/* FLOATING TOOLBAR */}
      <nav style={{ position: "fixed", left: "50%", transform: "translateX(-50%)", bottom: "max(14px, env(safe-area-inset-bottom, 14px))", width: "min(96vw, 460px)", zIndex: 20 }}>
        <div className={`pill-fade-l pill-fade-r ${aiMode ? "ai-mode" : ""}`}
          style={{ height: 54, background: "rgba(255,255,255,.97)", border: "1px solid rgba(0,0,0,.08)", borderRadius: 9999, boxShadow: "0 4px 20px rgba(0,0,0,.10),0 1px 4px rgba(0,0,0,.05)", backdropFilter: "blur(20px)", display: "flex", alignItems: "center", overflow: "hidden", position: "relative", transition: "all 220ms" }}>
          {aiMode ? (
            <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "0 16px", flex: 1, minWidth: 0 }}>
              <input ref={aiInputRef} value={aiInput} onChange={e => setAiInput(e.target.value)}
                onKeyDown={e => { if (e.key === "Enter") { e.preventDefault(); doAI(); } }}
                placeholder="Pergunta à IA…"
                style={{ flex: 1, border: "none", background: "transparent", fontFamily: "'DM Sans',sans-serif", fontSize: 14, color: "#34322d", outline: "none", WebkitUserSelect: "text", userSelect: "text" }} />
            </div>
          ) : (
            <div className="no-scrollbar" style={{ display: "flex", alignItems: "center", gap: 1, padding: "0 6px", overflowX: "auto", overflowY: "hidden", flex: 1, minWidth: 0, WebkitOverflowScrolling: "touch" }}>
              {/* Color */}
              <TbBtn onMouseDown={e => e.preventDefault()} onClick={e => openPopup("color-text", e.currentTarget)}>
                <span style={{ fontSize: 16, fontWeight: 900, lineHeight: 1 }}>A</span>
                <div style={{ width: 16, height: 3, borderRadius: 2, background: colorBar }} />
              </TbBtn>
              <Div />
              {/* B/I/U/S */}
              {[["btnBold","bold","B","font-black"],["btnItalic","italic","I","italic font-semibold"],["btnUnderline","underline","U","font-semibold underline"],["btnStrike","strikeThrough","S","font-semibold line-through"]].map(([,cmd,lbl]) => (
                <TbBtn key={cmd} onMouseDown={e => e.preventDefault()} onClick={() => exec(cmd)}>
                  <span style={{ fontSize: 16, fontWeight: cmd === "bold" ? 900 : 600, fontStyle: cmd === "italic" ? "italic" : "normal", textDecoration: cmd === "underline" ? "underline" : cmd === "strikeThrough" ? "line-through" : "none", lineHeight: 1 }}>{lbl}</span>
                </TbBtn>
              ))}
              <Div />
              {/* Font chip */}
              <TbChip id="chipFont" onMouseDown={e => e.preventDefault()} onClick={e => openPopup("font", e.currentTarget)} active={activePopup === "font"}>
                {fontLabel}<Icon name="chevron-down" size={11} />
              </TbChip>
              {/* Size chip */}
              <TbChip id="chipSize" style={{ marginLeft: 3 }} onMouseDown={e => e.preventDefault()} onClick={e => openPopup("size", e.currentTarget)} active={activePopup === "size"}>
                {curSz}<Icon name="chevron-down" size={11} />
              </TbChip>
              <Div />
              <TbChip onMouseDown={e => e.preventDefault()} onClick={e => openPopup("styles", e.currentTarget)} active={activePopup === "styles"}>
                Estilos<Icon name="chevron-down" size={11} />
              </TbChip>
              <Div />
              {/* Align */}
              {[["alignLeft","align-left","justifyLeft"],["alignCenter","align-center","justifyCenter"],["alignRight","align-right","justifyRight"],["alignJustify","align-justify","justifyFull"]].map(([id, ic, cmd]) => (
                <TbBtn key={id} active={alignActive === id} onMouseDown={e => e.preventDefault()} onClick={() => { setAlignActive(id); exec(cmd); }}>
                  <Icon name={ic} size={17} />
                </TbBtn>
              ))}
              <Div />
              {[["list","insertUnorderedList"],["list-ordered","insertOrderedList"],["indent","indent"],["outdent","outdent"]].map(([ic,cmd]) => (
                <TbBtn key={ic} onMouseDown={e => e.preventDefault()} onClick={() => exec(cmd)}><Icon name={ic} size={17} /></TbBtn>
              ))}
              <Div />
              <TbChip onMouseDown={e => e.preventDefault()} onClick={e => openPopup("insert", e.currentTarget)} active={activePopup === "insert"}>
                Inserir<Icon name="plus" size={11} />
              </TbChip>
              <Div />
              <TbChip onMouseDown={e => e.preventDefault()} onClick={e => openPopup("format", e.currentTarget)} active={activePopup === "format"}>
                Formatar<Icon name="settings-2" size={11} />
              </TbChip>
            </div>
          )}
          {/* Confirm/Send btn */}
          <button onMouseDown={e => e.preventDefault()}
            onClick={() => { if (aiMode) { if (!aiLoading) doAI(); } else { closePopup(); edRef.current?.focus(); } }}
            style={{ width: 40, height: 40, flexShrink: 0, borderRadius: "50%", border: aiMode && !aiLoading ? "none" : "1.5px solid rgba(0,0,0,.08)", background: aiMode && !aiLoading ? "#2563eb" : "#fff", color: aiMode && !aiLoading ? "#fff" : "#5e5e5b", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", marginRight: 6, marginLeft: 2, zIndex: 3, transition: "all .2s" }}>
            {aiLoading ? (
              <div style={{ display: "flex", gap: 3, alignItems: "center" }}>
                <div className="ai-dot"/><div className="ai-dot"/><div className="ai-dot"/>
              </div>
            ) : aiMode ? <Icon name="send" size={16} /> : <Icon name="check" size={16} strokeWidth={2.6} />}
          </button>
        </div>
      </nav>

      {/* SELECTION MENU */}
      {selMenuVisible && (
        <div className="sel-menu-show" onMouseDown={e => e.preventDefault()}
          style={{ position: "fixed", zIndex: 300, background: "#1c1c1e", borderRadius: 12, boxShadow: "0 4px 24px rgba(0,0,0,.4)", overflow: "hidden", left: Math.max(6, selMenuPos.left - 180), top: selMenuPos.top, maxWidth: "min(98vw, 600px)" }}>
          <div style={{ display: "flex", alignItems: "stretch", overflowX: "auto" }} className="no-scrollbar">
            {[
              { l: "Cortar", ic: "scissors", fn: async () => { const s = window.getSelection(); if (s&&!s.isCollapsed) { try { await navigator.clipboard.writeText(s.toString()) } catch(_) {} exec("delete"); } setSelMenuVisible(false); } },
              { l: "Copiar", ic: "copy", fn: async () => { const s = window.getSelection(); if (s&&!s.isCollapsed) { try { await navigator.clipboard.writeText(s.toString()) } catch(_) { document.execCommand("copy"); } } setSelMenuVisible(false); } },
              { l: "Colar", ic: "clipboard", fn: async () => { setSelMenuVisible(false); try { const t = await navigator.clipboard.readText(); restoreSel(); exec("insertText", t); } catch(_) { edRef.current?.focus(); } } },
              { l: "Sel. tudo", ic: "check-square", fn: () => { edRef.current?.focus(); document.execCommand("selectAll"); setSelMenuVisible(false); setTimeout(tryShowSel, 80); } },
              { l: "Negrito", ic: "bold", fn: () => { exec("bold"); setSelMenuVisible(false); } },
              { l: "Itálico", ic: "italic", fn: () => { exec("italic"); setSelMenuVisible(false); } },
              { l: "Sublinhado", ic: "underline", fn: () => { exec("underline"); setSelMenuVisible(false); } },
              { l: "MAIÚSCULAS", ic: "case-upper", fn: () => { restoreSel(); const s = window.getSelection(); if (s&&!s.isCollapsed) document.execCommand("insertText", false, s.toString().toUpperCase()); setSelMenuVisible(false); } },
              { l: "Apagar", ic: "trash-2", fn: () => { exec("delete"); setSelMenuVisible(false); } },
            ].map(a => (
              <button key={a.l} onClick={a.fn} onMouseDown={e => e.preventDefault()}
                style={{ flexShrink: 0, padding: "10px 13px", border: "none", background: "transparent", color: "#fff", fontFamily: "'DM Sans',sans-serif", fontSize: 12.5, fontWeight: 500, cursor: "pointer", borderRight: "1px solid rgba(255,255,255,.1)", whiteSpace: "nowrap", display: "flex", alignItems: "center", gap: 5 }}>
                <Icon name={a.ic} size={13} />{a.l}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* POPUP MASK */}
      {activePopup && <div onClick={closePopup} style={{ position: "fixed", inset: 0, zIndex: 99, background: "transparent" }} />}

      {/* POPUP */}
      {activePopup && (
        <div ref={popupRef} className="popup-card"
          style={{ position: "fixed", background: "#fff", border: "1px solid rgba(0,0,0,.08)", borderRadius: 14, boxShadow: "0 8px 32px rgba(0,0,0,.13),0 2px 8px rgba(0,0,0,.07)", zIndex: 100, width: popW, left: popupPos.left, bottom: popupPos.bottom, overflow: "visible", transformOrigin: `${popupPos.origX}px calc(100% + 14px)` }}>
          <div style={{ borderRadius: 14, overflow: "hidden" }}>
            {renderPopupContent()}
          </div>
          <div className="popup-arrow" style={{ left: Math.max(12, Math.min(popW - 24, (popupTrigRef.current?.getBoundingClientRect().left || 0) + (popupTrigRef.current?.getBoundingClientRect().width || 0) / 2 - popupPos.left - 7)) }} />
        </div>
      )}

      {/* FULLSCREEN FONT BROWSER */}
      {fontFullscreen && (
        <div className="ff-in" style={{ position: "fixed", inset: 0, zIndex: 500, background: "#fff", display: "flex", flexDirection: "column" }}>
          <div style={{ height: 54, display: "flex", alignItems: "center", gap: 10, padding: "0 14px", borderBottom: "1px solid rgba(0,0,0,.08)", flexShrink: 0 }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: "#34322d", flexShrink: 0 }}>Fontes</span>
            <input value={ffSearch} onChange={e => setFfSearch(e.target.value)} placeholder="Pesquisar fonte…"
              style={{ flex: 1, height: 34, border: "1.5px solid rgba(0,0,0,.08)", borderRadius: 9999, padding: "0 14px", fontSize: 13, fontFamily: "inherit", outline: "none", background: "#f8f8f7", color: "#34322d", minWidth: 0 }} />
            <button onClick={() => setFontFullscreen(false)} style={{ width: 36, height: 36, border: "none", background: "transparent", cursor: "pointer", borderRadius: 9, display: "flex", alignItems: "center", justifyContent: "center", color: "#5e5e5b" }}><Icon name="x" size={17} /></button>
          </div>
          <div style={{ display: "flex", gap: 6, padding: "10px 14px", borderBottom: "1px solid rgba(0,0,0,.08)", overflowX: "auto", flexShrink: 0 }} className="no-scrollbar">
            {["Todas", ...new Set(FONTS.map(f => f.g))].map(cat => (
              <button key={cat} onClick={() => setFfCat(cat)}
                style={{ flexShrink: 0, padding: "5px 13px", border: `1.5px solid ${ffCat === cat ? "#2563eb" : "rgba(0,0,0,.08)"}`, borderRadius: 9999, fontFamily: "inherit", fontSize: 12, fontWeight: 600, cursor: "pointer", background: ffCat === cat ? "#eff6ff" : "transparent", color: ffCat === cat ? "#2563eb" : "#5e5e5b" }}>
                {cat}
              </button>
            ))}
          </div>
          <div style={{ flex: 1, overflowY: "auto", display: "grid", gap: 8, padding: 14, gridTemplateColumns: "repeat(auto-fill,minmax(140px,1fr))" }}>
            {FONTS.filter(f => (!ffSearch || f.l.toLowerCase().includes(ffSearch.toLowerCase())) && (ffCat === "Todas" || f.g === ffCat)).map(f => (
              <div key={f.v} onClick={() => setFfSelected(f.v)}
                style={{ border: `1.5px solid ${ffSelected === f.v ? "#2563eb" : "rgba(0,0,0,.08)"}`, borderRadius: 10, padding: "10px 12px", cursor: "pointer", background: ffSelected === f.v ? "#eff6ff" : "#fff", transition: "all .15s" }}>
                <div style={{ fontSize: 10, fontWeight: 700, color: "#858481", textTransform: "uppercase", letterSpacing: ".05em", marginBottom: 4, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{f.g}</div>
                <div style={{ fontSize: 20, color: "#34322d", lineHeight: 1.2, fontFamily: f.v, overflow: "hidden", whiteSpace: "nowrap", textOverflow: "ellipsis" }}>Aa Bb</div>
                <div style={{ fontSize: 10, color: "#5e5e5b", marginTop: 4, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{f.l}</div>
              </div>
            ))}
          </div>
          <div style={{ padding: "10px 14px", borderTop: "1px solid rgba(0,0,0,.08)", flexShrink: 0 }}>
            <button disabled={!ffSelected} onClick={() => {
              const f = FONTS.find(x => x.v === ffSelected);
              if (f) { setCurFont(f.v); setFontLabel(f.l); exec("fontName", f.l); setFontFullscreen(false); }
            }}
              style={{ width: "100%", padding: "12px 0", background: ffSelected ? "#2563eb" : "rgba(0,0,0,.08)", color: ffSelected ? "#fff" : "#858481", border: "none", borderRadius: 10, cursor: ffSelected ? "pointer" : "default", fontFamily: "inherit", fontSize: 13.5, fontWeight: 600 }}>
              {ffSelected ? `Aplicar "${FONTS.find(f => f.v === ffSelected)?.l}"` : "Aplicar fonte"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

// ── SMALL COMPONENTS ──────────────────────────────────────
const TbBtn = ({ children, active, style, ...p }) => (
  <button {...p} style={{ height: 38, minWidth: 38, padding: "0 7px", border: "none", background: active ? "#eff6ff" : "transparent", borderRadius: 9999, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 2, flexShrink: 0, color: active ? "#2563eb" : "#5e5e5b", transition: "background .15s", ...style }}>
    {children}
  </button>
);
const TbChip = ({ children, active, style, ...p }) => (
  <button {...p} style={{ height: 32, border: `1.5px solid ${active ? "#2563eb" : "rgba(0,0,0,.08)"}`, borderRadius: 9999, padding: "0 11px", fontFamily: "inherit", fontSize: 12, fontWeight: 600, color: active ? "#2563eb" : "#34322d", background: active ? "#eff6ff" : "transparent", cursor: "pointer", display: "flex", alignItems: "center", gap: 4, whiteSpace: "nowrap", flexShrink: 0, transition: "all .15s", ...style }}>
    {children}
  </button>
);
const Div = () => <div style={{ width: 1, height: 20, background: "rgba(0,0,0,.08)", flexShrink: 0, margin: "0 4px" }} />;

const PopupHeader = ({ title }) => (
  <div style={{ padding: "11px 14px", fontSize: 10.5, fontWeight: 700, color: "#858481", textTransform: "uppercase", letterSpacing: ".07em", borderBottom: "1px solid rgba(0,0,0,.08)" }}>{title}</div>
);
const PopupItem = ({ icon, label, danger, onClick }) => (
  <button onMouseDown={e => e.preventDefault()} onClick={onClick}
    style={{ display: "flex", alignItems: "center", gap: 10, padding: "9px 14px", fontSize: 13, fontWeight: 500, color: danger ? "#dc2626" : "#34322d", cursor: "pointer", border: "none", background: "transparent", width: "100%", textAlign: "left", fontFamily: "inherit", transition: "background .12s" }}
    onMouseOver={e => e.currentTarget.style.background = "rgba(0,0,0,.04)"} onMouseOut={e => e.currentTarget.style.background = "transparent"}>
    <Icon name={icon} size={15} style={{ color: danger ? "#ef4444" : "#858481", flexShrink: 0 }} />{label}
  </button>
);

// ── COLOR POPUP ───────────────────────────────────────────
function ColorPopup({ colors, hexInput, setHexInput, hexPreview, setHexPreview, onApply }) {
  return <>
    <PopupHeader title="Cor do texto" />
    <div style={{ display: "grid", gridTemplateColumns: "repeat(8,1fr)", gap: 5, padding: "10px 14px" }}>
      {colors.map(c => (
        <div key={c} onMouseDown={e => e.preventDefault()} onClick={() => onApply(c)}
          style={{ width: 24, height: 24, borderRadius: 4, background: c, cursor: "pointer", border: c === "#ffffff" ? "2px solid rgba(0,0,0,.15)" : "2px solid transparent", transition: "transform .1s" }}
          onMouseOver={e => { e.currentTarget.style.transform = "scale(1.25)"; }} onMouseOut={e => { e.currentTarget.style.transform = "scale(1)"; }} />
      ))}
    </div>
    <div style={{ display: "flex", gap: 6, alignItems: "center", padding: "0 14px 12px" }}>
      <div style={{ width: 26, height: 26, background: hexPreview, borderRadius: 6, border: "1.5px solid rgba(0,0,0,.12)", flexShrink: 0 }} />
      <input value={hexInput} onChange={e => { setHexInput(e.target.value); if (/^#[0-9a-f]{6}$/i.test(e.target.value)) setHexPreview(e.target.value); }}
        maxLength={7} style={{ flex: 1, padding: "7px 10px", border: "1.5px solid rgba(0,0,0,.08)", borderRadius: 8, fontSize: 12, fontWeight: 600, fontFamily: "monospace", outline: "none", background: "#fafafa", color: "#34322d", WebkitUserSelect: "text", userSelect: "text" }} />
      <button onMouseDown={e => e.preventDefault()} onClick={() => { if (/^#[0-9a-f]{6}$/i.test(hexInput)) onApply(hexInput); }}
        style={{ width: 32, height: 32, borderRadius: 8, border: "none", background: hexPreview, color: "#fff", cursor: "pointer", fontSize: 13, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>✓</button>
    </div>
  </>;
}

// ── FONT POPUP ────────────────────────────────────────────
function FontPopup({ fonts, curFont, fontSearch, setFontSearch, fontPreview, setFontPreview, onExpand, onApply }) {
  const groups = [...new Set(fonts.map(f => f.g))];
  const filtered = fonts.filter(f => f.l.toLowerCase().includes(fontSearch.toLowerCase()));
  return <>
    <div style={{ display: "flex", alignItems: "center", borderBottom: "1px solid rgba(0,0,0,.08)" }}>
      <div style={{ flex: 1, padding: "11px 14px", fontSize: 10.5, fontWeight: 700, color: "#858481", textTransform: "uppercase", letterSpacing: ".07em" }}>Tipo de letra</div>
      <button onMouseDown={e => e.preventDefault()} onClick={onExpand}
        style={{ width: 32, height: 32, border: "none", background: "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", color: "#858481", borderRadius: 7, marginRight: 8 }}>
        <Icon name="maximize-2" size={14} />
      </button>
    </div>
    <div style={{ padding: "10px 10px 6px", borderBottom: "1px solid rgba(0,0,0,.08)" }}>
      <input value={fontSearch} onChange={e => setFontSearch(e.target.value)} placeholder="Pesquisar…"
        style={{ width: "100%", padding: "7px 10px", border: "1.5px solid rgba(0,0,0,.08)", borderRadius: 8, fontSize: 12.5, outline: "none", background: "#fafafa", fontFamily: "inherit", WebkitUserSelect: "text", userSelect: "text" }} />
    </div>
    <div style={{ maxHeight: 190, overflowY: "auto" }} className="no-scrollbar">
      {!fontSearch && groups.map((g, gi) => {
        const gFonts = filtered.filter(f => f.g === g);
        if (!gFonts.length) return null;
        return [
          <div key={g} className="font-group-label" style={gi === 0 ? { borderTop: "none" } : {}}>{g}</div>,
          ...gFonts.map(f => (
            <button key={f.v} onMouseDown={e => e.preventDefault()} onClick={() => setFontPreview(f)}
              style={{ padding: "9px 14px", fontSize: 13.5, cursor: "pointer", border: "none", background: "transparent", width: "100%", textAlign: "left", fontFamily: "inherit", display: "flex", alignItems: "center", color: f.v === curFont ? "#2563eb" : "#34322d", fontWeight: f.v === curFont ? 600 : 400 }}>
              <span style={{ fontFamily: f.v, fontSize: 14, flex: 1 }}>{f.l}</span>
            </button>
          ))
        ];
      })}
      {fontSearch && filtered.map(f => (
        <button key={f.v} onMouseDown={e => e.preventDefault()} onClick={() => setFontPreview(f)}
          style={{ padding: "9px 14px", fontSize: 13.5, cursor: "pointer", border: "none", background: "transparent", width: "100%", textAlign: "left", fontFamily: "inherit", display: "flex", alignItems: "center", color: f.v === curFont ? "#2563eb" : "#34322d" }}>
          <span style={{ fontFamily: f.v, fontSize: 14, flex: 1 }}>{f.l}</span>
        </button>
      ))}
    </div>
    {fontPreview && (
      <div style={{ borderTop: "1px solid rgba(0,0,0,.08)", padding: "10px 14px 12px", background: "#fafafa" }}>
        <div style={{ fontSize: 10, fontWeight: 700, color: "#858481", textTransform: "uppercase", letterSpacing: ".06em", marginBottom: 4 }}>{fontPreview.l}</div>
        <div style={{ fontSize: 26, color: "#34322d", marginBottom: 8, lineHeight: 1.2, fontFamily: fontPreview.v }}>Aa Bb Cc</div>
        <button onMouseDown={e => e.preventDefault()} onClick={() => onApply(fontPreview)}
          style={{ width: "100%", padding: "8px 0", background: "#2563eb", color: "#fff", border: "none", borderRadius: 8, cursor: "pointer", fontFamily: "inherit", fontSize: 12.5, fontWeight: 600 }}>
          Aplicar
        </button>
      </div>
    )}
  </>;
}

// ── SIZE POPUP ────────────────────────────────────────────
function SizePopup({ curSz, szPreview, setSzPreview, onApply, onStep }) {
  return <>
    <PopupHeader title="Tamanho" />
    <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "12px 14px" }}>
      {[["−",-1],["+"  ,1]].map(([lbl, d], i) => i === 0 ? (
        <button key={lbl} onMouseDown={e => e.preventDefault()} onClick={() => onStep(d)}
          style={{ width: 36, height: 36, borderRadius: 9, border: "1.5px solid rgba(0,0,0,.08)", background: "#fff", cursor: "pointer", fontSize: 18, color: "#5e5e5b", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>{lbl}</button>
      ) : null)}
      <div style={{ flex: 1, textAlign: "center", fontSize: 20, fontWeight: 700, color: "#34322d" }}>{szPreview}</div>
      {[["+"  ,1]].map(([lbl, d]) => (
        <button key={lbl} onMouseDown={e => e.preventDefault()} onClick={() => onStep(d)}
          style={{ width: 36, height: 36, borderRadius: 9, border: "1.5px solid rgba(0,0,0,.08)", background: "#fff", cursor: "pointer", fontSize: 18, color: "#5e5e5b", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>{lbl}</button>
      ))}
    </div>
    <div style={{ display: "flex", flexWrap: "wrap", gap: 5, padding: "10px 14px 12px", borderTop: "1px solid rgba(0,0,0,.08)" }}>
      {SZP.map(s => (
        <button key={s} onMouseDown={e => e.preventDefault()} onClick={() => onApply(s)}
          style={{ padding: "4px 10px", borderRadius: 9999, border: `1.5px solid ${s === szPreview ? "#2563eb" : "rgba(0,0,0,.08)"}`, background: s === szPreview ? "#eff6ff" : "transparent", color: s === szPreview ? "#2563eb" : "#5e5e5b", fontSize: 12, fontWeight: 600, cursor: "pointer", fontFamily: "inherit" }}>
          {s}
        </button>
      ))}
    </div>
  </>;
}

// ── STYLES POPUP ──────────────────────────────────────────
function StylesPopup({ exec, onClose }) {
  const stls = [
    { l: "Parágrafo", c: () => exec("formatBlock", "<p>"), i: "pilcrow" },
    { l: "Título 1", c: () => exec("formatBlock", "<h1>"), i: "heading-1" },
    { l: "Título 2", c: () => exec("formatBlock", "<h2>"), i: "heading-2" },
    { l: "Título 3", c: () => exec("formatBlock", "<h3>"), i: "heading-3" },
    { l: "Título 4", c: () => exec("formatBlock", "<h4>"), i: "heading-4" },
    { l: "Citação", c: () => exec("formatBlock", "<blockquote>"), i: "quote" },
    { l: "Código", c: () => exec("formatBlock", "<pre>"), i: "code" },
  ];
  return <>
    <PopupHeader title="Estilo de parágrafo" />
    {stls.map(s => <PopupItem key={s.l} icon={s.i} label={s.l} onClick={() => { s.c(); onClose(); }} />)}
  </>;
}

// ── INSERT POPUP ──────────────────────────────────────────
function InsertPopup({ exec, onClose, insertImg, insertTable }) {
  const cx = { iCw: ["#fef3c7","#f59e0b","▲"], iCi: ["#eff6ff","#3b82f6","i"], iCo: ["#f0fdf4","#22c55e","✓"], iCe: ["#fef2f2","#ef4444","✕"] };
  return <>
    <PopupHeader title="Inserir" />
    <div style={{ borderBottom: "1px solid rgba(0,0,0,.08)" }}>
      <PopupItem icon="link" label="Link" onClick={() => { onClose(); const u = prompt("URL:"); if (u) exec("createLink", u); }} />
      <PopupItem icon="image" label="Imagem" onClick={insertImg} />
      <PopupItem icon="table" label="Tabela 3×3" onClick={insertTable} />
    </div>
    <div style={{ borderBottom: "1px solid rgba(0,0,0,.08)" }}>
      <PopupItem icon="minus" label="Linha divisória" onClick={() => { exec("insertHorizontalRule"); onClose(); }} />
      <PopupItem icon="calendar" label="Data e hora" onClick={() => { exec("insertText", new Date().toLocaleString("pt-PT")); onClose(); }} />
    </div>
    <div>
      <div style={{ padding: "4px 14px 2px", fontSize: 10, fontWeight: 700, color: "#ccc", textTransform: "uppercase", letterSpacing: ".06em" }}>Caixas de destaque</div>
      {[["iCw","alert-triangle","Aviso"],["iCi","info","Informação"],["iCo","check-circle","Sucesso"],["iCe","x-circle","Erro"]].map(([id, ic, lbl]) => (
        <PopupItem key={id} icon={ic} label={lbl} onClick={() => {
          const [bg, br, ico] = cx[id];
          exec("insertHTML", `<div style="background:${bg};border-left:4px solid ${br};padding:12px 16px;margin:8px 0;font-size:.9em;border-radius:6px">${ico} Escreve aqui.</div><p></p>`);
          onClose();
        }} />
      ))}
    </div>
  </>;
}

// ── FORMAT POPUP ──────────────────────────────────────────
function FormatPopup({ exec, onClose, edRef, restoreSel }) {
  const getSel = () => { restoreSel(); const s = window.getSelection(); return s && !s.isCollapsed ? s : null; };
  return <>
    <PopupHeader title="Formatar" />
    <div style={{ borderBottom: "1px solid rgba(0,0,0,.08)" }}>
      <div style={{ padding: "4px 14px 2px", fontSize: 10, fontWeight: 700, color: "#ccc", textTransform: "uppercase", letterSpacing: ".06em" }}>Maiúsculas</div>
      <PopupItem icon="case-upper" label="MAIÚSCULAS" onClick={() => { const s = getSel(); if (s) exec("insertText", s.toString().toUpperCase()); onClose(); }} />
      <PopupItem icon="case-lower" label="minúsculas" onClick={() => { const s = getSel(); if (s) exec("insertText", s.toString().toLowerCase()); onClose(); }} />
      <PopupItem icon="case-sensitive" label="Primeira Maiúscula" onClick={() => { const s = getSel(); if (s) exec("insertText", s.toString().replace(/\b\w/g, c => c.toUpperCase())); onClose(); }} />
    </div>
    <div style={{ borderBottom: "1px solid rgba(0,0,0,.08)" }}>
      <div style={{ padding: "4px 14px 2px", fontSize: 10, fontWeight: 700, color: "#ccc", textTransform: "uppercase", letterSpacing: ".06em" }}>Inline</div>
      <PopupItem icon="superscript" label="Sobrescrito" onClick={() => { exec("superscript"); onClose(); }} />
      <PopupItem icon="subscript" label="Subscrito" onClick={() => { exec("subscript"); onClose(); }} />
      <PopupItem icon="code" label="Código inline" onClick={() => { exec("insertHTML", '<code style="background:#f0eeeb;padding:1px 5px;font-family:monospace;font-size:.88em;border-radius:4px">código</code>'); onClose(); }} />
    </div>
    <div style={{ borderBottom: "1px solid rgba(0,0,0,.08)" }}>
      <div style={{ padding: "4px 14px 2px", fontSize: 10, fontWeight: 700, color: "#ccc", textTransform: "uppercase", letterSpacing: ".06em" }}>Espaçamento</div>
      {[["1.0 — Compacto","1"],["1.5 — Normal","1.5"],["2.0 — Espaçado","2"]].map(([lbl, val]) => (
        <PopupItem key={val} icon="align-vertical-justify-start" label={lbl} onClick={() => { if (edRef.current) edRef.current.style.lineHeight = val; onClose(); }} />
      ))}
    </div>
    <PopupItem icon="trash-2" label="Limpar formatação" danger onClick={() => { exec("removeFormat"); onClose(); }} />
  </>;
}