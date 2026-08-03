import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Switch, makeStyles, tokens, Button, Text } from '@fluentui/react-components';
import { ArrowLeft24Regular, WeatherMoon24Regular } from '@fluentui/react-icons';

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
  body: {
    paddingTop: tokens.spacingVerticalXL,
    paddingBottom: tokens.spacingVerticalXL,
    paddingLeft: tokens.spacingHorizontalL,
    paddingRight: tokens.spacingHorizontalL,
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    paddingTop: tokens.spacingVerticalM,
    paddingBottom: tokens.spacingVerticalM,
    paddingLeft: tokens.spacingHorizontalL,
    paddingRight: tokens.spacingHorizontalL,
    borderRadius: tokens.borderRadiusLarge,
    border: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
    backgroundColor: tokens.colorNeutralBackground2,
  },
  rowLabel: {
    flex: 1,
  },
});

export default function SettingsPage({ isDark, setIsDark }) {
  const styles = useStyles();
  const navigate = useNavigate();
  
  return (
    <div className={styles.root}>
      <div className={styles.header}>
        <Button appearance="subtle" icon={<ArrowLeft24Regular />} onClick={() => navigate('/home')} />
        <Text weight="bold" size={500}>Definições</Text>
      </div>

      <div className={styles.body}>
        <div className={styles.row}>
          <WeatherMoon24Regular fontSize={22} />
          <Text weight="semibold" className={styles.rowLabel}>Tema escuro</Text>
          <Switch checked={isDark} onChange={(_, data) => setIsDark(data.checked)} />
        </div>
      </div>
    </div>
  );
}