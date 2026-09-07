import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/language/language_controller.dart';
import 'settings_widgets.dart';

class MemoryScreen extends StatefulWidget {
  final VoidCallback onDeleteAllConversations;
  const MemoryScreen({super.key, required this.onDeleteAllConversations});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      t.memoryDescription,
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
                        label: t.memoryDeleteAllConversations,
                        labelColor: s.error,
                        onTap: widget.onDeleteAllConversations,
                        trailing: const SizedBox.shrink(),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            SolidAppBar(
              s: s,
              title: t.memoryTitle,
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}