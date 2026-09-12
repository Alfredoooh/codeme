import 'package:flutter/material.dart';

/// ScrollBehavior global da app. Força ClampingScrollPhysics em
/// TODAS as plataformas (por padrão o Flutter usa BouncingScrollPhysics
/// no iOS, que dá exatamente o efeito de "overscroll, tem que
/// arrastar de volta" — o bug reportado). Também desativa o glow
/// de overscroll do Android, que por vezes é confundido com o
/// mesmo problema.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Sem glow de overscroll — evita duplo feedback visual quando
    // já não há bounce.
    return child;
  }
}