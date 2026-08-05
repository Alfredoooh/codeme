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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  children: [

                    // ── Aparência ──────────────────────────────
                    _SectionLabel(s: s, label: 'Aparência'),
                    const SizedBox(height: 10),
                    _SettingsGroup(s: s, rows: [
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
                    _SettingsGroup(s: s, rows: [
                      _SettingsRow(
                        s: s,
                        label: 'Utilizador',
                        trailing: Text('Alterar',
                            style: TextStyle(
                                fontSize: 14,
                                color: s.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                      _SettingsRow(
                        s: s,
                        label: 'Email',
                        trailing: Text('Alterar',
                            style: TextStyle(
                                fontSize: 14,
                                color: s.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                      _SettingsRow(
                        s: s,
                        label: 'Palavra-passe',
                        trailing: Text('Alterar',
                            style: TextStyle(
                                fontSize: 14,
                                color: s.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                      _SettingsRow(
                        s: s,
                        label: 'Plano actual',
                        trailing: Text('Gratuito',
                            style: TextStyle(
                                fontSize: 14,
                                color: s.onSurfaceVariant)),
                      ),
                      _SettingsRow(
                        s: s,
                        label: 'Privacidade e dados',
                        trailing: const SizedBox.shrink(),
                      ),
                    ]),

                    const SizedBox(height: 28),

                    // ── Sobre ──────────────────────────────────
                    _SectionLabel(s: s, label: 'Sobre'),
                    const SizedBox(height: 10),
                    _SettingsGroup(s: s, rows: [
                      _SettingsRow(
                        s: s,
                        label: 'Versão',
                        trailing: Text('1.0.0',
                            style: TextStyle(
                                fontSize: 14,
                                color: s.onSurfaceVariant)),
                      ),
                      _SettingsRow(
                        s: s,
                        label: 'Termos de serviço',
                        trailing: const SizedBox.shrink(),
                      ),
                      _SettingsRow(
                        s: s,
                        label: 'Política de privacidade',
                        trailing: const SizedBox.shrink(),
                      ),
                      _SettingsRow(
                        s: s,
                        label: 'Enviar feedback',
                        trailing: const SizedBox.shrink(),
                      ),
                      _SettingsRow(
                        s: s,
                        label: 'Ajuda e suporte',
                        trailing: const SizedBox.shrink(),
                      ),
                    ]),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Botão terminar sessão (fixo, no fundo) ────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _LogoutButton(s: s, onTap: () {}),
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

// ── Grupo de cards ───────────────────────────────────────────
// • 1 único card  → todos os cantos bem arredondados
// • 2+ cards       → cada row é o seu próprio card, com um gap
//   pequeno entre eles (sem linha de divisão); o raio de cada
//   canto depende da posição:
//     primeiro → cantos de CIMA bem curvos, cantos de BAIXO quase retos
//     meio     → todos os cantos quase retos
//     último   → cantos de BAIXO bem curvos, cantos de CIMA quase retos

class _SettingsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> rows;
  const _SettingsGroup({required this.s, required this.rows});

  static const double _outerRadius = 16;
  static const double _innerRadius = 4;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final count = rows.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          _SettingsCard(
            s: s,
            radius: _radiusFor(i, count),
            child: rows[i],
          ),
        ],
      ],
    );
  }

  BorderRadius _radiusFor(int index, int count) {
    if (count == 1) {
      return BorderRadius.circular(_outerRadius);
    }
    final isFirst = index == 0;
    final isLast  = index == count - 1;

    return BorderRadius.only(
      topLeft:     Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight:    Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft:  Radius.circular(isLast  ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast  ? _outerRadius : _innerRadius),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final Widget child;
  const _SettingsCard({
    required this.s,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: child,
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
          color: _p ? widget.s.hover : Colors.transparent,
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

// ── Botão terminar sessão ───────────────────────────────────
// Fixo no fundo, retangular com cantos totalmente curvos, tom
// avermelhado (usa a cor semântica `error` do tema).

class _LogoutButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _LogoutButton({required this.s, required this.onTap});
  @override State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.error.withOpacity(s.isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: s.error, width: 1.5),
          ),
          child: Text('Terminar sessão',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: s.error)),
        ),
      ),
    );
  }
}