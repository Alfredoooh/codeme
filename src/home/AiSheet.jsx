import React from 'react';
import { Dismiss24Regular, Sparkle24Filled, ArrowUp24Filled } from '@fluentui/react-icons';
import { makeStyles, tokens, Textarea } from '@fluentui/react-components';

const useStyles = makeStyles({
  backdrop: {
    position: 'fixed',
    inset: 0,
    zIndex: 40,
    backgroundColor: 'rgba(0,0,0,0.4)',
    transitionProperty: 'opacity',
    transitionDuration: '0.28s',
    transitionTimingFunction: 'ease-out',
  },
  backdropHidden: {
    opacity: 0,
    pointerEvents: 'none',
  },
  backdropVisible: {
    opacity: 1,
  },
  sheet: {
    position: 'fixed',
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 41,
    maxWidth: '640px',
    marginLeft: 'auto',
    marginRight: 'auto',
    height: '82vh',
    maxHeight: '760px',
    display: 'flex',
    flexDirection: 'column',
    backgroundColor: tokens.colorNeutralBackground1,
    borderTopLeftRadius: '20px',
    borderTopRightRadius: '20px',
    boxShadow: tokens.shadow64,
    willChange: 'transform',
    transitionProperty: 'transform',
    transitionDuration: '0.38s',
    transitionTimingFunction: 'cubic-bezier(0.32, 0.72, 0, 1)',
    touchAction: 'none',
  },
  sheetClosed: {
    transform: 'translateY(100%)',
  },
  sheetOpen: {
    transform: 'translateY(0)',
  },
  sheetDragging: {
    transitionProperty: 'none',
  },
  grabberRow: {
    display: 'flex',
    justifyContent: 'center',
    paddingTop: '10px',
    paddingBottom: '6px',
    flexShrink: 0,
    cursor: 'grab',
    touchAction: 'none',
  },
  grabber: {
    width: '36px',
    height: '4px',
    borderRadius: tokens.borderRadiusCircular,
    backgroundColor: tokens.colorNeutralStroke1,
  },
  headerRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'flex-end',
    paddingLeft: tokens.spacingHorizontalM,
    paddingRight: tokens.spacingHorizontalM,
    paddingBottom: tokens.spacingVerticalXS,
    flexShrink: 0,
  },
  closeBtn: {
    width: '32px',
    height: '32px',
    borderRadius: tokens.borderRadiusCircular,
    border: 'none',
    background: tokens.colorNeutralBackground3,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    color: tokens.colorNeutralForeground1,
    flexShrink: 0,
  },
  body: {
    flex: 1,
    minHeight: 0,
    overflowY: 'auto',
    WebkitOverflowScrolling: 'touch',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    textAlign: 'center',
    paddingLeft: tokens.spacingHorizontalXXL,
    paddingRight: tokens.spacingHorizontalXXL,
    gap: tokens.spacingVerticalM,
  },
  bodyIcon: {
    width: '56px',
    height: '56px',
    borderRadius: tokens.borderRadiusCircular,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: '#fff',
    backgroundImage: `linear-gradient(135deg, ${tokens.colorBrandBackground}, ${tokens.colorPalettePurpleBackground3})`,
  },
  bodyPrompt: {
    fontSize: '17px',
    fontWeight: tokens.fontWeightSemibold,
    color: tokens.colorNeutralForeground1,
    maxWidth: '280px',
    lineHeight: '1.35',
  },
  inputRow: {
    flexShrink: 0,
    display: 'flex',
    alignItems: 'flex-end',
    gap: tokens.spacingHorizontalS,
    paddingLeft: tokens.spacingHorizontalM,
    paddingRight: tokens.spacingHorizontalM,
    paddingTop: tokens.spacingVerticalS,
    paddingBottom: 'calc(env(safe-area-inset-bottom, 0px) + 12px)',
    borderTop: `${tokens.strokeWidthThin} solid ${tokens.colorNeutralStroke2}`,
  },
  textarea: {
    flex: 1,
    minWidth: 0,
    maxHeight: '120px',
  },
  sendBtn: {
    width: '38px',
    height: '38px',
    minWidth: '38px',
    borderRadius: tokens.borderRadiusCircular,
    border: 'none',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    color: '#fff',
    backgroundColor: tokens.colorBrandBackground,
    flexShrink: 0,
    transitionProperty: 'opacity, transform',
    transitionDuration: '0.15s',
  },
  sendBtnDisabled: {
    opacity: 0.4,
    pointerEvents: 'none',
  },
});

const DRAG_DISMISS_THRESHOLD = 120;

function buzz(ms = 6) {
  try { navigator.vibrate && navigator.vibrate(ms); } catch (e) {}
}

