// ══════════════════════════════════════════════════════════════
// FILE: lib/core/widgets/anchored_popup.dart
// Popup que nasce a partir de um botão específico — cresce e
// desvanece a partir das coordenadas globais do botão, em vez de
// subir do fundo do ecrã (como showModalBottomSheet) ou usar a
// animação genérica do showMenu do Material.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AnchoredPopupItem<T> {
  final T value;
  final String label;
  final String assetName;
  final bool destructive;
  final bool disabled;
  final bool selected;
  const AnchoredPopupItem({
    required this.value,
    required this.label,
    required this.assetName,
    this.destructive = false,
    this.disabled = false,
    this.selected = false,
  });
}

/// Mostra um popup ancorado à posição global de [anchorKey], com
/// animação de scale+fade nascendo a partir do canto do botão
/// (não do fundo do ecrã). O popup fica sempre sobre o botão,
/// nunca por baixo dele.
Future<T?> showAnchoredPopup<T>(
  BuildContext context, {
  required GlobalKey anchorKey,
  required AppColorScheme s,
  required List<AnchoredPopupItem<T>> items,
  double menuWidth = 220,
  Alignment align = Alignment.topRight,
}) {
  final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (anchorBox == null) return Future.value(null);

  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final anchorTopLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final anchorSize = anchorBox.size;
  final screenSize = overlayBox.size;

  // Ponto de origem da animação: o centro do botão que foi tocado.
  final origin = Offset(
    anchorTopLeft.dx + anchorSize.width / 2,
    anchorTopLeft.dy + anchorSize.height / 2,
  );

  return Navigator.of(context, rootNavigator: true).push<T>(
    _AnchoredPopupRoute<T>(
      origin: origin,
      anchorTopLeft: anchorTopLeft,
      anchorSize: anchorSize,
      screenSize: screenSize,
      s: s,
      items: items,
      menuWidth: menuWidth,
      align: align,
    ),
  );
}

class _AnchoredPopupRoute<T> extends PopupRoute<T> {
  final Offset origin;
  final Offset anchorTopLeft;
  final Size anchorSize;
  final Size screenSize;
  final AppColorScheme s;
  final List<AnchoredPopupItem<T>> items;
  final double menuWidth;
  final Alignment align;

  _AnchoredPopupRoute({
    required this.origin,
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.screenSize,
    required this.s,
    required this.items,
    required this.menuWidth,
    required this.align,
  });

  @override
  Color? get barrierColor => Colors.black.withOpacity(0.06);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fechar popup';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 190);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 140);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    // Estimativa de altura para decidir se o menu abre para cima ou
    // para baixo do botão, garantindo que fica sempre visível e
    // "sobre" o botão a partir de onde foi tocado — nunca escondido
    // atrás dele.
    final estimatedHeight = items.length * 46.0 + 16.0;
    final spaceBelow = screenSize.height - (anchorTopLeft.dy + anchorSize.height);
    final openDownward = spaceBelow >= estimatedHeight || spaceBelow >= (anchorTopLeft.dy);

    // Alinha a borda direita do menu com a borda direita do botão
    // (comportamento de "sobre o botão"), ajustando se ultrapassar
    // os limites do ecrã.
    double left = anchorTopLeft.dx + anchorSize.width - menuWidth;
    left = left.clamp(8.0, screenSize.width - menuWidth - 8.0);

    final double top = openDownward
        ? anchorTopLeft.dy + anchorSize.height + 6
        : anchorTopLeft.dy - estimatedHeight - 6;

    // O ponto de ancoragem da escala é o canto do menu mais próximo
    // do botão — para cima ou para baixo, sempre "saindo" do botão.
    final anchorAlignment = openDownward ? Alignment.topRight : Alignment.bottomRight;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack).drive(
              Tween(begin: 0.82, end: 1.0),
            ),
            alignment: anchorAlignment,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6)),
              child: Material(
                color: s.floatingSurface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                shadowColor: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: s.outline.withOpacity(0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(s.isDark ? 0.35 : 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final it in items)
                        _AnchoredPopupTile<T>(s: s, item: it),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnchoredPopupTile<T> extends StatelessWidget {
  final AppColorScheme s;
  final AnchoredPopupItem<T> item;
  const _AnchoredPopupTile({required this.s, required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.disabled
        ? s.onSurfaceVariant.withOpacity(0.4)
        : item.destructive
            ? s.error
            : item.selected
                ? s.primary
                : s.onSurface;

    return InkWell(
      onTap: item.disabled
          ? null
          : () => Navigator.of(context, rootNavigator: true).pop(item.value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: item.selected ? s.primaryContainer.withOpacity(0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AppIcon(item.assetName, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: item.selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (item.selected) AppIcon('check', size: 16, color: s.primary),
          ],
        ),
      ),
    );
  }
}