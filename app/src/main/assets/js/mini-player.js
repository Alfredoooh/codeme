function injectMiniPlayer() {
  const html =
    '<div class="mini-player" id="mini-player">' +
    '<div class="mini-player-progress" id="mini-player-progress"></div>' +
    '<img class="mini-player-thumb" id="mini-player-thumb" src="">' +
    '<div class="mini-player-info">' +
    '<div class="mini-player-title" id="mini-player-title"></div>' +
    '<div class="mini-player-subtitle" id="mini-player-subtitle"></div>' +
    '</div>' +
    '<div class="mini-player-btn" onclick="VibelyBridge.togglePlayPause()">' +
    '<ion-icon id="mini-player-play-icon" name="play"></ion-icon>' +
    '</div>' +
    '</div>';
  document.body.insertAdjacentHTML('beforeend', html);
}
document.addEventListener('DOMContentLoaded', injectMiniPlayer);