import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// FLOATING NAV — label aparece à direita do ícone ao selecionar
// ══════════════════════════════════════════════════════════════

class FloatingNav extends StatelessWidget {
  final AppColorScheme s;
  final int index;
  final ValueChanged<int> onChanged;

  const FloatingNav({
    super.key,
    required this.s,
    required this.index,
    required this.onChanged,
  });

  static const _tabs = [
    (svg: 'ai_tab.svg',       svgFilled: 'ai_tab_filled.svg',      label: 'IA'),
    (svg: 'edit_tab.svg',     svgFilled: 'edit_tab_filled.svg',    label: 'Editor'),
    (svg: 'template_tab.svg', svgFilled: 'template_tab_filled.svg', label: 'Templates'),
  ];

  static const double _iconW  = 44.0;
  static const double _height = 54.0;
  static const double _pad    = 5.0;

  @override
  Widget build(BuildContext context) {
    // Cor do fundo: igual modo escuro independente do tema (2C2C2E)
    const bgColor = Color(0xFF2C2C2E);

    return Material(
      color: Colors.transparent,
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          boxShadow: s.floatingShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: _pad),
                ...List.generate(_tabs.length, (i) {
                  final t   = _tabs[i];
                  final sel = index == i;

                  // Ícone: branco/opaco se selecionado, cinza se não
                  final iconColor = sel
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF8E8E93);

                  // Indicador selecionado usa primaryContainer do tema
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: kCupertinoOut,
                      margin: const EdgeInsets.symmetric(vertical: _pad),
                      padding: EdgeInsets.symmetric(
                        horizontal: sel ? 10.0 : 8.0,
                        vertical: 0,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? s.primaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: _iconW - 16,
                            height: _height - _pad * 2,
                            child: Center(
                              child: AnimatedScale(
                                scale: sel ? 1.1 : 1.0,
                                duration: const Duration(milliseconds: 260),
                                curve: kCupertinoOut,
                                child: AppIcon(
                                  sel ? t.svgFilled : t.svg,
                                  color: iconColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Label cresce da esquerda suavemente
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: kCupertinoOut,
                            child: sel
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(
                                      t.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: s.onPrimaryContainer,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(width: _pad),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO PROJETOS — azul sólido fixo, sem sombra colorida
// ══════════════════════════════════════════════════════════════

class ProjectsButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const ProjectsButton({super.key, required this.s, required this.onTap});

  @override
  State<ProjectsButton> createState() => _ProjectsButtonState();
}

class _ProjectsButtonState extends State<ProjectsButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    // Sempre azul sólido da cor primária do modo claro — sem glow
    const btnColor = Color(0xFF2F7BF6);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: kCupertinoOut,
        child: Container(
          width: 54,
          height: 54,
          // Mesmo comprimento que o nav (54px de altura)
          decoration: BoxDecoration(
            color: btnColor,
            borderRadius: BorderRadius.circular(999),
            // SEM boxShadow colorida — apenas sombra neutra
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AppIcon('projects.svg', color: Colors.white, size: 22),
        ),
      ),
    );
  }
}