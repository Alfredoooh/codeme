// ══════════════════════════════════════════════════════════════
// FILE: lib/app_sheet.dart
// Ponto único de modais da app — CupertinoSheetRoute (iOS 13+
// "paper sheet"). Substitui showModalBottomSheet, showCraftBottomSheet
// e showCupertinoDialog em toda a app.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // ← adicionado para TextField, InputDecoration etc.
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

// ══════════════════════════════════════════════════════════════
// MODAL DE EDIÇÃO COM IA
// Usado pelos editores (docs, sheets, slides) para pedir uma
// instrução de edição ao utilizador.
// ══════════════════════════════════════════════════════════════
Future<String?> showAiEditModal(
  BuildContext context,
  AppColorScheme s, {
  bool hasSelection = false,
}) {
  final ctrl = TextEditingController();
  return showAppSheet<String>(
    context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasSelection ? 'Editar seleção com IA' : 'Editar com IA',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(fontSize: 15, color: s.onSurface),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Descreve a alteração...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: s.onSurfaceVariant,
                ),
                filled: true,
                fillColor: s.hover,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx, ctrl.text.trim());
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Aplicar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: s.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}