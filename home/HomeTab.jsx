import React from 'react';
import { Sparkle24Filled, ChevronRight24Regular } from '@fluentui/react-icons';
import { getRawColors } from '../shared/theme.js';
import { ALL_APPS } from '../shared/apps.js';
import { useNavigate } from 'react-router-dom';

// Tab "Início": saudação + acesso rápido ao Assistente de IA + grid
// de apps (mesma ideia da HomeTab.svelte, simplificada para esta
// primeira passagem em React já que o resto do conteúdo real dessa
// tab no Svelte — templates recentes, sugestões — ainda não existe
// nesta base nova).
export default function HomeTab({ isDark }) {
  const c = getRawColors(isDark);
  const navigate = useNavigate();
  const greeting = (() => {
    const h = new Date().getHours();
    return h < 12 ? 'Bom dia' : h < 18 ? 'Boa tarde' : 'Boa noite';
  })();
  
  return (
    <div style={{ padding: '20px 20px 0' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, margin: '0 0 4px', color: c.textPrimary }}>{greeting}</h1>
      <p style={{ fontSize: 14, margin: '0 0 20px', color: c.textSecondary }}>Bem-vindo de volta ao Nexa</p>

      <button
        onClick={() => navigate('/ai')}
        style={{
          width: '100%',
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          padding: '16px 18px',
          borderRadius: 16,
          border: 'none',
          background: `linear-gradient(135deg, ${c.accent}, #862CD4)`,
          color: '#fff',
          cursor: 'pointer',
          marginBottom: 24,
        }}
      >
        <Sparkle24Filled fontSize={26} />
        <div style={{ textAlign: 'left', flex: 1 }}>
          <div style={{ fontSize: 15, fontWeight: 700 }}>Assistente de IA</div>
          <div style={{ fontSize: 12.5, opacity: 0.9 }}>Pergunta qualquer coisa</div>
        </div>
        <ChevronRight24Regular />
      </button>

      <div style={{ fontSize: 13, fontWeight: 700, color: c.textSecondary, textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: 12 }}>
        Apps
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, paddingBottom: 20 }}>
        {ALL_APPS.filter((a) => a.id !== 'home').map((app) => (
          <button
            key={app.id}
            onClick={() => navigate(app.path)}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 8,
              padding: '16px 8px',
              borderRadius: 16,
              border: `1px solid ${c.divider}`,
              background: c.surface,
              cursor: 'pointer',
              position: 'relative',
            }}
          >
            <div style={{ width: 44, height: 44, borderRadius: 12, background: app.color + '26', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ width: 22, height: 22, borderRadius: 6, background: app.color }} />
            </div>
            <span style={{ fontSize: 12, fontWeight: 600, color: c.textPrimary, textAlign: 'center' }}>{app.label}</span>
            {!app.ready && (
              <span style={{ position: 'absolute', top: 6, right: 6, fontSize: 9, fontWeight: 700, color: c.accent, background: c.accent + '1a', padding: '2px 6px', borderRadius: 8 }}>
                Em breve
              </span>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}