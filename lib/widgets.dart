// ══════════════════════════════════════════════════════════════
// FILE: lib/widgets.dart
//
// Componentes base da app — todos alinhados com Fluent Design 2:
//
//   • AppIcon / EditorTypeIcon       — ícones SVG/PNG
//   • AppTap                         — tap area com scale + pressed fill
//   • AppSwitch                      — toggle Fluent
//   • DashedRRectBorder              — borda tracejada
//   • FluentBottomSheet              — bottom sheet Fluent (radius 8 top)
//   • showFluentBottomSheet()        — helper imperativo
//   • FluentDialog                   — diálogo Fluent com título + actions
//   • showFluentDialog()             — helper imperativo
//   • FluentButton                   — botão primário / secundário / ghost / destrutivo
//   • FluentTextField                — campo de texto com label, hint, erro
//   • FluentDivider                  — divisor horizontal fino
//   • FluentListCard / FluentListGroup — card de lista estilo Settings
//   • FluentPopupContainer           — container padrão para menus flutuantes
//   • FluentChip                     — pill label / badge
//   • FluentIconButton               — botão circular com ícone
//   • FluentProgressBar              — barra de progresso linear
//   • FluentShimmer                  — skeleton loader
//   • SheetGrabber                   — grabber de bottom sheet
//   • SettingsStyleCard / SheetOptionsGroup  — compatibilidade anterior
// ══════════════════════════════════════════════════════════════

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
    final lower = asset.toLowerCase();
    final isPng = lower.endsWith('.png');
    final isSvg = lower.endsWith('.svg') || !isPng;
    final fileName = asset.contains('.') ? asset : (isPng ? asset : '$asset.svg');

    if (isPng) {
      return Image.asset(
        'assets/icons/png/$fileName',
        width: size,
        height: size,
        color: useColorAsset ? null : color,
        colorBlendMode: useColorAsset ? null : BlendMode.srcIn,
      );
    }

    if (isSvg) {
      final normalized =
          fileName.replaceAll(RegExp(r'\.(png|svg)$', caseSensitive: false), '.svg');
      return SvgPicture.asset(
        'assets/icons/svg/$normalized',
        width: size,
        height: size,
        colorFilter:
            useColorAsset ? null : ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    return const SizedBox.shrink();
  }
}

class EditorTypeIcon extends StatelessWidget {
  final String asset;
  final double size;
  const EditorTypeIcon(this.asset, {super.key, this.size = 20});

