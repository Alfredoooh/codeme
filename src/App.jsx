import React from 'react';
import ReactDOM from 'react-dom/client';
import { FluentProvider } from '@fluentui/react-components';
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom';
import { getNexaTheme, getStoredThemeMode, syncThemeMode } from './shared/theme.js';
import HomeApp from './home/App.jsx';
import AiApp from './ai/App.jsx';
import DocsApp from './docs/App.jsx';
import SheetsApp from './sheets/App.jsx';
import WhiteboardApp from './whiteboard/App.jsx';
import SlidesApp from './slides/App.jsx';
import ProfileApp from './profile/App.jsx';
import AuthApp from './auth/App.jsx';

function Root() {
  const [isDark, setIsDark] = React.useState(() => getStoredThemeMode() === 'dark');
  
  React.useEffect(() => {
    syncThemeMode(isDark);
  }, [isDark]);
  
  const theme = getNexaTheme(isDark);
  
  return (
    <FluentProvider theme={theme} style={{ width: '100%', height: '100%', overflow: 'hidden', background: 'transparent' }}>
      <HashRouter>
        <Routes>
          <Route path="/" element={<Navigate to="/home" replace />} />
          <Route path="/home/*" element={<HomeApp isDark={isDark} setIsDark={setIsDark} />} />
          <Route path="/ai/*" element={<AiApp isDark={isDark} setIsDark={setIsDark} />} />
          <Route path="/docs/*" element={<DocsApp isDark={isDark} setIsDark={setIsDark} />} />
          <Route path="/sheets/*" element={<SheetsApp isDark={isDark} setIsDark={setIsDark} />} />
          <Route path="/whiteboard/*" element={<WhiteboardApp isDark={isDark} setIsDark={setIsDark} />} />
          <Route path="/slides/*" element={<SlidesApp isDark={isDark} setIsDark={setIsDark} />} />
          <Route path="/profile/*" element={<ProfileApp isDark={isDark} setIsDark={setIsDark} />} />
          <Route path="/auth/*" element={<AuthApp isDark={isDark} setIsDark={setIsDark} />} />
          <Route path="*" element={<Navigate to="/home" replace />} />
        </Routes>
      </HashRouter>
    </FluentProvider>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Root />);