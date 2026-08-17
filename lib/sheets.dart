import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// BASE BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
// Adaptado para usar o design system Fluent, substituindo
// `showModalBottomSheet` por `showFluentBottomSheet` e o
// container manual por `FluentBottomSheet`.
Future<T?> showCraftBottomSheet<T>({
  required BuildContext context,
  required AppColorScheme s,
  required Widget child,
  String? title,
}) {
  // `s` é mantido para compatibilidade de assinatura com chamadas existentes,
  // mas não é necessário porque `showFluentBottomSheet` obtém o scheme
  // internamente através de `AppTheme.of(context)`.
  return showFluentBottomSheet<T>(
    context: context,
    builder: (ctx) => FluentBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: kTypeBody,
                fontWeight: FontWeight.w600,
                color: AppTheme.of(ctx).onSurface,
              ),
            ),
            SizedBox(height: kSpaceS),
          ],
          child,
          SizedBox(height: kSpaceS),
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
      padding: EdgeInsets.symmetric(
        horizontal: kSpaceXL,
        vertical: kSpaceM,
      ),
      child: Wrap(
        spacing: kSpaceM,
        runSpacing: kSpaceM,
        children: colors.map((hex) {
          final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
          return AppTap(
            onTap: () => Navigator.pop(context, hex),
            s: s,
            child: Container(
              width: 42,
              height: 42,
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
    context: context,
    s: s,
    title: 'Inserir imagem',
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: kSpaceXL,
        vertical: kSpaceS,
      ),
      child: Column(
        children: [
          _SrcOption(
            s: s,
            icon: 'image.svg',
            label: 'Galeria de fotos',
            onTap: () => Navigator.pop(context),
          ),
          _SrcOption(
            s: s,
            icon: 'camera.svg',
            label: 'Câmara',
            onTap: () => Navigator.pop(context),
          ),
          _SrcOption(
            s: s,
            icon: 'doc_text.svg',
            label: 'Ficheiros',
            onTap: () => Navigator.pop(context),
          ),
          _SrcOption(
            s: s,
            icon: 'link.svg',
            label: 'URL de imagem',
            onTap: () {
              Navigator.pop(context);
              _urlDialog(context, s);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _urlDialog(BuildContext context, AppColorScheme s) async {
  final ctrl = TextEditingController();
  await showFluentDialog<void>(
    context: context,
    builder: (ctx) => FluentDialog(
      title: 'URL da imagem',
      content: FluentTextField(
        controller: ctrl,
        hintText: 'https://',
        autofocus: true,
      ),
      actions: [
        FluentButton(
          label: 'Cancelar',
          onTap: () => Navigator.pop(ctx),
          style: FluentButtonStyle.secondary,
        ),
        FluentButton(
          label: 'Inserir',
          onTap: () => Navigator.pop(ctx),
          style: FluentButtonStyle.primary,
        ),
      ],
    ),
  );
  ctrl.dispose();
}

class _SrcOption extends StatelessWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _SrcOption({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppTap(
        onTap: onTap,
        s: s,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: kSpaceM),
          child: Row(
            children: [
              AppIcon(icon, size: 20, color: s.primary),
              SizedBox(width: kSpaceL - kSpaceXXS), // 14
              Text(
                label,
                style: TextStyle(fontSize: kTypeBody, color: s.onSurface),
              ),
              const Spacer(),
              AppIcon('chevron_right.svg', size: 14, color: s.onSurfaceVariant),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// LINK SHEET
// ══════════════════════════════════════════════════════════════

Future<void> showLinkSheet(
  BuildContext context,
  AppColorScheme s,
  void Function(String url, String text) onInsert,
) {
  final urlC = TextEditingController();
  final txtC = TextEditingController();
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    title: 'Inserir hiperligação',
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: kSpaceXL,
        vertical: kSpaceS,
      ),
      child: Column(
        children: [
          FluentTextField(
            controller: urlC,
            hintText: 'https://',
            fillColor: s.subtleFillHover,
            borderRadius: kRadiusLarge,
            contentPadding: EdgeInsets.symmetric(
              horizontal: kSpaceM,
              vertical: kSpaceM,
            ),
          ),
          SizedBox(height: kSpaceS + kSpaceXXS), // 10
          FluentTextField(
            controller: txtC,
            hintText: 'Texto (opcional)',
            fillColor: s.subtleFillHover,
            borderRadius: kRadiusLarge,
            contentPadding: EdgeInsets.symmetric(
              horizontal: kSpaceM,
              vertical: kSpaceM,
            ),
          ),
          SizedBox(height: kSpaceL),
          Row(
            children: [
              Expanded(
                child: FluentButton(
                  label: 'Cancelar',
                  onTap: () => Navigator.pop(context),
                  style: FluentButtonStyle.secondary,
                ),
              ),
              SizedBox(width: kSpaceS + kSpaceXXS), // 10
              Expanded(
                child: FluentButton(
                  label: 'Inserir',
                  onTap: () {
                    Navigator.pop(context);
                    final url = urlC.text.trim();
                    if (url.isNotEmpty) onInsert(url, txtC.text.trim());
                  },
                  style: FluentButtonStyle.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}