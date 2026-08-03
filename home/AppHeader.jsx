import React from 'react';
import { getRawColors } from '../shared/theme.js';

const TAB_TITLES = {
  home: 'Início',
  create: 'Criar',
  projects: 'Projetos',
  me: 'Eu',
};

// Appbar fixo do topo. Simples de propósito nesta primeira versão
// React: apenas o título da tab ativa, com o mesmo respeito por
// safe-area-inset-top que a versão Svelte já tinha em todos os
// appbars (env(safe-area-inset-top)).
export default function AppHeader({ isDark, activeTab }) {
  const c = getRawColors(isDark);
  return (
    <div
      style={{
        flexShrink: 0,
        display: 'flex',
        alignItems: 'center',
        padding: 'calc(env(safe-area-inset-top, 0px) + 14px) 20px 14px',
        background: c.background,
        borderBottom: `1px solid ${c.divider}`,
      }}
    >
      <span style={{ fontSize: 22, fontWeight: 700, color: c.textPrimary }}>{TAB_TITLES[activeTab] || 'Nexa'}</span> <
    /div>
  );
}