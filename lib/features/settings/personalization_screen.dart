import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/language/language_controller.dart';
import 'settings_widgets.dart';

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
    appPreferences.addListener(_onChanged);
    appTheme.addListener(_onChanged);
    appLanguage.addListener(_onChanged);
  }

  @override
  void dispose() {
    appPreferences.removeListener(_onChanged);
    appTheme.removeListener(_onChanged);
    appLanguage.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _openPromptEditor(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: _PromptEditorSheet(s: s),
    );
  }

  void _openEmojiFrequency(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: _EmojiFrequencySheet(s: s),
    );
  }

  void _openCustomInstructions(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: _TextPreferenceSheet(
        s: s,
        title: appLanguage.strings.personalizationCustomInstructions,
        description:
            appLanguage.strings.personalizationCustomInstructionsDescription,
        initialValue: appPreferences.customInstructions,
        onSave: appPreferences.setCustomInstructionsRemote,
      ),
    );
  }

  void _openTraits(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: _TextPreferenceSheet(
        s: s,
        title: appLanguage.strings.personalizationTraits,
        description: appLanguage.strings.personalizationTraitsDescription,
        initialValue: appPreferences.aiTraits,
        onSave: appPreferences.setAiTraitsRemote,
      ),
    );
  }

  void _openKnownInfo(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: _TextPreferenceSheet(
        s: s,
        title: appLanguage.strings.personalizationKnownInfo,
        description: appLanguage.strings.personalizationKnownInfoDescription,
        initialValue: appPreferences.knownInfo,
        onSave: appPreferences.setKnownInfoRemote,
      ),
    );
  }

  void _openResponseStyle(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: _ResponseStyleSheet(s: s),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsGroup(s: s, rows: [
                      SettingsRow(
                        s: s,
                        iconAsset: 'text_bubble',
                        label: t.personalizationPromptPreferences,
                        onTap: () => _openPromptEditor(context, s),
                        trailing: Text(
                          appPreferences.prompt.isEmpty
                              ? t.commonNone
                              : t.commonEdited,
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                      SettingsRow(
                        s: s,
                        iconAsset: 'list_bullet',
                        label: t.personalizationCustomInstructions,
                        onTap: () => _openCustomInstructions(context, s),
                        trailing: Text(
                          appPreferences.customInstructions.isEmpty
                              ? t.commonNone
                              : t.commonEdited,
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                      SettingsRow(
                        s: s,
                        iconAsset: 'sparkle',
                        label: t.personalizationTraits,
                        onTap: () => _openTraits(context, s),
                        trailing: Text(
                          appPreferences.aiTraits.isEmpty
                              ? t.commonNone
                              : t.commonEdited,
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                      SettingsRow(
                        s: s,
                        iconAsset: 'id_badge',
                        label: t.personalizationKnownInfo,
                        onTap: () => _openKnownInfo(context, s),
                        trailing: Text(
                          appPreferences.knownInfo.isEmpty
                              ? t.commonNone
                              : t.commonEdited,
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SettingsGroup(s: s, rows: [
                      SettingsRow(
                        s: s,
                        iconAsset: 'align_left',
                        label: t.personalizationResponseStyle,
                        onTap: () => _openResponseStyle(context, s),
                        trailing: Text(
                          _responseStyleLabel(
                              appPreferences.responseStyle, t),
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                      SettingsRow(
                        s: s,
                        iconAsset: 'emoji',
                        label: t.personalizationEmojiFrequency,
                        onTap: () => _openEmojiFrequency(context, s),
                        trailing: Text(
                          appPreferences.emojiFrequency.displayName,
                          style: TextStyle(
                              fontSize: 14, color: s.onSurfaceVariant),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SettingsGroup(s: s, rows: [
                      SettingsRow(
                        s: s,
                        iconAsset: 'globe_search',
                        label: t.personalizationAlwaysSearchWeb,
                        onTap: () => appPreferences.setAlwaysSearchWeb(
                            !appPreferences.alwaysSearchWeb),
                        trailing: _MiniSwitchInline(
                          s: s,
                          value: appPreferences.alwaysSearchWeb,
                          onChanged: appPreferences.setAlwaysSearchWeb,
                        ),
                      ),
                      SettingsRow(
                        s: s,
                        iconAsset: 'brain',
                        label: t.personalizationRememberAcrossChats,
                        onTap: () => appPreferences.setRememberAcrossChats(
                            !appPreferences.rememberAcrossChats),
                        trailing: _MiniSwitchInline(
                          s: s,
                          value: appPreferences.rememberAcrossChats,
                          onChanged: appPreferences.setRememberAcrossChats,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            SolidAppBar(
              s: s,
              title: t.personalizationTitle,
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }

  String _responseStyleLabel(ResponseStyle style, dynamic t) {
    switch (style) {
      case ResponseStyle.concise:
        return t.personalizationResponseStyleConcise;
      case ResponseStyle.balanced:
        return t.personalizationResponseStyleBalanced;
      case ResponseStyle.detailed:
        return t.personalizationResponseStyleDetailed;
    }
  }
}

class _MiniSwitchInline extends StatelessWidget {
  final AppColorScheme s;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MiniSwitchInline(
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
    final t = appLanguage.strings;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.personalizationPromptEditorTitle,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface)),
            const SizedBox(height: 8),
            Text(
              t.personalizationPromptEditorDescription,
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
                  hintText: t.personalizationPromptEditorHint,
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
                  label: t.commonCancel,
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
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation(s.onPrimary),
                            ),
                          )
                        : Text(t.commonSave,
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

class _TextPreferenceSheet extends StatefulWidget {
  final AppColorScheme s;
  final String title;
  final String description;
  final String initialValue;
  final void Function(String value, String? token) onSave;
  const _TextPreferenceSheet({
    required this.s,
    required this.title,
    required this.description,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<_TextPreferenceSheet> createState() => _TextPreferenceSheetState();
}

class _TextPreferenceSheetState extends State<_TextPreferenceSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue);
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    widget.onSave(_ctrl.text.trim(), authController.token);
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final t = appLanguage.strings;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface)),
            const SizedBox(height: 8),
            Text(
              widget.description,
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
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: SheetActionButton(
                  s: s,
                  label: t.commonCancel,
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
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation(s.onPrimary),
                            ),
                          )
                        : Text(t.commonSave,
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
    final t = appLanguage.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.personalizationEmojiFrequency,
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

class _ResponseStyleSheet extends StatelessWidget {
  final AppColorScheme s;
  const _ResponseStyleSheet({required this.s});

  @override
  Widget build(BuildContext context) {
    final t = appLanguage.strings;
    final options = [
      (ResponseStyle.concise, t.personalizationResponseStyleConcise),
      (ResponseStyle.balanced, t.personalizationResponseStyleBalanced),
      (ResponseStyle.detailed, t.personalizationResponseStyleDetailed),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.personalizationResponseStyle,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const SizedBox(height: 6),
          Text(t.personalizationResponseStyleDescription,
              style: TextStyle(
                  fontSize: 12.5, color: s.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          for (final (style, label) in options)
            _PersSimpleOptionRow(
              s: s,
              label: label,
              selected: appPreferences.responseStyle == style,
              onTap: () {
                appPreferences.setResponseStyle(style);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _PersSimpleOptionRow extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PersSimpleOptionRow({
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