import React from 'react';
import { useNavigate } from 'react-router-dom';
import { makeStyles, tokens, Title2, Text, Caption1, Card } from '@fluentui/react-components';
import { ALL_APPS } from '../shared/apps.js';

const useStyles = makeStyles({
  root: {
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    paddingTop: tokens.spacingVerticalXXL,
  },
  title: {
    marginBottom: tokens.spacingVerticalXL,
  },
  list: {
    display: 'flex',
    flexDirection: 'column',
    gap: tokens.spacingVerticalS,
    paddingBottom: tokens.spacingVerticalXL,
  },
  item: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    paddingTop: tokens.spacingVerticalM,
    paddingBottom: tokens.spacingVerticalM,
    paddingLeft: tokens.spacingHorizontalL,
    paddingRight: tokens.spacingHorizontalL,
    cursor: 'pointer',
    textAlign: 'left',
  },
  swatch: {
    width: '40px',
    height: '40px',
    borderRadius: tokens.borderRadiusMedium,
    flexShrink: 0,
  },
  itemBody: {
    flex: 1,
  },
  itemSubtitle: {
    display: 'block',
    marginTop: tokens.spacingVerticalXXS,
    color: tokens.colorNeutralForeground3,
  },
});

export default function CreateTab() {
  const styles = useStyles();
  const navigate = useNavigate();
  const creationApps = ALL_APPS.filter((a) => a.id !== 'home');
  
  return (
    <div className={styles.root}>
      <Title2 as="h1" block className={styles.title}>O que queres criar?</Title2>
      <div className={styles.list}>
        {creationApps.map((app) => (
          <Card key={app.id} className={styles.item} onClick={() => navigate(app.path)}>
            <div className={styles.swatch} style={{ backgroundColor: app.color }} />
            <div className={styles.itemBody}>
              <Text weight="bold" block>{app.label}</Text>
              <Caption1 block className={styles.itemSubtitle}>
                {app.ready ? 'Toca para começar' : 'Em breve'}
              </Caption1>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}