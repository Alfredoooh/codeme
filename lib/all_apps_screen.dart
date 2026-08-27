// ══════════════════════════════════════════════════════════════
// ARQUIVO: lib/all_apps_screen.dart
// ══════════════════════════════════════════════════════════════
//
// Tela isolada que lista todos os apps disponíveis, reaproveitando
// o mesmo enum AppKind e a mesma extensão (iconAsset/label/description)
// já usados em drawermenu.dart. Não redefine AppKind aqui — importa
// do arquivo onde já está declarado. Ajuste o import abaixo se o
// enum estiver em outro arquivo (ex.: 'apps/app_types.dart').

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemUiOverlayStyle;
import 'colors.dart';
import 'widgets.dart';
import 'apps/app_types.dart'; // onde AppKind está declarado — ajuste se necessário
import 'apps/docs.dart';
import 'apps/sheets_app.dart';
import 'apps/slides_app.dart';
import 'apps/sound.dart';

class AllAppsScreen extends StatelessWidget {
  const AllAppsScreen({super.key});

  void _openApp(BuildContext context, AppKind app) {
    HapticFeedback.lightImpact();
    switch (app) {
      case AppKind.docs:
        Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => const DocsScreen(),
        ));
        break;
      case AppKind.sheets:
        Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => const SheetsScreen(),
        ));
        break;
      case AppKind.slides:
        Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => const SlidesScreen(),
        ));
        break;
      case AppKind.sound:
        Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => const SoundScreen(),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: s.statusBarStyle,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(children: [
                    _BackButton(s: s, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text(
                      'Todos os Apps',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: s.onSurface,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                    itemCount: AppKind.values.length,
                    itemBuilder: (_, i) {
                      final app = AppKind.values[i];
                      return _AppListTile(
                        s: s,
                        app: app,
                        index: i,
                        onTap: () => _openApp(context, app),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tile de app individual, com entrada animada em cascata ────

class _AppListTile extends StatefulWidget {
  final AppColorScheme s;
  final AppKind app;
  final int index;
  final VoidCallback onTap;
  const _AppListTile({
    required this.s,
    required this.app,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AppListTile> createState() => _AppListTileState();
}

class _AppListTileState extends State<_AppListTile>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _enterAnim;

  static const double _iconSize = 48;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _enterAnim = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _enterController.forward();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return FadeTransition(
      opacity: _enterAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_enterAnim),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _pressed ? s.hover : s.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: s.cardShadowSoft,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  widget.app.iconAsset,
                  width: _iconSize,
                  height: _iconSize,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.app.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: s.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.app.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: s.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AppIcon('chevron_forward', size: 16, color: s.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botão voltar (mesmo padrão do resto do app) ────────────────

class _BackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _BackButton({required this.s, required this.onTap});
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
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