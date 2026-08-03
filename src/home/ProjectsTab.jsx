import React from 'react';
import { Folder24Regular } from '@fluentui/react-icons';
import { makeStyles, tokens, Text, Body1 } from '@fluentui/react-components';

const useStyles = makeStyles({
  root: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    paddingTop: '60px',
    paddingBottom: '60px',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    textAlign: 'center',
  },
  icon: {
    color: tokens.colorNeutralForeground3,
    marginBottom: tokens.spacingVerticalL,
  },
  title: {
    marginBottom: tokens.spacingVerticalXS,
  },
  subtitle: {
    color: tokens.colorNeutralForeground3,
    lineHeight: tokens.lineHeightBase300,
  },
});

export default function ProjectsTab() {
  const styles = useStyles();
  return (
    <div className={styles.root}>
      <Folder24Regular fontSize={48} className={styles.icon} />
      <Text weight="bold" size={500} block className={styles.title}>Ainda sem projetos</Text>
      <Body1 block className={styles.subtitle}>
        Os teus documentos, folhas de cálculo e designs vão aparecer aqui assim que os criares.
      </Body1>
    </div>
  );
}