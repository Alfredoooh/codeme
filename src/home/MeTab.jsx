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
  Dialog,
  DialogSurface,
  DialogBody,
  DialogTitle,
  DialogContent,
  DialogActions,
} from '@fluentui/react-components';

const useStyles = makeStyles({
  header: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
    height: 'calc(env(safe-area-inset-top, 0px) + 60px)',
    paddingTop: 'env(safe-area-inset-top, 0px)',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    backgroundColor: tokens.colorNeutralBackground1,
    borderBottom: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
  },
  headerTitle: {
    // Mesma escala tipográfica dos outros ecrãs (Projects, Templates):
    // título grande, peso 600, para consistência entre todas as tabs.
    fontSize: '26px',
    fontWeight: '600',
    letterSpacing: '-0.3px',
    margin: 0,
    color: tokens.colorNeutralForeground1,
  },
  
  root: {
    paddingTop: tokens.spacingVerticalXL,
    paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 54px + 88px)',
    paddingLeft: tokens.spacingHorizontalL,
    paddingRight: tokens.spacingHorizontalL,
  },
  
  // --- Bloco de identidade: cartão próprio, não texto solto ---
  identityCard: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    width: '100%',
    padding: tokens.spacingVerticalM,
    marginBottom: tokens.spacingVerticalXL,
    borderRadius: tokens.borderRadiusXLarge,
    backgroundColor: tokens.colorNeutralBackground1,
    boxShadow: tokens.shadow4,
    background: 'transparent',
    border: 'none',
    cursor: 'pointer',
    textAlign: 'left',
    transitionProperty: 'transform',
    transitionDuration: '0.15s',
    ':active': {
      transform: 'scale(0.98)',
    },
  },
  identity: {
    flex: 1,
    minWidth: 0,
  },
  name: {
    fontSize: '17px',
    fontWeight: '700',
    letterSpacing: '-0.2px',
    color: tokens.colorNeutralForeground1,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    display: 'block',
  },
  email: {
    fontSize: '13px',
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
  
  // --- Grupo de definições: cartão único com linhas separadas por
  // divisórias internas, ao estilo Android Settings / Google Account,
  // em vez de botões soltos flutuando no fundo. ---
  sectionLabel: {
    fontSize: '12px',
    fontWeight: tokens.fontWeightBold,
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
    color: tokens.colorNeutralForeground3,
    marginBottom: tokens.spacingVerticalS,
    marginLeft: tokens.spacingHorizontalXS,
  },
  group: {
    borderRadius: tokens.borderRadiusXLarge,
    backgroundColor: tokens.colorNeutralBackground1,
    boxShadow: tokens.shadow4,
    overflow: 'hidden',
    marginBottom: tokens.spacingVerticalXL,
  },
  row: {
    display: 'flex',
    alignItems: 'center',
    gap: tokens.spacingHorizontalM,
    width: '100%',
    minHeight: '56px',
    paddingTop: tokens.spacingVerticalS,
    paddingBottom: tokens.spacingVerticalS,
    paddingLeft: tokens.spacingHorizontalM,
    paddingRight: tokens.spacingHorizontalM,
    border: 'none',
    borderBottom: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
    background: 'transparent',
    cursor: 'pointer',
    textAlign: 'left',
    color: tokens.colorNeutralForeground1,
    ':active': {
      backgroundColor: tokens.colorNeutralBackground3,
    },
  },
  rowLast: {
    borderBottom: 'none',
  },
  rowIconWrap: {
    width: '32px',
    height: '32px',
    borderRadius: tokens.borderRadiusMedium,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    backgroundColor: tokens.colorNeutralBackground3,
    color: tokens.colorNeutralForeground2,
  },
  rowLabel: {
    flex: 1,
    fontSize: '15px',
    fontWeight: '500',
    color: tokens.colorNeutralForeground1,
  },
  rowChevron: {
    color: tokens.colorNeutralForeground3,
    flexShrink: 0,
  },
  
  logoutBtn: {
    width: '100%',
    height: '48px',
    borderRadius: tokens.borderRadiusXLarge,
    fontSize: '15px',
    fontWeight: tokens.fontWeightSemibold,
  },
});

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
      <div className={styles.header}>
        <h1 className={styles.headerTitle}>Eu</h1>
      </div>

      <div className={styles.root}>
        <button className={styles.identityCard} onClick={() => navigate('/profile')}>
          <Avatar
            image={avatarUrl ? { src: avatarUrl } : undefined}
            name={avatarUrl ? undefined : userInitial}
            size={56}
            style={!avatarUrl ? { backgroundColor: avatarColor, color: '#fff' } : undefined}
          />
          <div className={styles.identity}>
            <span className={styles.name}>{userName}</span>
            {userEmail && <span className={styles.email}>{userEmail}</span>}
          </div>
          <ChevronRight24Regular className={styles.chevron} />
        </button>

        <div className={styles.sectionLabel}>Conta</div>
        <div className={styles.group}>
          <button className={styles.row} onClick={() => navigate('/home/notifications')}>
            <span className={styles.rowIconWrap}>
              <Alert24Regular fontSize={18} />
            </span>
            <span className={styles.rowLabel}>Notificações</span>
            <ChevronRight24Regular fontSize={18} className={styles.rowChevron} />
          </button>

          <button className={styles.row} onClick={() => navigate('/home/settings')}>
            <span className={styles.rowIconWrap}>
              <Settings24Regular fontSize={18} />
            </span>
            <span className={styles.rowLabel}>Definições</span>
            <ChevronRight24Regular fontSize={18} className={styles.rowChevron} />
          </button>

          <button className={`${styles.row} ${styles.rowLast}`} onClick={() => navigate('/home/settings?section=help')}>
            <span className={styles.rowIconWrap}>
              <QuestionCircle24Regular fontSize={18} />
            </span>
            <span className={styles.rowLabel}>Ajuda e suporte</span>
            <ChevronRight24Regular fontSize={18} className={styles.rowChevron} />
          </button>
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