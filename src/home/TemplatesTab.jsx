import React from 'react';
import { Grid24Regular } from '@fluentui/react-icons';
import { makeStyles, tokens, Text, Body1 } from '@fluentui/react-components';

const useStyles = makeStyles({
  root: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    paddingTop: '60px',
    paddingBottom: '60px',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    textAlign: 'center',
  },
  icon: {
    color: tokens.colorNeutralForeground3,
    marginBottom: tokens.spacingVerticalL,
  },
  title: {
    marginBottom: tokens.spacingVerticalXS,
  },
  subtitle: {
    color: tokens.colorNeutralForeground3,
    lineHeight: tokens.lineHeightBase300,
  },
});

export default function TemplatesTab() {
  const styles = useStyles();
  return (
    <div className={styles.root}>
      <Grid24Regular fontSize={48} className={styles.icon} />
      <Text weight="bold" size={500} block className={styles.title}>Templates em breve</Text>
      <Body1 block className={styles.subtitle}>
        Modelos prontos a usar para documentos, folhas de cálculo e apresentações vão aparecer aqui.
      </Body1>
    </div>
  );
}