import React from 'react';
import { makeStyles, tokens } from '@fluentui/react-components';
import AppHeader from './AppHeader.jsx';
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

const TABS = [
  { id: 'create', label: 'Criar', icon: 'Add24Regular', iconFilled: 'Add24Filled' },
  { id: 'projects', label: 'Projetos', icon: 'Folder24Regular', iconFilled: 'Folder24Filled' },
  { id: 'templates', label: 'Templates', icon: 'Table24Regular', iconFilled: 'Table24Filled' },
  { id: 'me', label: 'Eu', isAvatar: true },
];

export default function HomeShell({ user }) {
  const styles = useStyles();
  const [activeTab, setActiveTab] = React.useState('create');
  const [aiOpen, setAiOpen] = React.useState(false);
  const scrollContainerRef = React.useRef(null);
  
  return (
    <div className={styles.root}>
      {activeTab !== 'create' && <AppHeader activeTab={activeTab} />}

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