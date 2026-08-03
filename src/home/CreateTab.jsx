import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Search24Regular, Alert24Regular } from '@fluentui/react-icons';
import { makeStyles, tokens, Text, Caption1, Card } from '@fluentui/react-components';
import { ALL_APPS } from '../shared/apps.js';

const SKELETON_COUNT = 4;

const useStyles = makeStyles({
  header: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 15,
    height: 'calc(env(safe-area-inset-top, 0px) + 56px)',
    backgroundColor: 'transparent',
    pointerEvents: 'auto',
    overflow: 'hidden',
  },
  headerInner: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: tokens.spacingHorizontalM,
    width: '100%',
    height: '100%',
    maxWidth: '640px',
    margin: '0 auto',
    paddingTop: 'env(safe-area-inset-top, 0px)',
    paddingLeft: tokens.spacingHorizontalL,
    paddingRight: tokens.spacingHorizontalL,
  },
  headerTitle: {
    fontSize: '22px',
    fontWeight: '900',
    letterSpacing: '-0.4px',
    margin: 0,
    flex: 1,
    minWidth: 0,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    color: tokens.colorBrandForeground1,
  },
  headerActions: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalXS,
    flexShrink: 0,
    marginLeft: 'auto',
  },
  iconBtn: {
    position: 'relative',
    width: '40px',
    height: '40px',
    borderRadius: tokens.borderRadiusCircular,
    border: 'none',
    background: 'transparent',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    flexShrink: 0,
    padding: 0,
    color: tokens.colorNeutralForeground1,
    transitionProperty: 'opacity, transform',
    transitionDuration: '0.2s',
  },
  iconBtnHidden: {
    opacity: 0,
    transform: 'scale(0.7)',
    pointerEvents: 'none',
  },
  notifDot: {
    position: 'absolute',
    top: '9px',
    right: '9px',
    width: '8px',
    height: '8px',
    borderRadius: tokens.borderRadiusCircular,
    backgroundColor: tokens.colorPaletteRedBackground3,
    border: `1.5px solid ${tokens.colorNeutralBackground1}`,
  },
  root: {
    width: '100%',
  },
  heroBg: {
    position: 'relative',
    width: '100%',
    paddingTop: 'calc(env(safe-area-inset-top, 0px) + 68px)',
    paddingBottom: tokens.spacingVerticalS,
  },
  searchBar: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalS,
    width: `calc(100% - ${tokens.spacingHorizontalXXL} * 2)`,
    height: '44px',
    marginLeft: tokens.spacingHorizontalXXL,
    marginRight: tokens.spacingHorizontalXXL,
    paddingLeft: tokens.spacingHorizontalM,
    paddingRight: tokens.spacingHorizontalM,
    border: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
    borderRadius: tokens.borderRadiusCircular,
    backgroundColor: tokens.colorNeutralBackground2,
    cursor: 'pointer',
    position: 'relative',
    zIndex: 1,
  },
  searchBarIcon: {
    color: tokens.colorNeutralForeground3,
    flexShrink: 0,
  },
  searchBarPlaceholder: {
    color: tokens.colorNeutralForeground3,
  },
  cardTitle: {
    display: 'block',
    marginTop: '18px',
    marginBottom: tokens.spacingVerticalS,
    marginLeft: tokens.spacingHorizontalXXL,
    marginRight: tokens.spacingHorizontalXXL,
    color: tokens.colorNeutralForeground3,
  },
  appsCard: {
    marginLeft: tokens.spacingHorizontalL,
    marginRight: tokens.spacingHorizontalL,
    padding: tokens.spacingVerticalL,
  },
  appsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: '20px 8px',
  },
  appItem: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: tokens.spacingVerticalS,
    border: 'none',
    background: 'transparent',
    padding: 0,
    cursor: 'pointer',
  },
  appIconWrap: {
    width: '40px',
    height: '40px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    borderRadius: tokens.borderRadiusMedium,
  },
  appIconImg: {
    width: '100%',
    height: '100%',
    objectFit: 'contain',
    display: 'block',
  },
  appLabel: {
    textAlign: 'center',
    maxWidth: '88px',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    display: '-webkit-box',
    WebkitLineClamp: 2,
    WebkitBoxOrient: 'vertical',
  },
  skeletonBlock: {
    position: 'relative',
    overflow: 'hidden',
    backgroundColor: tokens.colorNeutralBackground3,
    borderRadius: tokens.borderRadiusMedium,
  },
  recentSection: {
    marginTop: '28px',
  },
  recentSectionHead: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    paddingBottom: tokens.spacingVerticalM,
  },
  recentCta: {
    color: tokens.colorBrandForeground1,
  },
  recentRow: {
    display: 'flex',
    gap: tokens.spacingHorizontalM,
    overflowX: 'auto',
    WebkitOverflowScrolling: 'touch',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
  },
  recentCard: {
    flex: '0 0 auto',
    width: '132px',
    display: 'flex',
    flexDirection: 'column',
    gap: tokens.spacingVerticalXS,
    border: 'none',
    background: 'transparent',
    padding: 0,
    textAlign: 'left',
    cursor: 'pointer',
  },
  recentThumb: {
    width: '132px',
    height: '132px',
    borderRadius: tokens.borderRadiusXLarge,
    overflow: 'hidden',
    backgroundColor: tokens.colorNeutralBackground3,
    border: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
    flexShrink: 0,
  },
  recentThumbImg: {
    width: '100%',
    height: '100%',
    objectFit: 'cover',
    display: 'block',
  },
  recentCardTime: {
    color: tokens.colorNeutralForeground3,
  },
  emptyState: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    textAlign: 'center',
    paddingTop: tokens.spacingVerticalXL,
    paddingBottom: tokens.spacingVerticalS,
    paddingLeft: '32px',
    paddingRight: '32px',
  },
  emptyIllustration: {
    width: '120px',
    height: '100px',
    marginBottom: tokens.spacingVerticalM,
  },
  emptyTitle: {
    marginBottom: tokens.spacingVerticalXXS,
  },
  emptyText: {
    color: tokens.colorNeutralForeground3,
    maxWidth: '260px',
  },
});

