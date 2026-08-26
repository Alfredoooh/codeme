// ══════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'colors.dart';
import 'widgets.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'app_sheet.dart';
import 'sheets.dart';

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
    showCraftBottomSheet(
      context: context,
      s: s,
      child: Builder(
        builder: (sheetContext) => _ConfirmActionSheet(
          s: s,
          message: 'Terminar sessão? Vais precisar de iniciar sessão novamente para continuar a usar a Nexa.',
          confirmLabel: 'Terminar sessão',
          onConfirm: () {
            Navigator.pop(sheetContext);
            _logoutNow(context);
          },
        ),
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
    showCraftBottomSheet(
      context: context,
      s: s,
      child: _EditFieldSheet(
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
    showCraftBottomSheet(
      context: context,
      s: s,
      child: _EditFieldSheet(
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
    showCraftBottomSheet(
      context: context,
      s: s,
      child: Builder(
        builder: (sheetContext) => _ConfirmActionSheet(
          s: s,
          message: 'Eliminar todas as conversas? Esta ação não pode ser desfeita.',
          confirmLabel: 'Eliminar tudo',
          destructive: true,
          onConfirm: () async {
            Navigator.pop(sheetContext);
            final token = authController.token;
            if (token == null) return;
            await ConversationsApiService.deleteAll(token);
          },
        ),
      ),
    );
  }

  void _openAppearance(BuildContext context, AppColorScheme s) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const _AppearanceScreen(),
    ));
  }

  void _openMemory(BuildContext context, AppColorScheme s) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => _MemoryScreen(
        onDeleteAllConversations: () => _confirmDeleteAllConversations(context, s),
      ),
    ));
  }

  void _openWorkspace(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const _WorkspaceScreen(),
    ));
  }

  void _openPersonalization(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const _PersonalizationScreen(),
    ));
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

                          const SizedBox(height: 32),

                          _SectionLabel(s: s, label: 'Geral'),
                          const SizedBox(height: 10),
                          _SettingsGroup(s: s, rows: [
                            _SettingsRow(
                              s: s,
                              iconAsset: 'paintbrush',
                              label: 'Aparência',
                              onTap: () => _openAppearance(context, s),
                              trailing: AppIcon('chevron_forward',
                                  size: 16, color: s.onSurfaceVariant),
                            ),
                            _SettingsRow(
                              s: s,
                              iconAsset: 'sliders',
                              label: 'Personalização',
                              onTap: () => _openPersonalization(context),
                              trailing: AppIcon('chevron_forward',
                                  size: 16, color: s.onSurfaceVariant),
                            ),
                            _SettingsRow(
                              s: s,
                              iconAsset: 'database',
                              label: 'Memória',
                              onTap: () => _openMemory(context, s),
                              trailing: AppIcon('chevron_forward',
                                  size: 16, color: s.onSurfaceVariant),
                            ),
                            _SettingsRow(
                              s: s,
                              iconAsset: 'briefcase',
                              label: 'Área de trabalho',
                              onTap: () => _openWorkspace(context),
                              trailing: AppIcon('chevron_forward',
                                  size: 16, color: s.onSurfaceVariant),
                            ),
                          ]),

                          const SizedBox(height: 28),

                          _SectionLabel(s: s, label: 'Conta'),
                          const SizedBox(height: 10),
                          _SettingsGroup(s: s, rows: [
                            _SettingsRow(
                              s: s,
                              iconAsset: 'person',
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
                              iconAsset: 'mail',
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
                              iconAsset: 'lock',
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
                              iconAsset: 'credit',
                              label: 'Créditos',
                              onTap: () {},
                              trailing: Text('${user?.credits ?? 0}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant)),
                            ),
                          ]),

                          const SizedBox(height: 28),

                          _SectionLabel(s: s, label: 'Sobre'),
                          const SizedBox(height: 10),
                          _SettingsGroup(s: s, rows: [
                            _SettingsRow(
                              s: s,
                              iconAsset: 'info',
                              label: 'Versão',
                              onTap: () {},
                              trailing: Text('1.0.0',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant)),
                            ),
                            _SettingsRow(
                              s: s,
                              iconAsset: 'license',
                              label: 'Termos de serviço',
                              onTap: () {},
                              trailing: const SizedBox.shrink(),
                            ),
                            _SettingsRow(
                              s: s,
                              iconAsset: 'shield',
                              label: 'Política de privacidade',
                              onTap: () {},
                              trailing: const SizedBox.shrink(),
                            ),
                            _SettingsRow(
                              s: s,
                              iconAsset: 'comment',
                              label: 'Enviar feedback',
                              onTap: () {},
                              trailing: const SizedBox.shrink(),
                            ),
                            _SettingsRow(
                              s: s,
                              iconAsset: 'question',
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

              // Appbar
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    _CircularBackButton(
                      s: s,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Text('Definições',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: s.onSurface)),
                  ]),
                ),
              ),

              // Bottombar
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

