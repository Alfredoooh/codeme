import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';

class ScheduledTasksScreen extends StatelessWidget {
  const ScheduledTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      color: s.pageBackground,
      child: SafeArea(
        child: Stack(
          children: [
            // ── Conteúdo do ecrã (placeholder para a lista de tarefas) ──
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 70),
                child: Center(
                  child: Text(
                    'Sem tarefas agendadas',
                    style: TextStyle(
                      fontSize: 14,
                      color: s.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

            // ── Appbar transparente progressivo, sem título ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      s.pageBackground,
                      s.pageBackground.withOpacity(0.4),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    _BackCircleButton(
                      s: s,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: s.cardShadow,
        ),
        child: AppIcon('back', size: 18, color: s.onSurface),
      ),
    );
  }
}