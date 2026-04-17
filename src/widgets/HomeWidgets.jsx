import { useRef } from "react";
import { TwEmoji, EMOJI_LIST } from "../data/emojis";

/* ══════════════════════════════════════
   EMOJI PICKER
══════════════════════════════════════ */
export function EmojiPickerOverlay({ picker, onSelect, onClose, T, Icon }) {
  return (
    &lt;div style={{
      position: "fixed", inset: 0, zIndex: 300,
      background: T.card, display: "flex", flexDirection: "column",
      animation: "scaleIn .22s cubic-bezier(.32,1,.56,1) both",
    }}&gt;
      &lt;div style={{
        height: 56, display: "flex", alignItems: "center",
        padding: "0 16px", borderBottom: `1px solid ${T.brd}`,
        flexShrink: 0, background: T.bar,
      }}&gt;
        &lt;div style={{ flex: 1, fontSize: 16, fontWeight: 700, color: T.text }}&gt;
          Escolher ícone
        &lt;/div&gt;
        &lt;button className="pressable" onClick={onClose} style={{
          width: 36, height: 36, border: "none", background: "transparent",
          cursor: "pointer", display: "flex", alignItems: "center",
          justifyContent: "center", borderRadius: 10, color: T.sub,
        }}&gt;
          &lt;Icon name="x" size={20} /&gt;
        &lt;/button&gt;
      &lt;/div&gt;
      &lt;div style={{ flex: 1, overflowY: "auto", padding: "16px 12px", scrollbarWidth: "none" }}&gt;
        &lt;div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}&gt;
          {EMOJI_LIST.map(e =&gt; (
            &lt;button
              key={e.cp}
              className="pressable"
              onClick={() =&gt; onSelect(picker.target, picker.id, e.cp)}
              style={{
                width: 60, height: 60, borderRadius: 14,
                border: `1.5px solid ${T.brd}`, background: "transparent",
                cursor: "pointer", display: "flex", flexDirection: "column",
                alignItems: "center", justifyContent: "center", gap: 4,
              }}
            &gt;
              &lt;TwEmoji cp={e.cp} size={28} /&gt;
              &lt;span style={{ fontSize: 9, color: T.sub, fontWeight: 500, lineHeight: 1 }}&gt;
                {e.lbl}
              &lt;/span&gt;
            &lt;/button&gt;
          ))}
        &lt;/div&gt;
      &lt;/div&gt;
    &lt;/div&gt;
  );
}

/* ══════════════════════════════════════
   CONTEXT MENU
══════════════════════════════════════ */
export function DocContextMenu({ ctxMenu, onEdit, onMove, onTrash, onClose, T, Icon }) {
  return (
    &lt;&gt;
      &lt;div style={{ position: "fixed", inset: 0, zIndex: 9998 }} onClick={onClose} /&gt;
      &lt;div style={{
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
      }}&gt;
        &lt;button className="ctx-item" style={{ color: T.text }} onClick={onEdit}&gt;
          &lt;Icon name="pencil" size={15} style={{ color: T.sub }} /&gt; Editar
        &lt;/button&gt;
        &lt;div style={{ height: 1, background: T.brd }} /&gt;
        &lt;button className="ctx-item" style={{ color: T.text }} onClick={onMove}&gt;
          &lt;Icon name="move" size={15} style={{ color: T.sub }} /&gt; Mover para pasta
        &lt;/button&gt;
        &lt;div style={{ height: 1, background: T.brd }} /&gt;
        &lt;button className="ctx-item danger" onClick={onTrash}&gt;
          &lt;Icon name="trash-2" size={15} style={{ color: "#ff3b30" }} /&gt; Enviar ao lixo
        &lt;/button&gt;
      &lt;/div&gt;
    &lt;/&gt;
  );
}

