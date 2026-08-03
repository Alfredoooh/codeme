export const ALL_APPS = [
  { id: 'home', label: 'Início', icon: 'Home', path: '/home', color: '#D9D9D9', ready: true },
  { id: 'ai', label: 'Assistente de IA', icon: 'Sparkle', path: '/ai', color: '#862CD4', ready: false },
  { id: 'docs', label: 'Editor de Documentos', icon: 'DocumentText', path: '/docs', color: '#2F7BF6', ready: false },
  { id: 'sheets', label: 'Folha de Cálculo', icon: 'Table', path: '/sheets', color: '#23A63F', ready: false },
  { id: 'slides', label: 'Apresentações', icon: 'SlideText', path: '/slides', color: '#FB6704', ready: false },
  { id: 'whiteboard', label: 'Quadro Branco', icon: 'DrawText', path: '/whiteboard', color: '#7630CA', ready: false },
];

export function getAppById(id) {
  return ALL_APPS.find((a) => a.id === id) || null;
}