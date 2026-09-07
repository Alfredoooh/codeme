import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/language/language_controller.dart';
import 'settings_widgets.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen>
    with ThemeReactive<AppearanceScreen> {
  @override
  void initState() {
    super.initState();
    appLanguage.addListener(_onChanged);
  }

  @override
  void dispose() {
    appLanguage.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _openPrimaryColorPicker(BuildContext context, AppColorScheme s) {
    showAppSheet(
      context,
      builder: (sheetContext) => _PrimaryColorSheet(s: s),
    );
  }

  void _openFontFamilyPicker(BuildContext context, AppColorScheme s) {
    showAppSheet(
      context,
      builder: (sheetContext) => _FontFamilySheet(s: s),
    );
  }

  void _openIconStylePicker(BuildContext context, AppColorScheme s) {
    showAppSheet(
      context,
      builder: (sheetContext) => _IconStyleSheet(s: s),
    );
  }

  void _openChatBubbleStylePicker(BuildContext context, AppColorScheme s) {
    showAppSheet(
      context,
      builder: (sheetContext) => _ChatBubbleStyleSheet(s: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final t = appLanguage.strings;

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(top: 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ThemeSegmentedControl(s: s, t: t),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(t.appearanceTextSize,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: s.onSurfaceVariant)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _FontSizeCard(
                      s: s,
                      t: t,
                      value: appPreferences.fontScale,
                      onChanged: appPreferences.setFontScale,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SettingsGroup(s: s, rows: [
                      SettingsRow(
                        s: s,
                        iconAsset: 'palette',
                        label: t.appearancePrimaryColor,
                        onTap: () => _openPrimaryColorPicker(context, s),
                        trailing: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: s.isDark
                                ? kPrimaryColorPairs[appTheme.primaryPairIndex]
                                    .dark
                                : kPrimaryColorPairs[appTheme.primaryPairIndex]
                                    .light,
                            shape: BoxShape.circle,
                            border: Border.all(color: s.outline),
                          ),
                        ),
                      ),
                      SettingsRow(
                        s: s,
                        iconAsset: 'text',
                        label: t.appearanceFontFamily,
                        onTap: () => _openFontFamilyPicker(context, s),
                        trailing: Text(
                          appPreferences.fontFamily,
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                      SettingsRow(
                        s: s,
                        iconAsset: 'shapes',
                        label: t.appearanceIconStyle,
                        onTap: () => _openIconStylePicker(context, s),
                        trailing: Text(
                          appPreferences.iconStyle ==
                                  AppIconStyle.filled
                              ? 'Preenchido'
                              : 'Contorno',
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                      SettingsRow(
                        s: s,
                        iconAsset: 'message',
                        label: t.appearanceChatBubbleStyle,
                        onTap: () =>
                            _openChatBubbleStylePicker(context, s),
                        trailing: Text(
                          appPreferences.chatBubbleStyle ==
                                  ChatBubbleStyle.bubble
                              ? 'Balão'
                              : 'Plano',
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SettingsGroup(s: s, rows: [
                      SettingsRow(
                        s: s,
                        iconAsset: 'motion',
                        label: t.appearanceReduceMotion,
                        onTap: () => appPreferences.setReduceMotion(
                            !appPreferences.reduceMotion),
                        trailing: _MiniSwitch(
                          s: s,
                          value: appPreferences.reduceMotion,
                          onChanged: appPreferences.setReduceMotion,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            SolidAppBar(
              s: s,
              title: t.appearanceTitle,
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  final AppColorScheme s;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitch(
      {required this.s, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 42,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? s.primary : s.hover,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final AppColorScheme s;
  final dynamic t;
  const _ThemeSegmentedControl({required this.s, required this.t});

  @override
  Widget build(BuildContext context) {
    final options = [
      (AppThemeMode.light, t.appearanceThemeLight),
      (AppThemeMode.dark, t.appearanceThemeDark),
      (AppThemeMode.system, t.appearanceThemeSystem),
    ];
    final selectedIndex =
        options.indexWhere((o) => o.$1 == appTheme.mode);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: s.hover,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left:
                segmentWidth * selectedIndex.clamp(0, options.length - 1),
            top: 0,
            bottom: 0,
            width: segmentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: s.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              for (final (mode, label) in options)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => appTheme.setMode(mode),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: appTheme.mode == mode
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: appTheme.mode == mode
                              ? s.onPrimary
                              : s.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]);
      }),
    );
  }
}

class _FontSizeCard extends StatelessWidget {
  final AppColorScheme s;
  final dynamic t;
  final double value;
  final ValueChanged<double> onChanged;
  const _FontSizeCard(
      {required this.s,
      required this.t,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final previewScale = 0.85 + (value * 0.5);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        _ExpressiveSlider(s: s, value: value, onChanged: onChanged),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: s.hover,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(t.appearanceTextSizePreviewQuestion,
                style:
                    TextStyle(fontSize: 14 * previewScale, color: s.onSurface)),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              t.appearanceTextSizePreviewAnswer,
              style: TextStyle(
                  fontSize: 14 * previewScale,
                  color: s.onSurface,
                  height: 1.35)),
        ),
        const SizedBox(height: 18),
        Text(t.appearanceTextSizePreviewLabel,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: s.onSurfaceVariant)),
      ]),
    );
  }
}

class _ExpressiveSlider extends StatefulWidget {
  final AppColorScheme s;
  final double value;
  final ValueChanged<double> onChanged;
  const _ExpressiveSlider(
      {required this.s, required this.value, required this.onChanged});
  @override
  State<_ExpressiveSlider> createState() => _ExpressiveSliderState();
}

class _ExpressiveSliderState extends State<_ExpressiveSlider> {
  static const double _trackHeight = 26;
  static const double _thumbWidth = 4;
  static const double _thumbHeight = 38;
  static const double _gap = 2;
  static const double _filledEndRadius = 3;

  double _dragValue = 0;
  bool _dragging = false;

  double get _effectiveValue =>
      _dragging ? _dragValue : widget.value;

  void _handlePan(double dx, double width) {
    final usable = width - _thumbWidth;
    final clamped = (dx / usable).clamp(0.0, 1.0);
    setState(() => _dragValue = clamped);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final v = _effectiveValue;
      final thumbX =
          (v * (width - _thumbWidth)).clamp(0.0, width - _thumbWidth);
      final filledWidth = (thumbX - _gap).clamp(0.0, width);

      return GestureDetector(
        onPanStart: (d) {
          setState(() {
            _dragging = true;
            _dragValue = widget.value;
          });
          _handlePan(d.localPosition.dx, width);
        },
        onPanUpdate: (d) => _handlePan(d.localPosition.dx, width),
        onPanEnd: (_) => setState(() => _dragging = false),
        onTapUp: (d) {
          setState(() => _dragging = true);
          _handlePan(d.localPosition.dx, width);
          setState(() => _dragging = false);
        },
        child: SizedBox(
          height: _thumbHeight,
          width: width,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: (_thumbHeight - _trackHeight) / 2,
                left: 0,
                right: 0,
                child: Container(
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    color: s.hover,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                top: (_thumbHeight - _trackHeight) / 2,
                left: 0,
                width: filledWidth,
                child: Container(
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    color: s.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(999),
                      bottomLeft: const Radius.circular(999),
                      topRight:
                          const Radius.circular(_filledEndRadius),
                      bottomRight:
                          const Radius.circular(_filledEndRadius),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: thumbX,
                top: 0,
                child: Container(
                  width: _thumbWidth,
                  height: _thumbHeight,
                  decoration: BoxDecoration(
                    color: s.onSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
// PRIMARY COLOR PICKER — movido para Aparência (antes estava em
// Personalização).
// ══════════════════════════════════════════════════════════════

class _PrimaryColorSheet extends StatelessWidget {
  final AppColorScheme s;
  const _PrimaryColorSheet({required this.s});

  @override
  Widget build(BuildContext context) {
    final t = appLanguage.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.appearancePrimaryColor,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: List.generate(kPrimaryColorPairs.length, (i) {
              final pair = kPrimaryColorPairs[i];
              final displayColor = s.isDark ? pair.dark : pair.light;
              final selected = appTheme.primaryPairIndex == i;
              return GestureDetector(
                onTap: () {
                  appTheme.setPrimaryPairIndex(i);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: displayColor,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: s.onSurface, width: 3)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const AppIcon('check',
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FONT FAMILY — só guarda a preferência e mostra no preview desta
// própria tela. NÃO aplica globalmente ainda (ThemeData/MaterialApp
// não são tocados por isto).
// ══════════════════════════════════════════════════════════════

class _FontFamilySheet extends StatelessWidget {
  final AppColorScheme s;
  const _FontFamilySheet({required this.s});

  static const _options = [
    'Inter',
    'Roboto',
    'System',
    'Poppins',
    'Nunito',
  ];

  @override
  Widget build(BuildContext context) {
    final t = appLanguage.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.appearanceFontFamily,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const SizedBox(height: 6),
          Text(t.appearanceFontFamilyDescription,
              style: TextStyle(
                  fontSize: 12.5, color: s.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          for (final font in _options)
            _SimpleOptionRow(
              s: s,
              label: font,
              selected: appPreferences.fontFamily == font,
              onTap: () {
                appPreferences.setFontFamily(font);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _IconStyleSheet extends StatelessWidget {
  final AppColorScheme s;
  const _IconStyleSheet({required this.s});

  @override
  Widget build(BuildContext context) {
    final t = appLanguage.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.appearanceIconStyle,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const SizedBox(height: 6),
          Text(t.appearanceIconStyleDescription,
              style: TextStyle(
                  fontSize: 12.5, color: s.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          _SimpleOptionRow(
            s: s,
            label: 'Contorno',
            selected: appPreferences.iconStyle == AppIconStyle.outline,
            onTap: () {
              appPreferences.setIconStyle(AppIconStyle.outline);
              Navigator.pop(context);
            },
          ),
          _SimpleOptionRow(
            s: s,
            label: 'Preenchido',
            selected: appPreferences.iconStyle == AppIconStyle.filled,
            onTap: () {
              appPreferences.setIconStyle(AppIconStyle.filled);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _ChatBubbleStyleSheet extends StatelessWidget {
  final AppColorScheme s;
  const _ChatBubbleStyleSheet({required this.s});

  @override
  Widget build(BuildContext context) {
    final t = appLanguage.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.appearanceChatBubbleStyle,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const SizedBox(height: 6),
          Text(t.appearanceChatBubbleStyleDescription,
              style: TextStyle(
                  fontSize: 12.5, color: s.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          _SimpleOptionRow(
            s: s,
            label: 'Balão',
            selected:
                appPreferences.chatBubbleStyle == ChatBubbleStyle.bubble,
            onTap: () {
              appPreferences.setChatBubbleStyle(ChatBubbleStyle.bubble);
              Navigator.pop(context);
            },
          ),
          _SimpleOptionRow(
            s: s,
            label: 'Plano',
            selected: appPreferences.chatBubbleStyle == ChatBubbleStyle.flat,
            onTap: () {
              appPreferences.setChatBubbleStyle(ChatBubbleStyle.flat);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _SimpleOptionRow extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SimpleOptionRow({
    required this.s,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected ? s.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? s.onPrimaryContainer : s.onSurface,
                ),
              ),
            ),
            if (selected)
              AppIcon('checkmark_circle',
                  size: 20, color: s.onPrimaryContainer)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}