// ══════════════════════════════════════════════════════════════
// FILE: lib/app_sheet.dart
// Ponto único de modais da app — CupertinoSheetRoute (iOS 13+
// "paper sheet"). Substitui showModalBottomSheet, showCraftBottomSheet
// e showCupertinoDialog em toda a app.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/cupertino.dart';

/// Abre um modal no estilo Cupertino "paper sheet" — a tela por trás
/// encolhe e fica visível, o novo conteúdo desliza por cima com
/// cantos arredondados no topo. Substitui showModalBottomSheet em
/// toda a app. Devolve o valor passado a Navigator.pop(context, valor),
/// tal como um showModalBottomSheet normal.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    CupertinoSheetRoute<T>(
      builder: builder,
    ),
  );
}