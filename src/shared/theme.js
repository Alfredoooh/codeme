import { webLightTheme, webDarkTheme } from '@fluentui/react-components';

// Fluent puro: sem paleta de marca custom, sem overrides de token.
// getNexaTheme devolve exatamente webLightTheme ou webDarkTheme sem
// qualquer alteração — o FluentProvider aplica isto globalmente e
// todos os componentes abaixo consomem tokens.* diretamente, por
// isso já não existe getRawColors nenhum: a cor certa para cada
// contexto (fundo, texto, divisor, etc.) vem sempre do token Fluent
// equivalente, que já reage sozinho ao tema ativo.

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