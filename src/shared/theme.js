import { webLightTheme, webDarkTheme, tokens } from '@fluentui/react-components';

const THEME_STORAGE_KEY = 'nexa_theme';

export function getStoredThemeMode() {
  const saved = localStorage.getItem(THEME_STORAGE_KEY);
  if (saved === 'dark' || saved === 'light') return saved;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function setStoredThemeMode(mode) {
  localStorage.setItem(THEME_STORAGE_KEY, mode);
}

export function syncThemeMode(isDark) {
  setStoredThemeMode(isDark ? 'dark' : 'light');
  const root = document.documentElement;
  root.classList.toggle('dark', isDark);
  root.classList.toggle('light', !isDark);
  document.body.style.background = isDark ? webDarkTheme.colorNeutralBackground1 : webLightTheme.colorNeutralBackground1;
  
  let meta = document.querySelector('meta[name="theme-color"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'theme-color';
    document.head.appendChild(meta);
  }
  meta.setAttribute('content', isDark ? webDarkTheme.colorNeutralBackground1 : webLightTheme.colorNeutralBackground1);
  
  if (window.AndroidTheme && typeof window.AndroidTheme.onThemeChanged === 'function') {
    window.AndroidTheme.onThemeChanged(isDark);
  }
}

export function getNexaTheme(isDark) {
  return isDark ? webDarkTheme : webLightTheme;
}

// Azul "Microsoft" que muda por tema — usado no Svelte original em
// switches, segmented controls e no FAB de logout (#0078D4 no claro,
// #4CC2FF no escuro). No Fluent v9 isto corresponde a
// colorBrandForeground1/colorCompoundBrandBackground consoante o
// tema ativo, por isso aqui expomos como função direta em vez de
// depender do valor de tokens.* (que já muda sozinho com o
// FluentProvider, mas os componentes desta função podem ser usados
// fora de um contexto React puro, como veremos no cálculo de cor
// do avatar).
export function getMsBlue(isDark) {
  return isDark ? '#4CC2FF' : '#0078D4';
}

export function getMsBluePressed(isDark) {
  return isDark ? '#005A9E' : '#005A9E';
}