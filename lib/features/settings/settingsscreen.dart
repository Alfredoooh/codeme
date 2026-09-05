import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../core/widgets/app_sheet.dart';
import '../apps/sheets/sheets.dart';
import 'settings_widgets.dart';
import '../../core/navigation/app_page_route.dart';
import 'appearance_screen.dart';
import 'personalization_screen.dart';
import 'memory_screen.dart';
import 'workspace_screen.dart';
import 'avatar_viewer_screen.dart';
import 'webview_screen.dart';

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

  double _scrollOffset = 0.0;
  final ScrollController _scrollController = ScrollController();

  static const double _avatarBlockHeight = 200.0;
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
        builder: (sheetContext) => ConfirmActionSheet(
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
      child: EditFieldSheet(
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
      child: ChangePasswordSheet(s: s),
    );
  }

  void _confirmDeleteAllConversations(BuildContext context, AppColorScheme s) {
    showCraftBottomSheet(
      context: context,
      s: s,
      child: Builder(
        builder: (sheetContext) => ConfirmActionSheet(
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
    Navigator.of(context).push(AppPageRoute(
      builder: (_) => const AppearanceScreen(),
    ));
  }

  void _openMemory(BuildContext context, AppColorScheme s) {
    Navigator.of(context).push(AppPageRoute(
      builder: (_) => MemoryScreen(
        onDeleteAllConversations: () =>
            _confirmDeleteAllConversations(context, s),
      ),
    ));
  }

  void _openWorkspace(BuildContext context) {
    Navigator.of(context).push(AppPageRoute(
      builder: (_) => const WorkspaceScreen(),
    ));
  }

  void _openPersonalization(BuildContext context) {
    Navigator.of(context).push(AppPageRoute(
      builder: (_) => const PersonalizationScreen(),
    ));
  }

  void _openTerms(BuildContext context) {
    Navigator.of(context).push(AppPageRoute(
      builder: (_) => const WebViewScreen(
        title: 'Termos de serviço',
        url: 'https://example.com/terms',
      ),
    ));
  }

  void _openPrivacyPolicy(BuildContext context) {
    Navigator.of(context).push(AppPageRoute(
      builder: (_) => const WebViewScreen(
        title: 'Política de privacidade',
        url: 'https://example.com/privacy',
      ),
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
        pageBuilder: (ctx, anim, _) => AvatarViewerScreen(
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

              RefreshIndicator(
                color: s.primary,
                backgroundColor: s.cardBackground,
                onRefresh: _refreshMe,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 60)),

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

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            SectionLabel(s: s, label: 'Geral'),
                            const SizedBox(height: 10),
                            SettingsGroup(s: s, rows: [
                              SettingsRow(
                                s: s,
                                iconAsset: 'paintbrush',
                                label: 'Aparência',
                                onTap: () =>
                                    _openAppearance(context, s),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'sliders',
                                label: 'Personalização',
                                onTap: () =>
                                    _openPersonalization(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'database',
                                label: 'Memória',
                                onTap: () =>
                                    _openMemory(context, s),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
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
                            SectionLabel(s: s, label: 'Conta'),
                            const SizedBox(height: 10),
                            SettingsGroup(s: s, rows: [
                              SettingsRow(
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
                              SettingsRow(
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
                              SettingsRow(
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
                              SettingsRow(
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
                            SectionLabel(s: s, label: 'Sobre'),
                            const SizedBox(height: 10),
                            SettingsGroup(s: s, rows: [
                              SettingsRow(
                                s: s,
                                iconAsset: 'info',
                                label: 'Versão',
                                onTap: () {},
                                trailing: Text('1.0.0',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: s.onSurfaceVariant)),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'license',
                                label: 'Termos de serviço',
                                onTap: () => _openTerms(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'shield',
                                label: 'Política de privacidade',
                                onTap: () => _openPrivacyPolicy(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'comment',
                                label: 'Enviar feedback',
                                onTap: () {},
                                trailing: const SizedBox.shrink(),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'question',
                                label: 'Ajuda e suporte',
                                onTap: () {},
                                trailing: const SizedBox.shrink(),
                              ),
                            ]),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
                  child: LogoutButton(
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
// APPBAR DO SETTINGS — transparência progressiva
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
          // ANTES: colors: [s.pageBackground, s.pageBackground.withOpacity(0.0)]
          // AGORA: nunca chega a 0 — fica sempre com um mínimo de opacidade,
          // uniforme com scheduled_tasks e chat_search.
          colors: [
            s.pageBackground,
            s.pageBackground.withOpacity(0.4),
          ],
        ),
      ),
      child: Row(
        children: [
          CircularBackButton(
            s: s,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
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
// BLOCO AVATAR + NOME
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