// ── Botão de voltar (inalterado) ───────────────────────────────

class _CircularBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _CircularBackButton({required this.s, required this.onTap});
  @override State<_CircularBackButton> createState() => _CircularBackButtonState();
}

class _CircularBackButtonState extends State<_CircularBackButton> {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36, height: 36,
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

// ── Cabeçalho (inalterado) ─────────────────────────────────────

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
    final avatarRaw = user?.avatar;
    final avatarBytes = (avatarRaw != null && avatarRaw.isNotEmpty)
        ? _decodeAvatar(avatarRaw)
        : null;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 88, height: 88,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: s.primary, shape: BoxShape.circle),
              child: avatarBytes != null
                  ? Image.memory(
                      avatarBytes,
                      width: 88, height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(initial,
                          style: TextStyle(
                              color: s.onPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 32)),
                    )
                  : Text(initial,
                      style: TextStyle(
                          color: s.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 32)),
            ),
            if (loading)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: -2, bottom: -2,
              child: Container(
                width: 30, height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.cardBackground,
                  shape: BoxShape.circle,
                  boxShadow: s.cardShadow,
                ),
                child: AppIcon('pencil', size: 14, color: s.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(name,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: s.onSurface),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ── Componentes internos (inalterados) ────────────────────────

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

class _SettingsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<_SettingsRow> rows;
  const _SettingsGroup({required this.s, required this.rows});

  static const double _outerRadius = 20;
  static const double _innerRadius = 6;

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
            borderRadius: radius,
            boxShadow: s.cardShadowSoft),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _SettingsRow extends StatefulWidget {
  final AppColorScheme s;
  final String iconAsset;
  final String label;
  final Widget trailing;
  final Color? labelColor;
  final VoidCallback onTap;
  const _SettingsRow(
      {required this.s,
      required this.iconAsset,
      required this.label,
      required this.trailing,
      required this.onTap,
      this.labelColor});
  @override State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final color = widget.labelColor ?? s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: _p ? s.hover : Colors.transparent,
        child: Row(
          children: [
            AppIcon(widget.iconAsset,
                size: 19, color: widget.labelColor ?? s.onSurfaceVariant),
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

// ══════════════════════════════════════════════════════════════
// APARÊNCIA (com fonte global ligada ao slider)
// ══════════════════════════════════════════════════════════════

class _AppearanceScreen extends StatefulWidget {
  const _AppearanceScreen();
  @override State<_AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<_AppearanceScreen> with ThemeReactive<_AppearanceScreen> {
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  _CircularBackButton(s: s, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text('Aparência',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: s.onSurface)),
                ]),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ThemeSegmentedControl(s: s),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Tamanho do texto',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: s.onSurfaceVariant)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _FontSizeCard(
                  s: s,
                  value: appPreferences.fontScale,
                  onChanged: appPreferences.setFontScale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final AppColorScheme s;
  const _ThemeSegmentedControl({required this.s});

  static const _options = [
    (AppThemeMode.light, 'Claro'),
    (AppThemeMode.dark, 'Escuro'),
    (AppThemeMode.system, 'Automático'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _options.indexWhere((o) => o.$1 == appTheme.mode);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: s.hover,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / _options.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: segmentWidth * selectedIndex.clamp(0, _options.length - 1),
            top: 0,
            bottom: 0,
            width: segmentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: s.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: s.cardShadow,
              ),
            ),
          ),
          Row(
            children: [
              for (final (mode, label) in _options)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => appTheme.setMode(mode),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: appTheme.mode == mode ? FontWeight.w600 : FontWeight.w500,
                          color: appTheme.mode == mode ? s.onPrimary : s.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]);
      }),
    );
  }
}

