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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: _AppsGroup(
                      s: s,
                      apps: AppRegistry.all,
                      onTapApp: (app) => _openAppDetail(context, app),
                    ),
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

// ══════════════════════════════════════════════════════════════
// GRUPO DE APPS — mesmo padrão visual de _SettingsGroup/_SettingsCard
// (cantos grandes só nas pontas do grupo, 2px entre linhas, cantos
// pequenos onde as linhas se tocam), mas com linhas mais altas para
// caber o ícone grande de cada app.
// ══════════════════════════════════════════════════════════════

class _AppsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<AppEntry> apps;
  final ValueChanged<AppEntry> onTapApp;
  const _AppsGroup({
    required this.s,
    required this.apps,
    required this.onTapApp,
  });

  static const double _outerRadius = 20;
  static const double _innerRadius = 6;

  BorderRadius _radiusFor(int index, int count) {
    if (count == 1) return BorderRadius.circular(_outerRadius);
    final isFirst = index == 0;
    final isLast = index == count - 1;
    return BorderRadius.only(
      topLeft: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft: Radius.circular(isLast ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast ? _outerRadius : _innerRadius),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < apps.length; i++) {
      children.add(_AppCard(
        s: s,
        radius: _radiusFor(i, apps.length),
        app: apps[i],
        index: i,
        onTap: () => onTapApp(apps[i]),
      ));
      if (i != apps.length - 1) children.add(const SizedBox(height: 2));
    }
    return Column(children: children);
  }
}

class _AppCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final AppEntry app;
  final int index;
  final VoidCallback onTap;
  const _AppCard({
    required this.s,
    required this.radius,
    required this.app,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: radius,
          boxShadow: s.cardShadowSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: _AppRow(s: s, app: app, index: index, onTap: onTap),
      );
}

class _AppRow extends StatefulWidget {
  final AppColorScheme s;
  final AppEntry app;
  final int index;
  final VoidCallback onTap;
  const _AppRow({
    required this.s,
    required this.app,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AppRow> createState() => _AppRowState();
}

class _AppRowState extends State<_AppRow>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _enterAnim;

  static const double _iconSize = 60;

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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: _pressed ? s.hover : Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    widget.app.manifest.isCircularIcon ? _iconSize / 2 : 16,
                  ),
                  child: Container(
                    width: _iconSize,
                    height: _iconSize,
                    color: widget.app.manifest.isCircularIcon
                        ? Colors.white
                        : Colors.transparent,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: s.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.app.manifest.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: s.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
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