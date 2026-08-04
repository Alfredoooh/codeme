import React from 'react';
import { makeStyles, tokens } from '@fluentui/react-components';
import BottomTabBar from './BottomTabBar.jsx';
import AiFab from './AiFab.jsx';
import AiSheet from './AiSheet.jsx';
import CreateTab from './CreateTab.jsx';
import ProjectsTab from './ProjectsTab.jsx';
import TemplatesTab from './TemplatesTab.jsx';
import MeTab from './MeTab.jsx';

const useStyles = makeStyles({
  root: {
    position: 'fixed',
    inset: 0,
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    backgroundColor: tokens.colorNeutralBackground2,
    color: tokens.colorNeutralForeground1,
  },
  content: {
    flex: 1,
    minHeight: 0,
    overflowY: 'auto',
    WebkitOverflowScrolling: 'touch',
    paddingBottom: '88px',
  },
});

// CollectionsAdd para "Criar" e Board para "Templates" — os ícones
// pedidos explicitamente, não substitutos.
const TABS = [
  { id: 'create', label: 'Criar', icon: 'CollectionsAdd24Regular', iconFilled: 'CollectionsAdd24Filled' },
  { id: 'projects', label: 'Projetos', icon: 'Folder24Regular', iconFilled: 'Folder24Filled' },
  { id: 'templates', label: 'Templates', icon: 'Board24Regular', iconFilled: 'Board24Filled' },
  { id: 'me', label: 'Eu', isAvatar: true },
];

export default function HomeShell({ user }) {
  const styles = useStyles();
  const [activeTab, setActiveTab] = React.useState('create');
  const [aiOpen, setAiOpen] = React.useState(false);
  const scrollContainerRef = React.useRef(null);
  
  // Cada tab é dona do seu próprio appbar — nenhuma delas depende
  // de um AppHeader partilhado no shell.
  return (
    <div className={styles.root}>
      <div className={styles.content} ref={scrollContainerRef}>
        {activeTab === 'create' && <CreateTab scrollContainerRef={scrollContainerRef} />}
        {activeTab === 'projects' && <ProjectsTab />}
        {activeTab === 'templates' && <TemplatesTab />}
        {activeTab === 'me' && <MeTab user={user} />}
      </div>

      <AiFab onClick={() => setAiOpen(true)} />
      <AiSheet open={aiOpen} onOpenChange={setAiOpen} />

      <BottomTabBar
        tabs={TABS}
        activeTab={activeTab}
        onChange={setActiveTab}
        avatarUrl={user?.avatarUrl}
        avatarColor={user?.avatarColor}
        userInitial={user?.initial}
      />
    </div>
  );
}