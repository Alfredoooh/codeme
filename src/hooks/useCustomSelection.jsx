/**
 * useCustomSelection
 * Handles de seleção + lupa + menu contextual para contentEditable.
 * Não altera o editor — apenas observa o edRef.
 */
import { useState, useEffect, useRef, useCallback } from "react";

const BLUE = "#1a73e8";
const MW = 132, MH = 60, SCALE = 1.6;

const IC = {
  scissors:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><line x1="20" y1="4" x2="8.12" y2="15.88"/><line x1="14.47" y1="14.48" x2="20" y2="20"/><line x1="8.12" y1="8.12" x2="12" y2="12"/></svg>`,
  copy:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>`,
  clipboard:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="2" width="8" height="4" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/></svg>`,
  "check-square":`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>`,
  bold:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"/></svg>`,
  italic:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="4" x2="10" y2="4"/><line x1="14" y1="20" x2="5" y2="20"/><line x1="15" y1="4" x2="9" y2="20"/></svg>`,
  underline:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4v6a6 6 0 0 0 12 0V4"/><line x1="4" y1="20" x2="20" y2="20"/></svg>`,
  "case-upper":`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 15 4-8 4 8"/><path d="M4 13h6"/><path d="M15 11h4.5a2 2 0 0 1 0 4H15V7h4a2 2 0 0 1 0 4"/></svg>`,
  link:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>`,
  "trash-2":`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/></svg>`,
};

const CSS = `
/* suppress native selection highlight — we draw our own */
.cs-ed-target::selection, .cs-ed-target *::selection { background: transparent !important; }

.cs-hl {
  position: fixed; pointer-events: none; z-index: 290;
  background: rgba(0,120,255,.22); border-radius: 2px;
}
.cs-handle {
  position: fixed; z-index: 295;
  width: 22px; height: 44px;
  pointer-events: auto; touch-action: none;
  -webkit-user-select: none; user-select: none; cursor: pointer;
}
.cs-handle-inner {
  width: 100%; height: 100%;
  display: flex; flex-direction: column; align-items: center;
}
.cs-dot {
  width: 14px; height: 14px; border-radius: 50%;
  background: ${BLUE}; box-shadow: 0 1px 4px rgba(26,115,232,.5);
  flex-shrink: 0;
}
.cs-line {
  width: 2px; flex: 1; border-radius: 2px;
  background: ${BLUE};
}
.cs-mag {
  position: fixed; pointer-events: none; z-index: 9998;
  width: ${MW}px; height: ${MH}px;
  border-radius: 18px;
  background: rgba(255,255,255,.98);
  box-shadow: 0 6px 24px rgba(0,0,0,.22), 0 0 0 1.5px rgba(0,0,0,.08);
  overflow: hidden;
}
.cs-mag-inner {
  position: absolute; inset: 0; overflow: hidden; border-radius: 18px;
}
.cs-mag-clone {
  position: absolute; top: 0; left: 0;
  pointer-events: none; -webkit-user-select: none; user-select: none;
  transform-origin: top left;
  font-size: 16px; line-height: 1.85; color: #34322d;
  font-family: 'Lora', Georgia, serif;
  white-space: pre-wrap; word-break: break-word;
}
.cs-mag-clone .cs-hl-clone {
  background: rgba(0,120,255,.3); border-radius: 2px;
}
.cs-menu {
  position: fixed; z-index: 9999;
  background: #1c1c1e; border-radius: 14px;
  box-shadow: 0 6px 28px rgba(0,0,0,.4);
  overflow: visible;
  -webkit-user-select: none; user-select: none;
  pointer-events: auto;
  animation: csPop .14s cubic-bezier(.34,1.56,.64,1) both;
}
.cs-menu::before {
  content: ""; position: absolute;
  left: var(--cs-ax, 50%); transform: translateX(-50%);
  width: 0; height: 0; pointer-events: none;
}
.cs-menu.adown::before {
  top: 100%;
  border-left: 8px solid transparent; border-right: 8px solid transparent;
  border-top: 9px solid #1c1c1e;
}
.cs-menu.aup::before {
  bottom: 100%;
  border-left: 8px solid transparent; border-right: 8px solid transparent;
  border-bottom: 9px solid #1c1c1e;
}
.cs-inner {
  display: flex; align-items: stretch;
  overflow-x: auto; scrollbar-width: none; border-radius: 14px;
}
.cs-inner::-webkit-scrollbar { display: none; }
.cs-btn {
  border: none; background: transparent; color: #fff;
  padding: 12px 14px; font-size: 13px; font-weight: 500;
  font-family: 'DM Sans', system-ui, sans-serif;
  cursor: pointer; border-right: 1px solid rgba(255,255,255,.10);
  white-space: nowrap; display: flex; align-items: center; gap: 6px;
  outline: none; flex-shrink: 0;
  -webkit-tap-highlight-color: transparent;
}
.cs-btn:last-child { border-right: none; }
.cs-btn:active { background: rgba(255,255,255,.16); }
.cs-btn.cs-danger { color: #ff6b6b; }
.cs-btn svg { width: 13px; height: 13px; flex-shrink: 0; pointer-events: none; }
@keyframes csPop {
  from { opacity: 0; transform: scale(.9) translateY(4px); }
  to   { opacity: 1; transform: scale(1) translateY(0); }
}
`;

let _cssInjected = false;
function injectCSS() {
  if (_cssInjected) return; _cssInjected = true;
  const s = document.createElement("style"); s.textContent = CSS;
  document.head.appendChild(s);
}

/* ── geometry helpers ── */
function getActiveRects() {
  const s = window.getSelection();
  if (!s || s.isCollapsed || !s.rangeCount) return [];
  return [...s.getRangeAt(0).getClientRects()].filter(r => r.width > 1);
}

function caretFromPoint(x, y) {
  if (document.caretPositionFromPoint) {
    const p = document.caretPositionFromPoint(x, y);
    return p ? { node: p.offsetNode, offset: p.offset } : null;
  }
  if (document.caretRangeFromPoint) {
    const r = document.caretRangeFromPoint(x, y);
    return r ? { node: r.startContainer, offset: r.startOffset } : null;
  }
  return null;
}

function menuPos(selRect, menuW, menuH) {
  const GAP = 10, AH = 9, vw = window.innerWidth, vh = window.innerHeight;
  let left = selRect.left + selRect.width / 2 - menuW / 2;
  left = Math.max(8, Math.min(vw - menuW - 8, left));
  const ax = Math.max(18, Math.min(menuW - 18, selRect.left + selRect.width / 2 - left));
  let top, dir;
  const spaceAbove = selRect.top - GAP - AH - menuH;
  const spaceBelow = vh - selRect.bottom - GAP - AH - menuH;
  if (spaceAbove >= 0) { top = selRect.top - menuH - GAP - AH; dir = "down"; }
  else if (spaceBelow >= 0) { top = selRect.bottom + GAP + AH; dir = "up"; }
  else if (spaceAbove > spaceBelow) { top = Math.max(8, selRect.top - menuH - GAP - AH); dir = "down"; }
  else { top = selRect.bottom + GAP + AH; dir = "up"; }
  return { left, top, ax, dir };
}

/* ══════════════════════════════════════════════════════════ */
export function useCustomSelection(edRef) {
  injectCSS();

  // Visual state
  const [hlRects,  setHlRects]  = useState([]);  // [{left,top,width,height}]
  const [hStart,   setHStart]   = useState(null); // {left,top}
  const [hEnd,     setHEnd]     = useState(null); // {left,top}
  const [mag,      setMag]      = useState(null); // {left,top,cloneStyle,selRangeData}
  const [menu,     setMenu]     = useState(null); // {left,top,ax,dir} | "measure"

  // Refs (no re-render needed)
  const dragging   = useRef(null);   // "start"|"end"|null
  const isMouseSel = useRef(false);
  const longTimer  = useRef(null);
  const menuMeasRef= useRef(null);   // ref on off-screen menu for measuring

  /* ── snapshot current selection visuals ── */
  const snap = useCallback((showMenu = false) => {
    const s = window.getSelection();
    const active = s && !s.isCollapsed && s.rangeCount > 0;
    if (!active) {
      setHlRects([]); setHStart(null); setHEnd(null); setMag(null); setMenu(null);
      return;
    }
    const rects = getActiveRects();
    setHlRects(rects);
    if (rects.length) {
      const f = rects[0], l = rects[rects.length - 1];
      setHStart({ left: f.left - 11,  top: f.top - 16 });
      setHEnd({   left: l.right - 11, top: l.bottom - 24 });
    }
    if (showMenu) setMenu("measure");
  }, []);

  /* after off-screen menu mounts, measure it and place it properly */
  useEffect(() => {
    if (menu !== "measure" || !menuMeasRef.current) return;
    const s = window.getSelection();
    if (!s || s.isCollapsed || !s.rangeCount) { setMenu(null); return; }
    const selRect = s.getRangeAt(0).getBoundingClientRect();
    const mw = menuMeasRef.current.offsetWidth || 340;
    const mh = menuMeasRef.current.offsetHeight || 44;
    setMenu(menuPos(selRect, mw, mh));
  });

  /* ── handle drag: rewrite selection range ── */
  const moveHandle = useCallback((cx, cy, which) => {
    const ed = edRef.current;
    if (!ed) return;
    const s = window.getSelection();
    if (!s || !s.rangeCount) return;
    const range = s.getRangeAt(0);
    const caret = caretFromPoint(cx, cy);
    if (!caret || !ed.contains(caret.node)) return;
    const nr = document.createRange();
    try {
      if (which === "start") {
        nr.setStart(caret.node, caret.offset);
        nr.setEnd(range.endContainer, range.endOffset);
      } else {
        nr.setStart(range.startContainer, range.startOffset);
        nr.setEnd(caret.node, caret.offset);
      }
      if (nr.collapsed) return;
    } catch { return; }
    s.removeAllRanges(); s.addRange(nr);
    snap(false);

    // magnifier
    const er = ed.getBoundingClientRect();
    setMag({ x: cx, y: cy, edRect: er, html: ed.innerHTML });
  }, [edRef, snap]);

  /* ── editor-level events (mouseup, touchend, keyup, longpress) ── */
  useEffect(() => {
    const ed = edRef.current;
    if (!ed) return;

    // Mark editor so CSS can suppress native selection colour
    ed.classList.add("cs-ed-target");

    const onMouseDown = (e) => {
      // Don't interfere with handle or menu clicks
      if (e.target.closest(".cs-handle") || e.target.closest(".cs-menu")) return;
      isMouseSel.current = true;
      setMenu(null);
    };
    const onMouseUp = () => {
      if (!isMouseSel.current) return;
      isMouseSel.current = false;
      setTimeout(() => snap(true), 20);
    };
    const onMouseMove = (e) => {
      if (!isMouseSel.current) return;
      const s = window.getSelection();
      if (s && !s.isCollapsed) {
        const er = ed.getBoundingClientRect();
        setMag({ x: e.clientX, y: e.clientY, edRect: er, html: ed.innerHTML });
        snap(false);
      }
    };

    // Touch: long-press to select word
    let tx0 = 0, ty0 = 0;
    const onTouchStart = (e) => {
      if (e.target.closest(".cs-handle") || e.target.closest(".cs-menu")) return;
      const t = e.touches[0];
      tx0 = t.clientX; ty0 = t.clientY;
      clearTimeout(longTimer.current);
      longTimer.current = setTimeout(() => {
        if (navigator.vibrate) navigator.vibrate(35);
        const caret = caretFromPoint(tx0, ty0);
        if (!caret) return;
        // Expand to word
        const nr = document.createRange();
        try {
          nr.setStart(caret.node, caret.offset);
          nr.setEnd(caret.node, caret.offset);
          const txt = caret.node.textContent || "";
          let s2 = caret.offset, e2 = caret.offset;
          while (s2 > 0 && /\S/.test(txt[s2 - 1])) s2--;
          while (e2 < txt.length && /\S/.test(txt[e2])) e2++;
          nr.setStart(caret.node, s2);
          nr.setEnd(caret.node, e2);
          if (!nr.collapsed) {
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(nr);
            snap(true);
          }
        } catch { }
      }, 480);
    };
    const onTouchMove = (e) => {
      const t = e.touches[0];
      if (Math.abs(t.clientX - tx0) > 8 || Math.abs(t.clientY - ty0) > 8)
        clearTimeout(longTimer.current);
    };
    const onTouchEnd = () => {
      clearTimeout(longTimer.current);
      setTimeout(() => snap(true), 120);
    };
    const onKeyUp = () => snap(false);

    ed.addEventListener("mousedown", onMouseDown);
    ed.addEventListener("mouseup",   onMouseUp);
    ed.addEventListener("mousemove", onMouseMove);
    ed.addEventListener("touchstart",onTouchStart, { passive: true });
    ed.addEventListener("touchmove", onTouchMove,  { passive: true });
    ed.addEventListener("touchend",  onTouchEnd,   { passive: true });
    ed.addEventListener("keyup",     onKeyUp);

    return () => {
      ed.classList.remove("cs-ed-target");
      ed.removeEventListener("mousedown", onMouseDown);
      ed.removeEventListener("mouseup",   onMouseUp);
      ed.removeEventListener("mousemove", onMouseMove);
      ed.removeEventListener("touchstart",onTouchStart);
      ed.removeEventListener("touchmove", onTouchMove);
      ed.removeEventListener("touchend",  onTouchEnd);
      ed.removeEventListener("keyup",     onKeyUp);
    };
  }, [edRef, snap]);

  /* ── global mouse: handle drags + dismiss on outside click ── */
  useEffect(() => {
    const onMove = (e) => {
      if (!dragging.current) return;
      moveHandle(e.clientX, e.clientY, dragging.current);
    };
    const onUp = () => {
      if (dragging.current) {
        dragging.current = null;
        setMag(null);
        snap(true);
      }
    };
    const onDown = (e) => {
      const ed = edRef.current;
      if (!ed) return;
      if (!ed.contains(e.target) && !e.target.closest(".cs-handle") && !e.target.closest(".cs-menu")) {
        window.getSelection()?.removeAllRanges();
        setHlRects([]); setHStart(null); setHEnd(null); setMag(null); setMenu(null);
      }
    };
    const onScroll = () => snap(!!menu && menu !== "measure");
    const onResize = () => snap(false);

    document.addEventListener("mousemove",  onMove);
    document.addEventListener("mouseup",    onUp);
    document.addEventListener("mousedown",  onDown);
    document.addEventListener("touchstart", onDown, { passive: true });
    window.addEventListener("scroll", onScroll, true);
    window.addEventListener("resize", onResize);
    return () => {
      document.removeEventListener("mousemove",  onMove);
      document.removeEventListener("mouseup",    onUp);
      document.removeEventListener("mousedown",  onDown);
      document.removeEventListener("touchstart", onDown);
      window.removeEventListener("scroll", onScroll, true);
      window.removeEventListener("resize", onResize);
    };
  }, [edRef, snap, moveHandle, menu]);

  /* ── actions ── */
  const doExec = useCallback((cmd, val) => {
    const ed = edRef.current; if (ed) ed.focus();
    document.execCommand(cmd, false, val || null);
    setMenu(null);
    setTimeout(() => snap(false), 30);
  }, [edRef, snap]);

  const ACTIONS = [
    { l:"Cortar",    ic:"scissors",     fn: async () => { const s=window.getSelection(); if(s&&!s.isCollapsed){try{await navigator.clipboard.writeText(s.toString())}catch(_){}}; doExec("delete"); } },
    { l:"Copiar",    ic:"copy",         fn: async () => { const s=window.getSelection(); if(s&&!s.isCollapsed){try{await navigator.clipboard.writeText(s.toString())}catch(_){document.execCommand("copy")}}; setMenu(null); } },
    { l:"Colar",     ic:"clipboard",    fn: async () => { setMenu(null); try{const t=await navigator.clipboard.readText(); doExec("insertText",t);}catch(_){} } },
    { l:"Sel. tudo", ic:"check-square", fn: () => { doExec("selectAll"); setTimeout(()=>snap(true),80); } },
    { l:"Negrito",   ic:"bold",         fn: () => doExec("bold") },
    { l:"Itálico",   ic:"italic",       fn: () => doExec("italic") },
    { l:"Sublinhado",ic:"underline",    fn: () => doExec("underline") },
    { l:"MAIÚSC.",   ic:"case-upper",   fn: () => { const s=window.getSelection(); if(s&&!s.isCollapsed) doExec("insertText",s.toString().toUpperCase()); } },
    { l:"Link",      ic:"link",         fn: () => { setMenu(null); const u=prompt("URL:"); if(u) doExec("createLink",u); } },
    { l:"Apagar",    ic:"trash-2",      danger:true, fn: () => doExec("delete") },
  ];

  /* ── handle component props ── */
  function hProps(which) {
    return {
      onMouseDown: (e) => { e.preventDefault(); e.stopPropagation(); dragging.current = which; setMenu(null); },
      onTouchStart: (e) => { e.preventDefault(); e.stopPropagation(); dragging.current = which; setMenu(null); },
      onTouchMove: (e) => { e.preventDefault(); const t = e.touches[0]; moveHandle(t.clientX, t.clientY, which); },
      onTouchEnd: (e) => { e.preventDefault(); dragging.current = null; setMag(null); snap(true); },
    };
  }

  /* ── magnifier transform ── */
  function magTransform() {
    if (!mag) return "";
    const { x, y, edRect } = mag;
    const ox = x - edRect.left, oy = y - edRect.top;
    return `translate(${MW/2 - SCALE*ox}px, ${MH/2 - SCALE*oy}px) scale(${SCALE})`;
  }

  /* ── Overlay ── */
  function Overlay() {
    return (
      <>
        {/* Highlight rects */}
        {hlRects.map((r, i) => (
          <div key={i} className="cs-hl" style={{ left: r.left, top: r.top, width: r.width, height: r.height }} />
        ))}

        {/* Start handle — dot on top, line below */}
        {hStart && (
          <div className="cs-handle" style={{ left: hStart.left, top: hStart.top }} {...hProps("start")}>
            <div className="cs-handle-inner">
              <div className="cs-dot" />
              <div className="cs-line" />
            </div>
          </div>
        )}

        {/* End handle — line on top, dot below */}
        {hEnd && (
          <div className="cs-handle" style={{ left: hEnd.left, top: hEnd.top }} {...hProps("end")}>
            <div className="cs-handle-inner">
              <div className="cs-line" />
              <div className="cs-dot" />
            </div>
          </div>
        )}

        {/* Magnifier */}
        {mag && (
          <div className="cs-mag" style={{
            left: Math.max(8, Math.min(window.innerWidth - MW - 8, mag.x - MW/2)),
            top: Math.max(8, mag.y - MH - 40),
          }}>
            <div className="cs-mag-inner">
              <div className="cs-mag-clone"
                style={{ width: mag.edRect.width, transform: magTransform() }}
                dangerouslySetInnerHTML={{ __html: mag.html }}
              />
            </div>
          </div>
        )}

        {/* Off-screen menu for measuring */}
        {menu === "measure" && (
          <div ref={menuMeasRef} className="cs-menu"
            style={{ position:"fixed", left:-9999, top:-9999, visibility:"hidden", pointerEvents:"none" }}>
            <div className="cs-inner">
              {ACTIONS.map(a => (
                <button key={a.l} className={`cs-btn${a.danger?" cs-danger":""}`}>
                  <span dangerouslySetInnerHTML={{__html: IC[a.ic]}}/>
                  {a.l}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Real menu */}
        {menu && menu !== "measure" && (
          <div className={`cs-menu ${menu.dir==="down"?"adown":"aup"}`}
            style={{ left: menu.left, top: menu.top, "--cs-ax": menu.ax+"px" }}>
            <div className="cs-inner">
              {ACTIONS.map(a => (
                <button key={a.l} className={`cs-btn${a.danger?" cs-danger":""}`}
                  onMouseDown={e => e.preventDefault()}
                  onTouchStart={e => e.stopPropagation()}
                  onClick={a.fn}>
                  <span dangerouslySetInnerHTML={{__html: IC[a.ic]}}/>
                  {a.l}
                </button>
              ))}
            </div>
          </div>
        )}
      </>
    );
  }

  return { Overlay };
}