import React from 'react';
import { useNavigate } from 'react-router-dom';
import { AddCircle24Filled } from '@fluentui/react-icons';
import { makeStyles, tokens, Button } from '@fluentui/react-components';
import { ALL_APPS } from '../shared/apps.js';

const useStyles = makeStyles({
  header: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
    height: 'calc(env(safe-area-inset-top, 0px) + 60px)',
    paddingTop: 'env(safe-area-inset-top, 0px)',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    backgroundColor: tokens.colorNeutralBackground1,
    borderBottom: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
  },
  headerTitle: {
    // Escala tipográfica ao estilo Google Drive/Docs: título grande,
    // peso mais leve que o Title2 do Fluent, para não parecer um
    // rótulo genérico de componente de biblioteca.
    fontSize: '26px',
    fontWeight: '600',
    letterSpacing: '-0.3px',
    margin: 0,
    color: tokens.colorNeutralForeground1,
  },
  
  root: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 'calc(100% - 60px)',
    paddingTop: '48px',
    paddingBottom: '48px',
    paddingLeft: '36px',
    paddingRight: '36px',
    textAlign: 'center',
  },
  illustration: {
    width: '180px',
    height: '150px',
    marginBottom: tokens.spacingVerticalXL,
  },
  title: {
    fontSize: '22px',
    fontWeight: '700',
    letterSpacing: '-0.3px',
    lineHeight: '1.3',
    color: tokens.colorNeutralForeground1,
    marginBottom: tokens.spacingVerticalS,
    maxWidth: '300px',
  },
  subtitle: {
    fontSize: '15px',
    lineHeight: '1.5',
    color: tokens.colorNeutralForeground3,
    maxWidth: '300px',
    marginBottom: tokens.spacingVerticalXL,
  },
  ctaBtn: {
    borderRadius: tokens.borderRadiusCircular,
    paddingLeft: tokens.spacingHorizontalL,
    paddingRight: tokens.spacingHorizontalL,
    height: '44px',
    fontSize: '15px',
    fontWeight: tokens.fontWeightSemibold,
  },
});

export default function ProjectsTab() {
  const styles = useStyles();
  const navigate = useNavigate();
  
  function handleCreate() {
    try { navigator.vibrate && navigator.vibrate(7); } catch (e) {}
    const firstApp = ALL_APPS[0];
    if (firstApp) navigate(firstApp.path);
  }
  
  return (
    <>
      <div className={styles.header}>
        <h1 className={styles.headerTitle}>Projetos</h1>
      </div>

      <div className={styles.root}>
        <svg className={styles.illustration} viewBox="0 0 180 150" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <rect x="20" y="34" width="140" height="98" rx="16" fill={tokens.colorNeutralBackground3} />
          <rect x="20" y="34" width="140" height="98" rx="16" stroke={tokens.colorNeutralStroke2} strokeWidth="1.5" />
          <rect x="38" y="54" width="76" height="10" rx="5" fill={tokens.colorNeutralStroke1} />
          <rect x="38" y="72" width="104" height="10" rx="5" fill={tokens.colorNeutralStroke1} />
          <rect x="38" y="90" width="60" height="10" rx="5" fill={tokens.colorNeutralStroke1} />
          <rect x="38" y="108" width="88" height="10" rx="5" fill={tokens.colorNeutralStroke1} />
          <circle cx="140" cy="112" r="30" fill={tokens.colorBrandBackground} />
          <path d="M140 99v26M127 112h26" stroke="#fff" strokeWidth="4.5" strokeLinecap="round" />
        </svg>

        <div className={styles.title}>Ainda sem projetos</div>
        <div className={styles.subtitle}>
          Os teus documentos, folhas de cálculo e designs vão aparecer aqui assim que os criares.
        </div>

        <Button
          appearance="primary"
          className={styles.ctaBtn}
          icon={<AddCircle24Filled fontSize={20} />}
          onClick={handleCreate}
        >
          Criar novo
        </Button>
      </div>
    </>
  );
}