import React from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ChevronRight24Regular,
  WeatherSunny24Regular,
  WeatherMoon24Regular,
  Alert24Regular,
  Settings24Regular,
  QuestionCircle24Regular,
  ArrowExit24Regular,
} from '@fluentui/react-icons';
import {
  makeStyles,
  tokens,
  Text,
  Caption1,
  Avatar,
  Button,
  Dialog,
  DialogSurface,
  DialogBody,
  DialogTitle,
  DialogContent,
  DialogActions,
} from '@fluentui/react-components';
import { getStoredThemeMode } from '../shared/theme.js';

const useStyles = makeStyles({
  root: {
    paddingTop: 'calc(env(safe-area-inset-top, 0px) + 20px)',
    paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 54px + 88px)',
  },
  avatarBlock: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    width: '100%',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    marginBottom: tokens.spacingVerticalXL,
    background: 'transparent',
    border: 'none',
    cursor: 'pointer',
    textAlign: 'left',
  },
  identity: {
    flex: 1,
    minWidth: 0,
  },
  name: {
    color: tokens.colorNeutralForeground1,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
  },
  email: {
    display: 'block',
    marginTop: '2px',
    color: tokens.colorNeutralForeground3,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
  },
  chevron: {
    color: tokens.colorNeutralForeground3,
    flexShrink: 0,
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    width: '100%',
    minHeight: '58px',
    paddingTop: tokens.spacingVerticalS,
    paddingBottom: tokens.spacingVerticalS,
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    textAlign: 'left',
    color: tokens.colorNeutralForeground1,
  },
  rowIcon: {
    color: tokens.colorNeutralForeground1,
    flexShrink: 0,
  },
  rowLabel: {
    flex: 1,
    color: tokens.colorNeutralForeground1,
  },
  logoutFab: {
    position: 'fixed',
    left: tokens.spacingHorizontalL,
    right: tokens.spacingHorizontalL,
    bottom: 'calc(env(safe-area-inset-bottom, 0px) + 54px + 14px)',
    zIndex: 10,
    width: 'auto',
  },
});

export default function MeTab({ user }) {
  const styles = useStyles();
  const navigate = useNavigate();
  const isDark = getStoredThemeMode() === 'dark';
  const [logoutOpen, setLogoutOpen] = React.useState(false);
  
  function confirmLogout() {
    setLogoutOpen(false);
    if (window.AndroidSession) window.AndroidSession.onLogout();
    navigate('/auth');
  }
  
  const avatarUrl = user?.avatarUrl || '';
  const userName = user?.name || 'Utilizador';
  const userEmail = user?.email || '';
  const userInitial = user?.initial || 'U';
  const avatarColor = user?.avatarColor || '#FF3B30';
  
  return (
    <div className={styles.root}>
      <button className={styles.avatarBlock} onClick={() => navigate('/profile')}>
        <Avatar
          image={avatarUrl ? { src: avatarUrl } : undefined}
          name={avatarUrl ? undefined : userInitial}
          size={60}
          style={!avatarUrl ? { backgroundColor: avatarColor, color: '#fff' } : undefined}
        />
        <div className={styles.identity}>
          <Text weight="bold" size={500} block className={styles.name}>{userName}</Text>
          {userEmail && <Caption1 block className={styles.email}>{userEmail}</Caption1>}
        </div>
        <ChevronRight24Regular className={styles.chevron} />
      </button>

      <button className={styles.row} onClick={() => navigate('/home/settings')}>
        {isDark ? <WeatherMoon24Regular className={styles.rowIcon} fontSize={24} /> : <WeatherSunny24Regular className={styles.rowIcon} fontSize={24} />}
        <Text weight="medium" className={styles.rowLabel}>Modo escuro</Text>
      </button>

      <button className={styles.row} onClick={() => navigate('/home/notifications')}>
        <Alert24Regular className={styles.rowIcon} fontSize={24} />
        <Text weight="medium" className={styles.rowLabel}>Notificações</Text>
      </button>

      <button className={styles.row} onClick={() => navigate('/home/settings')}>
        <Settings24Regular className={styles.rowIcon} fontSize={24} />
        <Text weight="medium" className={styles.rowLabel}>Definições</Text>
      </button>

      <button className={styles.row} onClick={() => navigate('/home/settings?section=help')}>
        <QuestionCircle24Regular className={styles.rowIcon} fontSize={24} />
        <Text weight="medium" className={styles.rowLabel}>Ajuda e suporte</Text>
      </button>

      <Button
        className={styles.logoutFab}
        appearance="primary"
        shape="circular"
        icon={<ArrowExit24Regular />}
        onClick={() => setLogoutOpen(true)}
      >
        Terminar sessão
      </Button>

      <Dialog open={logoutOpen} onOpenChange={(_, data) => setLogoutOpen(data.open)}>
        <DialogSurface>
          <DialogBody>
            <DialogTitle>Terminar sessão</DialogTitle>
            <DialogContent>Tens a certeza que queres terminar sessão?</DialogContent>
            <DialogActions>
              <Button appearance="secondary" onClick={() => setLogoutOpen(false)}>Cancelar</Button>
              <Button appearance="primary" onClick={confirmLogout}>Terminar</Button>
            </DialogActions>
          </DialogBody>
        </DialogSurface>
      </Dialog>
    </div>
  );
}