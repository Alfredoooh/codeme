import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// BASE BOTTOM SHEET
// ══════════════════════════════════════════════════════════════

Future<T?> showCraftBottomSheet<T>({
  required BuildContext context,
  required AppColorScheme s,
  required Widget child,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: s.cardBackground,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (_) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: s.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface)),
            ),
            const SizedBox(height: 4),
          ],
          child,
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// COLOR PICKER
// ══════════════════════════════════════════════════════════════

Future<String?> showColorPickerSheet(BuildContext context, AppColorScheme s,
    {String? label}) {
  final colors = [
    '#000000', '#FFFFFF', '#FF3B30', '#FF9500',
    '#FFCC00', '#34C759', '#00C7BE', '#2F7BF6',
    '#5856D6', '#AF52DE', '#FF2D55', '#8E8E93',
  ];
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    title: label ?? 'Selecionar cor',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        spacing: 12, runSpacing: 12,
        children: colors.map((hex) {
          final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
          return GestureDetector(
            onTap: () => Navigator.pop(context, hex),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: s.outline, width: 1.5),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// IMAGE PICKER
// ══════════════════════════════════════════════════════════════

Future<void> showImagePickerSheet(BuildContext context, AppColorScheme s) {
  return showCraftBottomSheet<void>(
    context: context, s: s,
    title: 'Inserir imagem',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: [
        _SrcOption(s: s, icon: 'image.svg',
            label: 'Galeria de fotos', onTap: () => Navigator.pop(context)),
        _SrcOption(s: s, icon: 'camera.svg',
            label: 'Câmara', onTap: () => Navigator.pop(context)),
        _SrcOption(s: s, icon: 'doc_text.svg',
            label: 'Ficheiros', onTap: () => Navigator.pop(context)),
        _SrcOption(s: s, icon: 'link.svg',
            label: 'URL de imagem',
            onTap: () { Navigator.pop(context); _urlDialog(context, s); }),
      ]),
    ),
  );
}

void _urlDialog(BuildContext context, AppColorScheme s) {
  final ctrl = TextEditingController();
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('URL da imagem'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
            controller: ctrl, placeholder: 'https://', autofocus: true),
      ),
      actions: [
        CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
        CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx), child: const Text('Inserir')),
      ],
    ),
  );
}

class _SrcOption extends StatelessWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _SrcOption(
      {required this.s, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            AppIcon(icon, size: 20, color: s.primary),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 15, color: s.onSurface)),
            const Spacer(),
            AppIcon('chevron_right.svg', size: 14, color: s.onSurfaceVariant),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// LINK SHEET
// ══════════════════════════════════════════════════════════════

Future<void> showLinkSheet(BuildContext context, AppColorScheme s,
    void Function(String url, String text) onInsert) {
  final urlC = TextEditingController();
  final txtC = TextEditingController();
  return showCraftBottomSheet<void>(
    context: context, s: s,
    title: 'Inserir hiperligação',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: [
        _SheetField(s: s, ctrl: urlC, hint: 'https://'),
        const SizedBox(height: 10),
        _SheetField(s: s, ctrl: txtC, hint: 'Texto (opcional)'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: s.outline.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('Cancelar', style: TextStyle(color: s.onSurface)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                final url = urlC.text.trim();
                if (url.isNotEmpty) onInsert(url, txtC.text.trim());
              },
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: s.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('Inserir',
                    style: TextStyle(
                        color: s.onPrimary, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ]),
    ),
  );
}

class _SheetField extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final String hint;
  const _SheetField({required this.s, required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: s.outline.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: ctrl,
          style: TextStyle(fontSize: 14, color: s.onSurface),
          cursorColor: s.primary,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
}