import React from 'react';
import { getRawColors } from '../shared/theme.js';
import AppHeader from './AppHeader.jsx';
import BottomTabBar from './BottomTabBar.jsx';
import HomeTab from './HomeTab.jsx';
import CreateTab from './CreateTab.jsx';
import ProjectsTab from './ProjectsTab.jsx';
import MeTab from './MeTab.jsx';

// Shell principal do 'home': appbar fixo + conteúdo da tab ativa +
// bottom tab bar fixo. Mantém o estado de qual tab está ativa em
// memória local (não precisa de estar na URL, tal como no Svelte o
// HomeTab/CreateTab/ProjectsTab/MeTab eram trocados por uma variável
// local `activeTab`, não por rota).
const TABS = [
  { id: 'home', label: 'Início', icon: 'Home24Regular', iconFilled: 'Home24Filled' },
  { id: 'create', label: 'Criar', icon: 'Add24Regular', iconFilled: 'Add24Filled' },
  { id: 'projects', label: 'Projetos', icon: 'Folder24Regular', iconFilled: 'Folder24Filled' },
  { id: 'me', label: 'Eu', icon: 'Person24Regular', iconFilled: 'Person24Filled' },
];

export default function HomeShell({ isDark }) {
  const [activeTab, setActiveTab] = React.useState('home');
  const c = getRawColors(isDark);
  
  return (
    <div style={{ position: 'fixed', inset: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: c.background, color: c.textPrimary }}>
      <AppHeader isDark={isDark} activeTab={activeTab} />

      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', WebkitOverflowScrolling: 'touch', paddingBottom: 88 }}>
        {activeTab === 'home' && <HomeTab isDark={isDark} />}
        {activeTab === 'create' && <CreateTab isDark={isDark} />}
        {activeTab === 'projects' && <ProjectsTab isDark={isDark} />}
        {activeTab === 'me' && <MeTab isDark={isDark} />}
      </div>

      <BottomTabBar isDark={isDark} tabs={TABS} activeTab={activeTab} onChange={setActiveTab} />
    </div>
  );
}