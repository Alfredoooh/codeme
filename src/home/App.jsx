import React from 'react';
import { Routes, Route } from 'react-router-dom';
import HomeShell from './HomeShell.jsx';
import SettingsPage from './SettingsPage.jsx';
import NotificationsPage from './NotificationsPage.jsx';

export default function HomeApp({ isDark, setIsDark, user, onOpenAI }) {
  return (
    <Routes>
      <Route path="/" element={<HomeShell user={user} onOpenAI={onOpenAI} />} />
      <Route path="/settings" element={<SettingsPage isDark={isDark} setIsDark={setIsDark} />} />
      <Route path="/notifications" element={<NotificationsPage />} />
    </Routes>
  );
}