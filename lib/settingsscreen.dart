import 'package:flutter/material.dart';
import 'colors.dart';
import 'widgets.dart';

// ══════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ══════════════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _confirmLogout(BuildContext context, AppColorScheme s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ConfirmActionSheet(
        s: s,
        message: 'Continuar com esta ação?',
        onConfirm: () {
          Navigator.pop(ctx);
          // TODO: ligar aqui a lógica real de terminar sessão.
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Espaço reservado para a appbar (que fica sobreposta,
                // com gradiente, ver Stack abaixo)
                SizedBox(height: 52 + 6),

                // Conteúdo
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ],
            ),

            // ── Appbar sobreposta, com gradiente de transparência
            //    para baixo (contínuo, sem blur)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      s.pageBackground,
                      s.pageBackground.withOpacity(0.0),
                    ],
                  ),
                ),
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
            ),

            // ── Botão terminar sessão (fixo no fundo), com o
            //    container-fundo em gradiente de transparência
            //    para cima (contínuo, sem blur)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      s.pageBackground,
                      s.pageBackground.withOpacity(0.0),
                    ],
                  ),
                ),
                child: _LogoutButton(
                    s: s, onTap: () => _confirmLogout(context, s)),
              ),
            ),
          ]),
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
// Filled: fundo vermelho sólido, texto branco, cantos totalmente curvos.

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
            color: s.error,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('Terminar sessão',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: s.isDark ? const Color(0xFF3A0000) : Colors.white)),
        ),
      ),
    );
  }
}

// ── Sheet de confirmação genérico (Sim / Não) ─────────────────

class _ConfirmActionSheet extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  final VoidCallback onConfirm;
  const _ConfirmActionSheet(
      {required this.s, required this.message, required this.onConfirm});

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: s.outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: _SheetActionButton(
                      s: s,
                      label: 'Não',
                      filled: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetActionButton(
                      s: s,
                      label: 'Sim',
                      filled: true,
                      onTap: onConfirm,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}

class _SheetActionButton extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _SheetActionButton(
      {required this.s,
      required this.label,
      required this.filled,
      required this.onTap});
  @override State<_SheetActionButton> createState() => _SheetActionButtonState();
}

class _SheetActionButtonState extends State<_SheetActionButton> {
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
        scale: _p ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? s.error : s.hover,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.filled
                  ? (s.isDark ? const Color(0xFF3A0000) : Colors.white)
                  : s.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}