/* ══════════════════════════════════════
   FOLDER SHEET
══════════════════════════════════════ */
export function FolderSheet({ projects, onMove, onClose, T, Icon }) {
  return (
    &lt;&gt;
      &lt;div style={{
        position: "fixed", inset: 0, zIndex: 199,
        background: "rgba(0,0,0,.25)", animation: "fadeIn .2s both",
      }} onClick={onClose} /&gt;
      &lt;div style={{
        position: "fixed", bottom: 0, left: 0, right: 0,
        background: T.card, borderRadius: "24px 24px 0 0",
        padding: "20px 0 max(28px,env(safe-area-inset-bottom,28px))",
        zIndex: 200, animation: "slideUp .3s cubic-bezier(.32,1,.56,1) both",
        maxHeight: "70vh", display: "flex", flexDirection: "column",
      }}&gt;
        &lt;div style={{
          width: 36, height: 4, background: T.brd,
          borderRadius: 2, margin: "0 auto 14px",
        }} /&gt;
        &lt;div style={{
          fontSize: 16, fontWeight: 700, color: T.text,
          padding: "0 20px 12px", borderBottom: `1px solid ${T.brd}`,
        }}&gt;
          Mover para pasta
        &lt;/div&gt;
        &lt;div style={{ flex: 1, overflowY: "auto", scrollbarWidth: "none" }}&gt;
          {projects.map(proj =&gt; (
            &lt;div key={proj.id}&gt;
              &lt;div style={{
                padding: "10px 20px 4px", fontSize: 12, fontWeight: 700,
                color: T.sub, textTransform: "uppercase", letterSpacing: ".06em",
                display: "flex", alignItems: "center", gap: 8,
              }}&gt;
                &lt;TwEmoji cp={proj.emoji} size={14} /&gt; {proj.name}
              &lt;/div&gt;
              {proj.folders.map(f =&gt; (
                &lt;button key={f.id} className="pressable" onClick={() =&gt; onMove(f.id, proj.id)}
                  style={{
                    display: "flex", alignItems: "center", gap: 12,
                    padding: "13px 20px", border: "none", background: "transparent",
                    width: "100%", cursor: "pointer",
                    fontFamily: "'DM Sans',sans-serif", fontSize: 14, color: T.text,
                  }}&gt;
                  &lt;TwEmoji cp={f.emoji} size={18} /&gt;
                  {f.name}
                  &lt;Icon name="chevron-right" size={14} style={{ color: T.sub, marginLeft: "auto" }} /&gt;
                &lt;/button&gt;
              ))}
            &lt;/div&gt;
          ))}
        &lt;/div&gt;
      &lt;/div&gt;
    &lt;/&gt;
  );
}

