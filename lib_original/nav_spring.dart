// ══════════════════════════════════════════════════════════════
// FILE: lib/nav_spring.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/animation.dart';

/// Controla a animação de abertura/fecho do drawer lateral.
///
/// slideCtrl.value = 0.0  → drawer totalmente visível (aberto)
/// slideCtrl.value = 1.0  → drawer totalmente escondido (fechado)
///
/// Usado em RootShell através de:
///   left: -drawerWidth + drawerWidth * (1.0 - v)
/// onde v = slideCtrl.value, portanto v=1.0 → left=-drawerWidth (fora do ecrã)
/// e v=0.0 → left=0 (encostado à esquerda, visível).
class SpringNav {
  SpringNav({required TickerProvider vsync})
      : slideCtrl = AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 320),
        );

  final AnimationController slideCtrl;

  /// Anima para o estado aberto (v → 0.0).
  void open() {
    slideCtrl.animateTo(
      0.0,
      curve: Curves.easeOutCubic,
    );
  }

  /// Anima para o estado fechado (v → 1.0).
  void close() {
    slideCtrl.animateTo(
      1.0,
      curve: Curves.easeInCubic,
    );
  }

  void dispose() {
    slideCtrl.dispose();
  }
}