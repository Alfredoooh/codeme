import { webLightTheme, webDarkTheme } from '@fluentui/react-components';

// Camada fina por cima dos temas base do Fluent UI v9. Mantém os
// mesmos nomes de conceito que já existem em shared/theme.js da
// versão Svelte (getThemeColors, isDark, persistência em
// localStorage) para a migração ficar mentalmente 1:1 com o que já
// conheces daquele projeto, mas devolvendo objetos "theme" do Fluent
// em vez de mapas de variáveis CSS.

const THEME_STORAGE_KEY = 'nexa_theme';

export function getStoredThemeMode() {
  const saved = localStorage.getItem(THEME_STORAGE_KEY);
  if (saved === 'dark' || saved === 'light') return saved;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function setStoredThemeMode(mode) {
  localStorage.setItem(THEME_STORAGE_KEY, mode);
}

// Aplica a cor de fundo/status bar e sincroniza a classe no <html>,
// espelhando syncTheme() da versão Svelte (mesmo objetivo: manter a
// barra de estado do Android/iOS coerente com o tema ativo).
export function syncThemeMode(isDark) {
  setStoredThemeMode(isDark ? 'dark' : 'light');
  const root = document.documentElement;
  root.classList.toggle('dark', isDark);
  root.classList.toggle('light', !isDark);
  document.body.style.background = isDark ? '#0F0F0F' : '#FFFFFF';

  let meta = document.querySelector('meta[name="theme-color"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'theme-color';
    document.head.appendChild(meta);
  }
  meta.setAttribute('content', isDark ? '#0F0F0F' : '#FFFFFF');

  if (window.AndroidTheme && typeof window.AndroidTheme.onThemeChanged === 'function') {
    window.AndroidTheme.onThemeChanged(isDark);
  }
}

// Paleta Nexa por cima do tema Fluent base — só sobrepomos as cores
// de marca (accent) para o resto do design system (tipografia,
// espaçamento, elevação, motion) continuar a vir 100% do Fluent 2,
// que é o pedido explícito ("use fluent design").
const NEXA_BRAND = {
  10: '#020305', 20: '#111827', 30: '#182449', 40: '#1E2D5C',
  50: '#22366F', 60: '#254082', 70: '#264A96', 80: '#2555AB',
  90: '#2F7BF6', 100: '#4A8BF7', 110: '#649BF8', 120: '#7EACF9',
  130: '#98BCFA', 140: '#B3CDFB', 150: '#CDDDFC', 160: '#E8EEFE',
};

export function getNexaTheme(isDark) {
  const base = isDark ? webDarkTheme : webLightTheme;
  return {
    ...base,
    colorBrandBackground: NEXA_BRAND[90],
    colorBrandBackgroundHover: NEXA_BRAND[80],
    colorBrandBackgroundPressed: NEXA_BRAND[70],
    colorBrandForeground1: NEXA_BRAND[90],
    colorBrandForeground2: NEXA_BRAND[80],
    colorBrandStroke1: NEXA_BRAND[90],
    colorBrandStroke2: NEXA_BRAND[80],
  };
}

// Cores "cruas" para uso fora de componentes Fluent (ex: canvas,
// SVG, estilos inline pontuais) — equivalente ao objeto `c` que o
// Svelte passava a componentes filhos via getThemeColors(isDark).
export function getRawColors(isDark) {
  return isDark
    ? {
        background: '#0F0F0F',
        surface: '#1C1C1E',
        surfaceStrong: '#232325',
        textPrimary: '#F3F4F6',
        textSecondary: '#9A9A9A',
        divider: 'rgba(255,255,255,0.08)',
        iconTint: '#F3F4F6',
        accent: NEXA_BRAND[90],
      }
    : {
        background: '#FFFFFF',
        surface: '#F7F7F8',
        surfaceStrong: '#F0F0F2',
        textPrimary: '#1F2937',
        textSecondary: '#6B7280',
        divider: 'rgba(0,0,0,0.08)',
        iconTint: '#1F2937',
        accent: NEXA_BRAND[90],
      };
}