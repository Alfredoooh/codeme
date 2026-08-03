import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Sparkle24Filled, ChevronRight24Regular } from '@fluentui/react-icons';
import { makeStyles, tokens, Title1, Body1, Caption1, Text, Button, Card } from '@fluentui/react-components';
import { ALL_APPS } from '../shared/apps.js';

const useStyles = makeStyles({
  root: {
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    paddingTop: tokens.spacingVerticalXXL,
  },
  greeting: {
    marginBottom: tokens.spacingVerticalXXS,
  },
  subtitle: {
    display: 'block',
    marginBottom: tokens.spacingVerticalXL,
    color: tokens.colorNeutralForeground3,
  },
  aiButton: {
    width: '100%',
    justifyContent: 'flex-start',
    height: 'auto',
    paddingTop: tokens.spacingVerticalL,
    paddingBottom: tokens.spacingVerticalL,
    paddingLeft: tokens.spacingHorizontalL,
    paddingRight: tokens.spacingHorizontalL,
    marginBottom: tokens.spacingVerticalXXL,
    backgroundImage: `linear-gradient(135deg, ${tokens.colorBrandBackground}, ${tokens.colorPaletteGrapeBackground2})`,
    border: 'none',
  },
  aiButtonText: {
    flex: 1,
    textAlign: 'left',
  },
  sectionLabel: {
    display: 'block',
    marginBottom: tokens.spacingVerticalM,
    textTransform: 'uppercase',
    letterSpacing: '0.04em',
    color: tokens.colorNeutralForeground3,
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: tokens.spacingHorizontalM,
    paddingBottom: tokens.spacingVerticalXL,
  },
  appCard: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: tokens.spacingVerticalS,
    paddingTop: tokens.spacingVerticalL,
    paddingBottom: tokens.spacingVerticalL,
    paddingLeft: tokens.spacingHorizontalS,
    paddingRight: tokens.spacingHorizontalS,
    cursor: 'pointer',
    position: 'relative',
    textAlign: 'center',
  },
  iconWrap: {
    width: '44px',
    height: '44px',
    borderRadius: tokens.borderRadiusLarge,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconDot: {
    width: '22px',
    height: '22px',
    borderRadius: tokens.borderRadiusMedium,
  },
  badge: {
    position: 'absolute',
    top: '6px',
    right: '6px',
    fontSize: tokens.fontSizeBase100,
    fontWeight: tokens.fontWeightSemibold,
    color: tokens.colorBrandForeground1,
    backgroundColor: tokens.colorBrandBackground2,
    paddingTop: '2px',
    paddingBottom: '2px',
    paddingLeft: tokens.spacingHorizontalSNudge,
    paddingRight: tokens.spacingHorizontalSNudge,
    borderRadius: tokens.borderRadiusCircular,
  },
});

export default function HomeTab() {
  const styles = useStyles();
  const navigate = useNavigate();
  const greeting = (() => {
    const h = new Date().getHours();
    return h < 12 ? 'Bom dia' : h < 18 ? 'Boa tarde' : 'Boa noite';
  })();
  
  return (
    <div className={styles.root}>
      <Title1 as="h1" block className={styles.greeting}>{greeting}</Title1>
      <Body1 block className={styles.subtitle}>Bem-vindo de volta ao Nexa</Body1>

      <Button
        appearance="primary"
        className={styles.aiButton}
        icon={<Sparkle24Filled fontSize={26} />}
        iconPosition="before"
        onClick={() => navigate('/ai')}
      >
        <div className={styles.aiButtonText}>
          <Text weight="bold" block>Assistente de IA</Text>
          <Caption1 block>Pergunta qualquer coisa</Caption1>
        </div>
        <ChevronRight24Regular />
      </Button>

      <Caption1 block className={styles.sectionLabel}>Apps</Caption1>
      <div className={styles.grid}>
        {ALL_APPS.filter((a) => a.id !== 'home').map((app) => (
          <Card key={app.id} className={styles.appCard} onClick={() => navigate(app.path)}>
            <div className={styles.iconWrap} style={{ backgroundColor: app.color + '26' }}>
              <div className={styles.iconDot} style={{ backgroundColor: app.color }} />
            </div>
            <Caption1 weight="semibold">{app.label}</Caption1>
            {!app.ready && <span className={styles.badge}>Em breve</span>}
          </Card>
        ))}
      </div>
    </div>
  );
}