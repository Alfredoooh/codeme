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
        AppTab.projects:  'projects.svg',      // mesmo ícone — azul sólido
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
// • Pill flutuante — branco no tema claro, #2C2C2E no escuro
// • Tabs IA / Editor / Templates com label animado
// • Tab Projetos: pill azul sólido à direita (sempre)
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
  // Tabs do lado esquerdo (pill principal)
  static const _mainTabs = [AppTab.ai, AppTab.edit, AppTab.templates];

  static const double _height = 54.0;
  static const double _pad    =  5.0;

  // Spring para o botão de projetos (scale press)
  bool _projectsPressed = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Pill principal (IA / Editor / Templates) ───────────
        _MainPill(
          s: widget.s,
          tabs: _mainTabs,
          current: widget.current,
          onChanged: widget.onChanged,
          height: _height,
          pad: _pad,
        ),

        // ── Pill projetos ──────────────────────────────────────
        _ProjectsPill(
          s: widget.s,
          selected: widget.current == AppTab.projects,
          onTap: () => widget.onChanged(AppTab.projects),
          size: _height,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PILL PRINCIPAL — IA | Editor | Templates
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
          // ← CORRECÇÃO PRINCIPAL: usa navBarBg que varia com o tema
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
                ...tabs.map((tab) => _MainTab(
                      s: s,
                      tab: tab,
                      selected: current == tab,
                      onTap: () => onChanged(tab),
                      height: height,
                      pad: pad,
                    )),
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
// TAB ITEM (dentro da pill principal)
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
                width:  28,
                height: widget.height - widget.pad * 2,
                child: Center(
                  child: AnimatedScale(
                    scale: sel ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 260),
                    curve: kCupertinoOut,
                    child: AppIcon(
                      sel ? widget.tab.svgFilled : widget.tab.svg,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // Label cresce suavemente quando seleccionado
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
// PILL PROJETOS — azul sólido, sempre à direita
// ══════════════════════════════════════════════════════════════

class _ProjectsPill extends StatefulWidget {
  final AppColorScheme s;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  const _ProjectsPill({
    required this.s,
    required this.selected,
    required this.onTap,
    required this.size,
  });

  @override
  State<_ProjectsPill> createState() => _ProjectsPillState();
}

class _ProjectsPillState extends State<_ProjectsPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s   = widget.s;
    final sel = widget.selected;

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
          width:  widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: s.projectsTabBg,
            borderRadius: BorderRadius.circular(999),
            // Anel branco quando seleccionado
            border: sel
                ? Border.all(color: Colors.white.withOpacity(0.45), width: 2.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F7BF6).withOpacity(sel ? 0.40 : 0.22),
                blurRadius: sel ? 18 : 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: sel ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 260),
            curve: kCupertinoOut,
            child: AppIcon(AppTab.projects.svg, color: s.projectsTabFg, size: 22),
          ),
        ),
      ),
    );
  }
}