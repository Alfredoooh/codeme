export const ALL_APPS = [
  { id: 'ai', label: 'Assistente de IA', icon: 'Sparkle', iconPath: '/icons/apps/ai.png', path: '/ai', color: '#862CD4', ready: false },
  { id: 'docs', label: 'Editor de Documentos', icon: 'DocumentText', iconPath: '/icons/apps/docs.png', path: '/docs', color: '#2F7BF6', ready: false },
  { id: 'sheets', label: 'Folha de Cálculo', icon: 'Table', iconPath: '/icons/apps/sheets.png', path: '/sheets', color: '#23A63F', ready: false },
  { id: 'slides', label: 'Apresentações', icon: 'SlideText', iconPath: '/icons/apps/slides.png', path: '/slides', color: '#FB6704', ready: false },
  { id: 'whiteboard', label: 'Quadro Branco', icon: 'DrawText', iconPath: '/icons/apps/whiteboard.png', path: '/whiteboard', color: '#7630CA', ready: false },
];

export function getAppById(id) {
  return ALL_APPS.find((a) => a.id === id) || null;
}