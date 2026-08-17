// ══════════════════════════════════════════════════════════════
// FILE: lib/settingsscreen.dart
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'colors.dart';
import 'widgets.dart';
import 'auth_service.dart';
import 'api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with ThemeReactive<SettingsScreen> {
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

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

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
      // mantém o que estava
    }
    if (mounted) setState(() => _refreshing = false);
  }

  void _confirmLogout(BuildContext context, AppColorScheme s) {
    showFluentBottomSheet(
      context: context,
      s: s,
      child: _ConfirmActionSheet(
        s: s,
        message:
            'Terminar sessão? Vais precisar de iniciar sessão novamente para continuar a usar a Nexa.',
        confirmLabel: 'Terminar sessão',
        onConfirm: () {
          Navigator.pop(context);
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
    showFluentBottomSheet(
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
    showFluentBottomSheet(
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
    showFluentBottomSheet(
      context: context,
      s: s,
      child: _ConfirmActionSheet(
        s: s,
        message: 'Eliminar todas as conversas? Esta ação não pode ser desfeita.',
        confirmLabel: 'Eliminar tudo',
        destructive: true,
        onConfirm: () async {
          Navigator.pop(context);
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
        systemNavigationBarIconBrightness:
            s.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: kSpaceXXXL + kSpaceXXL + kSpaceXXS),
                    Expanded(
                      child: RefreshIndicator(
                        color: s.primary,
                        backgroundColor: s.cardBackground,
                        onRefresh: _refreshMe,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            kSpaceXL,
                            kSpaceS,
                            kSpaceXL,
                            kSpaceM,
                          ),
                          children: [
                            _ProfileHeader(
                              s: s,
                              user: user,
                              loading: _refreshing,
                            ),
                            SizedBox(height: kSpaceXXL + kSpaceXS),
                            FluentSectionLabel(s: s, label: 'Aparência'),
                            SizedBox(height: kSpaceS + kSpaceXXS),
                            FluentListGroup(
                              s: s,
                              children: [
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Modo escuro',
                                  onTap: () {},
                                  trailing: AppSwitch(
                                    value: appTheme.isDark,
                                    s: s,
                                    onChanged: (_) => appTheme.toggleDark(),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: kSpaceXXL + kSpaceXS),
                            FluentSectionLabel(s: s, label: 'Conta'),
                            SizedBox(height: kSpaceS + kSpaceXXS),
                            FluentListGroup(
                              s: s,
                              children: [
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Nome',
                                  onTap: () => _editName(context, s),
                                  trailing: Text(
                                    'Alterar',
                                    style: TextStyle(
                                      fontSize: kTypeBody,
                                      color: s.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Email',
                                  onTap: () {},
                                  trailing: Text(
                                    user?.email ?? '—',
                                    style: TextStyle(
                                      fontSize: kTypeBody,
                                      color: s.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Palavra-passe',
                                  onTap: () => _editPassword(context, s),
                                  trailing: Text(
                                    'Alterar',
                                    style: TextStyle(
                                      fontSize: kTypeBody,
                                      color: s.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Créditos',
                                  onTap: () {},
                                  trailing: Text(
                                    '${user?.credits ?? 0}',
                                    style: TextStyle(
                                      fontSize: kTypeBody,
                                      color: s.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: kSpaceXXL + kSpaceXS),
                            FluentSectionLabel(s: s, label: 'Dados'),
                            SizedBox(height: kSpaceS + kSpaceXXS),
                            FluentListGroup(
                              s: s,
                              children: [
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Eliminar todas as conversas',
                                  labelColor: s.error,
                                  onTap: () =>
                                      _confirmDeleteAllConversations(context, s),
                                  trailing: const SizedBox.shrink(),
                                ),
                              ],
                            ),
                            SizedBox(height: kSpaceXXL + kSpaceXS),
                            FluentSectionLabel(s: s, label: 'Sobre'),
                            SizedBox(height: kSpaceS + kSpaceXXS),
                            FluentListGroup(
                              s: s,
                              children: [
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Versão',
                                  onTap: () {},
                                  trailing: Text(
                                    '1.0.0',
                                    style: TextStyle(
                                      fontSize: kTypeBody,
                                      color: s.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Termos de serviço',
                                  onTap: () {},
                                  trailing: const SizedBox.shrink(),
                                ),
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Política de privacidade',
                                  onTap: () {},
                                  trailing: const SizedBox.shrink(),
                                ),
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Enviar feedback',
                                  onTap: () {},
                                  trailing: const SizedBox.shrink(),
                                ),
                                FluentListCard(
                                  s: s,
                                  radius: kRadiusLarge,
                                  label: 'Ajuda e suporte',
                                  onTap: () {},
                                  trailing: const SizedBox.shrink(),
                                ),
                              ],
                            ),
                            SizedBox(
                                height:
                                    kSpaceXXXL * 2 + kSpaceXXL + kSpaceXXS),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: kSpaceS),
                    height: kSpaceXXXL + kSpaceXL,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [s.pageBackground, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        AppTap(
                          onTap: () => Navigator.pop(context),
                          s: s,
                          child: AppIcon(
                            'back.svg',
                            color: s.onSurface,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: kSpaceS),
                        Text(
                          'Definições',
                          style: TextStyle(
                            fontSize: kTypeBodyLarge,
                            fontWeight: FontWeight.w600,
                            color: s.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      kSpaceXL,
                      kSpaceXXL + kSpaceXS,
                      kSpaceXL,
                      kSpaceL,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [s.pageBackground, Colors.transparent],
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FluentButton(
                        s: s,
                        label: 'Terminar sessão',
                        onTap: () => _confirmLogout(context, s),
                        style: FluentButtonStyle.destructive,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
  const _ProfileHeader({
    required this.s,
    required this.user,
    required this.loading,
  });

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
      padding: EdgeInsets.all(kSpaceL + kSpaceXXS),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(kRadiusLarge),
      ),
      child: Row(
        children: [
          Container(
            width: kSpaceXXXL + kSpaceXXL,
            height: kSpaceXXXL + kSpaceXXL,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: s.primary,
              shape: BoxShape.circle,
            ),
            child: avatarBytes != null
                ? Image.memory(
                    avatarBytes,
                    width: kSpaceXXXL + kSpaceXXL,
                    height: kSpaceXXXL + kSpaceXXL,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(
                      initial,
                      style: TextStyle(
                        color: s.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: kTypeSubtitle,
                      ),
                    ),
                  )
                : Text(
                    initial,
                    style: TextStyle(
                      color: s.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: kTypeSubtitle,
                    ),
                  ),
          ),
          SizedBox(width: kSpaceL - kSpaceXXS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: kTypeBodyLarge,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  SizedBox(height: kSpaceXS),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: kTypeBody,
                      color: s.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (loading)
            FluentShimmer(
              s: s,
              width: kSpaceL,
              height: kSpaceL,
            ),
        ],
      ),
    );
  }
}

// ── Sheet de confirmação genérico ────────────────────────────────

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
    return FluentBottomSheet(
      s: s,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: kTypeBody,
              fontWeight: FontWeight.w500,
              color: s.onSurface,
            ),
          ),
          SizedBox(height: kSpaceXL),
          Row(
            children: [
              Expanded(
                child: FluentButton(
                  s: s,
                  label: 'Cancelar',
                  onTap: () => Navigator.pop(context),
                  style: FluentButtonStyle.secondary,
                ),
              ),
              SizedBox(width: kSpaceS + kSpaceXXS),
              Expanded(
                child: FluentButton(
                  s: s,
                  label: confirmLabel,
                  onTap: onConfirm,
                  style: destructive
                      ? FluentButtonStyle.destructive
                      : FluentButtonStyle.primary,
                ),
              ),
            ],
          ),
        ],
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

  @override
  State<_EditFieldSheet> createState() => _EditFieldSheetState();
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
    return FluentBottomSheet(
      s: s,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: kTypeBodyLarge,
              fontWeight: FontWeight.w700,
              color: s.onSurface,
            ),
          ),
          SizedBox(height: kSpaceL),
          FluentTextField(
            s: s,
            controller: _ctrl,
            label: widget.label,
            hint: widget.hint,
            obscure: widget.obscure ? _obscureNow : false,
            error: _error,
            autofocus: true,
            onSubmitted: (_) => _save(),
            suffixIcon: widget.obscure
                ? AppTap(
                    onTap: () =>
                        setState(() => _obscureNow = !_obscureNow),
                    s: s,
                    child: AppIcon(
                      _obscureNow ? 'eye.svg' : 'eye_off.svg',
                      color: s.onSurfaceVariant,
                      size: 18,
                    ),
                  )
                : null,
          ),
          SizedBox(height: kSpaceXL),
          Row(
            children: [
              Expanded(
                child: FluentButton(
                  s: s,
                  label: 'Cancelar',
                  onTap: () => Navigator.pop(context),
                  style: FluentButtonStyle.secondary,
                ),
              ),
              SizedBox(width: kSpaceS + kSpaceXXS),
              Expanded(
                child: FluentButton(
                  s: s,
                  label: 'Guardar',
                  onTap: _saving ? null : _save,
                  style: FluentButtonStyle.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}