import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import 'settings_widgets.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen>
    with ThemeReactive<AppearanceScreen> {
  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(top: 62),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ThemeSegmentedControl(s: s),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Tamanho do texto',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: s.onSurfaceVariant)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _FontSizeCard(
                      s: s,
                      value: appPreferences.fontScale,
                      onChanged: appPreferences.setFontScale,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            TransparentFadeAppBar(
              s: s,
              title: 'Aparência',
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final AppColorScheme s;
  const _ThemeSegmentedControl({required this.s});

  static const _options = [
    (AppThemeMode.light, 'Claro'),
    (AppThemeMode.dark, 'Escuro'),
    (AppThemeMode.system, 'Automático'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        _options.indexWhere((o) => o.$1 == appTheme.mode);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: s.hover,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / _options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left:
                segmentWidth * selectedIndex.clamp(0, _options.length - 1),
            top: 0,
            bottom: 0,
            width: segmentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: s.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: s.cardShadow,
              ),
            ),
          ),
          Row(
            children: [
              for (final (mode, label) in _options)
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
  final double value;
  final ValueChanged<double> onChanged;
  const _FontSizeCard(
      {required this.s, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final previewScale = 0.85 + (value * 0.5);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: s.cardShadowSoft,
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
            child: Text('Qual é a verdade do universo?',
                style:
                    TextStyle(fontSize: 14 * previewScale, color: s.onSurface)),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              'O Universo é um vasto sistema de leis e mistérios.',
              style: TextStyle(
                  fontSize: 14 * previewScale,
                  color: s.onSurface,
                  height: 1.35)),
        ),
        const SizedBox(height: 18),
        Text('PRÉ-VISUALIZAR',
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