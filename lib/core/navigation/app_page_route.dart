// ══════════════════════════════════════════════════════════════
// FILE: lib/core/navigation/app_page_route.dart
// ══════════════════════════════════════════════════════════════
//
// Rota de navegação nativa customizada:
//  - Slide horizontal padrão (entra da direita, sai para a esquerda),
//    respeitando a orientação correta em RTL.
//  - Sem sombra/parallax do CupertinoPageRoute.
//  - Sem glow de overscroll do Android (tratado à parte via
//    AppScrollBehavior, aplicado uma única vez no MaterialApp).
//
// Uso:
//   Navigator.of(context).push(AppPageRoute(builder: (_) => const Foo()));

import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    this.fullscreenDialog = false,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 260),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          opaque: true,
          barrierDismissible: false,
          transitionsBuilder: _buildTransition,
        );

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  final bool fullscreenDialog;

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final beginOffsetIn = Offset(isRtl ? -1.0 : 1.0, 0.0);
    final beginOffsetOutSecondary = Offset(isRtl ? 0.30 : -0.30, 0.0);

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final curvedSecondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final incomingOffset = Tween<Offset>(
      begin: beginOffsetIn,
      end: Offset.zero,
    ).animate(curved);

    final outgoingOffset = Tween<Offset>(
      begin: Offset.zero,
      end: beginOffsetOutSecondary,
    ).animate(curvedSecondary);

    return SlideTransition(
      position: outgoingOffset,
      child: SlideTransition(
        position: incomingOffset,
        child: child,
      ),
    );
  }
}

// ── ScrollBehavior sem glow de overscroll ──────────────────────
//
// Aplicar uma única vez no MaterialApp:
//   MaterialApp(scrollBehavior: const AppScrollBehavior(), ...)
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}