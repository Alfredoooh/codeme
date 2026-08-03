import React from 'react';
import { Routes, Route, useNavigate, useLocation } from 'react-router-dom';
import HomeShell from './HomeShell.jsx';
import SettingsPage from './SettingsPage.jsx';

// App.jsx do 'home' segue o mesmo papel que tinha no Svelte: decide
// entre a rota principal (a shell com as tabs) e a página de
// definições, e trata a navegação para fora do próprio mini-app
// (auth, outras apps) delegando para o Root via useNavigate — nesta
// versão React não há um sistema de eventos `dispatch('nav', ...)`
// próprio, o próprio react-router-dom já resolve isso de forma
// nativa entre mini-apps porque todos vivem sob o mesmo HashRouter.
export default function HomeApp({ isDark, setIsDark }) {
  return (
    <Routes>
      <Route path="/" element={<HomeShell isDark={isDark} />} />
      <Route path="/settings" element={<SettingsPage isDark={isDark} setIsDark={setIsDark} />} />
    </Routes>
  );
}