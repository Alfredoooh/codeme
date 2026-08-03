import React from 'react';
import * as Icons from '@fluentui/react-icons';
import { makeStyles, tokens } from '@fluentui/react-components';

const useStyles = makeStyles({
  root: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'stretch',
    justifyContent: 'space-around',
    backgroundColor: tokens.colorNeutralBackground2,
    borderTop: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
    paddingTop: tokens.spacingVerticalSNudge,
    paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 6px)',
    paddingLeft: tokens.spacingHorizontalXS,
    paddingRight: tokens.spacingHorizontalXS,
  },
  tabButton: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '3px',
    paddingTop: tokens.spacingVerticalSNudge,
    paddingBottom: tokens.spacingVerticalSNudge,
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    color: tokens.colorNeutralForeground3,
    transitionProperty: 'color',
    transitionDuration: tokens.durationFaster,
    transitionTimingFunction: tokens.curveEasyEase,
  },
  tabButtonActive: {
    color: tokens.colorBrandForeground1,
  },
  label: {
    fontSize: tokens.fontSizeBase200,
    fontWeight: tokens.fontWeightRegular,
  },
  labelActive: {
    fontWeight: tokens.fontWeightSemibold,
  },
});

export default function BottomTabBar({ tabs, activeTab, onChange }) {
  const styles = useStyles();
  return (
    <div className={styles.root}>
      {tabs.map((tab) => {
        const isActive = activeTab === tab.id;
        const IconComp = Icons[isActive ? tab.iconFilled : tab.icon] || Icons.Circle24Regular;
        return (
          <button
            key={tab.id}
            onClick={() => onChange(tab.id)}
            className={`${styles.tabButton} ${isActive ? styles.tabButtonActive : ''}`}
          >
            <IconComp fontSize={24} />
            <span className={`${styles.label} ${isActive ? styles.labelActive : ''}`}>{tab.label}</span>
          </button>
        );
      })}
    </div>
  );
}