import React from 'react';
import * as Icons from '@fluentui/react-icons';
import { makeStyles, tokens } from '@fluentui/react-components';

const useStyles = makeStyles({
  root: {
    position: 'fixed',
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 20,
    display: 'flex',
    alignItems: 'stretch',
    justifyContent: 'space-around',
    backgroundColor: tokens.colorNeutralBackground2,
    borderTop: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
    paddingTop: '6px',
    paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 6px)',
    paddingLeft: '6px',
    paddingRight: '6px',
    touchAction: 'pan-y',
    WebkitUserSelect: 'none',
    userSelect: 'none',
  },
  tabBtn: {
    position: 'relative',
    zIndex: 1,
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '2px',
    height: '42px',
    border: 'none',
    background: 'transparent',
    color: tokens.colorNeutralForeground3,
    cursor: 'pointer',
    WebkitTapHighlightColor: 'transparent',
  },
  tabBtnActive: {
    color: tokens.colorBrandForeground1,
  },
  tabIcon: {
    position: 'relative',
    width: '24px',
    height: '24px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    transitionProperty: 'transform',
    transitionDuration: '0.18s',
    transitionTimingFunction: 'cubic-bezier(0.32, 0.72, 0, 1)',
  },
  tabLabel: {
    fontSize: '10px',
    fontWeight: tokens.fontWeightSemibold,
    letterSpacing: '-0.1px',
    opacity: 0.7,
  },
  tabLabelActive: {
    opacity: 1,
    fontWeight: tokens.fontWeightBold,
  },
  avatarWrap: {
    width: '26px',
    height: '26px',
    borderRadius: tokens.borderRadiusCircular,
    overflow: 'hidden',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    border: '1.5px solid transparent',
    transitionProperty: 'border-color',
    transitionDuration: '0.18s',
  },
  avatarWrapActive: {
    borderColor: tokens.colorBrandForeground1,
  },
  avatarImg: {
    width: '100%',
    height: '100%',
    objectFit: 'cover',
    display: 'block',
  },
  avatarInitial: {
    width: '100%',
    height: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: '11px',
    fontWeight: tokens.fontWeightBold,
    color: '#fff',
  },
});

function buzz() {
  try { navigator.vibrate && navigator.vibrate(6); } catch (e) {}
}

export default function BottomTabBar({ tabs, activeTab, onChange, avatarUrl, avatarColor = '#FF3B30', userInitial = 'U' }) {
  const styles = useStyles();
  
  function select(tab) {
    buzz();
    if (tab.id === activeTab) return;
    onChange(tab.id);
  }
  
  return (
    <nav className={styles.root}>
      {tabs.map((tab) => {
        const isActive = activeTab === tab.id;
        const IconComp = !tab.isAvatar ? (Icons[isActive ? tab.iconFilled : tab.icon] || Icons.Circle24Regular) : null;
        return (
          <button
            key={tab.id}
            className={`${styles.tabBtn} ${isActive ? styles.tabBtnActive : ''}`}
            onClick={() => select(tab)}
            aria-label={tab.label}
            aria-current={isActive ? 'page' : undefined}
          >
            <span className={styles.tabIcon}>
              {tab.isAvatar ? (
                <span className={`${styles.avatarWrap} ${isActive ? styles.avatarWrapActive : ''}`}>
                  {avatarUrl ? (
                    <img src={avatarUrl} alt={tab.label} className={styles.avatarImg} />
                  ) : (
                    <span className={styles.avatarInitial} style={{ backgroundColor: avatarColor }}>{userInitial}</span>
                  )}
                </span>
              ) : (
                <IconComp fontSize={24} />
              )}
            </span>
            <span className={`${styles.tabLabel} ${isActive ? styles.tabLabelActive : ''}`}>{tab.label}</span>
          </button>
        );
      })}
    </nav>
  );
}