class _FontSizeCard extends StatelessWidget {
  final AppColorScheme s;
  final double value;
  final ValueChanged<double> onChanged;
  const _FontSizeCard({required this.s, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final previewScale = 0.85 + (value * 0.5);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: s.cardShadowSoft,
      ),
      child: Column(children: [
        _ExpressiveSlider(s: s, value: value, onChanged: onChanged),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: s.hover,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Qual é a verdade do universo?',
                style: TextStyle(
                    fontSize: 14 * previewScale,
                    color: s.onSurface)),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('O Universo é um vasto sistema de leis e mistérios.',
              style: TextStyle(
                  fontSize: 14 * previewScale,
                  color: s.onSurface,
                  height: 1.35)),
        ),
        const SizedBox(height: 18),
        Text('PRÉ-VISUALIZAR',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: s.onSurfaceVariant)),
      ]),
    );
  }
}

class _ExpressiveSlider extends StatefulWidget {
  final AppColorScheme s;
  final double value;
  final ValueChanged<double> onChanged;
  const _ExpressiveSlider({required this.s, required this.value, required this.onChanged});
  @override State<_ExpressiveSlider> createState() => _ExpressiveSliderState();
}

class _ExpressiveSliderState extends State<_ExpressiveSlider> {
  static const double _trackHeight = 26;
  static const double _thumbWidth = 4;
  static const double _thumbHeight = 38;
  static const double _gap = 2;
  static const double _filledEndRadius = 3;

  double _dragValue = 0;
  bool _dragging = false;

  double get _effectiveValue => _dragging ? _dragValue : widget.value;

