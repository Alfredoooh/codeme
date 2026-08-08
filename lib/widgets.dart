import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'colors.dart';

// ══════════════════════════════════════════════════════════════
// ÍCONES SVG / PNG
// ══════════════════════════════════════════════════════════════

class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;
  /// Quando true, carrega de assets/icons/svg_color/ e NÃO aplica
  /// colorFilter — o ícone mantém as cores originais do próprio SVG.
  /// Não tem efeito em PNG (o PNG já vem colorido de fábrica).
  final bool useColorAsset;

  const AppIcon(
    this.asset, {
    super.key,
    this.size = 20,
    required this.color,
    this.useColorAsset = false,
  });

  @override
  Widget build(BuildContext context) {
    // PNG (hoje: os ícones "filled" dos tabs) segue para
    // assets/icons/png/ e nunca passa por SvgPicture — antes disto,
    // um asset .png chegava a ser pedido como se fosse SVG dentro da
    // pasta svg/, o que falha sem nenhum erro visível na tela.
    if (asset.toLowerCase().endsWith('.png')) {
      return Image.asset(
        'assets/icons/png/$asset',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        // Fallback visível: se o PNG realmente não existir/carregar,
        // mostra um ícone de aviso em vez de ficar em branco em
        // silêncio — assim qualquer falha futura fica visível mesmo
        // sem acesso a console/logcat.
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image_outlined,
          size: size,
          color: color,
        ),
      );
    }

    final path = useColorAsset
        ? 'assets/icons/svg_color/$asset'
        : 'assets/icons/svg/$asset';

    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter:
          useColorAsset ? null : ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (context) => Icon(
        Icons.broken_image_outlined,
        size: size,
        color: color,
      ),
    );
  }
}

class EditorTypeIcon extends StatelessWidget {
  final String asset;
  final double size;
  const EditorTypeIcon(this.asset, {super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/icons/png/$asset',
        width: size, height: size,
        filterQuality: FilterQuality.medium,
      );
}

// ══════════════════════════════════════════════════════════════
// TAP AREA
// ══════════════════════════════════════════════════════════════

class AppTap extends StatefulWidget {
  final VoidCallback onTap;
  final AppColorScheme s;
  final Widget child;
  final double size;

  const AppTap({
    super.key,
    required this.onTap,
    required this.s,
    required this.child,
    this.size = 36,
  });

  @override
  State<AppTap> createState() => _AppTapState();
}

class _AppTapState extends State<AppTap> {
  bool _p = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _p = true),
        onTapCancel: () => setState(() => _p = false),
        onTapUp: (_) => setState(() => _p = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _p ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.size, height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _p ? widget.s.pressed : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.size / 2),
            ),
            child: widget.child,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// SWITCH
// ══════════════════════════════════════════════════════════════

class AppSwitch extends StatelessWidget {
  final bool value;
  final AppColorScheme s;
  final ValueChanged<bool> onChanged;
  const AppSwitch({super.key, required this.value, required this.s, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: kCupertinoOut,
          width: 46, height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? s.primary : s.outline,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: value ? s.onPrimary : s.cardBackground,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// DASHED ROUNDED BORDER — usado no input de chat quando incógnito
// ══════════════════════════════════════════════════════════════

class DashedRRectBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;
  DashedRRectBorderPainter({
    required this.color,
    required this.radius,
    this.dashWidth = 5,
    this.dashGap = 4,
    this.strokeWidth = 1.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class DashedRRectBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const DashedRRectBorder({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: DashedRRectBorderPainter(color: color, radius: radius),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════
// GENERIC BOTTOM SHEET CARD (usado em drawer/settings/aitab)
// ══════════════════════════════════════════════════════════════

class SettingsStyleCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final Widget child;
  const SettingsStyleCard(
      {super.key, required this.s, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: s.cardBackground, borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class SheetOptionsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> options;
  const SheetOptionsGroup({super.key, required this.s, required this.options});

  static const double _outerRadius = 16;
  static const double _innerRadius = 4;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final count = options.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          SettingsStyleCard(
            s: s,
            radius: _radiusFor(i, count),
            child: options[i],
          ),
        ],
      ],
    );
  }

  BorderRadius _radiusFor(int index, int count) {
    if (count == 1) return BorderRadius.circular(_outerRadius);
    final isFirst = index == 0;
    final isLast  = index == count - 1;
    return BorderRadius.only(
      topLeft:     Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight:    Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft:  Radius.circular(isLast  ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast  ? _outerRadius : _innerRadius),
    );
  }
}

class SheetGrabber extends StatelessWidget {
  final AppColorScheme s;
  const SheetGrabber({super.key, required this.s});
  @override
  Widget build(BuildContext context) => Container(
        width: 36, height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: s.outline,
          borderRadius: BorderRadius.circular(999),
        ),
      );
}