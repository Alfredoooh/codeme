import React from 'react';
import { Sparkle24Filled } from '@fluentui/react-icons';
import { makeStyles, tokens, Button } from '@fluentui/react-components';

const useStyles = makeStyles({
  fab: {
    position: 'fixed',
    right: tokens.spacingHorizontalL,
    // 42px altura da bottom bar + 6px padding topo + safe-area + folga
    bottom: 'calc(env(safe-area-inset-bottom, 0px) + 42px + 6px + 16px)',
    zIndex: 25,
    width: '56px',
    height: '56px',
    minWidth: '56px',
    borderRadius: tokens.borderRadiusCircular,
    boxShadow: tokens.shadow16,
  },
});

function buzz() {
  try { navigator.vibrate && navigator.vibrate(10); } catch (e) {}
}

export default function AiFab({ onClick }) {
  const styles = useStyles();
  return (
    <Button
      appearance="primary"
      shape="circular"
      size="large"
      className={styles.fab}
      icon={<Sparkle24Filled fontSize={26} />}
      aria-label="Assistente de IA"
      onClick={() => { buzz(); onClick && onClick(); }}
    />
  );
}