  void _handlePan(double dx, double width) {
    final usable = width - _thumbWidth;
    final clamped = (dx / usable).clamp(0.0, 1.0);
    setState(() => _dragValue = clamped);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final v = _effectiveValue;
      final thumbX = (v * (width - _thumbWidth)).clamp(0.0, width - _thumbWidth);
      final filledWidth = (thumbX - _gap).clamp(0.0, width);

      return GestureDetector(
        onPanStart: (d) {
          setState(() { _dragging = true; _dragValue = widget.value; });
          _handlePan(d.localPosition.dx, width);
        },
        onPanUpdate: (d) => _handlePan(d.localPosition.dx, width),
        onPanEnd: (_) => setState(() => _dragging = false),
        onTapUp: (d) {
          setState(() { _dragging = true; });
          _handlePan(d.localPosition.dx, width);
          setState(() => _dragging = false);
        },
        child: SizedBox(
          height: _thumbHeight,
          width: width,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: (_thumbHeight - _trackHeight) / 2,
                left: 0, right: 0,
                child: Container(
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    color: s.hover,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                top: (_thumbHeight - _trackHeight) / 2,
                left: 0,
                width: filledWidth,
                child: Container(
                  height: _trackHeight,
                  decoration: BoxDecoration(
                    color: s.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(999),
                      bottomLeft: const Radius.circular(999),
                      topRight: const Radius.circular(_filledEndRadius),
                      bottomRight: const Radius.circular(_filledEndRadius),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: thumbX,
                top: 0,
                child: Container(
                  width: _thumbWidth,
                  height: _thumbHeight,
                  decoration: BoxDecoration(
                    color: s.onSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════
// PERSONALIZAÇÃO (inalterada)
// ══════════════════════════════════════════════════════════════

class _PersonalizationScreen extends StatelessWidget {
  const _PersonalizationScreen();

  void _openPromptEditor(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: _PromptEditorSheet(s: s),
    );
  }

  void _openEmojiFrequency(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: _EmojiFrequencySheet(s: s),
    );
  }

  void _openPrimaryColorPicker(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: _PrimaryColorSheet(s: s),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  _CircularBackButton(s: s, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text('Personalização',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: s.onSurface)),
                ]),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SettingsGroup(s: s, rows: [
                  _SettingsRow(
                    s: s,
                    iconAsset: 'text',
                    label: 'Preferências de prompt',
                    onTap: () => _openPromptEditor(context, s),
                    trailing: Text(
                      appPreferences.prompt.isEmpty ? 'Nenhuma' : 'Editado',
                      style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                    ),
                  ),
                  _SettingsRow(
                    s: s,
                    iconAsset: 'emoji',
                    label: 'Frequência de emojis',
                    onTap: () => _openEmojiFrequency(context, s),
                    trailing: Text(
                      appPreferences.emojiFrequency.displayName,
                      style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                    ),
                  ),
                  _SettingsRow(
                    s: s,
                    iconAsset: 'palette',
                    label: 'Cor primária',
                    onTap: () => _openPrimaryColorPicker(context, s),
                    trailing: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: appTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: s.outline),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sheet editor de prompt ────────────────────────────────────

class _PromptEditorSheet extends StatefulWidget {
  final AppColorScheme s;
  const _PromptEditorSheet({required this.s});
  @override State<_PromptEditorSheet> createState() => _PromptEditorSheetState();
}

class _PromptEditorSheetState extends State<_PromptEditorSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: appPreferences.prompt);
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    appPreferences.setPrompt(_ctrl.text.trim());
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) Navigator.pop(context);
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
            Text('Preferências de prompt',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Instruções que a IA deve seguir em todas as conversas. Ex.: "Responde sempre em português europeu".',
              style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: s.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: s.outline.withOpacity(0.5)),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 15, color: s.onSurface),
                cursorColor: s.primary,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: 'Escreve aqui as tuas preferências...',
                  hintStyle: TextStyle(
                      fontSize: 15, color: s.onSurfaceVariant.withOpacity(0.7)),
                ),
              ),
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

// ── Sheet frequência de emojis ────────────────────────────────

class _EmojiFrequencySheet extends StatelessWidget {
  final AppColorScheme s;
  const _EmojiFrequencySheet({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Frequência de emojis',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const SizedBox(height: 16),
          for (final freq in EmojiFrequency.values)
            _FrequencyOption(
              s: s,
              freq: freq,
              selected: appPreferences.emojiFrequency == freq,
              onTap: () {
                appPreferences.setEmojiFrequency(freq);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _FrequencyOption extends StatelessWidget {
  final AppColorScheme s;
  final EmojiFrequency freq;
  final bool selected;
  final VoidCallback onTap;
  const _FrequencyOption({
    required this.s,
    required this.freq,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected ? s.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                freq.displayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? s.onPrimaryContainer : s.onSurface,
                ),
              ),
            ),
            if (selected)
              AppIcon('checkmark_circle', size: 20, color: s.onPrimaryContainer)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

// ── Sheet seletor de cor primária ─────────────────────────────

class _PrimaryColorSheet extends StatelessWidget {
  final AppColorScheme s;
  const _PrimaryColorSheet({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cor primária',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: s.onSurface)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: kPrimaryColorOptions.map((color) {
              final selected = appTheme.primaryColor.value == color.value;
              return GestureDetector(
                onTap: () {
                  appTheme.setPrimaryColor(color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: s.onSurface, width: 3)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const AppIcon('check', color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MEMÓRIA (inalterada)
// ══════════════════════════════════════════════════════════════

class _MemoryScreen extends StatelessWidget {
  final VoidCallback onDeleteAllConversations;
  const _MemoryScreen({required this.onDeleteAllConversations});

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  _CircularBackButton(s: s, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text('Memória',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: s.onSurface)),
                ]),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Gere os dados de conversas guardados na tua conta.',
                  style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SettingsGroup(s: s, rows: [
                  _SettingsRow(
                    s: s,
                    iconAsset: 'trash',
                    label: 'Eliminar todas as conversas',
                    labelColor: s.error,
                    onTap: onDeleteAllConversations,
                    trailing: const SizedBox.shrink(),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ÁREA DE TRABALHO (inalterada)
// ══════════════════════════════════════════════════════════════

class _WorkspaceScreen extends StatelessWidget {
  const _WorkspaceScreen();

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  _CircularBackButton(s: s, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text('Área de trabalho',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: s.onSurface)),
                ]),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SettingsGroup(s: s, rows: [
                  _SettingsRow(
                    s: s,
                    iconAsset: 'person',
                    label: 'Pessoal',
                    onTap: () {},
                    trailing: AppIcon('checkmark_circle',
                        size: 18, color: s.primary),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}