import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      color: s.pageBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            _BackCircleButton(s: s, onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}

class _BackCircleButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _BackCircleButton({required this.s, required this.onTap});
  @override
  State<_BackCircleButton> createState() => _BackCircleButtonState();
}

class _BackCircleButtonState extends State<_BackCircleButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: widget.s.cardShadow,
          ),
          child: AppIcon('back', size: 18, color: widget.s.onSurface),
        ),
      ),
    );
  }
}