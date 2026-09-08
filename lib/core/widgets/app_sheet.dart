// ══════════════════════════════════════════════════════════════
// FILE: lib/core/widgets/app_sheet.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/colors.dart';

const double _kAppSheetRadius = 28.0;

class _AppSheetHandlebar extends StatelessWidget {
  final AppColorScheme s;
  const _AppSheetHandlebar({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: s.onSurfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Abre o bottom sheet próprio do app. Devolve o valor passado a
/// Navigator.pop(context, valor), tal como um showModalBottomSheet
/// normal — mas sem usar essa API, e sem qualquer dependência de
/// pacote de bottom sheet externo.
///
/// Tema claro: fundo puramente branco (Colors.white), sem nenhum
/// tom fraco/derivado. Tema escuro: mantém s.cardBackground.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final s = AppTheme.of(context);
  final sheetBg = s.isDark ? s.cardBackground : Colors.white;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, anim1, anim2) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_kAppSheetRadius),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AppSheetHandlebar(s: AppTheme.of(dialogContext)),
                    Flexible(child: builder(dialogContext)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}