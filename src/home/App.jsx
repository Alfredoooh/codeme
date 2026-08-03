import React from 'react';
import { Routes, Route } from 'react-router-dom';
import HomeShell from './HomeShell.jsx';
import SettingsPage from './SettingsPage.jsx';

export default function HomeApp({ isDark, setIsDark }) {
  return (
    <Routes>
      <Route path="/" element={<HomeShell />} />
      <Route path="/settings" element={<SettingsPage isDark={isDark} setIsDark={setIsDark} />} />
    </Routes>
  );
}