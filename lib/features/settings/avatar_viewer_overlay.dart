// ══════════════════════════════════════════════════════════════
// FILE: lib/features/settings/avatar_viewer_overlay.dart
// Substitui o antigo PageRouteBuilder do avatar viewer. Usa
// OverlayEntry — não é uma rota, não há push/pop, então a tela de
// trás não sofre nenhum deslocamento/sinal de "navegação". A
// animação de entrada é a mesma de antes: fade + scale (Container
// transform 0.92 → 1.0).
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'avatar_viewer_screen.dart';

/// Mostra o avatar viewer como overlay flutuante por cima do
/// ecrã atual — sem rota, sem navegação, sem deslocar o fundo.
void showAvatarViewerOverlay(
  BuildContext context, {
  required AppColorScheme s,
  required Future<void> Function(String base64Avatar) onAvatarUpdated,
}) {
  late OverlayEntry entry;
  final overlayState = Overlay.of(context);

  entry = OverlayEntry(
    builder: (overlayContext) => _AvatarViewerOverlayContent(
      s: s,
      onAvatarUpdated: onAvatarUpdated,
      onClose: () => entry.remove(),
    ),
  );

  overlayState.insert(entry);
}

class _AvatarViewerOverlayContent extends StatefulWidget {
  final AppColorScheme s;
  final Future<void> Function(String base64Avatar) onAvatarUpdated;
  final VoidCallback onClose;
  const _AvatarViewerOverlayContent({
    required this.s,
    required this.onAvatarUpdated,
    required this.onClose,
  });

  @override
  State<_AvatarViewerOverlayContent> createState() =>
      _AvatarViewerOverlayContentState();
}

class _AvatarViewerOverlayContentState
    extends State<_AvatarViewerOverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 280),
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fade = curved;
    _scale = Tween(begin: 0.92, end: 1.0).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _closeAnimated() async {
    await _ctrl.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Positioned.fill(
        child: FadeTransition(
          opacity: _fade,
          child: Container(
            color: Colors.black.withOpacity(0.6 * _ctrl.value),
            child: child,
          ),
        ),
      ),
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: AvatarViewerScreen(
            s: widget.s,
            onAvatarUpdated: widget.onAvatarUpdated,
            onRequestClose: _closeAnimated,
          ),
        ),
      ),
    );
  }
}