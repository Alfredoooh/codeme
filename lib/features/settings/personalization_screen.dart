import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../../core/widgets/app_sheet.dart';
import 'settings_widgets.dart';
import '../apps/sheets/sheets.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});
  @override
  State<PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen>
    with ThemeReactive<PersonalizationScreen> {

  @override
  void initState() {
    super.initState();
    appPreferences.addListener(_onPrefsChanged);
    appTheme.addListener(_onPrefsChanged);
  }

  @override
  void dispose() {
    appPreferences.removeListener(_onPrefsChanged);
    appTheme.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  void _openPromptEditor(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: _PromptEditorSheet(s: s),
    );
  }

  void _openEmojiFrequency(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: _EmojiFrequencySheet(s: s),
    );
  }

  void _openPrimaryColorPicker(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: _PrimaryColorSheet(s: s),
    );
  }

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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _PersonalizationGroup(s: s, rows: [
                  _PersonalizationRow(
                    s: s,
                    label: 'Preferências de prompt',
                    onTap: () => _openPromptEditor(context, s),
                    trailing: Text(
                      appPreferences.prompt.isEmpty ? 'Nenhuma' : 'Editado',
                      style: TextStyle(
                          fontSize: 14, color: s.onSurfaceVariant),
                    ),
                  ),
                  _PersonalizationRow(
                    s: s,
                    label: 'Frequência de emojis',
                    onTap: () => _openEmojiFrequency(context, s),
                    trailing: Text(
                      appPreferences.emojiFrequency.displayName,
                      style: TextStyle(
                          fontSize: 14, color: s.onSurfaceVariant),
                    ),
                  ),
                  _PersonalizationRow(
                    s: s,
                    label: 'Cor primária',
                    onTap: () => _openPrimaryColorPicker(context, s),
                    trailing: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: s.isDark
                            ? kPrimaryColorPairs[appTheme.primaryPairIndex].dark
                            : kPrimaryColorPairs[appTheme.primaryPairIndex].light,
                        shape: BoxShape.circle,
                        border: Border.all(color: s.outline),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            TransparentFadeAppBar(
              s: s,
              title: 'Personalização',
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PersonalizationGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<_PersonalizationRow> rows;
  const _PersonalizationGroup(
      {required this.s, required this.rows});

  static const double _outerRadius = 20;
  static const double _innerRadius = 6;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final radius = _radiusFor(i, rows.length);
      children.add(Container(
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: radius,
          boxShadow: s.cardShadowSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: rows[i],
      ));
      if (i != rows.length - 1) children.add(const SizedBox(height: 2));
    }
    return Column(children: children);
  }

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
}

class _PersonalizationRow extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final Widget trailing;
  final VoidCallback onTap;
  const _PersonalizationRow({
    required this.s,
    required this.label,
    required this.trailing,
    required this.onTap,
  });
  @override
  State<_PersonalizationRow> createState() => _PersonalizationRowState();
}

class _PersonalizationRowState extends State<_PersonalizationRow> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        color: _p ? s.hover : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(widget.label,
                  style:
                      TextStyle(fontSize: 15, color: s.onSurface)),
            ),
            widget.trailing,
          ],
        ),
      ),
    );
  }
}

class _PromptEditorSheet extends StatefulWidget {
  final AppColorScheme s;
  const _PromptEditorSheet({required this.s});
  @override
  State<_PromptEditorSheet> createState() => _PromptEditorSheetState();
}

class _PromptEditorSheetState extends State<_PromptEditorSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: appPreferences.prompt);
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    appPreferences.setPromptRemote(
        _ctrl.text.trim(), authController.token);
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preferências de prompt',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Instruções que a IA deve seguir em todas as conversas. Ex.: "Responde sempre em português europeu".',
              style: TextStyle(
                  fontSize: 12.5, color: s.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: s.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: s.outline.withOpacity(0.5)),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 15, color: s.onSurface),
                cursorColor: s.primary,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: 'Escreve aqui as tuas preferências...',
                  hintStyle: TextStyle(
                      fontSize: 15,
                      color: s.onSurfaceVariant.withOpacity(0.7)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: SheetActionButton(
                  s: s,
                  label: 'Cancelar',
                  filled: false,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.primary.withOpacity(_saving ? 0.6 : 1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              year2023: false,
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation(s.onPrimary),
                            ),
                          )
                        : Text('Guardar',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: s.onPrimary)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _EmojiFrequencySheet extends StatelessWidget {
  final AppColorScheme s;
  const _EmojiFrequencySheet({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Frequência de emojis',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const SizedBox(height: 16),
          for (final freq in EmojiFrequency.values)
            _FrequencyOption(
              s: s,
              freq: freq,
              selected: appPreferences.emojiFrequency == freq,
              onTap: () {
                appPreferences.setEmojiFrequencyRemote(
                    freq, authController.token);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _FrequencyOption extends StatelessWidget {
  final AppColorScheme s;
  final EmojiFrequency freq;
  final bool selected;
  final VoidCallback onTap;
  const _FrequencyOption({
    required this.s,
    required this.freq,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected ? s.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                freq.displayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      selected ? s.onPrimaryContainer : s.onSurface,
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

class _PrimaryColorSheet extends StatelessWidget {
  final AppColorScheme s;
  const _PrimaryColorSheet({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cor primária',
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