// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/app_detail_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemUiOverlayStyle;
import '../colors.dart';
import '../widgets.dart';
import 'app_types.dart';
import 'registry/app_registry.dart';

class AppDetailScreen extends StatelessWidget {
  final AppEntry app;
  const AppDetailScreen({super.key, required this.app});

  /// Navega para o ecrã real do app (chamado pelo botão "Abrir aplicativo").
  static void openApp(BuildContext context, AppEntry app) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(builder: app.builder),
    );
  }

  void _showFeedbackSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final s = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedbackSheet(s: s, app: app),
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
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Row(
                        children: [
                          _DetailBackButton(s: s, onTap: () => Navigator.pop(context)),
                          const Spacer(),
                          _FeedbackButton(s: s, onTap: () => _showFeedbackSheet(context)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                        children: [
                          _AppHeader(s: s, app: app),
                          const SizedBox(height: 28),
                          _SectionTitle(s: s, text: 'Para que serve'),
                          const SizedBox(height: 10),
                          Text(
                            app.manifest.longDescription,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.5,
                              color: s.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _SectionTitle(s: s, text: 'Funcionalidades'),
                          const SizedBox(height: 10),
                          ...app.manifest.features.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FeatureRow(s: s, text: f),
                            ),
                          ),
                          const SizedBox(height: 26),
                          _SectionTitle(s: s, text: 'Assistente de IA'),
                          const SizedBox(height: 10),
                          _AiConnectSwitchRow(s: s, app: app),
                          const SizedBox(height: 20),
                          _FeedbackRow(s: s, onTap: () => _showFeedbackSheet(context)),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: _OpenAppFloatingButton(
                      s: s,
                      onTap: () => AppDetailScreen.openApp(context, app),
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

class _AppHeader extends StatelessWidget {
  final AppColorScheme s;
  final AppEntry app;
  const _AppHeader({required this.s, required this.app});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(app.manifest.isCircularIcon ? 38 : 20),
          child: Container(
            width: 76,
            height: 76,
            color: app.manifest.isCircularIcon ? Colors.white : Colors.transparent,
            child: Image.asset(app.manifest.iconAsset, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.manifest.label,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: s.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                app.manifest.description,
                style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  const _SectionTitle({required this.s, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w800,
        color: s.onSurface,
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  const _FeatureRow({required this.s, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(CupertinoIcons.checkmark_alt, size: 13, color: s.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14.5, height: 1.4, color: s.onSurface),
          ),
        ),
      ],
    );
  }
}

class _AiConnectSwitchRow extends StatefulWidget {
  final AppColorScheme s;
  final AppEntry app;
  const _AiConnectSwitchRow({required this.s, required this.app});

  @override
  State<_AiConnectSwitchRow> createState() => _AiConnectSwitchRowState();
}

class _AiConnectSwitchRowState extends State<_AiConnectSwitchRow> {
  @override
  void initState() {
    super.initState();
    enabledAppsController.addListener(_onChanged);
  }

  @override
  void dispose() {
    enabledAppsController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final slug = widget.app.manifest.slug;
    final value = enabledAppsController.isEnabled(slug);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: s.cardShadowSoft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ligar ao Nexa AI',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: s.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.app.manifest.aiToggleDescription,
                  style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) => enabledAppsController.setEnabled(slug, v),
            activeColor: s.primary,
          ),
        ],
      ),
    );
  }
}

class _FeedbackRow extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _FeedbackRow({required this.s, required this.onTap});

  @override
  State<_FeedbackRow> createState() => _FeedbackRowState();
}

class _FeedbackRowState extends State<_FeedbackRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pressed ? s.hover : s.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: s.cardShadowSoft,
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.chat_bubble_text, size: 19, color: s.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enviar feedback',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: s.onSurface,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 17, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _OpenAppFloatingButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _OpenAppFloatingButton({required this.s, required this.onTap});

  @override
  State<_OpenAppFloatingButton> createState() => _OpenAppFloatingButtonState();
}

class _OpenAppFloatingButtonState extends State<_OpenAppFloatingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: s.primary.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            'Abrir aplicativo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: s.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  final AppColorScheme s;
  final AppEntry app;
  const _FeedbackSheet({required this.s, required this.app});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    // TODO: enviar `text` + `widget.app.manifest.slug` para o backend (Cloudflare Worker)
    Navigator.of(context).pop();
    if (text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obrigado pelo teu feedback!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: s.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              'Enviar feedback',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sobre ${widget.app.manifest.label}',
              style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: s.hover,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 4,
                style: TextStyle(fontSize: 14.5, color: s.onSurface),
                decoration: InputDecoration(
                  hintText: 'Escreve aqui a tua sugestão ou problema...',
                  hintStyle: TextStyle(color: s.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Enviar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: s.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _DetailBackButton({required this.s, required this.onTap});
  @override
  State<_DetailBackButton> createState() => _DetailBackButtonState();
}

class _DetailBackButtonState extends State<_DetailBackButton> {
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

class _FeedbackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _FeedbackButton({required this.s, required this.onTap});
  @override
  State<_FeedbackButton> createState() => _FeedbackButtonState();
}

class _FeedbackButtonState extends State<_FeedbackButton> {
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
          child: Icon(CupertinoIcons.chat_bubble_text, size: 18, color: widget.s.onSurface),
        ),
      ),
    );
  }
}