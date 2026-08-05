import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ══════════════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: s.pageBackground,
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 10),
                child: Row(children: [
                  AppTap(
                    onTap: () => Navigator.pop(context),
                    s: s,
                    child: AppIcon('back.svg', color: s.onSurface, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text('Definições',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: s.onSurface)),
                ]),
              ),

              // Conteúdo
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [

                    // ── Aparência ──────────────────────────────
                    _SectionLabel(s: s, label: 'Aparência'),
                    const SizedBox(height: 10),
                    _SettingsCard(s: s, children: [
                      _SettingsRow(
                        s: s,
                        label: 'Modo escuro',
                        trailing: AppSwitch(
                          value: appTheme.isDark,
                          s: s,
                          onChanged: (_) => appTheme.toggleDark(),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 28),

                    // ── Conta ──────────────────────────────────
                    _SectionLabel(s: s, label: 'Conta'),
                    const SizedBox(height: 10),
                    _SettingsCard(s: s, children: [
                      _SettingsRow(
                        s: s,
                        label: 'Utilizador',
                        trailing: Text('Alterar',
                            style: TextStyle(
                                fontSize: 14,
                                color: s.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                      _Divider(s: s),
                      _SettingsRow(
                        s: s,
                        label: 'Terminar sessão',
                        trailing: const SizedBox.shrink(),
                        labelColor: s.error,
                      ),
                    ]),

                    const SizedBox(height: 28),

                    // ── Sobre ──────────────────────────────────
                    _SectionLabel(s: s, label: 'Sobre'),
                    const SizedBox(height: 10),
                    _SettingsCard(s: s, children: [
                      _SettingsRow(
                        s: s,
                        label: 'Versão',
                        trailing: Text('1.0.0',
                            style: TextStyle(
                                fontSize: 14,
                                color: s.onSurfaceVariant)),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Componentes internos ──────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  const _SectionLabel({required this.s, required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.onSurfaceVariant,
          letterSpacing: 0.5));
}

class _SettingsCard extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> children;
  const _SettingsCard({required this.s, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: s.cardShadow),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );
}

class _SettingsRow extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final Widget trailing;
  final Color? labelColor;
  const _SettingsRow(
      {required this.s,
      required this.label,
      required this.trailing,
      this.labelColor});
  @override State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => setState(() => _p = true),
        onTapCancel: ()  => setState(() => _p = false),
        onTapUp:     (_) => setState(() => _p = false),
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _p ? widget.s.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 15,
                      color: widget.labelColor ?? widget.s.onSurface)),
              widget.trailing,
            ],
          ),
        ),
      );
}

class _Divider extends StatelessWidget {
  final AppColorScheme s;
  const _Divider({required this.s});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Divider(height: 1, color: s.outlineVariant),
      );
}