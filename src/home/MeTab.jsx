import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Person24Filled, Settings24Regular, ChevronRight24Regular } from '@fluentui/react-icons';
import { getRawColors } from '../shared/theme.js';

// Tab "Eu": ponto de entrada para definições. Mantém-se simples nesta
// primeira versão — a versão completa (MeTab.svelte, estilo
// Microsoft Settings, com secções de conta/credits/idioma) é o
// próximo passo depois de 'home' estar validada nesta base.
export default function MeTab({ isDark }) {
  const c = getRawColors(isDark);
  const navigate = useNavigate();
  
  return (
    <div style={{ padding: '20px 20px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '10px 4px 24px' }}>
        <div style={{ width: 56, height: 56, borderRadius: '50%', background: c.accent, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
          <Person24Filled fontSize={28} />
        </div>
        <div>
          <div style={{ fontSize: 17, fontWeight: 700, color: c.textPrimary }}>Utilizador Nexa</div>
          <div style={{ fontSize: 13, color: c.textSecondary, marginTop: 2 }}>Ver e editar perfil</div>
        </div>
      </div>

      <button
        onClick={() => navigate('/home/settings')}
        style={{
          width: '100%',
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          padding: '14px 16px',
          borderRadius: 14,
          border: `1px solid ${c.divider}`,
          background: c.surface,
          cursor: 'pointer',
        }}
      >
        <Settings24Regular fontSize={22} style={{ color: c.textPrimary }} />
        <span style={{ flex: 1, textAlign: 'left', fontSize: 14.5, fontWeight: 600, color: c.textPrimary }}>Definições</span>
        <ChevronRight24Regular style={{ color: c.textSecondary }} />
      </button>
    </div>
  );
}