export default function AiSheet({ open, onOpenChange }) {
  const styles = useStyles();
  const [mounted, setMounted] = React.useState(open);
  const [animatedIn, setAnimatedIn] = React.useState(false);
  const [message, setMessage] = React.useState('');
  const [dragY, setDragY] = React.useState(0);
  const [dragging, setDragging] = React.useState(false);
  const dragStartY = React.useRef(0);
  const sheetRef = React.useRef(null);

  // mounted controla presença no DOM; animatedIn controla a classe
  // que dispara a transição CSS. Separar os dois é o que permite
  // animar tanto a entrada como a saída (senão o unmount é instantâneo
  // e a transição de saída nunca chega a correr).
  React.useEffect(() => {
    if (open) {
      setMounted(true);
      // Um frame depois do mount, para o browser já ter pintado o
      // estado "fechado" antes de aplicarmos "aberto" — é isto que
      // faz a transição correr em vez de saltar direto ao fim.
      requestAnimationFrame(() => requestAnimationFrame(() => setAnimatedIn(true)));
    } else {
      setAnimatedIn(false);
    }
  }, [open]);

  function handleTransitionEnd() {
    if (!open) {
      setMounted(false);
      setDragY(0);
    }
  }

  // Bloqueia o scroll do body por trás do sheet enquanto está aberto,
  // como um bottom sheet nativo faz.
  React.useEffect(() => {
    if (!mounted) return;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { document.body.style.overflow = prevOverflow; };
  }, [mounted]);

  function close() {
    buzz();
    onOpenChange(false);
  }

  function handleDragStart(clientY) {
    dragStartY.current = clientY;
    setDragging(true);
  }

  function handleDragMove(clientY) {
    const delta = clientY - dragStartY.current;
    setDragY(Math.max(0, delta));
  }

  function handleDragEnd() {
    setDragging(false);
    if (dragY > DRAG_DISMISS_THRESHOLD) {
      close();
    } else {
      setDragY(0);
    }
  }

  function onGrabberTouchStart(e) {
    handleDragStart(e.touches[0].clientY);
  }
  function onGrabberTouchMove(e) {
    handleDragMove(e.touches[0].clientY);
  }
  function onGrabberTouchEnd() {
    handleDragEnd();
  }
  function onGrabberMouseDown(e) {
    handleDragStart(e.clientY);
    function onMove(ev) { handleDragMove(ev.clientY); }
    function onUp() {
      handleDragEnd();
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
    }
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  }

  function handleSend() {
    if (!message.trim()) return;
    buzz(8);
    // Sem backend de chat ligado ainda — placeholder até existir.
    setMessage('');
  }

  function handleKeyDown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }

  if (!mounted) return null;

  const isOpenState = animatedIn && open;
  const transform = dragging || dragY > 0
    ? `translateY(${dragY}px)`
    : undefined;

  return (
    <>
      <div
        className={`${styles.backdrop} ${isOpenState ? styles.backdropVisible : styles.backdropHidden}`}
        onClick={close}
      />
      <div
        ref={sheetRef}
        className={`${styles.sheet} ${isOpenState ? styles.sheetOpen : styles.sheetClosed} ${dragging ? styles.sheetDragging : ''}`}
        style={transform ? { transform } : undefined}
        onTransitionEnd={handleTransitionEnd}
        role="dialog"
        aria-modal="true"
      >
        <div
          className={styles.grabberRow}
          onTouchStart={onGrabberTouchStart}
          onTouchMove={onGrabberTouchMove}
          onTouchEnd={onGrabberTouchEnd}
          onMouseDown={onGrabberMouseDown}
        >
          <div className={styles.grabber} />
        </div>

        <div className={styles.headerRow}>
          <button className={styles.closeBtn} onClick={close} aria-label="Fechar">
            <Dismiss24Regular fontSize={16} />
          </button>
        </div>

        <div className={styles.body}>
          <div className={styles.bodyIcon}>
            <Sparkle24Filled fontSize={28} />
          </div>
          <div className={styles.bodyPrompt}>Pergunta qualquer coisa ou pede para criar algo</div>
        </div>

        <div className={styles.inputRow}>
          <Textarea
            className={styles.textarea}
            value={message}
            onChange={(_, data) => setMessage(data.value)}
            onKeyDown={handleKeyDown}
            placeholder="Escreve uma mensagem…"
            resize="none"
            rows={1}
          />
          <button
            className={`${styles.sendBtn} ${!message.trim() ? styles.sendBtnDisabled : ''}`}
            onClick={handleSend}
            aria-label="Enviar"
          >
            <ArrowUp24Filled fontSize={18} />
          </button>
        </div>
      </div>
    </>
  );
}