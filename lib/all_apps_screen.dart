// ══════════════════════════════════════════════════════════════
// ARQUIVO: lib/all_apps_screen.dart
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemUiOverlayStyle;
import 'colors.dart';
import 'widgets.dart';
import 'apps/app_types.dart';
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
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const DocsScreen()),
        );
        break;
      case AppKind.sheets:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const SheetsScreen()),
        );
        break;
      case AppKind.slides:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const SlidesScreen()),
        );
        break;
      case AppKind.sound:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const SoundScreen()),
        );
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
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: s.onSurface,
                        ),
                      ),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      'Todas as ferramentas disponíveis, num só lugar.',
                      style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: _AppStoreLabel(s: s, text: 'Em destaque'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 168,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: AppKind.values.length,
                      itemBuilder: (_, i) {
                        final app = AppKind.values[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _FeaturedAppCard(
                            s: s,
                            app: app,
                            index: i,
                            onTap: () => _openApp(context, app),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                    child: _AppStoreLabel(s: s, text: 'Todos os apps'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: AppKind.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final app = AppKind.values[i];
                      return _AppListRow(
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

class _AppStoreLabel extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  const _AppStoreLabel({required this.s, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: s.onSurface,
      ),
    );
  }
}

// Card grande em destaque, estilo banner de App Store
class _FeaturedAppCard extends StatefulWidget {
  final AppColorScheme s;
  final AppKind app;
  final int index;
  final VoidCallback onTap;
  const _FeaturedAppCard({
    required this.s,
    required this.app,
    required this.index,
    required this.onTap,
  });

  @override
  State<_FeaturedAppCard> createState() => _FeaturedAppCardState();
}

class _FeaturedAppCardState extends State<_FeaturedAppCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _enterAnim;

  static const List<List<Color>> _gradients = [
    [Color(0xFF6D5AE6), Color(0xFF9B7BFF)],
    [Color(0xFF2E8BC9), Color(0xFF5FB4E8)],
    [Color(0xFFC9622E), Color(0xFFE89355)],
    [Color(0xFF2EC9A0), Color(0xFF5FE8C4)],
  ];

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _enterAnim = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
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
    final gradient = _gradients[widget.index % _gradients.length];
    return FadeTransition(
      opacity: _enterAnim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
            .animate(_enterAnim),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      widget.app.iconAsset,
                      fit: BoxFit.contain,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.app.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Linha de lista, estilo App Store "Todos os apps"
class _AppListRow extends StatefulWidget {
  final AppColorScheme s;
  final AppKind app;
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

  static const double _iconSize = 52;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
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
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(_enterAnim),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _pressed ? s.hover : s.cardBackground,
              borderRadius: BorderRadius.circular(18),
              boxShadow: s.cardShadowSoft,
            ),
            child: Row(
              children: [
                Container(
                  width: _iconSize,
                  height: _iconSize,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: s.hover,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Image.asset(widget.app.iconAsset, fit: BoxFit.contain),
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
                          fontWeight: FontWeight.w700,
                          color: s.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.app.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: s.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Abrir',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: s.onPrimary,
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