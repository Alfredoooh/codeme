import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// TEMPLATES TAB
// ══════════════════════════════════════════════════════════════

class TemplatesTab extends StatelessWidget {
  const TemplatesTab({super.key});

  static const _categories = [
    'Todos', 'Documentos', 'Apresentações', 'Folhas', 'Quadros'
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Text('Templates',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: s.onSurface)),
      ),
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) =>
              _CategoryChip(s: s, label: _categories[i], selected: i == 0),
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppIcon('doc_text.svg', size: 48, color: s.onSurfaceVariant.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text('Sem templates ainda',
                style: TextStyle(fontSize: 15, color: s.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Em breve',
                style: TextStyle(
                    fontSize: 13,
                    color: s.onSurfaceVariant.withOpacity(0.55))),
          ]),
        ),
      ),
    ]);
  }
}

class _CategoryChip extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final bool selected;
  const _CategoryChip(
      {required this.s, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: kCupertinoOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? s.primary : s.outline.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? s.onPrimary : s.onSurfaceVariant,
            )),
      );
}