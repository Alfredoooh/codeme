// ══════════════════════════════════════════════════════════════
// FILE: lib/home/home.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../colors.dart';
import '../widgets.dart';
import '../templatestab.dart';
import '../projectstab.dart';
import '../aitab.dart' show LocalCanvasItem;
import 'agendatab.dart';

// ══════════════════════════════════════════════════════════════
// HOME TAB ENUM
// ══════════════════════════════════════════════════════════════

enum HomeTab { templates, projects, agenda }

extension HomeTabX on HomeTab {
  String get svg       => const {
        HomeTab.templates: 'templates_tab.svg',
        HomeTab.projects:  'projects_tab.svg',
        HomeTab.agenda:    'agenda_tab.svg',
      }[this]!;

  String get svgFilled => const {
        HomeTab.templates: 'templates_tab_filled.svg',
        HomeTab.projects:  'projects_tab_filled.svg',
        HomeTab.agenda:    'agenda_tab_filled.svg',
      }[this]!;

  String get label => const {
        HomeTab.templates: 'Templates',
        HomeTab.projects:  'Projetos',
        HomeTab.agenda:    'Agenda',
      }[this]!;
}

// ══════════════════════════════════════════════════════════════
// HOME SCREEN — tela principal com bottom tab bar (templates,
// projetos, agenda). Aberta a partir do botão de home no drawer.
// A tab inicial do APP continua a ser aitab (RootShell), esta tela é
// apenas empurrada por cima quando o utilizador navega para "home".
// ══════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  /// Chamado quando o utilizador toca num template ou ficheiro de
  /// projeto. A Home fecha-se e o RootShell abre o documento no editor.
  final ValueChanged<LocalCanvasItem>? onOpenDocument;

  const HomeScreen({super.key, this.onOpenDocument});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.projects;

  void _selectTab(HomeTab t) {
    if (t != _tab) setState(() => _tab = t);
  }

  void _openDocument(LocalCanvasItem item) {
    Navigator.of(context).pop();
    widget.onOpenDocument?.call(item);
  }

  Widget _buildTab() {
    switch (_tab) {
      case HomeTab.templates:
        return TemplatesTab(onOpenTemplate: _openDocument);
      case HomeTab.projects:
        return ProjectsTab(onOpenFile: _openDocument);
      case HomeTab.agenda:
        return const AgendaTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      color: s.surface,
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: kCupertinoOut,
            switchOutCurve: kCupertinoIn,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(key: ValueKey(_tab), child: _buildTab()),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _HomeBottomBar(s: s, current: _tab, onSelect: _selectTab),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HOME BOTTOM BAR — estilo customizado, mesmo padrão de cor do
// tab ativo do drawer (escuro não profundo no dark, branco levemente
// azulado no light — s.navIndicatorBg / s.navLabelActive).
// ══════════════════════════════════════════════════════════════

class _HomeBottomBar extends StatelessWidget {
  final AppColorScheme s;
  final HomeTab current;
  final ValueChanged<HomeTab> onSelect;
  const _HomeBottomBar({required this.s, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: s.navBarBg,
            borderRadius: BorderRadius.circular(28),
            boxShadow: s.navBarShadow,
          ),
          child: Row(
            children: [
              for (final tab in HomeTab.values)
                Expanded(
                  child: _HomeBottomBarItem(
                    s: s,
                    tab: tab,
                    selected: current == tab,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _HomeBottomBarItem extends StatefulWidget {
  final AppColorScheme s;
  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;
  const _HomeBottomBarItem({
    required this.s,
    required this.tab,
    required this.selected,
    required this.onTap,
  });
  @override State<_HomeBottomBarItem> createState() => _HomeBottomBarItemState();
}

class _HomeBottomBarItemState extends State<_HomeBottomBarItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final sel = widget.selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: kCupertinoOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: sel
              ? s.navIndicatorBg
              : (_pressed ? s.hover : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(
            sel ? widget.tab.svgFilled : widget.tab.svg,
            color: sel ? s.navLabelActive : s.navIconInactive,
            size: 21,
          ),
          const SizedBox(height: 3),
          Text(
            widget.tab.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? s.navLabelActive : s.navIconInactive,
            ),
          ),
        ]),
      ),
    );
  }
}