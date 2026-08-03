import React from 'react';
import * as Icons from '@fluentui/react-icons';
import { getRawColors } from '../shared/theme.js';

// Bottom tab bar fixo. Usa @fluentui/react-icons dinamicamente pelo
// nome (Icons[iconName]) para não ter de importar cada ícone
// individualmente aqui — troca automaticamente entre a variante
// regular e a filled consoante a tab está ativa, tal como o padrão
// de ícones "regular vs filled" que já usavas no Svelte
// (/icons/svg/regular/ vs /icons/svg/filled/).
export default function BottomTabBar({ isDark, tabs, activeTab, onChange }) {
  const c = getRawColors(isDark);
  return (
    <div
      style={{
        flexShrink: 0,
        display: 'flex',
        alignItems: 'stretch',
        justifyContent: 'space-around',
        background: c.surface,
        borderTop: `1px solid ${c.divider}`,
        padding: '6px 4px calc(env(safe-area-inset-bottom, 0px) + 6px)',
      }}
    >
      {tabs.map((tab) => {
        const isActive = activeTab === tab.id;
        const IconComp = Icons[isActive ? tab.iconFilled : tab.icon] || Icons.Circle24Regular;
        return (
          <button
            key={tab.id}
            onClick={() => onChange(tab.id)}
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 3,
              padding: '6px 4px',
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              color: isActive ? c.accent : c.textSecondary,
              transition: 'color 0.15s ease',
            }}
          >
            <IconComp fontSize={24} />
            <span style={{ fontSize: 11, fontWeight: isActive ? 700 : 500 }}>{tab.label}</span>
          </button>
        );
      })}
    </div>
  );
}