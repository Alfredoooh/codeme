const VibelyBridge = {
  
  applyTheme: function(themeMode, isDarkActive) {
    document.documentElement.setAttribute('data-theme', isDarkActive ? 'dark' : 'light');
    const radios = document.querySelectorAll('input[name="theme-option"]');
    radios.forEach(function(r) {
      r.checked = (r.value === themeMode);
    });
  },
  
  initTheme: function() {
    try {
      const isDark = NativeBridge.isDarkModeActive();
      const themeMode = NativeBridge.getCurrentTheme();
      VibelyBridge.applyTheme(themeMode, isDark);
    } catch (e) {
      console.warn('NativeBridge indisponível para tema:', e);
    }
  },
  
  setTheme: function(themeValue) {
    try { NativeBridge.setTheme(themeValue); } catch (e) { console.warn(e); }
  },
  
  navigateTo: function(screen) {
    try { NativeBridge.navigateTo(screen); } catch (e) { console.warn(e); }
  },
  
  goBack: function() {
    try { NativeBridge.goBack(); } catch (e) { console.warn(e); }
  },
  
  searchCallbacks: {},
  
  searchMusic: function(query, onResults) {
    const callbackId = 'cb_' + Date.now() + '_' + Math.floor(Math.random() * 10000);
    VibelyBridge.searchCallbacks[callbackId] = onResults;
    try {
      NativeBridge.searchMusic(query, callbackId);
    } catch (e) {
      console.warn(e);
      onResults([]);
    }
  },
  
  openDrawer: function() {
    document.getElementById('drawer').classList.add('open');
    document.getElementById('drawer-overlay').classList.add('open');
  },
  
  closeDrawer: function() {
    document.getElementById('drawer').classList.remove('open');
    document.getElementById('drawer-overlay').classList.remove('open');
  },
  
  currentTrack: null,
  
  playTrack: function(videoId, videoUrl, title, channel, thumbnail) {
    VibelyBridge.currentTrack = { videoId: videoId, title: title, channel: channel, thumbnail: thumbnail };
    try {
      NativeBridge.playTrack(videoId, videoUrl);
    } catch (e) { console.warn(e); }
    VibelyBridge.renderMiniPlayer();
  },
  
  togglePlayPause: function() {
    try { NativeBridge.togglePlayPause(); } catch (e) { console.warn(e); }
  },
  
  seekTo: function(positionMs) {
    try { NativeBridge.seekTo(positionMs); } catch (e) { console.warn(e); }
  },
  
  formatTime: function(ms) {
    if (!ms || ms < 0) return '0:00';
    const totalSec = Math.floor(ms / 1000);
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    return m + ':' + (s < 10 ? '0' : '') + s;
  },
  
  renderMiniPlayer: function() {
    const el = document.getElementById('mini-player');
    if (!el) return;
    if (!VibelyBridge.currentTrack) {
      el.classList.remove('visible');
      return;
    }
    el.classList.add('visible');
    document.getElementById('mini-player-thumb').src = VibelyBridge.currentTrack.thumbnail || '';
    document.getElementById('mini-player-title').textContent = VibelyBridge.currentTrack.title || '';
    document.getElementById('mini-player-subtitle').textContent = VibelyBridge.currentTrack.channel || '';
  },
  
  setMiniPlayerPlayingIcon: function(isPlaying) {
    const btn = document.getElementById('mini-player-play-icon');
    if (btn) btn.setAttribute('name', isPlaying ? 'pause' : 'play');
  }
};

window.onThemeChanged = function(themeMode, isDarkActive) {
  VibelyBridge.applyTheme(themeMode, isDarkActive);
};

window.onSearchResults = function(callbackId, resultsJson) {
  const callback = VibelyBridge.searchCallbacks[callbackId];
  if (callback) {
    callback(resultsJson);
    delete VibelyBridge.searchCallbacks[callbackId];
  }
};

window.onPlayerStateChanged = function(isPlaying, isLoading, videoId) {
  VibelyBridge.setMiniPlayerPlayingIcon(isPlaying);
  if (typeof window.onTrackPlayingStateChanged === 'function') {
    window.onTrackPlayingStateChanged(isPlaying, isLoading, videoId);
  }
};

window.onPlayerProgress = function(positionMs, durationMs) {
  const bar = document.getElementById('mini-player-progress');
  if (bar && durationMs > 0) {
    bar.style.width = Math.min(100, (positionMs / durationMs) * 100) + '%';
  }
};

document.addEventListener('DOMContentLoaded', function() {
  VibelyBridge.initTheme();
  VibelyBridge.renderMiniPlayer();
});