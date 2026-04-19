import { useRef } from "react";
import { TwEmoji, EMOJI_LIST } from "../data/emojis";

/* ══════════════════════════════════════
   EMOJI PICKER
══════════════════════════════════════ */
export function EmojiPickerOverlay({ picker, onSelect, onClose, T, Icon }) {
  return (
    <div style={{
      position: "fixed", inset: 0, zIndex: 300,
      background: T.card, display: "flex", flexDirection: "column",
      animation: "scaleIn .22s cubic-bezier(.32,1,.56,1) both",
    }}>
      <div style={{
        height: 56, display: "flex", alignItems: "center",
        padding: "0 16px", borderBottom: `1px solid ${T.brd}`,
        flexShrink: 0, background: T.bar,
      }}>
        <div style={{ flex: 1, fontSize: 16, fontWeight: 700, color: T.text }}>
          Escolher ícone
        </div>
        <button className="pressable" onClick={onClose} style={{
          width: 36, height: 36, border: "none", background: "transparent",
          cursor: "pointer", display: "flex", alignItems: "center",
          justifyContent: "center", borderRadius: 10, color: T.sub,
        }}>
          <Icon name="x" size={20} />
        </button>
      </div>
      <div style={{ flex: 1, overflowY: "auto", padding: "16px 12px", scrollbarWidth: "none" }}>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
          {EMOJI_LIST.map(e => (
            <button
              key={e.cp}
              className="pressable"
              onClick={() => onSelect(picker.target, picker.id, e.cp)}
              style={{
                width: 60, height: 60, borderRadius: 14,
                border: `1.5px solid ${T.brd}`, background: "transparent",
                cursor: "pointer", display: "flex", flexDirection: "column",
                alignItems: "center", justifyContent: "center", gap: 4,
              }}
            >
              <TwEmoji cp={e.cp} size={28} />
              <span style={{ fontSize: 9, color: T.sub, fontWeight: 500, lineHeight: 1 }}>
                {e.lbl}
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ══════════════════════════════════════
   CONTEXT MENU
══════════════════════════════════════ */
export function DocContextMenu({ ctxMenu, onEdit, onMove, onTrash, onClose, T, Icon }) {
  return (
    <>
      <div style={{ position: "fixed", inset: 0, zIndex: 9998 }} onClick={onClose} />
      <div style={{
        position: "fixed",
        background: T.card,
        borderRadius: 14,
        boxShadow: "0 4px 24px rgba(0,0,0,.15),0 1px 4px rgba(0,0,0,.08)",
        border: `1px solid ${T.brd}`,
        zIndex: 9999,
        overflow: "hidden",
        minWidth: 200,
        left: ctxMenu.x,
        top: ctxMenu.y,
        animation: "scaleIn .18s cubic-bezier(.32,1,.56,1) both",
      }}>
        <button className="ctx-item" style={{ color: T.text }} onClick={onEdit}>
          <Icon name="pencil" size={15} style={{ color: T.sub }} /> Editar
        </button>
        <div style={{ height: 1, background: T.brd }} />
        <button className="ctx-item" style={{ color: T.text }} onClick={onMove}>
          <Icon name="move" size={15} style={{ color: T.sub }} /> Mover para pasta
        </button>
        <div style={{ height: 1, background: T.brd }} />
        <button className="ctx-item danger" onClick={onTrash}>
          <Icon name="trash-2" size={15} style={{ color: "#ff3b30" }} /> Enviar ao lixo
        </button>
      </div>
    </>
  );
}

/* ══════════════════════════════════════
   FOLDER SHEET
══════════════════════════════════════ */
export function FolderSheet({ projects, onMove, onClose, T, Icon }) {
  return (
    <>
      <div style={{
        position: "fixed", inset: 0, zIndex: 199,
        background: "rgba(0,0,0,.25)", animation: "fadeIn .2s both",
      }} onClick={onClose} />
      <div style={{
        position: "fixed", bottom: 0, left: 0, right: 0,
        background: T.card, borderRadius: "24px 24px 0 0",
        padding: "20px 0 max(28px,env(safe-area-inset-bottom,28px))",
        zIndex: 200, animation: "slideUp .3s cubic-bezier(.32,1,.56,1) both",
        maxHeight: "70vh", display: "flex", flexDirection: "column",
      }}>
        <div style={{
          width: 36, height: 4, background: T.brd,
          borderRadius: 2, margin: "0 auto 14px",
        }} />
        <div style={{
          fontSize: 16, fontWeight: 700, color: T.text,
          padding: "0 20px 12px", borderBottom: `1px solid ${T.brd}`,
        }}>
          Mover para pasta
        </div>
        <div style={{ flex: 1, overflowY: "auto", scrollbarWidth: "none" }}>
          {projects.map(proj => (
            <div key={proj.id}>
              <div style={{
                padding: "10px 20px 4px", fontSize: 12, fontWeight: 700,
                color: T.sub, textTransform: "uppercase", letterSpacing: ".06em",
                display: "flex", alignItems: "center", gap: 8,
              }}>
                <TwEmoji cp={proj.emoji} size={14} /> {proj.name}
              </div>
              {proj.folders.map(f => (
                <button key={f.id} className="pressable" onClick={() => onMove(f.id, proj.id)}
                  style={{
                    display: "flex", alignItems: "center", gap: 12,
                    padding: "13px 20px", border: "none", background: "transparent",
                    width: "100%", cursor: "pointer",
                    fontFamily: "'DM Sans',sans-serif", fontSize: 14, color: T.text,
                  }}>
                  <TwEmoji cp={f.emoji} size={18} />
                  {f.name}
                  <Icon name="chevron-right" size={14} style={{ color: T.sub, marginLeft: "auto" }} />
                </button>
              ))}
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

/* ══════════════════════════════════════
   NEW FOLDER DIALOG
══════════════════════════════════════ */
export function NewFolderDialog({ newFolderDlg, newFolderName, setNewFolderName, onConfirm, onClose, T, Icon }) {
  const inputRef = useRef(null);
  return (
    <>
      <div style={{ position: "fixed", inset: 0, zIndex: 299, background: "rgba(0,0,0,.35)", animation: "fadeIn .18s both" }} onClick={onClose} />
      <div style={{
        position: "fixed", top: "50%", left: "50%",
        transform: "translate(-50%,-50%)",
        width: "min(88vw,340px)", background: T.card,
        borderRadius: 20, zIndex: 300, overflow: "hidden",
        boxShadow: "0 20px 60px rgba(0,0,0,.3),0 4px 16px rgba(0,0,0,.15)",
        animation: "scaleIn .22s cubic-bezier(.32,1,.56,1) both",
      }}>
        <div style={{ padding: "24px 24px 8px" }}>
          <Icon name="folder-plus" size={32} style={{ color: "#007aff", marginBottom: 14, display: "block" }} />
          <div style={{ fontSize: 18, fontWeight: 700, color: T.text, marginBottom: 4 }}>
            Nova pasta
          </div>
          <div style={{ fontSize: 13, color: T.sub, marginBottom: 20 }}>
            {newFolderDlg.parentFolderId
              ? "Criar sub-pasta dentro da pasta selecionada"
              : "Criar pasta no projeto"}
          </div>
          <input
            ref={inputRef}
            value={newFolderName}
            onChange={e => setNewFolderName(e.target.value)}
            onKeyDown={e => {
              if (e.key === "Enter") onConfirm();
              if (e.key === "Escape") onClose();
            }}
            placeholder="Nome da pasta…"
            autoFocus
            style={{
              width: "100%", padding: "12px 14px",
              border: `1.5px solid ${T.brd}`, borderRadius: 10,
              fontSize: 15, outline: "none",
              fontFamily: "'DM Sans',sans-serif",
              background: T.bg, color: T.text,
              WebkitUserSelect: "text", userSelect: "text",
            }}
          />
        </div>
        <div style={{ display: "flex", borderTop: `1px solid ${T.brd}`, marginTop: 16 }}>
          <button className="pressable" onClick={onClose} style={{
            flex: 1, padding: "15px 0", border: "none", background: "transparent",
            cursor: "pointer", fontFamily: "'DM Sans',sans-serif",
            fontSize: 16, fontWeight: 500, color: T.sub,
          }}>
            Cancelar
          </button>
          <div style={{ width: 1, background: T.brd }} />
          <button className="pressable" onClick={onConfirm} style={{
            flex: 1, padding: "15px 0", border: "none", background: "transparent",
            cursor: "pointer", fontFamily: "'DM Sans',sans-serif",
            fontSize: 16, fontWeight: 700,
            color: newFolderName.trim() ? "#007aff" : T.sub,
          }}>
            Criar
          </button>
        </div>
      </div>
    </>
  );
}

/* ══════════════════════════════════════
   THEME DIALOG
══════════════════════════════════════ */
export function ThemeDialog({ theme, setTheme, onClose, T, Icon, isDark }) {
  const opts = [
    { id: "light",  icon: "sun",     label: "Claro",   desc: "Fundo branco brilhante" },
    { id: "dark",   icon: "moon",    label: "Escuro",  desc: "Fundo escuro confortável" },
    { id: "system", icon: "monitor", label: "Sistema", desc: "Segue o tema do dispositivo" },
  ];
  return (
    <>
      <div style={{ position: "fixed", inset: 0, zIndex: 399, background: "rgba(0,0,0,.35)", animation: "fadeIn .18s both" }} onClick={onClose} />
      <div style={{
        position: "fixed", top: "50%", left: "50%",
        transform: "translate(-50%,-50%)",
        width: "min(88vw,320px)", background: T.card,
        borderRadius: 20, zIndex: 400, overflow: "hidden",
        boxShadow: "0 20px 60px rgba(0,0,0,.3),0 4px 16px rgba(0,0,0,.15)",
        animation: "scaleIn .22s cubic-bezier(.32,1,.56,1) both",
      }}>
        <div style={{ padding: "24px 24px 16px" }}>
          <Icon name="palette" size={32} style={{ color: "#7c3aed", marginBottom: 14, display: "block" }} />
          <div style={{ fontSize: 18, fontWeight: 700, color: T.text, marginBottom: 4 }}>Aparência</div>
          <div style={{ fontSize: 13, color: T.sub, marginBottom: 20 }}>Escolhe o tema da aplicação</div>
          {opts.map(t => (
            <button key={t.id} className="pressable" onClick={() => setTheme(t.id)} style={{
              display: "flex", alignItems: "center", gap: 14,
              width: "100%", padding: "12px 14px",
              border: `1.5px solid ${theme === t.id ? "#007aff" : T.brd}`,
              borderRadius: 14,
              background: theme === t.id ? (isDark ? "rgba(0,122,255,.12)" : "#eff6ff") : "transparent",
              cursor: "pointer", marginBottom: 10,
              fontFamily: "'DM Sans',sans-serif", textAlign: "left",
              transition: "all .15s",
            }}>
              <Icon
                name={t.icon} size={20}
                style={{ color: theme === t.id ? "#007aff" : T.sub, flexShrink: 0 }}
              />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 600, color: T.text }}>{t.label}</div>
                <div style={{ fontSize: 12, color: T.sub }}>{t.desc}</div>
              </div>
              {theme === t.id && <Icon name="check" size={18} style={{ color: "#007aff" }} />}
            </button>
          ))}
        </div>
        <div style={{ borderTop: `1px solid ${T.brd}` }}>
          <button className="pressable" onClick={onClose} style={{
            width: "100%", padding: "15px 0", border: "none", background: "transparent",
            cursor: "pointer", fontFamily: "'DM Sans',sans-serif",
            fontSize: 16, fontWeight: 700, color: "#007aff",
          }}>
            Feito
          </button>
        </div>
      </div>
    </>
  );
}

/* ══════════════════════════════════════
   AI SHEET
══════════════════════════════════════ */
export function AiSheet({ aiInput, setAiInput, aiLoading, onSubmit, onClose, T, Icon }) {
  const ref = useRef(null);
  return (
    <>
      <div style={{
        position: "fixed", inset: 0, zIndex: 60,
        background: "rgba(0,0,0,.3)", animation: "fadeIn .2s both",
      }} onClick={onClose} />
      <div style={{
        position: "fixed", bottom: 0, left: 0, right: 0,
        background: T.card, borderRadius: "24px 24px 0 0",
        padding: "20px 20px max(32px,env(safe-area-inset-bottom,32px))",
        zIndex: 61, animation: "slideUp .3s cubic-bezier(.32,1,.56,1) both",
      }}>
        <div style={{
          width: 36, height: 4, background: T.brd,
          borderRadius: 2, margin: "0 auto 18px",
        }} />
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
          <Icon name="sparkles" size={22} style={{ color: "#007aff", flexShrink: 0 }} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: T.text }}>Criar com IA</div>
            <div style={{ fontSize: 13, color: T.sub }}>Descreve o que queres criar</div>
          </div>
          <button className="pressable" onClick={onClose} style={{
            border: "none", background: "transparent", cursor: "pointer",
            color: T.sub, padding: 6, borderRadius: 9,
          }}>
            <Icon name="x" size={18} />
          </button>
        </div>
        <textarea
          ref={ref}
          autoFocus
          value={aiInput}
          onChange={e => setAiInput(e.target.value)}
          placeholder="Ex: Plano de aula sobre fotossíntese, relatório de vendas, resumo de livro…"
          rows={5}
          style={{
            width: "100%", padding: "14px 16px",
            border: `1.5px solid ${T.brd}`,
            borderRadius: 10,
            fontSize: 15,
            fontFamily: "'DM Sans',sans-serif",
            outline: "none", resize: "none",
            color: T.text, background: T.bg,
            lineHeight: 1.65,
            WebkitUserSelect: "text", userSelect: "text",
            minHeight: 120,
          }}
        />
        <button
          className="pressable"
          onClick={onSubmit}
          disabled={!aiInput.trim() || aiLoading}
          style={{
            width: "100%", marginTop: 14, padding: "15px 0",
            background: aiInput.trim() && !aiLoading ? "#007aff" : "rgba(0,0,0,.07)",
            color: aiInput.trim() && !aiLoading ? "#fff" : T.sub,
            border: "none", borderRadius: 14,
            cursor: aiInput.trim() && !aiLoading ? "pointer" : "default",
            fontFamily: "'DM Sans',sans-serif", fontSize: 16, fontWeight: 600,
            display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
            transition: "background .2s",
          }}
        >
          {aiLoading ? "A criar…" : <><Icon name="send" size={16} />Criar documento</>}
        </button>
      </div>
    </>
  );
}

/* ══════════════════════════════════════
   TEMPLATES SHEET
══════════════════════════════════════ */
const TEMPLATES = [
  { id: "meeting",  emoji: "1f4cb", label: "Ata de Reunião",      desc: "Estrutura para registar pontos e decisões" },
  { id: "plan",     emoji: "1f3af", label: "Plano de Projecto",    desc: "Objectivos, tarefas e prazos" },
  { id: "lesson",   emoji: "1f393", label: "Plano de Aula",        desc: "Conteúdos, actividades e avaliação" },
  { id: "report",   emoji: "1f4ca", label: "Relatório",            desc: "Sumário executivo e análise" },
  { id: "journal",  emoji: "1f4d3", label: "Diário",               desc: "Reflexão pessoal do dia" },
  { id: "recipe",   emoji: "1f35e", label: "Receita",              desc: "Ingredientes e modo de preparação" },
  { id: "budget",   emoji: "1f4b0", label: "Orçamento",            desc: "Entradas, saídas e saldo" },
  { id: "cv",       emoji: "1f4bc", label: "Curriculum Vitae",     desc: "Experiência, formação e competências" },
  { id: "email",    emoji: "1f4e7", label: "Email Formal",         desc: "Estrutura de email profissional" },
  { id: "research", emoji: "1f52c", label: "Pesquisa",             desc: "Introdução, metodologia e conclusão" },
];

export function TemplatesSheet({ onSelect, onClose, T, Icon }) {
  return (
    <>
      <div style={{
        position: "fixed", inset: 0, zIndex: 199,
        background: "rgba(0,0,0,.25)", animation: "fadeIn .2s both",
      }} onClick={onClose} />
      <div style={{
        position: "fixed", bottom: 0, left: 0, right: 0,
        background: T.card, borderRadius: "24px 24px 0 0",
        padding: "20px 0 max(32px,env(safe-area-inset-bottom,32px))",
        zIndex: 200, animation: "slideUp .3s cubic-bezier(.32,1,.56,1) both",
        maxHeight: "75vh", display: "flex", flexDirection: "column",
      }}>
        <div style={{
          width: 36, height: 4, background: T.brd,
          borderRadius: 2, margin: "0 auto 14px",
        }} />
        <div style={{
          fontSize: 16, fontWeight: 700, color: T.text,
          padding: "0 20px 12px", borderBottom: `1px solid ${T.brd}`,
          display: "flex", alignItems: "center", gap: 10,
        }}>
          <Icon name="layout-template" size={18} style={{ color: "#007aff" }} />
          Templates
        </div>
        <div style={{ flex: 1, overflowY: "auto", scrollbarWidth: "none", padding: "12px 16px" }}>
          {TEMPLATES.map((tmpl, idx) => {
            const isFirst = idx === 0;
            const isLast  = idx === TEMPLATES.length - 1;
            const borderRadius = isFirst ? "12px 12px 3px 3px" : isLast ? "3px 3px 12px 12px" : "3px";
            return (
              <button
                key={tmpl.id}
                className="pressable"
                onClick={() => onSelect(tmpl)}
                style={{
                  display: "flex", alignItems: "center", gap: 14,
                  width: "100%", padding: "14px 16px",
                  background: T.card,
                  border: `1px solid ${T.brd}`,
                  borderRadius,
                  marginBottom: 2,
                  cursor: "pointer",
                  fontFamily: "'DM Sans',sans-serif", textAlign: "left",
                }}
                onPointerOver={e => e.currentTarget.style.background = T.hover}
                onPointerOut={e  => e.currentTarget.style.background = T.card}
              >
                <TwEmoji cp={tmpl.emoji} size={24} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 15, fontWeight: 600, color: T.text }}>{tmpl.label}</div>
                  <div style={{ fontSize: 12, color: T.sub }}>{tmpl.desc}</div>
                </div>
                <Icon name="chevron-right" size={15} style={{ color: T.sub }} />
              </button>
            );
          })}
        </div>
      </div>
    </>
  );
}
