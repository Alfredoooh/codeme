import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft24Regular, Alert24Regular } from '@fluentui/react-icons';
import { makeStyles, tokens, Button, Text, Body1 } from '@fluentui/react-components';

const useStyles = makeStyles({
  root: {
    position: 'fixed',
    inset: 0,
    display: 'flex',
    flexDirection: 'column',
    backgroundColor: tokens.colorNeutralBackground1,
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    paddingTop: 'calc(env(safe-area-inset-top, 0px) + 14px)',
    paddingBottom: tokens.spacingVerticalM,
    paddingLeft: tokens.spacingHorizontalL,
    paddingRight: tokens.spacingHorizontalL,
    borderBottom: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
  },
  empty: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    paddingLeft: '40px',
    paddingRight: '40px',
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

export default function NotificationsPage() {
  const styles = useStyles();
  const navigate = useNavigate();
  
  return (
    <div className={styles.root}>
      <div className={styles.header}>
        <Button appearance="subtle" icon={<ArrowLeft24Regular />} onClick={() => navigate(-1)} />
        <Text weight="bold" size={500}>Notificações</Text>
      </div>

      <div className={styles.empty}>
        <Alert24Regular fontSize={48} className={styles.icon} />
        <Text weight="bold" size={500} block className={styles.title}>Sem notificações</Text>
        <Body1 block className={styles.subtitle}>
          Quando tiveres novidades sobre os teus projetos, vão aparecer aqui.
        </Body1>
      </div>
    </div>
  );
}