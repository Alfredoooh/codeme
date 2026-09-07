// ══════════════════════════════════════════════════════════════
// FILE: lib/app_sheet.dart
// Ponto único de modais da app — bottom sheet Material padrão,
// mesma curva (20px no topo) e handlebar do modal de opções da
// conversa em drawermenu.dart. Substitui showModalBottomSheet
// "cru", showCraftBottomSheet e o antigo CupertinoSheetRoute em
// toda a app.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/colors.dart';

const double _kAppSheetRadius = 20.0;

class _AppSheetHandlebar extends StatelessWidget {
  final AppColorScheme s;
  const _AppSheetHandlebar({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: s.onSurfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Abre um modal padrão da app — bottom sheet Material com cantos
/// arredondados no topo (mesma curva usada no modal de opções da
/// conversa) e handlebar cinzenta no topo. Substitui qualquer uso
/// direto de showModalBottomSheet em toda a app. Devolve o valor
/// passado a Navigator.pop(context, valor), tal como um
/// showModalBottomSheet normal.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final s = AppTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: s.surface,
    barrierColor: Colors.black.withOpacity(0.35),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_kAppSheetRadius)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppSheetHandlebar(s: AppTheme.of(sheetContext)),
          Flexible(child: builder(sheetContext)),
        ],
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
        padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(ctx).padding.bottom,
        ),
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