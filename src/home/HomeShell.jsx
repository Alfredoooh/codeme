import React from 'react';
import { makeStyles, tokens } from '@fluentui/react-components';
import AppHeader from './AppHeader.jsx';
import BottomTabBar from './BottomTabBar.jsx';
import HomeTab from './HomeTab.jsx';
import CreateTab from './CreateTab.jsx';
import ProjectsTab from './ProjectsTab.jsx';
import MeTab from './MeTab.jsx';

const useStyles = makeStyles({
  root: {
    position: 'fixed',
    inset: 0,
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    backgroundColor: tokens.colorNeutralBackground1,
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
  { id: 'home', label: 'Início', icon: 'Home24Regular', iconFilled: 'Home24Filled' },
  { id: 'create', label: 'Criar', icon: 'Add24Regular', iconFilled: 'Add24Filled' },
  { id: 'projects', label: 'Projetos', icon: 'Folder24Regular', iconFilled: 'Folder24Filled' },
  { id: 'me', label: 'Eu', icon: 'Person24Regular', iconFilled: 'Person24Filled' },
];

export default function HomeShell() {
  const styles = useStyles();
  const [activeTab, setActiveTab] = React.useState('home');
  
  return (
    <div className={styles.root}>
      <AppHeader activeTab={activeTab} />

      <div className={styles.content}>
        {activeTab === 'home' && <HomeTab />}
        {activeTab === 'create' && <CreateTab />}
        {activeTab === 'projects' && <ProjectsTab />}
        {activeTab === 'me' && <MeTab />}
      </div>

      <BottomTabBar tabs={TABS} activeTab={activeTab} onChange={setActiveTab} />
    </div>
  );
}