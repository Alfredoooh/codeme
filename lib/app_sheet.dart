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
        // DefaultTextStyle força fonte default de plataforma (Roboto
        // no Android) em vez da fonte de sistema iOS (San Francisco),
        // que é a que o corretor ortográfico do iOS sublinha a
        // amarelo. fontFamily: null diz ao Flutter para não impor
        // nenhuma família específica — cai na default da plataforma.
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: null,
            color: CupertinoColors.label,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar: mesma barra cinzenta que a Apple usa nos
              // seus próprios sheets (Maps, Apple Music). 36×5,
              // radius 2.5 é o tamanho padrão que a Apple usa.
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4.resolveFrom(sheetContext),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        ),
      ),
    ),
  );
}