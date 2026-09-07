import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/language/language_controller.dart';
import 'settings_widgets.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SettingsGroup(s: s, rows: [
                  SettingsRow(
                    s: s,
                    iconAsset: 'person',
                    label: t.workspacePersonal,
                    onTap: () {},
                    trailing: AppIcon('checkmark_circle',
                        size: 18, color: s.primary),
                  ),
                ]),
              ),
            ),
            SolidAppBar(
              s: s,
              title: t.workspaceTitle,
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}