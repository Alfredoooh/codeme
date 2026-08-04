import React from 'react';
import { useNavigate } from 'react-router-dom';
import {
  ChevronRight24Regular,
  Alert24Regular,
  Settings24Regular,
  QuestionCircle24Regular,
  ArrowExit24Regular,
} from '@fluentui/react-icons';
import {
  makeStyles,
  tokens,
  Avatar,
  Button,
  Title3,
  Subtitle2,
  Caption1,
  Divider,
  Dialog,
  DialogSurface,
  DialogBody,
  DialogTitle,
  DialogContent,
  DialogActions,
} from '@fluentui/react-components';

const useStyles = makeStyles({
  root: {
    paddingTop: 'calc(env(safe-area-inset-top, 0px) + 28px)',
    paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 54px + 88px)',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
  },
  
  // --- Identidade: sem appbar, o avatar grande é o próprio título
  // do ecrã. É a lógica de perfil da Apple/Google — a foto e o
  // nome carregam a função que noutras tabs cabe ao <h1>. ---
  identityBlock: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    textAlign: 'center',
    marginBottom: tokens.spacingVerticalXXL,
    background: 'transparent',
    border: 'none',
    cursor: 'pointer',
    width: '100%',
  },
  avatarBtn: {
    marginBottom: tokens.spacingVerticalM,
    transitionProperty: 'transform',
    transitionDuration: '0.15s',
  },
  name: {
    marginBottom: '2px',
  },
  email: {
    color: tokens.colorNeutralForeground3,
  },
  editRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '2px',
    marginTop: tokens.spacingVerticalXS,
    color: tokens.colorBrandForeground1,
  },
  
  // --- Grupo de definições: hierarquia Fluent — Subtitle2 como
  // rótulo de secção (não caption pequena e apagada), linhas
  // separadas por Divider real do Fluent em vez de borderBottom
  // manual, sem caixa/cartão envolvente — o espaço em torno já
  // separa o grupo do resto, ao estilo Fluent 2 (que usa menos
  // "boxing" que Material). ---
  sectionLabel: {
    display: 'block',
    marginBottom: tokens.spacingVerticalS,
    color: tokens.colorNeutralForeground2,
  },
  group: {
    marginBottom: tokens.spacingVerticalXXL,
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    width: '100%',
    minHeight: '52px',
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    textAlign: 'left',
    padding: 0,
    color: tokens.colorNeutralForeground1,
  },
  rowIcon: {
    color: tokens.colorNeutralForeground2,
    flexShrink: 0,
  },
  rowLabel: {
    flex: 1,
  },
  rowChevron: {
    color: tokens.colorNeutralForeground3,
    flexShrink: 0,
  },
  divider: {
    marginTop: 0,
    marginBottom: 0,
  },
  
  logoutBtn: {
    width: '100%',
    height: '44px',
    borderRadius: tokens.borderRadiusLarge,
  },
});

const SETTINGS_ROWS = [
  { key: 'notifications', icon: Alert24Regular, label: 'Notificações', path: '/home/notifications' },
  { key: 'settings', icon: Settings24Regular, label: 'Definições', path: '/home/settings' },
  { key: 'help', icon: QuestionCircle24Regular, label: 'Ajuda e suporte', path: '/home/settings?section=help' },
];

export default function MeTab({ user }) {
  const styles = useStyles();
  const navigate = useNavigate();
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
    <>
      <div className={styles.root}>
        <button className={styles.identityBlock} onClick={() => navigate('/profile')}>
          <span className={styles.avatarBtn}>
            <Avatar
              image={avatarUrl ? { src: avatarUrl } : undefined}
              name={avatarUrl ? undefined : userInitial}
              size={88}
              style={!avatarUrl ? { backgroundColor: avatarColor, color: '#fff' } : undefined}
            />
          </span>
          <Title3 as="h1" block className={styles.name}>{userName}</Title3>
          {userEmail && <Caption1 block className={styles.email}>{userEmail}</Caption1>}
          <span className={styles.editRow}>
            <Caption1 weight="semibold">Editar perfil</Caption1>
            <ChevronRight24Regular fontSize={14} />
          </span>
        </button>

        <div className={styles.group}>
          <Subtitle2 as="h2" block className={styles.sectionLabel}>Conta</Subtitle2>
          {SETTINGS_ROWS.map((item, i) => {
            const RowIcon = item.icon;
            return (
              <React.Fragment key={item.key}>
                <button className={styles.row} onClick={() => navigate(item.path)}>
                  <RowIcon fontSize={20} className={styles.rowIcon} />
                  <span className={styles.rowLabel}>{item.label}</span>
                  <ChevronRight24Regular fontSize={18} className={styles.rowChevron} />
                </button>
                {i < SETTINGS_ROWS.length - 1 && <Divider className={styles.divider} />}
              </React.Fragment>
            );
          })}
        </div>

        <Button
          className={styles.logoutBtn}
          appearance="outline"
          icon={<ArrowExit24Regular fontSize={18} />}
          onClick={() => setLogoutOpen(true)}
        >
          Terminar sessão
        </Button>
      </div>

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
    </>
  );
}