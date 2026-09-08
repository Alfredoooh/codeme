// ══════════════════════════════════════════════════════════════
// FILE: lib/features/settings/language_picker_sheet.dart
// Seletor de idioma — bottom sheet estilo docs.dart (showCraftBottomSheet),
// com busca. Lista kAllLocales (25 idiomas).
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/language/language_model.dart';
import '../../core/language/language_controller.dart';

void showLanguagePickerSheet(BuildContext context, AppColorScheme s) {
  showCraftBottomSheet<void>(
    context: context,
    s: s,
    title: appLanguage.strings.languagePickerTitle,
    child: _LanguagePickerContent(s: s),
  );
}

class _LanguagePickerContent extends StatefulWidget {
  final AppColorScheme s;
  const _LanguagePickerContent({required this.s});

  @override
  State<_LanguagePickerContent> createState() =>
      _LanguagePickerContentState();
}

class _LanguagePickerContentState extends State<_LanguagePickerContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final t = appLanguage.strings;
    final results = appLanguage.search(_query);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Campo de busca
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: s.hover,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              AppIcon('search', size: 18, color: s.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 15, color: s.onSurface),
                  cursorColor: s.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: t.languagePickerSearchHint,
                    hintStyle:
                        TextStyle(fontSize: 15, color: s.onSurfaceVariant),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          // Lista de idiomas
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      t.languagePickerNoResults,
                      style:
                          TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final locale = results[i];
                      final selected = locale.language.code ==
                          appLanguage.language.code;
                      return _LanguageRow(
                        s: s,
                        locale: locale,
                        selected: selected,
                        onTap: () {
                          appLanguage.setLanguage(locale);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatefulWidget {
  final AppColorScheme s;
  final AppLocale locale;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageRow({
    required this.s,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LanguageRow> createState() => _LanguageRowState();
}

class _LanguageRowState extends State<_LanguageRow> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final lang = widget.locale.language;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _p
              ? s.hover
              : widget.selected
                  ? s.primaryContainer.withOpacity(0.4)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Text(lang.flagEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.nativeName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w500,
                    color: s.onSurface,
                  ),
                ),
                Text(
                  lang.englishName,
                  style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (widget.selected)
            AppIcon('check', size: 18, color: s.primary),
        ]),
      ),
    );
  }
}