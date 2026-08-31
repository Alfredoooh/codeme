// ══════════════════════════════════════════════════════════════
// FILE: lib/settingsscreen.dart
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'colors.dart';
import 'widgets.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'app_sheet.dart';
import 'sheets.dart';

// ══════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ══════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with ThemeReactive<SettingsScreen> {
  bool _refreshing = false;

  // Controlo do título na appbar (aparece só com scroll)
  double _scrollOffset = 0.0;
  final ScrollController _scrollController = ScrollController();

  // Altura do bloco de avatar + nome no topo do scroll
  static const double _avatarBlockHeight = 200.0;
  // A partir de que offset o título começa a aparecer
  static const double _titleFadeStart = 140.0;
  static const double _titleFadeEnd = 180.0;

  @override
  void initState() {
    super.initState();
    authController.addListener(_onAuthChanged);
    _scrollController.addListener(_onScroll);
    _refreshMe();
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if ((offset - _scrollOffset).abs() > 0.5) {
      setState(() => _scrollOffset = offset);
    }
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  // Opacidade do título na appbar: 0 quando avatar visível, 1 quando scrollou
  double get _titleOpacity {
    if (_scrollOffset <= _titleFadeStart) return 0.0;
    if (_scrollOffset >= _titleFadeEnd) return 1.0;
    return (_scrollOffset - _titleFadeStart) / (_titleFadeEnd - _titleFadeStart);
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
    } catch (_) {}
    if (mounted) setState(() => _refreshing = false);
  }

  void _confirmLogout(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: Builder(
        builder: (sheetContext) => _ConfirmActionSheet(
          s: s,
          message:
              'Terminar sessão? Vais precisar de iniciar sessão novamente para continuar a usar a Nexa.',
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
          final data =
              await ProfileApiService.updateAccount(token, name: value);
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
      child: _ChangePasswordSheet(s: s),
    );
  }

  void _confirmDeleteAllConversations(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: Builder(
        builder: (sheetContext) => _ConfirmActionSheet(
          s: s,
          message:
              'Eliminar todas as conversas? Esta ação não pode ser desfeita.',
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
        onDeleteAllConversations: () =>
            _confirmDeleteAllConversations(context, s),
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

  Future<void> _pickAvatarDirectly() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Editar avatar',
          toolbarColor: AppTheme.of(context).cardBackground,
          toolbarWidgetColor: AppTheme.of(context).onSurface,
          activeControlsWidgetColor: AppTheme.of(context).primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Editar avatar',
          aspectRatioLockEnabled: false,
          rotateButtonsHidden: false,
        ),
      ],
    );

    if (cropped == null || !mounted) return;

    final bytes = await cropped.readAsBytes();
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final token = authController.token;
    if (token == null) return;
    await ProfileApiService.updateAvatar(token, b64);
    authController.user = authController.user?.copyWith(avatar: b64);
    if (authController.user != null) {
      await SessionManager.updateUser(authController.user!);
    }
    authController.notifyListeners();
  }

  void _openAvatarViewer(BuildContext context, AppColorScheme s) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.6),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (ctx, anim, _) => _AvatarViewerScreen(
          s: s,
          onAvatarUpdated: (newAvatar) async {
            final token = authController.token;
            if (token == null) return;
            await ProfileApiService.updateAvatar(token, newAvatar);
            authController.user =
                authController.user?.copyWith(avatar: newAvatar);
            if (authController.user != null) {
              await SessionManager.updateUser(authController.user!);
            }
            authController.notifyListeners();
          },
        ),
        transitionsBuilder: (ctx, anim, _, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          );
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
        statusBarIconBrightness:
            s.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            s.isDark ? Brightness.dark : Brightness.light,
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
            child: Stack(children: [

              // ── Conteúdo com scroll ─────────────────────────
              RefreshIndicator(
                color: s.primary,
                backgroundColor: s.cardBackground,
                onRefresh: _refreshMe,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    // Espaço para a appbar
                    const SliverToBoxAdapter(child: SizedBox(height: 60)),

                    // ── Bloco avatar + nome (estático no scroll) ──
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: _AvatarBlock(
                          s: s,
                          user: user,
                          loading: _refreshing,
                          onAvatarTap: () =>
                              _openAvatarViewer(context, s),
                          onEditTap: _pickAvatarDirectly,
                        ),
                      ),
                    ),

                    // ── Secções ────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _SectionLabel(s: s, label: 'Geral'),
                            const SizedBox(height: 10),
                            _SettingsGroup(s: s, rows: [
                              _SettingsRow(
                                s: s,
                                iconAsset: 'paintbrush',
                                label: 'Aparência',
                                onTap: () =>
                                    _openAppearance(context, s),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              _SettingsRow(
                                s: s,
                                iconAsset: 'sliders',
                                label: 'Personalização',
                                onTap: () =>
                                    _openPersonalization(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              _SettingsRow(
                                s: s,
                                iconAsset: 'database',
                                label: 'Memória',
                                onTap: () =>
                                    _openMemory(context, s),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              _SettingsRow(
                                s: s,
                                iconAsset: 'briefcase',
                                label: 'Área de trabalho',
                                onTap: () =>
                                    _openWorkspace(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
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
                                onTap: () =>
                                    _editName(context, s),
                                trailing: Text('Alterar',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: s.primary,
                                        fontWeight:
                                            FontWeight.w500)),
                              ),
                              _SettingsRow(
                                s: s,
                                iconAsset: 'mail',
                                label: 'Email',
                                onTap: () {},
                                trailing: Text(
                                  user?.email ?? '—',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _SettingsRow(
                                s: s,
                                iconAsset: 'lock',
                                label: 'Palavra-passe',
                                onTap: () =>
                                    _editPassword(context, s),
                                trailing: Text('Alterar',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: s.primary,
                                        fontWeight:
                                            FontWeight.w500)),
                              ),
                              _SettingsRow(
                                s: s,
                                iconAsset: 'credit',
                                label: 'Créditos',
                                onTap: () {},
                                trailing: Text(
                                  '${user?.credits ?? 0}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: s.onSurfaceVariant),
                                ),
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
                            // Espaço para o botão de logout fixo na base
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Appbar transparente progressiva ────────────
              // Título "Configurações" aparece só com scroll
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _SettingsAppBar(
                  s: s,
                  titleOpacity: _titleOpacity,
                  onBack: () => Navigator.pop(context),
                ),
              ),

              // ── Botão logout fixo na base ──────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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
                      s: s,
                      onTap: () => _confirmLogout(context, s)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// APPBAR DO SETTINGS — transparência progressiva, título faz
// fade in só quando o avatar sai do ecrã ao fazer scroll.
// ══════════════════════════════════════════════════════════════

class _SettingsAppBar extends StatelessWidget {
  final AppColorScheme s;
  final double titleOpacity;
  final VoidCallback onBack;
  const _SettingsAppBar({
    required this.s,
    required this.titleOpacity,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
      child: Row(
        children: [
          _CircularBackButton(
            s: s,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          // Título aparece com fade suave ao fazer scroll
          Opacity(
            opacity: titleOpacity.clamp(0.0, 1.0),
            child: Text(
              'Configurações',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: s.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BLOCO AVATAR + NOME — estático, sem piscar, sem sliver.
// ══════════════════════════════════════════════════════════════

class _AvatarBlock extends StatelessWidget {
  final AppColorScheme s;
  final AppUser? user;
  final bool loading;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;
  const _AvatarBlock({
    required this.s,
    required this.user,
    required this.loading,
    required this.onAvatarTap,
    required this.onEditTap,
  });

  Uint8List? _decodeAvatar(String? raw) {
    if (raw == null || raw.isEmpty) return null;
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
    final avatarBytes = _decodeAvatar(user?.avatar);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    const avatarSize = 88.0;
    const ringWidth = 3.0;
    final innerSize = avatarSize - ringWidth * 2 - 2;

    return Column(
      children: [
        // Avatar com botão de editar (badge no canto)
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onAvatarTap,
              child: Hero(
                tag: 'avatar',
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: s.outline, width: ringWidth),
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: innerSize,
                      height: innerSize,
                      child: avatarBytes != null
                          ? Image.memory(
                              avatarBytes,
                              width: innerSize,
                              height: innerSize,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _AvatarInitial(
                                      s: s,
                                      initial: initial,
                                      size: avatarSize),
                            )
                          : _AvatarInitial(
                              s: s,
                              initial: initial,
                              size: avatarSize),
                    ),
                  ),
                ),
              ),
            ),

            // Badge de editar
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: onEditTap,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.cardBackground,
                    shape: BoxShape.circle,
                    boxShadow: s.cardShadow,
                    border:
                        Border.all(color: s.pageBackground, width: 2),
                  ),
                  child: AppIcon('pencil', size: 14, color: s.onSurface),
                ),
              ),
            ),

            // Loading overlay
            if (loading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 14),

        // Nome
        Text(
          name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: s.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // Email em subtítulo
        if (user?.email != null)
          Text(
    user!.email ?? '',
            style: TextStyle(
              fontSize: 13,
              color: s.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

// Widget auxiliar para o inicial do avatar
class _AvatarInitial extends StatelessWidget {
  final AppColorScheme s;
  final String initial;
  final double size;
  const _AvatarInitial(
      {required this.s, required this.initial, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        color: s.primary,
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: s.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.35,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// AVATAR VIEWER + EDITOR
// ══════════════════════════════════════════════════════════════

class _AvatarViewerScreen extends StatefulWidget {
  final AppColorScheme s;
  final Future<void> Function(String base64Avatar) onAvatarUpdated;
  const _AvatarViewerScreen({
    required this.s,
    required this.onAvatarUpdated,
  });

  @override
  State<_AvatarViewerScreen> createState() => _AvatarViewerScreenState();
}

class _AvatarViewerScreenState extends State<_AvatarViewerScreen> {
  bool _uploading = false;

  Uint8List? _decodeAvatar(String? raw) {
    if (raw == null || raw.isEmpty) return null;
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

  Future<void> _pickAndEdit() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Editar avatar',
          toolbarColor: widget.s.cardBackground,
          toolbarWidgetColor: widget.s.onSurface,
          activeControlsWidgetColor: widget.s.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Editar avatar',
          aspectRatioLockEnabled: false,
          rotateButtonsHidden: false,
        ),
      ],
    );

    if (cropped == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await cropped.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await widget.onAvatarUpdated(b64);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final user = authController.user;
    final avatarBytes = _decodeAvatar(user?.avatar);
    final initial =
        (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'U';
    final squareSize = MediaQuery.of(context).size.width - 32;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'avatar',
                  child: Container(
                    width: squareSize,
                    height: squareSize,
                    decoration: BoxDecoration(
                      color: s.primary,
                      borderRadius: BorderRadius.zero,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarBytes != null
                        ? Image.memory(avatarBytes, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(initial,
                                  style: TextStyle(
                                      color: s.onPrimary,
                                      fontSize: 72,
                                      fontWeight: FontWeight.w700)),
                            ))
                        : Center(
                            child: Text(initial,
                                style: TextStyle(
                                    color: s.onPrimary,
                                    fontSize: 72,
                                    fontWeight: FontWeight.w700)),
                          ),
                  ),
                ),
                GestureDetector(
                  onTap: _uploading ? null : _pickAndEdit,
                  child: Container(
                    width: squareSize,
                    height: 56,
                    decoration: BoxDecoration(
                      color: s.isDark ? Colors.white : s.primary,
                      borderRadius: BorderRadius.zero,
                    ),
                    alignment: Alignment.center,
                    child: _uploading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              year2023: false,
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                  s.isDark ? Colors.black : s.onPrimary),
                            ),
                          )
                        : Text(
                            'Carregar nova imagem',
                            style: TextStyle(
                              color:
                                  s.isDark ? Colors.black : s.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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

// ══════════════════════════════════════════════════════════════
// ALTERAR PALAVRA-PASSE
// ══════════════════════════════════════════════════════════════

class _ChangePasswordSheet extends StatefulWidget {
  final AppColorScheme s;
  const _ChangePasswordSheet({required this.s});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
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
              _PwField(
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
              _PwField(
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

class _PwField extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final String hint;
  final bool obscure;
  final bool hasError;
  final VoidCallback onToggle;
  const _PwField({
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

// ══════════════════════════════════════════════════════════════
// BOTÃO DE VOLTAR CIRCULAR
// ══════════════════════════════════════════════════════════════

class _CircularBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _CircularBackButton({required this.s, required this.onTap});
  @override
  State<_CircularBackButton> createState() => _CircularBackButtonState();
}

class _CircularBackButtonState extends State<_CircularBackButton> {
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
// COMPONENTES INTERNOS
// ══════════════════════════════════════════════════════════════

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
    final isLast = index == count - 1;
    return BorderRadius.only(
      topLeft: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft: Radius.circular(isLast ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast ? _outerRadius : _innerRadius),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final Widget child;
  const _SettingsCard(
      {required this.s, required this.radius, required this.child});

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
  const _SettingsRow({
    required this.s,
    required this.iconAsset,
    required this.label,
    required this.trailing,
    required this.onTap,
    this.labelColor,
  });
  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
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

class _LogoutButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _LogoutButton({required this.s, required this.onTap});
  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
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
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: s.onSurface)),
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
  const _SheetActionButton({
    required this.s,
    required this.label,
    required this.filled,
    required this.onTap,
  });
  @override
  State<_SheetActionButton> createState() => _SheetActionButtonState();
}

class _SheetActionButtonState extends State<_SheetActionButton> {
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
// APARÊNCIA
// ══════════════════════════════════════════════════════════════

class _AppearanceScreen extends StatefulWidget {
  const _AppearanceScreen();
  @override
  State<_AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<_AppearanceScreen>
    with ThemeReactive<_AppearanceScreen> {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
            _TransparentFadeAppBar(
              s: s,
              title: 'Aparência',
              onBack: () => Navigator.pop(context),
            ),
          ]),
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
    final selectedIndex =
        _options.indexWhere((o) => o.$1 == appTheme.mode);

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
            left:
                segmentWidth * selectedIndex.clamp(0, _options.length - 1),
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
                          fontWeight: appTheme.mode == mode
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: appTheme.mode == mode
                              ? s.onPrimary
                              : s.onSurfaceVariant,
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
  const _FontSizeCard(
      {required this.s, required this.value, required this.onChanged});

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
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: s.hover,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Qual é a verdade do universo?',
                style:
                    TextStyle(fontSize: 14 * previewScale, color: s.onSurface)),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              'O Universo é um vasto sistema de leis e mistérios.',
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
  const _ExpressiveSlider(
      {required this.s, required this.value, required this.onChanged});
  @override
  State<_ExpressiveSlider> createState() => _ExpressiveSliderState();
}

class _ExpressiveSliderState extends State<_ExpressiveSlider> {
  static const double _trackHeight = 26;
  static const double _thumbWidth = 4;
  static const double _thumbHeight = 38;
  static const double _gap = 2;
  static const double _filledEndRadius = 3;

  double _dragValue = 0;
  bool _dragging = false;

  double get _effectiveValue =>
      _dragging ? _dragValue : widget.value;

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
      final thumbX =
          (v * (width - _thumbWidth)).clamp(0.0, width - _thumbWidth);
      final filledWidth = (thumbX - _gap).clamp(0.0, width);

      return GestureDetector(
        onPanStart: (d) {
          setState(() {
            _dragging = true;
            _dragValue = widget.value;
          });
          _handlePan(d.localPosition.dx, width);
        },
        onPanUpdate: (d) => _handlePan(d.localPosition.dx, width),
        onPanEnd: (_) => setState(() => _dragging = false),
        onTapUp: (d) {
          setState(() => _dragging = true);
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
                left: 0,
                right: 0,
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
                      topRight:
                          const Radius.circular(_filledEndRadius),
                      bottomRight:
                          const Radius.circular(_filledEndRadius),
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
// PERSONALIZAÇÃO — sem ícones nas rows, só texto + trailing
// ══════════════════════════════════════════════════════════════

class _PersonalizationScreen extends StatefulWidget {
  const _PersonalizationScreen();
  @override
  State<_PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<_PersonalizationScreen>
    with ThemeReactive<_PersonalizationScreen> {

  @override
  void initState() {
    super.initState();
    appPreferences.addListener(_onPrefsChanged);
    appTheme.addListener(_onPrefsChanged);
  }

  @override
  void dispose() {
    appPreferences.removeListener(_onPrefsChanged);
    appTheme.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

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
          child: Stack(children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(top: 62),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // ── Grupo sem ícones ─────────────────────────
                child: _PersonalizationGroup(s: s, rows: [
                  _PersonalizationRow(
                    s: s,
                    label: 'Preferências de prompt',
                    onTap: () => _openPromptEditor(context, s),
                    trailing: Text(
                      appPreferences.prompt.isEmpty ? 'Nenhuma' : 'Editado',
                      style: TextStyle(
                          fontSize: 14, color: s.onSurfaceVariant),
                    ),
                  ),
                  _PersonalizationRow(
                    s: s,
                    label: 'Frequência de emojis',
                    onTap: () => _openEmojiFrequency(context, s),
                    trailing: Text(
                      appPreferences.emojiFrequency.displayName,
                      style: TextStyle(
                          fontSize: 14, color: s.onSurfaceVariant),
                    ),
                  ),
                  _PersonalizationRow(
                    s: s,
                    label: 'Cor primária',
                    onTap: () => _openPrimaryColorPicker(context, s),
                    trailing: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: s.isDark
                            ? kPrimaryColorPairs[appTheme.primaryPairIndex].dark
                            : kPrimaryColorPairs[appTheme.primaryPairIndex].light,
                        shape: BoxShape.circle,
                        border: Border.all(color: s.outline),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            _TransparentFadeAppBar(
              s: s,
              title: 'Personalização',
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}

// Grupo/row de personalização SEM ícone
class _PersonalizationGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<_PersonalizationRow> rows;
  const _PersonalizationGroup(
      {required this.s, required this.rows});

  static const double _outerRadius = 20;
  static const double _innerRadius = 6;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final radius = _radiusFor(i, rows.length);
      children.add(Container(
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: radius,
          boxShadow: s.cardShadowSoft,
        ),
        clipBehavior: Clip.antiAlias,
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

class _PersonalizationRow extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final Widget trailing;
  final VoidCallback onTap;
  const _PersonalizationRow({
    required this.s,
    required this.label,
    required this.trailing,
    required this.onTap,
  });
  @override
  State<_PersonalizationRow> createState() => _PersonalizationRowState();
}

class _PersonalizationRowState extends State<_PersonalizationRow> {
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
        duration: const Duration(milliseconds: 100),
        // Padding ligeiramente maior sem ícone para respirar
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        color: _p ? s.hover : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(widget.label,
                  style:
                      TextStyle(fontSize: 15, color: s.onSurface)),
            ),
            widget.trailing,
          ],
        ),
      ),
    );
  }
}

// ── Sheet editor de prompt ────────────────────────────────────

class _PromptEditorSheet extends StatefulWidget {
  final AppColorScheme s;
  const _PromptEditorSheet({required this.s});
  @override
  State<_PromptEditorSheet> createState() => _PromptEditorSheetState();
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
    appPreferences.setPromptRemote(
        _ctrl.text.trim(), authController.token);
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) Navigator.pop(context);
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
            Text('Preferências de prompt',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: s.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Instruções que a IA deve seguir em todas as conversas. Ex.: "Responde sempre em português europeu".',
              style: TextStyle(
                  fontSize: 12.5, color: s.onSurfaceVariant, height: 1.4),
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
                      fontSize: 15,
                      color: s.onSurfaceVariant.withOpacity(0.7)),
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
                appPreferences.setEmojiFrequencyRemote(
                    freq, authController.token);
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      selected ? s.onPrimaryContainer : s.onSurface,
                ),
              ),
            ),
            if (selected)
              AppIcon('checkmark_circle',
                  size: 20, color: s.onPrimaryContainer)
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
            children: List.generate(kPrimaryColorPairs.length, (i) {
              final pair = kPrimaryColorPairs[i];
              final displayColor = s.isDark ? pair.dark : pair.light;
              final selected = appTheme.primaryPairIndex == i;
              return GestureDetector(
                onTap: () {
                  appTheme.setPrimaryPairIndex(i);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: displayColor,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: s.onSurface, width: 3)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const AppIcon('check',
                          color: Colors.white, size: 20)
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MEMÓRIA
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
          child: Stack(children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(top: 62),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Gere os dados de conversas guardados na tua conta.',
                      style: TextStyle(
                          fontSize: 13.5,
                          color: s.onSurfaceVariant,
                          height: 1.4),
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
            _TransparentFadeAppBar(
              s: s,
              title: 'Memória',
              onBack: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ÁREA DE TRABALHO
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
          child: Stack(children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(top: 62),
              child: Padding(
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
            ),
            _TransparentFadeAppBar(
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

// ══════════════════════════════════════════════════════════════
// APPBAR TRANSPARENTE PROGRESSIVA — reutilizável em sub-telas
// Igual ao padrão do main.dart (gradiente topo → transparente)
// ══════════════════════════════════════════════════════════════

class _TransparentFadeAppBar extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onBack;
  const _TransparentFadeAppBar({
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
            colors: [
              s.pageBackground,
              s.pageBackground.withOpacity(0.0),
            ],
          ),
        ),
        child: Row(children: [
          _CircularBackButton(s: s, onTap: onBack),
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