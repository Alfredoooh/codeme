import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft24Regular, Clock24Regular } from '@fluentui/react-icons';
import { getRawColors } from './theme.js';

// Ecrã partilhado por todas as apps ainda não reconstruídas nesta
// base React (ai, docs, sheets, whiteboard, slides, profile, auth).
// Único ponto a atualizar quando cada uma for implementada de
// verdade: nessa altura, o App.jsx dessa pasta deixa de importar
// StubApp e passa a montar o conteúdo real, exatamente como HomeApp
// já faz para o 'home'.
export default function StubApp({ isDark, appLabel, appColor }) {
  const c = getRawColors(isDark);
  const navigate = useNavigate();
  
  return (
    <div style={{ position: 'fixed', inset: 0, display: 'flex', flexDirection: 'column', background: c.background }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 'calc(env(safe-area-inset-top, 0px) + 14px) 16px 14px' }}>
        <button onClick={() => navigate('/home')} style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', color: c.textPrimary }}>
          <ArrowLeft24Regular fontSize={22} />
        </button>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 40px', textAlign: 'center' }}>
        <div style={{ width: 64, height: 64, borderRadius: 18, background: appColor + '26', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 20 }}>
          <Clock24Regular fontSize={30} style={{ color: appColor }} />
        </div>
        <div style={{ fontSize: 19, fontWeight: 700, color: c.textPrimary, marginBottom: 8 }}>{appLabel}</div>
        <div style={{ fontSize: 14, color: c.textSecondary, lineHeight: 1.6 }}>
          Esta app ainda está a ser reconstruída na nova base React + Fluent UI. Por agora, só o Início está completo.
        </div>
      </div>
    </div>
  );
}