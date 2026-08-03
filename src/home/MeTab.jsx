import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Person24Filled, Settings24Regular, ChevronRight24Regular } from '@fluentui/react-icons';
import { makeStyles, tokens, Text, Caption1, Avatar, Card } from '@fluentui/react-components';

const useStyles = makeStyles({
  root: {
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    paddingTop: tokens.spacingVerticalXXL,
  },
  profileRow: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    paddingTop: tokens.spacingVerticalS,
    paddingBottom: tokens.spacingVerticalXL,
  },
  profileSubtitle: {
    display: 'block',
    marginTop: tokens.spacingVerticalXXS,
    color: tokens.colorNeutralForeground3,
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
  },
  itemLabel: {
    flex: 1,
    textAlign: 'left',
  },
  chevron: {
    color: tokens.colorNeutralForeground3,
  },
});

export default function MeTab() {
  const styles = useStyles();
  const navigate = useNavigate();
  
  return (
    <div className={styles.root}>
      <div className={styles.profileRow}>
        <Avatar icon={<Person24Filled />} size={56} color="brand" />
        <div>
          <Text weight="bold" size={500} block>Utilizador Nexa</Text>
          <Caption1 block className={styles.profileSubtitle}>Ver e editar perfil</Caption1>
        </div>
      </div>

      <Card className={styles.item} onClick={() => navigate('/home/settings')}>
        <Settings24Regular fontSize={22} />
        <Text weight="semibold" className={styles.itemLabel}>Definições</Text>
        <ChevronRight24Regular className={styles.chevron} />
      </Card>
    </div>
  );
}