  @override
  Widget build(BuildContext context) =>
      AppIcon(asset, size: size, color: Colors.white, useColorAsset: true);
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
          duration: kDurationFast,
          child: AnimatedContainer(
            duration: kDurationFast,
            width: widget.size,
            height: widget.size,
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
// SWITCH (Fluent)
// ══════════════════════════════════════════════════════════════

class AppSwitch extends StatelessWidget {
  final bool value;
  final AppColorScheme s;
  final ValueChanged<bool> onChanged;

  const AppSwitch({
    super.key,
    required this.value,
    required this.s,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: kDurationNormal,
          curve: kFluentStandard,
          width: 46,
          height: 26,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? s.primary : s.outline,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? s.onPrimary : s.cardBackground,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// DASHED ROUNDED BORDER
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
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth,
          size.height - strokeWidth),
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
        foregroundPainter:
            DashedRRectBorderPainter(color: color, radius: radius),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════
// SHEET GRABBER
// ══════════════════════════════════════════════════════════════

class SheetGrabber extends StatelessWidget {
  final AppColorScheme s;
  const SheetGrabber({super.key, required this.s});

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: s.strokeDivider,
          borderRadius: BorderRadius.circular(kRadiusCircle),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// FLUENT BOTTOM SHEET
//
// Fluent Design usa radius de 8px no topo (não 28px estilo iOS).
// O fundo é floatingSurface, grabber fino, sombra elevation8.
// Padding interno padronizado: 20h, 20 bottom + safe area.
// ══════════════════════════════════════════════════════════════

class FluentBottomSheet extends StatelessWidget {
  final AppColorScheme s;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool showGrabber;
  final double? maxHeightFactor;

  const FluentBottomSheet({
    super.key,
    required this.s,
    required this.child,
    this.padding,
    this.showGrabber = true,
    this.maxHeightFactor = 0.90,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;
    final maxH = maxHeightFactor != null ? screenH * maxHeightFactor! : double.infinity;

    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Container(
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              boxShadow: s.elevation8,
              border: Border(
                top: BorderSide(color: s.strokeCard, width: 1),
                left: BorderSide(color: s.strokeCard, width: 1),
                right: BorderSide(color: s.strokeCard, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: padding ??
                    EdgeInsets.fromLTRB(20, 14, 20, bottom > 0 ? bottom + 12 : safeBottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showGrabber) Center(child: SheetGrabber(s: s)),
                    Flexible(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper imperativo — usa sempre [FluentBottomSheet] por baixo.
Future<T?> showFluentBottomSheet<T>({
  required BuildContext context,
  required AppColorScheme s,
  required Widget child,
  bool showGrabber = true,
  EdgeInsetsGeometry? padding,
  double? maxHeightFactor = 0.90,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    barrierColor: const Color(0x55000000),
    builder: (_) => FluentBottomSheet(
      s: s,
      showGrabber: showGrabber,
      padding: padding,
      maxHeightFactor: maxHeightFactor,
      child: child,
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// FLUENT DIALOG
//
// Diálogo estilo Fluent: radius 8, surface card, max-width 400,
// sombra elevation8, título em Body Strong, ações na base.
// ══════════════════════════════════════════════════════════════

class FluentDialog extends StatelessWidget {
  final AppColorScheme s;
  final String? title;
  final Widget? titleWidget;
  final Widget content;
  final List<FluentDialogAction> actions;
  final double? maxWidth;

  const FluentDialog({
    super.key,
    required this.s,
    required this.content,
    required this.actions,
    this.title,
    this.titleWidget,
    this.maxWidth = 400,
  }) : assert(
          title != null || titleWidget != null || true,
          'title ou titleWidget é recomendado',
        );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? 400,
            minWidth: 280,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: BorderRadius.circular(kRadiusLarge),
              boxShadow: s.elevation16,
              border: Border.all(color: s.strokeCard, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cabeçalho ─────────────────────────────────
                if (title != null || titleWidget != null)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(kSpaceXXL, kSpaceXXL, kSpaceXXL, 0),
                    child: titleWidget ??
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: kTypeBodyStrong,
                            fontWeight: FontWeight.w600,
                            color: s.onSurface,
                          ),
                        ),
                  ),

                // ── Conteúdo ──────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    kSpaceXXL,
                    title != null || titleWidget != null ? kSpaceL : kSpaceXXL,
                    kSpaceXXL,
                    kSpaceXXL,
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: kTypeBody,
                      color: s.onSurfaceVariant,
                      height: 1.5,
                    ),
                    child: content,
                  ),
                ),

                // ── Divisor ───────────────────────────────────
                FluentDivider(s: s),

                // ── Ações ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(kSpaceM),
                  child: actions.length == 1
                      ? actions.first._build(context, s, fullWidth: true)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions
                              .map((a) => Padding(
                                    padding:
                                        const EdgeInsets.only(left: kSpaceS),
                                    child: a._build(context, s),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FluentDialogAction {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool destructive;

  const FluentDialogAction({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
  });

  Widget _build(BuildContext context, AppColorScheme s, {bool fullWidth = false}) {
    return FluentButton(
      s: s,
      label: label,
      onTap: onTap,
      style: destructive
          ? FluentButtonStyle.destructive
          : primary
              ? FluentButtonStyle.primary
              : FluentButtonStyle.secondary,
      fullWidth: fullWidth,
    );
  }
}

Future<T?> showFluentDialog<T>({
  required BuildContext context,
  required AppColorScheme s,
  required Widget content,
  required List<FluentDialogAction> actions,
  String? title,
  Widget? titleWidget,
  double? maxWidth,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: s.barrier,
    builder: (_) => FluentDialog(
      s: s,
      title: title,
      titleWidget: titleWidget,
      content: content,
      actions: actions,
      maxWidth: maxWidth,
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// FLUENT BUTTON
//
// Quatro estilos: primary, secondary, ghost, destructive.
// Dimensões: height 32px (compact) ou 36px (default).
// ══════════════════════════════════════════════════════════════

enum FluentButtonStyle { primary, secondary, ghost, destructive }
enum FluentButtonSize { compact, regular }

class FluentButton extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final VoidCallback? onTap;
  final FluentButtonStyle style;
  final FluentButtonSize size;
  final String? iconAsset;
  final bool fullWidth;
  final bool loading;

  const FluentButton({
    super.key,
    required this.s,
    required this.label,
    required this.onTap,
    this.style = FluentButtonStyle.secondary,
    this.size = FluentButtonSize.regular,
    this.iconAsset,
    this.fullWidth = false,
    this.loading = false,
  });

  @override
  State<FluentButton> createState() => _FluentButtonState();
}

class _FluentButtonState extends State<FluentButton> {
  bool _h = false;
  bool _p = false;

  Color _bg(AppColorScheme s) {
    final base = switch (widget.style) {
      FluentButtonStyle.primary     => s.accentFillDefault,
      FluentButtonStyle.secondary   => s.controlDefault,
      FluentButtonStyle.ghost       => Colors.transparent,
      FluentButtonStyle.destructive => s.error,
    };
    if (widget.onTap == null) {
      return switch (widget.style) {
        FluentButtonStyle.primary     => s.accentFillDisabled,
        FluentButtonStyle.destructive => s.error.withOpacity(0.45),
        _                             => s.controlDisabled,
      };
    }
    if (_p) {
      return switch (widget.style) {
        FluentButtonStyle.primary     => s.accentFillPressed,
        FluentButtonStyle.secondary   => s.subtleFillPressed,
        FluentButtonStyle.ghost       => s.subtleFillPressed,
        FluentButtonStyle.destructive => s.errorHover,
      };
    }
    if (_h) {
      return switch (widget.style) {
        FluentButtonStyle.primary     => s.accentFillHover,
        FluentButtonStyle.secondary   => s.subtleFillHover,
        FluentButtonStyle.ghost       => s.subtleFillHover,
        FluentButtonStyle.destructive => s.error.withOpacity(0.88),
      };
    }
    return base;
  }

  Color _fg(AppColorScheme s) {
    if (widget.onTap == null) {
      return s.onSurfaceDisabled;
    }
    return switch (widget.style) {
      FluentButtonStyle.primary     => s.onPrimary,
      FluentButtonStyle.secondary   => s.onSurface,
      FluentButtonStyle.ghost       => s.onSurface,
      FluentButtonStyle.destructive => s.onError,
    };
  }

  Border? _border(AppColorScheme s) {
    if (widget.style == FluentButtonStyle.secondary) {
      return Border.all(color: s.controlStroke, width: 1);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final enabled = widget.onTap != null && !widget.loading;
    final h = widget.size == FluentButtonSize.regular ? 36.0 : 30.0;
    final hPad = widget.size == FluentButtonSize.regular ? 16.0 : 12.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() { _h = true; _p = true; }) : null,
      onTapCancel: enabled ? () => setState(() { _h = false; _p = false; }) : null,
      onTapUp: enabled ? (_) => setState(() { _h = false; _p = false; }) : null,
      onTap: enabled ? widget.onTap : null,
      onLongPressCancel: enabled ? () => setState(() { _h = false; _p = false; }) : null,
      child: AnimatedContainer(
        duration: kDurationFast,
        height: h,
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _bg(s),
          borderRadius: BorderRadius.circular(kRadiusMedium),
          border: _border(s),
        ),
        child: widget.loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_fg(s)),
                ),
              )
            : Row(
                mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.iconAsset != null) ...[
                    AppIcon(widget.iconAsset!, color: _fg(s), size: 16),
                    const SizedBox(width: kSpaceXS),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: kTypeBody,
                      fontWeight: FontWeight.w400,
                      color: _fg(s),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FLUENT TEXT FIELD
//
// Linha de fundo Fluent (underline focus) + borda neutra.
// Suporte a label acima, hint, mensagem de erro, ícone sufixo.
// ══════════════════════════════════════════════════════════════

class FluentTextField extends StatefulWidget {
  final AppColorScheme s;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final bool autofocus;
  final bool enabled;
  final TextCapitalization textCapitalization;

  const FluentTextField({
    super.key,
    required this.s,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.suffix,
    this.autofocus = false,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<FluentTextField> createState() => _FluentTextFieldState();
}

class _FluentTextFieldState extends State<FluentTextField> {
  late FocusNode _focus;
  bool _focused = false;
  bool _obscureNow = false;

  @override
  void initState() {
    super.initState();
    _obscureNow = widget.obscure;
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final hasError = widget.error != null && widget.error!.isNotEmpty;
    final borderColor = hasError
        ? s.error
        : _focused
            ? s.primary
            : s.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: kTypeCaption,
              fontWeight: FontWeight.w600,
              color: s.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kSpaceXS),
        ],
        AnimatedContainer(
          duration: kDurationFast,
          decoration: BoxDecoration(
            color: widget.enabled ? s.controlInputActive : s.controlDisabled,
            borderRadius: BorderRadius.circular(kRadiusMedium),
            border: Border.all(
              color: borderColor,
              width: _focused ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: _obscureNow,
                  keyboardType: widget.keyboardType,
                  maxLines: _obscureNow ? 1 : widget.maxLines,
                  minLines: widget.minLines,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  textCapitalization: widget.textCapitalization,
                  style: TextStyle(
                    fontSize: kTypeBody,
                    color: widget.enabled ? s.onSurface : s.onSurfaceDisabled,
                  ),
                  cursorColor: s.primary,
                  onChanged: widget.onChanged,
                  onEditingComplete: widget.onEditingComplete,
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: kSpaceL,
                      vertical: kSpaceM,
                    ),
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      fontSize: kTypeBody,
                      color: s.onSurfaceTertiary,
                    ),
                  ),
                ),
              ),
              if (widget.obscure) ...[
                GestureDetector(
                  onTap: () => setState(() => _obscureNow = !_obscureNow),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpaceM),
                    child: AppIcon(
                      _obscureNow ? 'eye.svg' : 'eye_off.svg',
                      color: s.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                ),
              ] else if (widget.suffix != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: kSpaceM),
                  child: widget.suffix!,
                ),
              ],
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: kSpaceXS),
          Row(
            children: [
              AppIcon('error.svg', color: s.error, size: 12),
              const SizedBox(width: kSpaceXXS),
              Expanded(
                child: Text(
                  widget.error!,
                  style: TextStyle(fontSize: kTypeCaption, color: s.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FLUENT DIVIDER
// ══════════════════════════════════════════════════════════════

class FluentDivider extends StatelessWidget {
  final AppColorScheme s;
  final EdgeInsetsGeometry? margin;

  const FluentDivider({super.key, required this.s, this.margin});

  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? EdgeInsets.zero,
        height: 1,
        color: s.strokeDivider,
      );
}

// ══════════════════════════════════════════════════════════════
// FLUENT LIST CARD + LIST GROUP
//
// Card de lista padrão — estilo idêntico ao Settings da app.
// FluentListGroup agrupa N FluentListCard com radius Fluent:
//   • Primeiro card: radius grande no topo, pequeno na base
//   • Cards intermédios: radius pequeno em todos os cantos
//   • Último card: radius pequeno no topo, grande na base
//   • Card único: radius grande em todos os cantos
// Separação entre cards: 2px, fundo cardBackground.
// ══════════════════════════════════════════════════════════════

class FluentListCard extends StatefulWidget {
  final AppColorScheme s;
  final Widget? leading;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final bool showChevron;
  final bool disabled;

  const FluentListCard({
    super.key,
    required this.s,
    required this.label,
    required this.radius,
    this.leading,
    this.subtitle,
    this.labelColor,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.disabled = false,
  });

  @override
  State<FluentListCard> createState() => _FluentListCardState();
}

class _FluentListCardState extends State<FluentListCard> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final enabled = widget.onTap != null && !widget.disabled;

    return Opacity(
      opacity: widget.disabled ? 0.5 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _p = true) : null,
        onTapCancel: enabled ? () => setState(() => _p = false) : null,
        onTapUp: enabled ? (_) => setState(() => _p = false) : null,
        onTap: enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: kDurationFast,
          padding: const EdgeInsets.symmetric(
            horizontal: kSpaceL,
            vertical: kSpaceM + 2,
          ),
          decoration: BoxDecoration(
            color: _p ? s.subtleFillPressed : s.cardBackground,
            borderRadius: widget.radius,
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: kSpaceM),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: kTypeBody,
                        color: widget.labelColor ?? s.onSurface,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: kTypeCaption,
                          color: s.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: kSpaceM),
                widget.trailing!,
              ],
              if (widget.showChevron) ...[
                const SizedBox(width: kSpaceS),
                AppIcon('chevron_right.svg',
                    color: s.onSurfaceVariant, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Radii partilhados pelas ListCard
const double _kCardOuter = 6.0;
const double _kCardInner = 2.0;

BorderRadius _listCardRadius(int index, int total) {
  if (total == 1) return BorderRadius.circular(_kCardOuter);
  final isFirst = index == 0;
  final isLast = index == total - 1;
  return BorderRadius.only(
    topLeft: Radius.circular(isFirst ? _kCardOuter : _kCardInner),
    topRight: Radius.circular(isFirst ? _kCardOuter : _kCardInner),
    bottomLeft: Radius.circular(isLast ? _kCardOuter : _kCardInner),
    bottomRight: Radius.circular(isLast ? _kCardOuter : _kCardInner),
  );
}

class FluentListGroup extends StatelessWidget {
  final AppColorScheme s;
  final String? label;
  final List<FluentListCard Function(BorderRadius radius)> builders;

  const FluentListGroup({
    super.key,
    required this.s,
    required this.builders,
    this.label,
  });

  /// Atalho para construir grupos a partir de itens simples.
  static Widget simple({
    required AppColorScheme s,
    required List<_FluentListGroupItem> items,
    String? label,
  }) {
    return FluentListGroup(
      s: s,
      label: label,
      builders: List.generate(
        items.length,
        (i) => (radius) => FluentListCard(
              s: s,
              label: items[i].label,
              subtitle: items[i].subtitle,
              labelColor: items[i].labelColor,
              leading: items[i].leading,
              trailing: items[i].trailing,
              onTap: items[i].onTap,
              showChevron: items[i].showChevron,
              disabled: items[i].disabled,
              radius: radius,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = builders.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          _FluentSectionLabel(s: s, label: label!),
          const SizedBox(height: kSpaceS),
        ],
        for (int i = 0; i < total; i++) ...[
          builders[i](_listCardRadius(i, total)),
          if (i < total - 1) const SizedBox(height: 2),
        ],
      ],
    );
  }
}

class _FluentListGroupItem {
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool disabled;

  const _FluentListGroupItem({
    required this.label,
    this.subtitle,
    this.labelColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.disabled = false,
  });
}

// Construtor de item para usar com FluentListGroup.simple
_FluentListGroupItem fluentItem({
  required String label,
  String? subtitle,
  Color? labelColor,
  Widget? leading,
  Widget? trailing,
  VoidCallback? onTap,
  bool showChevron = false,
  bool disabled = false,
}) =>
    _FluentListGroupItem(
      label: label,
      subtitle: subtitle,
      labelColor: labelColor,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      showChevron: showChevron,
      disabled: disabled,
    );

// ══════════════════════════════════════════════════════════════
// FLUENT SECTION LABEL
// ══════════════════════════════════════════════════════════════

class _FluentSectionLabel extends StatelessWidget {
  final AppColorScheme s;
  final String label;

  const _FluentSectionLabel({required this.s, required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: kTypeCaption,
          fontWeight: FontWeight.w600,
          color: s.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      );
}

// Versão pública para uso fora do ficheiro
class FluentSectionLabel extends StatelessWidget {
  final AppColorScheme s;
  final String label;

  const FluentSectionLabel({super.key, required this.s, required this.label});

  @override
  Widget build(BuildContext context) => _FluentSectionLabel(s: s, label: label);
}

// ══════════════════════════════════════════════════════════════
// FLUENT POPUP CONTAINER
//
// Container padrão para menus flutuantes / overlays.
// Idêntico ao floatingSurface + floatingShadow + radius 8.
// ══════════════════════════════════════════════════════════════

class FluentPopupContainer extends StatelessWidget {
  final AppColorScheme s;
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;

  const FluentPopupContainer({
    super.key,
    required this.s,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(kSpaceS),
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: s.floatingSurface,
          borderRadius: BorderRadius.circular(kRadiusLarge),
          boxShadow: s.elevation8,
          border: Border.all(color: s.strokeCard, width: 1),
        ),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════
// FLUENT CHIP
//
// Pill label — para badges, filtros, tags.
// ══════════════════════════════════════════════════════════════

enum FluentChipStyle { accent, neutral, success, warning, error }

class FluentChip extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final FluentChipStyle style;
  final String? iconAsset;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const FluentChip({
    super.key,
    required this.s,
    required this.label,
    this.style = FluentChipStyle.neutral,
    this.iconAsset,
    this.onTap,
    this.onRemove,
  });

  Color _bg() => switch (style) {
        FluentChipStyle.accent  => s.primaryContainer,
        FluentChipStyle.neutral => s.subtleFillHover,
        FluentChipStyle.success => s.successContainer,
        FluentChipStyle.warning => s.warningContainer,
        FluentChipStyle.error   => s.errorContainer,
      };

  Color _fg() => switch (style) {
        FluentChipStyle.accent  => s.onPrimaryContainer,
        FluentChipStyle.neutral => s.onSurface,
        FluentChipStyle.success => s.onSuccessContainer,
        FluentChipStyle.warning => s.onWarningContainer,
        FluentChipStyle.error   => s.onErrorContainer,
      };

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconAsset != null) ...[
          AppIcon(iconAsset!, color: _fg(), size: 12),
          const SizedBox(width: kSpaceXXS),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: kTypeCaption,
            fontWeight: FontWeight.w600,
            color: _fg(),
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: kSpaceXXS),
          GestureDetector(
            onTap: onRemove,
            child: AppIcon('close.svg', color: _fg(), size: 10),
          ),
        ],
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceS + 2,
          vertical: kSpaceXXS + 2,
        ),
        decoration: BoxDecoration(
          color: _bg(),
          borderRadius: BorderRadius.circular(kRadiusCircle),
        ),
        child: content,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FLUENT ICON BUTTON
//
// Botão circular com ícone — hover/pressed fill sutil.
// ══════════════════════════════════════════════════════════════

class FluentIconButton extends StatefulWidget {
  final AppColorScheme s;
  final String asset;
  final double iconSize;
  final double containerSize;
  final Color? color;
  final Color? bgColor;
  final VoidCallback? onTap;
  final String? tooltip;

  const FluentIconButton({
    super.key,
    required this.s,
    required this.asset,
    this.iconSize = 18,
    this.containerSize = 32,
    this.color,
    this.bgColor,
    this.onTap,
    this.tooltip,
  });

  @override
  State<FluentIconButton> createState() => _FluentIconButtonState();
}

class _FluentIconButtonState extends State<FluentIconButton> {
  bool _h = false;
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final enabled = widget.onTap != null;
    final iconColor = widget.color ?? s.onSurface;
    final baseBg = widget.bgColor ?? Colors.transparent;

    final bg = _p
        ? s.subtleFillPressed
        : _h
            ? s.subtleFillHover
            : baseBg;

    final btn = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() { _h = true; _p = true; }) : null,
      onTapCancel: enabled ? () => setState(() { _h = false; _p = false; }) : null,
      onTapUp: enabled ? (_) => setState(() { _h = false; _p = false; }) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: kDurationFast,
        width: widget.containerSize,
        height: widget.containerSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(kRadiusMedium),
        ),
        child: AppIcon(
          widget.asset,
          color: enabled ? iconColor : s.onSurfaceDisabled,
          size: widget.iconSize,
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

// ══════════════════════════════════════════════════════════════
// FLUENT PROGRESS BAR
// ══════════════════════════════════════════════════════════════

class FluentProgressBar extends StatelessWidget {
  final AppColorScheme s;
  final double? value;
  final double height;
  final Color? color;

  const FluentProgressBar({
    super.key,
    required this.s,
    this.value,
    this.height = 4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = s.controlTertiary;
    final fillColor = color ?? s.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusCircle),
      child: Container(
        height: height,
        color: trackColor,
        child: value != null
            ? FractionallySizedBox(
                widthFactor: value!.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(color: fillColor),
              )
            : LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(fillColor),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FLUENT SHIMMER (skeleton loader)
// ══════════════════════════════════════════════════════════════

class FluentShimmer extends StatefulWidget {
  final AppColorScheme s;
  final double width;
  final double height;
  final double radius;

  const FluentShimmer({
    super.key,
    required this.s,
    required this.width,
    required this.height,
    this.radius = kRadiusMedium,
  });

  @override
  State<FluentShimmer> createState() => _FluentShimmerState();
}

class _FluentShimmerState extends State<FluentShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + (_anim.value * 3), 0),
            end: Alignment(-0.5 + (_anim.value * 3), 0),
            colors: [
              s.shimmerBase,
              s.shimmerHighlight,
              s.shimmerBase,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// COMPATIBILIDADE COM CÓDIGO ANTERIOR
// (SettingsStyleCard / SheetOptionsGroup — usados em aitab.dart,
//  settingsscreen.dart, etc. — agora delegam nos novos componentes
//  sem quebrar nenhuma chamada existente)
// ══════════════════════════════════════════════════════════════

/// @deprecated  Usa FluentListCard + FluentListGroup em código novo.
class SettingsStyleCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final Widget child;

  const SettingsStyleCard({
    super.key,
    required this.s,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: radius,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

/// @deprecated  Usa FluentListGroup em código novo.
class SheetOptionsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> options;

  const SheetOptionsGroup({
    super.key,
    required this.s,
    required this.options,
  });

  static const double _outerRadius = 6.0;
  static const double _innerRadius = 2.0;
  static const double _gap = 2.0;

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
            radius: _listCardRadius(i, count),
            child: options[i],
          ),
        ],
      ],
    );
  }
}