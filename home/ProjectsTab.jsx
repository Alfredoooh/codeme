import React from 'react';
import { Folder24Regular } from '@fluentui/react-icons';
import { getRawColors } from '../shared/theme.js';

// Tab "Projetos": placeholder de estado vazio nesta primeira versão.
// A listagem real de projetos guardados (docs/sheets/whiteboard) só
// faz sentido depois de essas apps existirem nesta base React com
// persistência própria — por agora mostra apenas o estado vazio para
// a navegação/estrutura ficar completa.
export default function ProjectsTab({ isDark }) {
  const c = getRawColors(isDark);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', padding: '60px 30px', textAlign: 'center' }}>
      <Folder24Regular fontSize={48} style={{ color: c.textSecondary, marginBottom: 16 }} />
      <div style={{ fontSize: 16, fontWeight: 700, color: c.textPrimary, marginBottom: 6 }}>Ainda sem projetos</div>
      <div style={{ fontSize: 13.5, color: c.textSecondary, lineHeight: 1.5 }}>
        Os teus documentos, folhas de cálculo e designs vão aparecer aqui assim que os criares.
      </div>
    </div>
  );
}