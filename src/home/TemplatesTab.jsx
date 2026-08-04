import React from 'react';
import { Board24Filled } from '@fluentui/react-icons';
import { makeStyles, tokens, Button } from '@fluentui/react-components';

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
    // Mesma escala tipográfica do ProjectsTab, ao estilo Google
    // Drive/Docs: título grande, peso mais leve que o Title2 do
    // Fluent, para os dois ecrãs terem hierarquia consistente entre si.
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

export default function TemplatesTab() {
  const styles = useStyles();
  
  function handleNotify() {
    try { navigator.vibrate && navigator.vibrate(7); } catch (e) {}
    // Sem lista de templates ligada ainda — placeholder até existir.
  }
  
  return (
    <>
      <div className={styles.header}>
        <h1 className={styles.headerTitle}>Templates</h1>
      </div>

      <div className={styles.root}>
        <svg className={styles.illustration} viewBox="0 0 180 150" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <rect x="16" y="30" width="72" height="58" rx="10" fill={tokens.colorNeutralBackground3} />
          <rect x="16" y="30" width="72" height="58" rx="10" stroke={tokens.colorNeutralStroke2} strokeWidth="1.5" />
          <rect x="28" y="42" width="48" height="7" rx="3.5" fill={tokens.colorNeutralStroke1} />
          <rect x="28" y="56" width="34" height="7" rx="3.5" fill={tokens.colorNeutralStroke1} />

          <rect x="92" y="30" width="72" height="58" rx="10" fill={tokens.colorNeutralBackground3} />
          <rect x="92" y="30" width="72" height="58" rx="10" stroke={tokens.colorNeutralStroke2} strokeWidth="1.5" />
          <rect x="104" y="42" width="48" height="7" rx="3.5" fill={tokens.colorNeutralStroke1} />
          <rect x="104" y="56" width="34" height="7" rx="3.5" fill={tokens.colorNeutralStroke1} />

          <rect x="16" y="94" width="72" height="42" rx="10" fill={tokens.colorNeutralBackground3} />
          <rect x="16" y="94" width="72" height="42" rx="10" stroke={tokens.colorNeutralStroke2} strokeWidth="1.5" />
          <rect x="28" y="106" width="48" height="7" rx="3.5" fill={tokens.colorNeutralStroke1} />

          <rect x="92" y="94" width="72" height="42" rx="10" fill={tokens.colorBrandBackground2} />
          <rect x="92" y="94" width="72" height="42" rx="10" stroke={tokens.colorBrandStroke1} strokeWidth="1.5" />
          <path d="M128 106v18M119 115h18" stroke={tokens.colorBrandForeground1} strokeWidth="3.6" strokeLinecap="round" />
        </svg>

        <div className={styles.title}>Templates em breve</div>
        <div className={styles.subtitle}>
          Modelos prontos a usar para documentos, folhas de cálculo e apresentações vão aparecer aqui.
        </div>

        <Button
          appearance="primary"
          className={styles.ctaBtn}
          icon={<Board24Filled fontSize={20} />}
          onClick={handleNotify}
        >
          Avisa-me quando estiver pronto
        </Button>
      </div>
    </>
  );
}