/* ══════════════════════════════════════
   NEW FOLDER DIALOG
══════════════════════════════════════ */
export function NewFolderDialog({ newFolderDlg, newFolderName, setNewFolderName, onConfirm, onClose, T, Icon }) {
  const inputRef = useRef(null);
  return (
    &lt;&gt;
      &lt;div style={{ position: "fixed", inset: 0, zIndex: 299, background: "rgba(0,0,0,.35)", animation: "fadeIn .18s both" }} onClick={onClose} /&gt;
      &lt;div style={{
        position: "fixed", top: "50%", left: "50%",
        transform: "translate(-50%,-50%)",
        width: "min(88vw,340px)", background: T.card,
        borderRadius: 20, zIndex: 300, overflow: "hidden",
        boxShadow: "0 20px 60px rgba(0,0,0,.3),0 4px 16px rgba(0,0,0,.15)",
        animation: "scaleIn .22s cubic-bezier(.32,1,.56,1) both",
      }}&gt;
        &lt;div style={{ padding: "24px 24px 8px" }}&gt;
          &lt;Icon name="folder-plus" size={32} style={{ color: "#007aff", marginBottom: 14, display: "block" }} /&gt;
          &lt;div style={{ fontSize: 18, fontWeight: 700, color: T.text, marginBottom: 4 }}&gt;
            Nova pasta
          &lt;/div&gt;
          &lt;div style={{ fontSize: 13, color: T.sub, marginBottom: 20 }}&gt;
            {newFolderDlg.parentFolderId
              ? "Criar sub-pasta dentro da pasta selecionada"
              : "Criar pasta no projeto"}
          &lt;/div&gt;
          &lt;input
            ref={inputRef}
            value={newFolderName}
            onChange={e =&gt; setNewFolderName(e.target.value)}
            onKeyDown={e =&gt; {
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
          /&gt;
        &lt;/div&gt;
        &lt;div style={{ display: "flex", borderTop: `1px solid ${T.brd}`, marginTop: 16 }}&gt;
          &lt;button className="pressable" onClick={onClose} style={{
            flex: 1, padding: "15px 0", border: "none", background: "transparent",
            cursor: "pointer", fontFamily: "'DM Sans',sans-serif",
            fontSize: 16, fontWeight: 500, color: T.sub,
          }}&gt;
            Cancelar
          &lt;/button&gt;
          &lt;div style={{ width: 1, background: T.brd }} /&gt;
          &lt;button className="pressable" onClick={onConfirm} style={{
            flex: 1, padding: "15px 0", border: "none", background: "transparent",
            cursor: "pointer", fontFamily: "'DM Sans',sans-serif",
            fontSize: 16, fontWeight: 700,
            color: newFolderName.trim() ? "#007aff" : T.sub,
          }}&gt;
            Criar
          &lt;/button&gt;
        &lt;/div&gt;
      &lt;/div&gt;
    &lt;/&gt;
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
    &lt;&gt;
      &lt;div style={{ position: "fixed", inset: 0, zIndex: 399, background: "rgba(0,0,0,.35)", animation: "fadeIn .18s both" }} onClick={onClose} /&gt;
      &lt;div style={{
        position: "fixed", top: "50%", left: "50%",
        transform: "translate(-50%,-50%)",
        width: "min(88vw,320px)", background: T.card,
        borderRadius: 20, zIndex: 400, overflow: "hidden",
        boxShadow: "0 20px 60px rgba(0,0,0,.3),0 4px 16px rgba(0,0,0,.15)",
        animation: "scaleIn .22s cubic-bezier(.32,1,.56,1) both",
      }}&gt;
        &lt;div style={{ padding: "24px 24px 16px" }}&gt;
          &lt;Icon name="palette" size={32} style={{ color: "#7c3aed", marginBottom: 14, display: "block" }} /&gt;
          &lt;div style={{ fontSize: 18, fontWeight: 700, color: T.text, marginBottom: 4 }}&gt;Aparência&lt;/div&gt;
          &lt;div style={{ fontSize: 13, color: T.sub, marginBottom: 20 }}&gt;Escolhe o tema da aplicação&lt;/div&gt;
          {opts.map(t =&gt; (
            &lt;button key={t.id} className="pressable" onClick={() =&gt; setTheme(t.id)} style={{
              display: "flex", alignItems: "center", gap: 14,
              width: "100%", padding: "12px 14px",
              border: `1.5px solid ${theme === t.id ? "#007aff" : T.brd}`,
              borderRadius: 14,
              background: theme === t.id ? (isDark ? "rgba(0,122,255,.12)" : "#eff6ff") : "transparent",
              cursor: "pointer", marginBottom: 10,
              fontFamily: "'DM Sans',sans-serif", textAlign: "left",
              transition: "all .15s",
            }}&gt;
              &lt;Icon
                name={t.icon} size={20}
                style={{ color: theme === t.id ? "#007aff" : T.sub, flexShrink: 0 }}
              /&gt;
              &lt;div style={{ flex: 1 }}&gt;
                &lt;div style={{ fontSize: 15, fontWeight: 600, color: T.text }}&gt;{t.label}&lt;/div&gt;
                &lt;div style={{ fontSize: 12, color: T.sub }}&gt;{t.desc}&lt;/div&gt;
              &lt;/div&gt;
              {theme === t.id &amp;&amp; &lt;Icon name="check" size={18} style={{ color: "#007aff" }} /&gt;}
            &lt;/button&gt;
          ))}
        &lt;/div&gt;
        &lt;div style={{ borderTop: `1px solid ${T.brd}` }}&gt;
          &lt;button className="pressable" onClick={onClose} style={{
            width: "100%", padding: "15px 0", border: "none", background: "transparent",
            cursor: "pointer", fontFamily: "'DM Sans',sans-serif",
            fontSize: 16, fontWeight: 700, color: "#007aff",
          }}&gt;
            Feito
          &lt;/button&gt;
        &lt;/div&gt;
      &lt;/div&gt;
    &lt;/&gt;
  );
}

/* ══════════════════════════════════════
   AI SHEET
══════════════════════════════════════ */
export function AiSheet({ aiInput, setAiInput, aiLoading, onSubmit, onClose, T, Icon }) {
  const ref = useRef(null);
  return (
    &lt;&gt;
      &lt;div style={{
        position: "fixed", inset: 0, zIndex: 60,
        background: "rgba(0,0,0,.3)", animation: "fadeIn .2s both",
      }} onClick={onClose} /&gt;
      &lt;div style={{
        position: "fixed", bottom: 0, left: 0, right: 0,
        background: T.card, borderRadius: "24px 24px 0 0",
        padding: "20px 20px max(32px,env(safe-area-inset-bottom,32px))",
        zIndex: 61, animation: "slideUp .3s cubic-bezier(.32,1,.56,1) both",
      }}&gt;
        &lt;div style={{
          width: 36, height: 4, background: T.brd,
          borderRadius: 2, margin: "0 auto 18px",
        }} /&gt;
        &lt;div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}&gt;
          &lt;Icon name="sparkles" size={22} style={{ color: "#007aff", flexShrink: 0 }} /&gt;
          &lt;div style={{ flex: 1 }}&gt;
            &lt;div style={{ fontSize: 16, fontWeight: 700, color: T.text }}&gt;Criar com IA&lt;/div&gt;
            &lt;div style={{ fontSize: 13, color: T.sub }}&gt;Descreve o que queres criar&lt;/div&gt;
          &lt;/div&gt;
          &lt;button className="pressable" onClick={onClose} style={{
            border: "none", background: "transparent", cursor: "pointer",
            color: T.sub, padding: 6, borderRadius: 9,
          }}&gt;
            &lt;Icon name="x" size={18} /&gt;
          &lt;/button&gt;
        &lt;/div&gt;
        &lt;textarea
          ref={ref}
          autoFocus
          value={aiInput}
          onChange={e =&gt; setAiInput(e.target.value)}
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
        /&gt;
        &lt;button
          className="pressable"
          onClick={onSubmit}
          disabled={!aiInput.trim() || aiLoading}
          style={{
            width: "100%", marginTop: 14, padding: "15px 0",
            background: aiInput.trim() &amp;&amp; !aiLoading ? "#007aff" : "rgba(0,0,0,.07)",
            color: aiInput.trim() &amp;&amp; !aiLoading ? "#fff" : T.sub,
            border: "none", borderRadius: 14,
            cursor: aiInput.trim() &amp;&amp; !aiLoading ? "pointer" : "default",
            fontFamily: "'DM Sans',sans-serif", fontSize: 16, fontWeight: 600,
            display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
            transition: "background .2s",
          }}
        &gt;
          {aiLoading ? "A criar…" : &lt;&gt;&lt;Icon name="send" size={16} /&gt;Criar documento&lt;/&gt;}
        &lt;/button&gt;
      &lt;/div&gt;
    &lt;/&gt;
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
    &lt;&gt;
      &lt;div style={{
        position: "fixed", inset: 0, zIndex: 199,
        background: "rgba(0,0,0,.25)", animation: "fadeIn .2s both",
      }} onClick={onClose} /&gt;
      &lt;div style={{
        position: "fixed", bottom: 0, left: 0, right: 0,
        background: T.card, borderRadius: "24px 24px 0 0",
        padding: "20px 0 max(32px,env(safe-area-inset-bottom,32px))",
        zIndex: 200, animation: "slideUp .3s cubic-bezier(.32,1,.56,1) both",
        maxHeight: "75vh", display: "flex", flexDirection: "column",
      }}&gt;
        &lt;div style={{
          width: 36, height: 4, background: T.brd,
          borderRadius: 2, margin: "0 auto 14px",
        }} /&gt;
        &lt;div style={{
          fontSize: 16, fontWeight: 700, color: T.text,
          padding: "0 20px 12px", borderBottom: `1px solid ${T.brd}`,
          display: "flex", alignItems: "center", gap: 10,
        }}&gt;
          &lt;Icon name="layout-template" size={18} style={{ color: "#007aff" }} /&gt;
          Templates
        &lt;/div&gt;
        &lt;div style={{ flex: 1, overflowY: "auto", scrollbarWidth: "none", padding: "12px 16px" }}&gt;
          {TEMPLATES.map((tmpl, idx) =&gt; {
            const isFirst = idx === 0;
            const isLast  = idx === TEMPLATES.length - 1;
            const borderRadius = isFirst ? "12px 12px 3px 3px" : isLast ? "3px 3px 12px 12px" : "3px";
            return (
              &lt;button
                key={tmpl.id}
                className="pressable"
                onClick={() =&gt; onSelect(tmpl)}
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
                onPointerOver={e =&gt; e.currentTarget.style.background = T.hover}
                onPointerOut={e  =&gt; e.currentTarget.style.background = T.card}
              &gt;
                &lt;TwEmoji cp={tmpl.emoji} size={24} /&gt;
                &lt;div style={{ flex: 1 }}&gt;
                  &lt;div style={{ fontSize: 15, fontWeight: 600, color: T.text }}&gt;{tmpl.label}&lt;/div&gt;
                  &lt;div style={{ fontSize: 12, color: T.sub }}&gt;{tmpl.desc}&lt;/div&gt;
                &lt;/div&gt;
                &lt;Icon name="chevron-right" size={15} style={{ color: T.sub }} /&gt;
              &lt;/button&gt;
            );
          })}
        &lt;/div&gt;
      &lt;/div&gt;
    &lt;/&gt;
  );
}