// theme.js
import {
  webLightTheme,
  webDarkTheme,
  tokens,
  createLightTheme,
  createDarkTheme,
} from '@fluentui/react-components';

const THEME_STORAGE_KEY = 'nexa_theme';

export function getStoredThemeMode() {
  const saved = localStorage.getItem(THEME_STORAGE_KEY);
  if (saved === 'dark' || saved === 'light') return saved;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function setStoredThemeMode(mode) {
  localStorage.setItem(THEME_STORAGE_KEY, mode);
}

// Corpo inteiro da app usa colorNeutralBackground2 — o mesmo tom que
// o bottom bar já usava. Isto resolve o pedido "o tom do bottom tem
// que ser aplicado no corpo do app inteiramente": ambos bebem do
// mesmo token, nunca podem dessincronizar. Cards, inputs de
// pesquisa, e superfícies "elevadas" usam colorNeutralBackground1
// (mais claro que o corpo em dark, mais branco puro em light) para
// se destacarem do fundo — é o inverso do que tínhamos antes.
export function syncThemeMode(isDark) {
  setStoredThemeMode(isDark ? 'dark' : 'light');
  const theme = isDark ? webDarkTheme : webLightTheme;
  const root = document.documentElement;
  root.classList.toggle('dark', isDark);
  root.classList.toggle('light', !isDark);
  document.body.style.background = theme.colorNeutralBackground2;
  
  // Injeta TODOS os tokens do tema Fluent como CSS custom properties
  // no :root. Assim qualquer CSS puro (sem React/Fluent) pode usar
  // var(--colorNeutralBackground1), var(--colorBrandForeground1), etc,
  // e ficam automaticamente sincronizados com o modo light/dark.
  applyFluentTokensToRoot(theme);
  
  let meta = document.querySelector('meta[name="theme-color"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'theme-color';
    document.head.appendChild(meta);
  }
  meta.setAttribute('content', theme.colorNeutralBackground2);
  
  if (window.AndroidTheme && typeof window.AndroidTheme.onThemeChanged === 'function') {
    window.AndroidTheme.onThemeChanged(isDark);
  }
}

// Percorre todas as chaves do objeto de tema (webLightTheme /
// webDarkTheme) e regista-as como --nomeDoToken no :root.
// Isto cobre automaticamente TODAS as paletas: neutral, brand,
// status (success/warning/danger), e as ~30 cores partilhadas
// (red, green, blue, purple, teal, etc — cada uma com variantes
// Background1-3, Foreground1-3, BorderActive), sem termos de
// listar cada uma manualmente e sem correr risco de esquecer
// tokens novos que o Fluent adicione em versões futuras.
function applyFluentTokensToRoot(theme) {
  const root = document.documentElement;
  for (const key in theme) {
    if (Object.prototype.hasOwnProperty.call(theme, key)) {
      root.style.setProperty(`--${key}`, theme[key]);
    }
  }
}

export function getNexaTheme(isDark) {
  return isDark ? webDarkTheme : webLightTheme;
}

// Reexporta `tokens` para quem preferir continuar a importar os
// nomes dos tokens (tokens.colorNeutralBackground1, etc) em vez de
// strings soltas — mantém compatibilidade com código existente.
export { tokens };

// ---------------------------------------------------------------
// LISTA DE REFERÊNCIA — todas as paletas de cor partilhadas do
// Fluent Design. Não são usadas diretamente aqui (o loop acima já
// as injeta todas), mas ficam documentadas para saberes que nomes
// tens disponíveis em var(--colorXxxBackground1) etc.
// ---------------------------------------------------------------
export const FLUENT_SHARED_PALETTES = [
  'red', 'green', 'darkOrange', 'yellow', 'berry', 'lightGreen',
  'marigold', 'lightTeal', 'blue', 'royalBlue', 'darkRed', 'cranberry',
  'pumpkin', 'peach', 'gold', 'brass', 'brown', 'forest', 'seafoam',
  'darkGreen', 'platinum', 'anchor', 'beige', 'mink', 'silver',
  'nickel', 'pewter', 'steel', 'metal', 'terracotta', 'orange',
  'grape', 'lilac', 'purple', 'lavender', 'plum', 'orchid', 'grape',
  'lightPurple', 'magenta', 'hotPink', 'pink', 'pinkRed',
];

// Sufixos que cada paleta partilhada expõe. Ex: para 'red' existem
// os tokens colorPaletteRedBackground1/2/3, colorPaletteRedForeground1/2/3,
// colorPaletteRedBorderActive.
export const FLUENT_PALETTE_SUFFIXES = [
  'Background1', 'Background2', 'Background3',
  'Foreground1', 'Foreground2', 'Foreground3',
  'BorderActive',
];

// Grupos de tokens semânticos mais usados no dia a dia do Nexa —
// útil como "cheat sheet" ao escrever CSS novo.
export const FLUENT_CORE_TOKENS = {
  neutralBackground: [
    'colorNeutralBackground1', 'colorNeutralBackground2', 'colorNeutralBackground3',
    'colorNeutralBackground4', 'colorNeutralBackground5', 'colorNeutralBackground6',
    'colorNeutralBackground1Hover', 'colorNeutralBackground1Pressed', 'colorNeutralBackground1Selected',
  ],
  neutralForeground: [
    'colorNeutralForeground1', 'colorNeutralForeground2', 'colorNeutralForeground3',
    'colorNeutralForeground4', 'colorNeutralForegroundDisabled', 'colorNeutralForegroundInverted',
  ],
  neutralStroke: [
    'colorNeutralStroke1', 'colorNeutralStroke2', 'colorNeutralStroke3', 'colorNeutralStrokeDisabled',
  ],
  brand: [
    'colorBrandBackground', 'colorBrandBackgroundHover', 'colorBrandBackgroundPressed',
    'colorBrandForeground1', 'colorBrandForeground2', 'colorBrandForegroundLink',
    'colorBrandStroke1', 'colorBrandStroke2',
  ],
  status: {
    success: ['colorPaletteGreenBackground1', 'colorPaletteGreenForeground1', 'colorPaletteGreenBorderActive'],
    warning: ['colorPaletteYellowBackground1', 'colorPaletteYellowForeground1', 'colorPaletteYellowBorderActive'],
    danger: ['colorPaletteRedBackground1', 'colorPaletteRedForeground1', 'colorPaletteRedBorderActive'],
  },
};