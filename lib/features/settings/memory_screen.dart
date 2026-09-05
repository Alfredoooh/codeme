import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import 'settings_widgets.dart';

class MemoryScreen extends StatelessWidget {
  final VoidCallback onDeleteAllConversations;
  const MemoryScreen({super.key, required this.onDeleteAllConversations});

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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Gere os dados de conversas guardados na tua conta.',
                      style: TextStyle(
                          fontSize: 13.5,
                          color: s.onSurfaceVariant,
                          height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SettingsGroup(s: s, rows: [
                      SettingsRow(
                        s: s,
                        iconAsset: 'trash',
                        label: 'Eliminar todas as conversas',
                        labelColor: s.error,
                        onTap: onDeleteAllConversations,
                        trailing: const SizedBox.shrink(),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            TransparentFadeAppBar(
              s: s,
              title: 'Memória',
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}