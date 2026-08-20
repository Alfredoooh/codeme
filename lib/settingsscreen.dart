// ══════════════════════════════════════════════════════════════
// SETTINGS SCREEN (atualizado com HugeIcons)
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:hugeicons/hugeicons.dart'; // ✅ adicionado
import 'colors.dart';
import 'widgets.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'app_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with ThemeReactive<SettingsScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    authController.addListener(_onAuthChanged);
    _refreshMe();
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() { if (mounted) setState(() {}); }

  Future<void> _refreshMe() async {
    final token = authController.token;
    if (token == null) return;
    setState(() => _refreshing = true);
    try {
      final me = await ProfileApiService.getMe(token);
      authController.user = AppUser.fromJson(me);
      await SessionManager.updateUser(authController.user!);
      authController.notifyListeners();
    } catch (_) {
      // Sem sorte agora — mantém o que já estava carregado localmente.
    }
    if (mounted) setState(() => _refreshing = false);
  }

  void _confirmLogout(BuildContext context, AppColorScheme s) {
    showAppSheet(
      context,
      builder: (ctx) => _ConfirmActionSheet(
        s: s,
        message: 'Terminar sessão? Vais precisar de iniciar sessão novamente para continuar a usar a Nexa.',
        confirmLabel: 'Terminar sessão',
        onConfirm: () {
          Navigator.pop(ctx);
          _logoutNow(context);
        },
      ),
    );
  }

  Future<void> _logoutNow(BuildContext context) async {
    await authController.logout();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _editName(BuildContext context, AppColorScheme s) {
    showAppSheet(
      context,
      builder: (ctx) => _EditFieldSheet(
        s: s,
        title: 'Alterar nome',
        label: 'Nome',
        hint: 'O teu nome completo',
        initialValue: authController.user?.name ?? '',
        onSave: (value) async {
          final token = authController.token;
          if (token == null) return;
          final data = await ProfileApiService.updateAccount(token, name: value);
          authController.user = authController.user?.copyWith(
            name: data['name']?.toString() ?? value,
          );
          if (authController.user != null) {
            await SessionManager.updateUser(authController.user!);
          }
          authController.notifyListeners();
        },
      ),
    );
  }

  void _editPassword(BuildContext context, AppColorScheme s) {
    showAppSheet(
      context,
      builder: (ctx) => _EditFieldSheet(
        s: s,
        title: 'Alterar palavra-passe',
        label: 'Nova palavra-passe',
        hint: 'Mínimo 6 caracteres',
        initialValue: '',
        obscure: true,
        minLength: 6,
        onSave: (value) async {
          final token = authController.token;
          if (token == null) return;
          await ProfileApiService.updateAccount(token, password: value);
        },
      ),
    );
  }

  void _confirmDeleteAllConversations(BuildContext context, AppColorScheme s) {
    showAppSheet(
      context,
      builder: (ctx) => _ConfirmActionSheet(
        s: s,
        message: 'Eliminar todas as conversas? Esta ação não pode ser desfeita.',
        confirmLabel: 'Eliminar tudo',
        destructive: true,
        onConfirm: () async {
          Navigator.pop(ctx);
          final token = authController.token;
          if (token == null) return;
          await ConversationsApiService.deleteAll(token);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final user = authController.user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: s.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: s.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: s.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Stack(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 52 + 6),
                  Expanded(
                    child: RefreshIndicator(
                      color: s.primary,
                      backgroundColor: s.cardBackground,
                      onRefresh: _refreshMe,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        children: [
                          _ProfileHeader(s: s, user: user, loading: _refreshing),

                          const SizedBox(height: 28),

                          _SectionLabel(s: s, label: 'Aparência'),
                          const SizedBox(height: 10),
                          _SettingsGroup(s: s, rows: [
                            _SettingsRow(
                              s: s,
                              label: 'Modo escuro',
                              onTap: () {},
                              trailing: AppSwitch(
                                value: appTheme.isDark,
                                s: s,
                                onChanged: (_) => appTheme.toggleDark(),
                              ),
                            ),
                          ]),

                          const SizedBox(height: 28),

                          _SectionLabel(s: s, label: 'Conta'),
                          const SizedBox(height: 10),
                          _SettingsGroup(s: s, rows: [
                            _SettingsRow(
                              s: s,
                              label: 'Nome',
                              onTap: () => _editName(context, s),
                              trailing: Text('Alterar',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.primary,
                                      fontWeight: FontWeight.w500)),
                            ),
                            _SettingsRow(
                              s: s,
                              label: 'Email',
                              onTap: () {},
                              trailing: Text(user?.email ?? '—',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            _SettingsRow(
                              s: s,
                              label: 'Palavra-passe',
                              onTap: () => _editPassword(context, s),
                              trailing: Text('Alterar',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.primary,
                                      fontWeight: FontWeight.w500)),
                            ),
                            _SettingsRow(
                              s: s,
                              label: 'Créditos',
                              onTap: () {},
                              trailing: Text('${user?.credits ?? 0}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant)),
                            ),
                          ]),

                          const SizedBox(height: 28),

                          _SectionLabel(s: s, label: 'Dados'),
                          const SizedBox(height: 10),
                          _SettingsGroup(s: s, rows: [
                            _SettingsRow(
                              s: s,
                              label: 'Eliminar todas as conversas',
                              labelColor: s.error,
                              onTap: () => _confirmDeleteAllConversations(context, s),
                              trailing: const SizedBox.shrink(),
                            ),
                          ]),

                          const SizedBox(height: 28),

                          _SectionLabel(s: s, label: 'Sobre'),
                          const SizedBox(height: 10),
                          _SettingsGroup(s: s, rows: [
                            _SettingsRow(
                              s: s,
                              label: 'Versão',
                              onTap: () {},
                              trailing: Text('1.0.0',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant)),
                            ),
                            _SettingsRow(
                              s: s,
                              label: 'Termos de serviço',
                              onTap: () {},
                              trailing: const SizedBox.shrink(),
                            ),
                            _SettingsRow(
                              s: s,
                              label: 'Política de privacidade',
                              onTap: () {},
                              trailing: const SizedBox.shrink(),
                            ),
                            _SettingsRow(
                              s: s,
                              label: 'Enviar feedback',
                              onTap: () {},
                              trailing: const SizedBox.shrink(),
                            ),
                            _SettingsRow(
                              s: s,
                              label: 'Ajuda e suporte',
                              onTap: () {},
                              trailing: const SizedBox.shrink(),
                            ),
                          ]),

                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

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
                      // ✅ substituído AppIcon por HugeIcon
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: s.onSurface,
                        size: 20,
                      ),
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
      ),
    );
  }
}

// ── Cabeçalho com avatar, nome e email reais ────────────────────

class _ProfileHeader extends StatelessWidget {
  final AppColorScheme s;
  final AppUser? user;
  final bool loading;
  const _ProfileHeader({required this.s, required this.user, required this.loading});

  Uint8List? _decodeAvatar(String raw) {
    try {
      final commaIdx = raw.indexOf(',');
      final b64 = raw.startsWith('data:') && commaIdx != -1
          ? raw.substring(commaIdx + 1)
          : raw;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Utilizador';
    final email = user?.email ?? '';
    final avatarRaw = user?.avatar;
    final avatarBytes = (avatarRaw != null && avatarRaw.isNotEmpty)
        ? _decodeAvatar(avatarRaw)
        : null;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: s.primary, shape: BoxShape.circle),
          child: avatarBytes != null
              ? Image.memory(
                  avatarBytes,
                  width: 56, height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(initial,
                      style: TextStyle(
                          color: s.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 22)),
                )
              : Text(initial,
                  style: TextStyle(
                      color: s.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: s.onSurface),
                  overflow: TextOverflow.ellipsis),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(email,
                    style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        if (loading)
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant),
            ),
          ),
      ]),
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
  final List<_SettingsRow> rows;
  const _SettingsGroup({required this.s, required this.rows});

  static const double _outerRadius = 16;
  static const double _innerRadius = 2;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(_SettingsCard(
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
  final VoidCallback onTap;
  const _SettingsRow(
      {required this.s,
      required this.label,
      required this.trailing,
      required this.onTap,
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
        onTap: widget.onTap,
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
                  color: s.onError)),
        ),
      ),
    );
  }
}