function buzz() {
  try { navigator.vibrate && navigator.vibrate(6); } catch (e) {}
}

function timeAgo(updatedAt) {
  if (!updatedAt) return '';
  const then = new Date(updatedAt).getTime();
  if (Number.isNaN(then)) return '';
  const diffMs = Date.now() - then;
  const min = Math.floor(diffMs / 60000);
  if (min < 1) return 'agora';
  if (min < 60) return `há ${min} min`;
  const h = Math.floor(min / 60);
  if (h < 24) return `há ${h}h`;
  const d = Math.floor(h / 24);
  if (d < 7) return `há ${d}d`;
  const w = Math.floor(d / 7);
  return `há ${w}sem`;
}

// recentProjects fica a null (estado "a carregar" → skeleton) até
// existir uma fonte de dados real. Assim que houver um endpoint ou
// storage local para projetos, troca este valor por esse resultado
// e o componente já sabe desenhar tudo sozinho (skeleton → lista →
// estado vazio, exatamente como no Svelte original).
const MOCK_RECENT_PROJECTS = null;

export default function CreateTab({ scrollContainerRef }) {
  const styles = useStyles();
  const navigate = useNavigate();
  const [heroProgress, setHeroProgress] = React.useState(0);
  const recentProjects = MOCK_RECENT_PROJECTS;

  // heroProgress: 0 quando a search bar do hero está totalmente
  // visível, 1 quando já saiu do ecrã pelo scroll — controla o
  // encolher/opacidade da search bar e o aparecimento do botão de
  // pesquisa no header fixo. Calculado a partir do scroll do
  // container pai (o mesmo <div> que já faz overflowY: auto no
  // HomeShell), medido em ~80px de curso total.
  React.useEffect(() => {
    const el = scrollContainerRef?.current;
    if (!el) return;
    function onScroll() {
      const progress = Math.min(1, Math.max(0, el.scrollTop / 80));
      setHeroProgress(progress);
    }
    el.addEventListener('scroll', onScroll, { passive: true });
    return () => el.removeEventListener('scroll', onScroll);
  }, [scrollContainerRef]);

  const searchBarOpacity = 1 - heroProgress;
  const searchBarScale = 1 - 0.08 * heroProgress;
  const searchBarInert = heroProgress > 0.9;
  const searchBtnVisible = searchBarOpacity <= 0;

  function handleOpenSearch() {
    buzz();
    // Sem página de pesquisa dedicada ainda — placeholder até existir.
  }

  function handleNotifications() {
    buzz();
    navigate('/home/notifications');
  }

  function openApp(app) {
    try { navigator.vibrate && navigator.vibrate(7); } catch (e) {}
    navigate(app.path);
  }

  function openProject(p) {
    try { navigator.vibrate && navigator.vibrate(7); } catch (e) {}
    // Sem rota de projeto individual ainda — placeholder até existir.
  }

  return (
    <>
      <div className={styles.header}>
        <div className={styles.headerInner}>
          <h1 className={styles.headerTitle}>Criar</h1>
          <div className={styles.headerActions}>
            <button
              className={`${styles.iconBtn} ${!searchBtnVisible ? styles.iconBtnHidden : ''}`}
              tabIndex={searchBtnVisible ? 0 : -1}
              aria-hidden={!searchBtnVisible}
              onClick={handleOpenSearch}
              aria-label="Pesquisar"
            >
              <Search24Regular fontSize={21} />
            </button>
            <button className={styles.iconBtn} onClick={handleNotifications} aria-label="Notificações">
              <Alert24Regular fontSize={21} />
              <span className={styles.notifDot} />
            </button>
          </div>
        </div>
      </div>

      <div className={styles.root}>
        <div className={styles.heroBg}>
          <button
            className={styles.searchBar}
            style={{
              opacity: searchBarOpacity,
              transform: `scale(${searchBarScale})`,
              pointerEvents: searchBarInert ? 'none' : 'auto',
            }}
            onClick={handleOpenSearch}
          >
            <Search24Regular fontSize={17} className={styles.searchBarIcon} />
            <Caption1 className={styles.searchBarPlaceholder}>Pesquisar designs, projetos, modelos…</Caption1>
          </button>
        </div>

        <Caption1 block weight="semibold" className={styles.cardTitle}>Comece a criar com</Caption1>
        <Card className={styles.appsCard}>
          <div className={styles.appsGrid}>
            {ALL_APPS.map((app) => (
              <button key={app.id} className={styles.appItem} onClick={() => openApp(app)}>
                <span className={styles.appIconWrap} style={{ backgroundColor: app.color + '26' }}>
                  <img src={app.iconPath} alt={app.label} className={styles.appIconImg} />
                </span>
                <Caption1 className={styles.appLabel}>{app.label}</Caption1>
              </button>
            ))}
          </div>
        </Card>

        {recentProjects === null && (
          <div className={styles.recentSection}>
            <div className={styles.recentSectionHead}>
              <div className={styles.skeletonBlock} style={{ width: '160px', height: '17px' }} />
            </div>
            <div className={styles.recentRow}>
              {Array.from({ length: SKELETON_COUNT }).map((_, i) => (
                <div key={i} className={styles.recentCard}>
                  <div className={styles.recentThumb} />
                  <div className={styles.skeletonBlock} style={{ width: '70%', height: '11px' }} />
                  <div className={styles.skeletonBlock} style={{ width: '45%', height: '11px' }} />
                </div>
              ))}
            </div>
          </div>
        )}

        {recentProjects !== null && recentProjects.length > 0 && (
          <div className={styles.recentSection}>
            <div className={styles.recentSectionHead}>
              <Text weight="semibold" size={400}>Continue a criar designs</Text>
              <Caption1 className={styles.recentCta}>Ver tudo</Caption1>
            </div>
            <div className={styles.recentRow}>
              {recentProjects.map((p) => (
                <button key={p.id} className={styles.recentCard} onClick={() => openProject(p)}>
                  <div className={styles.recentThumb}>
                    {p.thumbnail ? (
                      <img src={p.thumbnail} alt={p.title} loading="lazy" className={styles.recentThumbImg} />
                    ) : (
                      <div style={{ width: '100%', height: '100%', backgroundColor: p.color || tokens.colorNeutralBackground3 }} />
                    )}
                  </div>
                  <Text weight="semibold" size={300}>{p.title}</Text>
                  {p.updatedAt && <Caption1 className={styles.recentCardTime}>{timeAgo(p.updatedAt)}</Caption1>}
                </button>
              ))}
            </div>
          </div>
        )}

        {recentProjects !== null && recentProjects.length === 0 && (
          <div className={styles.recentSection}>
            <div className={styles.emptyState}>
              <svg className={styles.emptyIllustration} viewBox="0 0 120 100" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <rect x="14" y="18" width="70" height="54" rx="10" fill={tokens.colorNeutralBackground3} />
                <rect x="14" y="18" width="70" height="54" rx="10" stroke={tokens.colorNeutralStroke2} strokeWidth="1.5" />
                <rect x="26" y="32" width="46" height="6" rx="3" fill={tokens.colorNeutralStroke1} />
                <rect x="26" y="44" width="34" height="6" rx="3" fill={tokens.colorNeutralStroke1} />
                <rect x="26" y="56" width="24" height="6" rx="3" fill={tokens.colorNeutralStroke1} />
                <circle cx="92" cy="66" r="20" fill={tokens.colorBrandBackground} />
                <path d="M92 57v18M83 66h18" stroke="#fff" strokeWidth="3.4" strokeLinecap="round" />
              </svg>
              <Text weight="semibold" block className={styles.emptyTitle}>Ainda sem criações recentes</Text>
              <Caption1 block className={styles.emptyText}>Os teus projetos vão aparecer aqui assim que começares a criar.</Caption1>
            </div>
          </div>
        )}
      </div>
    </>
  );
}