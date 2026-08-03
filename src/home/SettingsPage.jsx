import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Switch } from '@fluentui/react-components';
import { ArrowLeft24Regular, WeatherMoon24Regular } from '@fluentui/react-icons';
import { getRawColors } from '../shared/theme.js';

// Página de definições, alcançável a partir de MeTab. Por agora só
// tem o toggle de tema claro/escuro, que é a única definição
// realmente funcional nesta primeira versão React.
export default function SettingsPage({ isDark, setIsDark }) {
  const c = getRawColors(isDark);
  const navigate = useNavigate();

  return (
    <div style={{ position: 'fixed', inset: 0, display: 'flex', flexDirection: 'column', background: c.background }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 'calc(env(safe-area-inset-top, 0px) + 14px) 16px 14px', borderBottom: `1px solid ${c.divider}` }}>
        <button onClick={() => navigate('/home')} style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', color: c.textPrimary }}>
          <ArrowLeft24Regular fontSize={22} />
        </button>
        <span style={{ fontSize: 17, fontWeight: 700, color: c.textPrimary }}>Definições</span>
      </div>

      <div style={{ padding: '20px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderRadius: 14, border: `1px solid ${c.divider}`, background: c.surface }}>
          <WeatherMoon24Regular fontSize={22} style={{ color: c.textPrimary }} />
          <span style={{ flex: 1, fontSize: 14.5, fontWeight: 600, color: c.textPrimary }}>Tema escuro</span>
          <Switch checked={isDark} onChange={(_, data) => setIsDark(data.checked)} />
        </div>
      </div>
    </div>
  );
}