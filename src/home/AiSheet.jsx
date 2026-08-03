import React from 'react';
import { Dismiss24Regular, Sparkle24Filled } from '@fluentui/react-icons';
import {
  makeStyles,
  tokens,
  Drawer,
  DrawerHeader,
  DrawerHeaderTitle,
  DrawerBody,
  Button,
  Text,
  Body1,
} from '@fluentui/react-components';

const useStyles = makeStyles({
  drawer: {
    maxWidth: '100%',
    height: '78vh',
    borderTopLeftRadius: tokens.borderRadiusXLarge,
    borderTopRightRadius: tokens.borderRadiusXLarge,
  },
  body: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
    textAlign: 'center',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
  },
  icon: {
    color: tokens.colorBrandForeground1,
    marginBottom: tokens.spacingVerticalL,
  },
  subtitle: {
    color: tokens.colorNeutralForeground3,
  },
});

export default function AiSheet({ open, onOpenChange }) {
  const styles = useStyles();
  
  return (
    <Drawer
      className={styles.drawer}
      separator
      open={open}
      onOpenChange={(_, data) => onOpenChange(data.open)}
      position="bottom"
    >
      <DrawerHeader>
        <DrawerHeaderTitle
          action={
            <Button
              appearance="subtle"
              icon={<Dismiss24Regular />}
              onClick={() => onOpenChange(false)}
              aria-label="Fechar"
            />
          }
        >
          Assistente de IA
        </DrawerHeaderTitle>
      </DrawerHeader>
      <DrawerBody>
        <div className={styles.body}>
          <Sparkle24Filled fontSize={48} className={styles.icon} />
          <Text weight="bold" size={500} block>Pergunta qualquer coisa</Text>
          <Body1 block className={styles.subtitle}>
            O assistente de IA está a ser construído nesta base React. Em breve vais poder conversar aqui.
          </Body1>
        </div>
      </DrawerBody>
    </Drawer>
  );
}