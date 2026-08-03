import React from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ChevronRight24Regular,
  ArrowDownload24Regular,
  Alert24Regular,
  QuestionCircle24Regular,
  Settings24Regular,
  ArrowExit24Regular,
} from '@fluentui/react-icons';
import {
  makeStyles,
  tokens,
  Text,
  Caption1,
  Avatar,
  Switch,
  Button,
  Dialog,
  DialogSurface,
  DialogBody,
  DialogTitle,
  DialogContent,
  DialogActions,
} from '@fluentui/react-components';
import { getStoredThemeMode, setStoredThemeMode, syncThemeMode } from '../shared/theme.js';

const useStyles = makeStyles({
  root: {
    paddingTop: 'calc(env(safe-area-inset-top, 0px) + 4px)',
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
  installRow: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalS,
    width: `calc(100% - ${tokens.spacingHorizontalXXL} * 2)`,
    marginLeft: tokens.spacingHorizontalXXL,
    marginRight: tokens.spacingHorizontalXXL,
    marginBottom: tokens.spacingVerticalL,
    padding: tokens.spacingVerticalM,
    borderRadius: tokens.borderRadiusLarge,
    border: `${tokens.strokeWidthThin} solid ${tokens.colorBrandStroke2}`,
    backgroundColor: tokens.colorBrandBackground2,
    cursor: 'pointer',
  },
  installLabel: {
    color: tokens.colorBrandForeground1,
    fontWeight: tokens.fontWeightSemibold,
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
  },
  rowLabel: {
    flex: 1,
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
  const [isDark, setIsDarkLocal] = React.useState(() => getStoredThemeMode() === 'dark');
  const [logoutOpen, setLogoutOpen] = React.useState(false);
  const [showInstall, setShowInstall] = React.useState(false);
  
  React.useEffect(() => {
    function handler(e) {
      e.preventDefault();
      window.__deferredInstallPrompt = e;
      setShowInstall(true);
    }
    window.addEventListener('beforeinstallprompt', handler);
    return () => window.removeEventListener('beforeinstallprompt', handler);
  }, []);
  
  function toggleDarkMode(checked) {
    setIsDarkLocal(checked);
    setStoredThemeMode(checked ? 'dark' : 'light');
    syncThemeMode(checked);
    window.location.reload();
  }
  
  async function handleInstall() {
    const promptEvent = window.__deferredInstallPrompt;
    if (!promptEvent) return;
    promptEvent.prompt();
    await promptEvent.userChoice;
    window.__deferredInstallPrompt = null;
    setShowInstall(false);
  }
  
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
          color={avatarUrl ? undefined : 'colorful'}
          size={60}
          style={!avatarUrl ? { backgroundColor: avatarColor } : undefined}
        />
        <div className={styles.identity}>
          <Text weight="bold" size={500} block className={styles.name}>{userName}</Text>
          {userEmail && <Caption1 block className={styles.email}>{userEmail}</Caption1>}
        </div>
        <ChevronRight24Regular className={styles.chevron} />
      </button>

      {showInstall && (
        <button className={styles.installRow} onClick={handleInstall}>
          <ArrowDownload24Regular fontSize={22} style={{ color: tokens.colorBrandForeground1 }} />
          <Text className={styles.installLabel}>Instalar app</Text>
        </button>
      )}

      <button className={styles.row} type="button">
        <Settings24Regular fontSize={24} style={{ opacity: isDark ? 1 : 0.85 }} />
        <Text weight="medium" className={styles.rowLabel}>Modo escuro</Text>
        <Switch checked={isDark} onChange={(_, data) => toggleDarkMode(data.checked)} />
      </button>

      <button className={styles.row} onClick={() => navigate('/home/settings?section=notifications')}>
        <Alert24Regular fontSize={24} />
        <Text weight="medium" className={styles.rowLabel}>Notificações</Text>
      </button>

      <button className={styles.row} onClick={() => navigate('/home/settings')}>
        <Settings24Regular fontSize={24} />
        <Text weight="medium" className={styles.rowLabel}>Definições</Text>
      </button>

      <button className={styles.row} onClick={() => navigate('/home/settings?section=help')}>
        <QuestionCircle24Regular fontSize={24} />
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