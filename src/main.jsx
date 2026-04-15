import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'

const statusBarHeight = 44

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      height: statusBarHeight,
      zIndex: 9999,
      backgroundColor: 'transparent',
      pointerEvents: 'none',
    }} />
    <div style={{ paddingTop: statusBarHeight }}>
      <App />
    </div>
  </StrictMode>
)