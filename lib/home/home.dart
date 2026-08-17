// ══════════════════════════════════════════════════════════════
// FILE: lib/home/home.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
// HOME SCREEN
// ══════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
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
            duration: kDurationSlow,
            switchInCurve: kFluentDecelerate,
            switchOutCurve: kFluentAccelerate,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(key: ValueKey(_tab), child: _buildTab()),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _HomeNavigationBar(s: s, current: _tab, onSelect: _selectTab),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NAVIGATION BAR — Material 3 NavigationBar nativo. Pill indicator,
// animação de seleção e ripple são os do próprio widget; só as
// cores são redirecionadas para s.* via NavigationBarThemeData.
//
// NOTA SOBRE O ÍCONE: NavigationBar pinta o Icon() dele via
// IconTheme (iconTheme abaixo), mas isso só funciona de facto se
// AppIcon ler IconTheme.of(context).color internamente — a maioria
// dos wrappers de flutter_svg não faz isso por default. Por isso
// aqui a cor é passada EXPLICITAMENTE ao AppIcon (color: ...),
// ignorando o IconTheme automático do NavigationBar, para garantir
// que pinta certo independentemente da implementação do AppIcon.
// O iconTheme no NavigationBarThemeData fica definido mesmo assim,
// como fallback caso algum ícone interno do NavigationBar precise.
// ══════════════════════════════════════════════════════════════

class _HomeNavigationBar extends StatelessWidget {
  final AppColorScheme s;
  final HomeTab current;
  final ValueChanged<HomeTab> onSelect;
  const _HomeNavigationBar({required this.s, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            height: 64,
            backgroundColor: s.navBarBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            indicatorColor: s.navIndicatorBg,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusXLarge),
            ),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? s.navLabelActive : s.navIconInactive,
                size: 21,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: kTypeCaption,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? s.navLabelActive : s.navIconInactive,
              );
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: HomeTab.values.indexOf(current),
          onDestinationSelected: (i) => onSelect(HomeTab.values[i]),
          destinations: [
            for (final tab in HomeTab.values)
              NavigationDestination(
                icon: AppIcon(tab.svg, size: 21, color: s.navIconInactive),
                selectedIcon: AppIcon(tab.svgFilled, size: 21, color: s.navLabelActive),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}