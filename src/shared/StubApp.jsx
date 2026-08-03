import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft24Regular, Clock24Regular } from '@fluentui/react-icons';
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
  },
  body: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    paddingLeft: '40px',
    paddingRight: '40px',
    textAlign: 'center',
  },
  iconWrap: {
    width: '64px',
    height: '64px',
    borderRadius: tokens.borderRadiusXLarge,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: tokens.spacingVerticalL,
  },
  title: {
    marginBottom: tokens.spacingVerticalS,
  },
  subtitle: {
    color: tokens.colorNeutralForeground3,
    lineHeight: tokens.lineHeightBase300,
  },
});

export default function StubApp({ appLabel, appColor }) {
  const styles = useStyles();
  const navigate = useNavigate();
  
  return (
    <div className={styles.root}>
      <div className={styles.header}>
        <Button appearance="subtle" icon={<ArrowLeft24Regular />} onClick={() => navigate('/home')} />
      </div>

      <div className={styles.body}>
        <div className={styles.iconWrap} style={{ backgroundColor: appColor + '26' }}>
          <Clock24Regular fontSize={30} style={{ color: appColor }} />
        </div>
        <Text weight="bold" size={500} block className={styles.title}>{appLabel}</Text>
        <Body1 block className={styles.subtitle}>
          Esta app ainda está a ser reconstruída na nova base React + Fluent UI. Por agora, só o Início está completo.
        </Body1>
      </div>
    </div>
  );
}