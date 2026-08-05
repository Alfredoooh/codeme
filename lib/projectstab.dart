import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'colors.dart';

// ══════════════════════════════════════════════════════════════
// PROJECTS TAB — ecrã completo de projetos
// ══════════════════════════════════════════════════════════════

class ProjectsTab extends StatelessWidget {
  const ProjectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Text('Projetos',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.add, size: 14, color: s.onPrimary),
                const SizedBox(width: 4),
                Text('Novo',
                    style: TextStyle(
                        fontSize: 13,
                        color: s.onPrimary,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),

      // Conteúdo vazio
      Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(CupertinoIcons.folder,
                size: 52, color: s.onSurfaceVariant.withOpacity(0.35)),
            const SizedBox(height: 14),
            Text('Sem projetos ainda',
                style: TextStyle(fontSize: 16, color: s.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('Cria o teu primeiro projeto',
                style: TextStyle(
                    fontSize: 13,
                    color: s.onSurfaceVariant.withOpacity(0.55))),
          ]),
        ),
      ),
      // Espaço para a nav bar
      const SizedBox(height: 84),
    ]);
  }
}