import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// TABS — 4 tabs: IA | Editor | Templates | Projetos
// ══════════════════════════════════════════════════════════════

enum AppTab { ai, edit, templates, projects }

extension AppTabX on AppTab {
  String get svg       => const {
        AppTab.ai:        'ai_tab.svg',
        AppTab.edit:      'edit_tab.svg',
        AppTab.templates: 'templates.svg',
        AppTab.projects:  'projects.svg',
      }[this]!;

  String get svgFilled => const {
        AppTab.ai:        'ai_tab_filled.svg',
        AppTab.edit:      'edit_tab_filled.svg',
        AppTab.templates: 'templates_filled.svg',
        AppTab.projects:  'projects_filled.svg',
      }[this]!;

  String get label => const {
        AppTab.ai:        'IA',
        AppTab.edit:      'Editor',
        AppTab.templates: 'Templates',
        AppTab.projects:  'Projetos',
      }[this]!;

  bool get isProjects => this == AppTab.projects;
}

// ══════════════════════════════════════════════════════════════
// FLOATING BOTTOM TAB BAR
// ──────────────────────────────────────────────────────────────
// • Pill flutuante única — branco no tema claro, #2C2C2E no escuro
// • Todas as 4 tabs (IA / Editor / Templates / Projetos) na mesma pill
// • Projetos mantém o destaque azul sólido quando seleccionado,
//   e troca para o ícone filled ao ser clicado, como as outras tabs
// • Barra centralizada no eixo horizontal, ícones maiores
// • Animações: scale, opacity, AnimatedSize no label, spring
// ══════════════════════════════════════════════════════════════

class BottomTabBar extends StatefulWidget {
  final AppColorScheme s;
  final AppTab current;
  final ValueChanged<AppTab> onChanged;

  const BottomTabBar({
    super.key,
    required this.s,
    required this.current,
    required this.onChanged,
  });

  @override
  State<BottomTabBar> createState() => _BottomTabBarState();
}

class _BottomTabBarState extends State<BottomTabBar>
    with SingleTickerProviderStateMixin {
  static const _allTabs = [
    AppTab.ai,
    AppTab.edit,
    AppTab.templates,
    AppTab.projects,
  ];

  static const double _height = 58.0;
  static const double _pad    =  5.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _MainPill(
        s: widget.s,
        tabs: _allTabs,
        current: widget.current,
        onChanged: widget.onChanged,
        height: _height,
        pad: _pad,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PILL PRINCIPAL — IA | Editor | Templates | Projetos
// ══════════════════════════════════════════════════════════════

class _MainPill extends StatelessWidget {
  final AppColorScheme s;
  final List<AppTab> tabs;
  final AppTab current;
  final ValueChanged<AppTab> onChanged;
  final double height;
  final double pad;

  const _MainPill({
    required this.s,
    required this.tabs,
    required this.current,
    required this.onChanged,
    required this.height,
    required this.pad,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: kCupertinoOut,
        height: height,
        decoration: BoxDecoration(
          color: s.navBarBg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: s.navBarShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: pad),
                for (final tab in tabs)
                  tab.isProjects
                      ? _ProjectsTab(
                          s: s,
                          selected: current == tab,
                          onTap: () => onChanged(tab),
                          height: height,
                          pad: pad,
                        )
                      : _MainTab(
                          s: s,
                          tab: tab,
                          selected: current == tab,
                          onTap: () => onChanged(tab),
                          height: height,
                          pad: pad,
                        ),
                SizedBox(width: pad),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB ITEM (IA / Editor / Templates)
// ══════════════════════════════════════════════════════════════

class _MainTab extends StatefulWidget {
  final AppColorScheme s;
  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double pad;

  const _MainTab({
    required this.s,
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.height,
    required this.pad,
  });

  @override
  State<_MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<_MainTab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s   = widget.s;
    final sel = widget.selected;

    final iconColor = sel ? s.navIconActive : s.navIconInactive;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: kCupertinoOut,
          margin: EdgeInsets.symmetric(vertical: widget.pad),
          padding: EdgeInsets.symmetric(
            horizontal: sel ? 10.0 : 8.0,
            vertical: 0,
          ),
          decoration: BoxDecoration(
            color: sel ? s.navIndicatorBg : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width:  32,
                height: widget.height - widget.pad * 2,
                child: Center(
                  child: AnimatedScale(
                    scale: sel ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 260),
                    curve: kCupertinoOut,
                    child: AppIcon(
                      sel ? widget.tab.svgFilled : widget.tab.svg,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: kCupertinoOut,
                child: sel
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          widget.tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: s.navLabelActive,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TAB PROJETOS — dentro da mesma pill; troca para ícone filled
// e cápsula azul quando seleccionado, igual às outras tabs
// ══════════════════════════════════════════════════════════════

class _ProjectsTab extends StatefulWidget {
  final AppColorScheme s;
  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double pad;

  const _ProjectsTab({
    required this.s,
    required this.selected,
    required this.onTap,
    required this.height,
    required this.pad,
  });

  @override
  State<_ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<_ProjectsTab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s   = widget.s;
    final sel = widget.selected;

    final double innerHeight = widget.height - widget.pad * 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: kCupertinoOut,
          margin: EdgeInsets.symmetric(vertical: widget.pad),
          padding: EdgeInsets.symmetric(
            horizontal: sel ? 14.0 : 8.0,
            vertical: 0,
          ),
          height: innerHeight,
          decoration: BoxDecoration(
            color: sel ? s.projectsTabBg : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: sel
                ? Border.all(color: Colors.white.withOpacity(0.45), width: 2.0)
                : null,
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: const Color(0xFF2F7BF6).withOpacity(0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: sel ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: kCupertinoOut,
                child: AppIcon(
                  sel ? AppTab.projects.svgFilled : AppTab.projects.svg,
                  color: sel ? s.projectsTabFg : s.navIconInactive,
                  size: 24,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: kCupertinoOut,
                child: sel
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          AppTab.projects.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: s.projectsTabFg,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}