// ── Sheet de confirmação genérico (Sim / Não) ─────────────────

class _ConfirmActionSheet extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final VoidCallback onConfirm;
  const _ConfirmActionSheet({
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: s.onSurface),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: _SheetActionButton(
                s: s,
                label: 'Cancelar',
                filled: false,
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SheetActionButton(
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
              color: widget.filled ? s.onError : s.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sheet de edição de campo simples (nome / palavra-passe) ────

class _EditFieldSheet extends StatefulWidget {
  final AppColorScheme s;
  final String title;
  final String label;
  final String hint;
  final String initialValue;
  final bool obscure;
  final int minLength;
  final Future<void> Function(String value) onSave;
  const _EditFieldSheet({
    required this.s,
    required this.title,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onSave,
    this.obscure = false,
    this.minLength = 1,
  });

  @override State<_EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<_EditFieldSheet> {
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
    setState(() { _saving = true; _error = null; });
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    color: _error != null ? s.error : s.outline.withOpacity(0.5)),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                      fontSize: 15, color: s.onSurfaceVariant.withOpacity(0.7)),
                  suffixIcon: widget.obscure
                      ? GestureDetector(
                          onTap: () => setState(() => _obscureNow = !_obscureNow),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            // ✅ substituído AppIcon por HugeIcon
                            child: HugeIcon(
  icon: _obscureNow
      ? HugeIcons.strokeRoundedEye
      : HugeIcons.strokeRoundedViewOffSlash,
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
              Text(_error!, style: TextStyle(fontSize: 12, color: s.error)),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _SheetActionButton(
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
                      color: s.primary.withOpacity(_saving ? 0.6 : 1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(s.onPrimary),
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