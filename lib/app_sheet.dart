// ══════════════════════════════════════════════════════════════
// FILE: lib/app_sheet.dart
// Ponto único de modais da app — CupertinoSheetRoute (iOS 13+
// "paper sheet"). Substitui showModalBottomSheet, showCraftBottomSheet
// e showCupertinoDialog em toda a app.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/cupertino.dart';
import 'colors.dart';

/// Abre um modal no estilo Cupertino "paper sheet" — a tela por trás
/// encolhe e fica visível, o novo conteúdo desliza por cima com
/// cantos arredondados no topo. Substitui showModalBottomSheet em
/// toda a app. Devolve o valor passado a Navigator.pop(context, valor),
/// tal como um showModalBottomSheet normal.
///
/// CupertinoSheetRoute desenha só a MOLDURA do sheet (cantos
/// arredondados, sombra, efeito de encolher a tela anterior) — não
/// pinta nenhum fundo dentro da área de conteúdo. Sem isto, qualquer
/// builder que devolva só Padding/Column (sem Container/ColoredBox
/// própria) fica com o conteúdo transparente, mostrando só o texto
/// "flutuando". Por isso o builder do chamador é envolvido aqui, uma
/// única vez, com a cor de superfície do tema atual — nenhum dos
/// pontos de chamada precisa de se preocupar com isto.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    CupertinoSheetRoute<T>(
      builder: (sheetContext) => ColoredBox(
        color: AppTheme.of(sheetContext).surface,
        child: builder(sheetContext),
      ),
    ),
  );
}