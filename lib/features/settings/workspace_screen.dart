import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import 'settings_widgets.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

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
                child: SettingsGroup(s: s, rows: [
                  SettingsRow(
                    s: s,
                    iconAsset: 'person',
                    label: 'Pessoal',
                    onTap: () {},
                    trailing: AppIcon('checkmark_circle',
                        size: 18, color: s.primary),
                  ),
                ]),
              ),
            ),
            TransparentFadeAppBar(
              s: s,
              title: 'Área de trabalho',
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}