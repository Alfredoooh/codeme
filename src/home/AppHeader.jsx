import React from 'react';
import { makeStyles, tokens, Title2 } from '@fluentui/react-components';

const useStyles = makeStyles({
  root: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
    paddingTop: 'calc(env(safe-area-inset-top, 0px) + 14px)',
    paddingBottom: tokens.spacingVerticalM,
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    backgroundColor: tokens.colorNeutralBackground1,
    borderBottom: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
  },
});

const TAB_TITLES = {
  create: 'Criar',
  projects: 'Projetos',
  templates: 'Templates',
  me: 'Eu',
};

export default function AppHeader({ activeTab }) {
  const styles = useStyles();
  return (
    <div className={styles.root}>
      <Title2>{TAB_TITLES[activeTab] || 'Nexa'}</Title2>
    </div>
  );
}