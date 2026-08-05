import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme.dart';

// ══════════════════════════════════════════════════════════════
// ÍCONES SVG
// ══════════════════════════════════════════════════════════════

class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;
  const AppIcon(this.asset, {super.key, this.size = 20, required this.color});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/svg/$asset',
        width: size, height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
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
          curve: kCupertinoOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.size, height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _p ? widget.s.pressed : Colors.transparent,
              borderRadius: BorderRadius.circular(widget.s.pressed == widget.s.pressed ? widget.size / 2 : widget.size / 2),
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