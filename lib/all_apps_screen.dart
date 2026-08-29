// ══════════════════════════════════════════════════════════════
// FILE: lib/all_apps_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemUiOverlayStyle;
import 'colors.dart';
import 'widgets.dart';
import 'apps/registry/app_registry.dart';
import 'apps/app_detail_screen.dart';

class AllAppsScreen extends StatelessWidget {
  const AllAppsScreen({super.key});

  void _openAppDetail(BuildContext context, AppEntry app) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => AppDetailScreen(app: app)),
    );
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
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(children: [
                      _BackButton(s: s, onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Text(
                        'Apps',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: s.onSurface,
                        ),
                      ),
                    ]),
                  ),
                ),
                // ══════════════════════════════════════════════
                // BLOCO DE DIAGNÓSTICO TEMPORÁRIO
                // Mostra no próprio ecrã porque razão a lista está
                // vazia. Remover depois de confirmares a causa.
                // ══════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppRegistry.all.isEmpty
                            ? Colors.red.withOpacity(0.12)
                            : Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppRegistry.all.isEmpty ? Colors.red : Colors.green,
                        ),
                      ),
                      child: Text(
                        AppRegistry.all.isEmpty
                            ? 'DIAGNÓSTICO: AppRegistry.all está vazio.\n'
                                'Nenhum assets/apps/*/manifest.json foi '
                                'encontrado no AssetManifest.json do build '
                                'instalado. Verifica se o pubspec.yaml foi '
                                'aplicado no build que instalaste (pub get '
                                'antes de gerar o pacote), e se a pasta '
                                'assets/apps foi mesmo incluída nele.'
                            : 'DIAGNÓSTICO: AppRegistry.all tem '
                                '${AppRegistry.all.length} apps: '
                                '${AppRegistry.all.map((e) => e.manifest.slug).join(", ")}.\n'
                                'Os manifests carregaram bem — se a lista '
                                'continua vazia lá em baixo, o problema está '
                                'no SliverList, não no registry.',
                        style: TextStyle(
                          color: AppRegistry.all.isEmpty ? Colors.red : Colors.green[800],
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: AppRegistry.all.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    itemBuilder: (_, i) {
                      final app = AppRegistry.all[i];
                      return _AppListRow(
                        s: s,
                        app: app,
                        index: i,
                        onTap: () => _openAppDetail(context, app),
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

class _AppListRow extends StatefulWidget {
  final AppColorScheme s;
  final AppEntry app;
  final int index;
  final VoidCallback onTap;
  const _AppListRow({
    required this.s,
    required this.app,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AppListRow> createState() => _AppListRowState();
}

class _AppListRowState extends State<_AppListRow>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _enterAnim;

  static const double _iconSize = 56;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _enterAnim = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 30 * widget.index), () {
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
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(_enterAnim),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 110),
            opacity: _pressed ? 0.6 : 1.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    widget.app.manifest.isCircularIcon ? _iconSize / 2 : 14,
                  ),
                  child: Container(
                    width: _iconSize,
                    height: _iconSize,
                    color: widget.app.manifest.isCircularIcon ? Colors.white : Colors.transparent,
                    child: Image.asset(
                      widget.app.manifest.iconAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.app.manifest.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: s.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.app.manifest.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: s.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: s.onSurfaceVariant,
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