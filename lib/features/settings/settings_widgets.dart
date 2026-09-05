import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../services/api_service.dart';

// ══════════════════════════════════════════════════════════════
// BOTÃO DE VOLTAR CIRCULAR
// ══════════════════════════════════════════════════════════════

class CircularBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const CircularBackButton({super.key, required this.s, required this.onTap});
  @override
  State<CircularBackButton> createState() => _CircularBackButtonState();
}

class _CircularBackButtonState extends State<CircularBackButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: s.cardShadow,
        ),
        child: AppIcon('back', color: s.onSurface, size: 18),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// APPBAR TRANSPARENTE PROGRESSIVA — reutilizável em sub-telas
// ══════════════════════════════════════════════════════════════

class TransparentFadeAppBar extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onBack;
  const TransparentFadeAppBar({
    super.key,
    required this.s,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Mesmo piso 0.4 usado no settings e no scheduled_tasks/chat_search.
            colors: [
              s.pageBackground,
              s.pageBackground.withOpacity(0.4),
            ],
          ),
        ),
        child: Row(children: [
          CircularBackButton(s: s, onTap: onBack),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: s.onSurface,
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECTION LABEL / GROUP / CARD / ROW (lista de definições)
// ══════════════════════════════════════════════════════════════

class SectionLabel extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  const SectionLabel({super.key, required this.s, required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.onSurfaceVariant,
          letterSpacing: 0.5));
}

class SettingsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<SettingsRow> rows;
  const SettingsGroup({super.key, required this.s, required this.rows});

  static const double _outerRadius = 20;
  static const double _innerRadius = 6;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(SettingsCard(
        s: s,
        radius: _radiusFor(i, rows.length),
        child: rows[i],
      ));
      if (i != rows.length - 1) children.add(const SizedBox(height: 2));
    }
    return Column(children: children);
  }

  BorderRadius _radiusFor(int index, int count) {
    if (count == 1) return BorderRadius.circular(_outerRadius);
    final isFirst = index == 0;
    final isLast = index == count - 1;
    return BorderRadius.only(
      topLeft: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft: Radius.circular(isLast ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast ? _outerRadius : _innerRadius),
    );
  }
}

class SettingsCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final Widget child;
  const SettingsCard(
      {super.key, required this.s, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: radius,
            boxShadow: s.cardShadowSoft),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class SettingsRow extends StatefulWidget {
  final AppColorScheme s;
  final String iconAsset;
  final String label;
  final Widget trailing;
  final Color? labelColor;
  final VoidCallback onTap;
  const SettingsRow({
    super.key,
    required this.s,
    required this.iconAsset,
    required this.label,
    required this.trailing,
    required this.onTap,
    this.labelColor,
  });
  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final color = widget.labelColor ?? s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: _p ? s.hover : Colors.transparent,
        child: Row(
          children: [
            AppIcon(widget.iconAsset,
                size: 19,
                color: widget.labelColor ?? s.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(fontSize: 15, color: color)),
            ),
            widget.trailing,
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LOGOUT BUTTON
// ══════════════════════════════════════════════════════════════

class LogoutButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const LogoutButton({super.key, required this.s, required this.onTap});
  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
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
                  color: s.onError)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHEETS DE CONFIRMAÇÃO / AÇÃO
// ══════════════════════════════════════════════════════════════

class ConfirmActionSheet extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final VoidCallback onConfirm;
  const ConfirmActionSheet({
    super.key,
    required this.s,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'Sim',
    this.destructive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: s.onSurface)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: SheetActionButton(
                s: s,
                label: 'Cancelar',
                filled: false,
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SheetActionButton(
                s: s,
                label: confirmLabel,
                filled: destructive,
                onTap: onConfirm,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class SheetActionButton extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const SheetActionButton({
    super.key,
    required this.s,
    required this.label,
    required this.filled,
    required this.onTap,
  });
  @override
  State<SheetActionButton> createState() => _SheetActionButtonState();
}

class _SheetActionButtonState extends State<SheetActionButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
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
              color: widget.filled ? s.onError : s.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EDIT FIELD SHEET (nome, campos genéricos)
// ══════════════════════════════════════════════════════════════

class EditFieldSheet extends StatefulWidget {
  final AppColorScheme s;
  final String title;
  final String label;
  final String hint;
  final String initialValue;
  final bool obscure;
  final int minLength;
  final Future<void> Function(String value) onSave;
  const EditFieldSheet({
    super.key,
    required this.s,
    required this.title,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onSave,
    this.obscure = false,
    this.minLength = 1,
  });

  @override
  State<EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<EditFieldSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue);
  bool _obscureNow = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _ctrl.text.trim();
    if (value.length < widget.minLength) {
      setState(() => _error = widget.minLength > 1
          ? 'Mínimo de ${widget.minLength} caracteres'
          : 'Este campo não pode ficar vazio');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(value);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : 'Não foi possível guardar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface)),
            const SizedBox(height: 16),
            Text(widget.label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: s.onSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: s.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _error != null
                        ? s.error
                        : s.outline.withOpacity(0.5)),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                obscureText: widget.obscure ? _obscureNow : false,
                style: TextStyle(fontSize: 15, color: s.onSurface),
                cursorColor: s.primary,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                      fontSize: 15,
                      color: s.onSurfaceVariant.withOpacity(0.7)),
                  suffixIcon: widget.obscure
                      ? GestureDetector(
                          onTap: () => setState(
                              () => _obscureNow = !_obscureNow),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: AppIcon(
                              _obscureNow ? 'eye' : 'eye_off',
                              color: s.onSurfaceVariant,
                              size: 18,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(fontSize: 12, color: s.error)),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: SheetActionButton(
                  s: s,
                  label: 'Cancelar',
                  filled: false,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          s.primary.withOpacity(_saving ? 0.6 : 1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              year2023: false,
                              strokeWidth: 2.2,
                              valueColor:
                                  AlwaysStoppedAnimation(s.onPrimary),
                            ),
                          )
                        : Text('Guardar',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: s.onPrimary)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ALTERAR PALAVRA-PASSE
// ══════════════════════════════════════════════════════════════

class ChangePasswordSheet extends StatefulWidget {
  final AppColorScheme s;
  const ChangePasswordSheet({super.key, required this.s});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _saving = false;
  String? _error;
  bool _forgotMode = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _currentCtrl.text.trim();
    final newPw = _newCtrl.text.trim();

    if (current.isEmpty) {
      setState(() => _error = 'Introduz a palavra-passe actual');
      return;
    }
    if (newPw.length < 6) {
      setState(
          () => _error = 'A nova palavra-passe deve ter pelo menos 6 caracteres');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final token = authController.token;
      if (token == null) throw ApiException('Sessão expirada');
      await ProfileApiService.updateAccount(token,
          password: newPw, currentPassword: current);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Não foi possível alterar a palavra-passe';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alterar palavra-passe',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface)),
            const SizedBox(height: 16),

            if (_forgotMode) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: s.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'A recuperação por email ainda não está disponível. Contacta o suporte para recuperar o acesso.',
                  style: TextStyle(
                      fontSize: 13, color: s.onSurface, height: 1.45),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _forgotMode = false),
                child: Text('← Voltar',
                    style: TextStyle(
                        fontSize: 13,
                        color: s.primary,
                        fontWeight: FontWeight.w500)),
              ),
            ] else ...[
              Text('Palavra-passe actual',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: s.onSurfaceVariant)),
              const SizedBox(height: 6),
              PwField(
                s: s,
                ctrl: _currentCtrl,
                hint: '••••••••',
                obscure: _obscureCurrent,
                hasError: _error != null,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _forgotMode = true;
                    _error = null;
                  }),
                  child: Text(
                    'Esqueci a palavra-passe',
                    style: TextStyle(
                        fontSize: 12,
                        color: s.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Nova palavra-passe',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: s.onSurfaceVariant)),
              const SizedBox(height: 6),
              PwField(
                s: s,
                ctrl: _newCtrl,
                hint: 'Mínimo 6 caracteres',
                obscure: _obscureNew,
                hasError: _error != null,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(fontSize: 12, color: s.error)),
              ],

              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: SheetActionButton(
                    s: s,
                    label: 'Cancelar',
                    filled: false,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            s.primary.withOpacity(_saving ? 0.6 : 1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                year2023: false,
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation(s.onPrimary),
                              ),
                            )
                          : Text('Guardar',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: s.onPrimary)),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class PwField extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final String hint;
  final bool obscure;
  final bool hasError;
  final VoidCallback onToggle;
  const PwField({
    super.key,
    required this.s,
    required this.ctrl,
    required this.hint,
    required this.obscure,
    required this.hasError,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: hasError ? s.error : s.outline.withOpacity(0.5)),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          autofocus: false,
          style: TextStyle(fontSize: 15, color: s.onSurface),
          cursorColor: s.primary,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintText: hint,
            hintStyle: TextStyle(
                fontSize: 15,
                color: s.onSurfaceVariant.withOpacity(0.6)),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AppIcon(
                  obscure ? 'eye' : 'eye_off',
                  color: s.onSurfaceVariant,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      );
}