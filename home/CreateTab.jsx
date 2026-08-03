import React from 'react';
import { useNavigate } from 'react-router-dom';
import { getRawColors } from '../shared/theme.js';
import { ALL_APPS } from '../shared/apps.js';

// Tab "Criar": grid focado em criação de conteúdo, um botão por app
// de conteúdo. Estruturalmente igual à CreateTab.svelte (grid de
// ícones coloridos por app), sem os templates ainda porque essa
// lógica (DOC_MODELS, etc.) ainda não foi portada para esta base.
export default function CreateTab({ isDark }) {
  const c = getRawColors(isDark);
  const navigate = useNavigate();
  const creationApps = ALL_APPS.filter((a) => a.id !== 'home');
  
  return (
    <div style={{ padding: '20px 20px 0' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, margin: '0 0 20px', color: c.textPrimary }}>O que queres criar?</h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 20 }}>
        {creationApps.map((app) => (
          <button
            key={app.id}
            onClick={() => navigate(app.path)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 14,
              padding: '14px 16px',
              borderRadius: 14,
              border: `1px solid ${c.divider}`,
              background: c.surface,
              cursor: 'pointer',
              textAlign: 'left',
            }}
          >
            <div style={{ width: 40, height: 40, borderRadius: 10, background: app.color, flexShrink: 0 }} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14.5, fontWeight: 700, color: c.textPrimary }}>{app.label}</div>
              <div style={{ fontSize: 12, color: c.textSecondary, marginTop: 2 }}>
                {app.ready ? 'Toca para começar' : 'Em breve'}
              </div>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}