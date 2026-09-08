import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/language/language_controller.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../apps/sheets/sheets.dart';
import 'settings_widgets.dart';
import '../../core/navigation/app_page_route.dart';
import 'appearance_screen.dart';
import 'personalization_screen.dart';
import 'memory_screen.dart';
import 'workspace_screen.dart';
import 'avatar_viewer_overlay.dart';
import 'webview_screen.dart';
import 'avatar_upload_utils.dart';
import 'language_picker_sheet.dart';

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
  bool _avatarUploading = false;

  @override
  void initState() {
    super.initState();
    authController.addListener(_onAuthChanged);
    appLanguage.addListener(_onLanguageChanged);
    _refreshMe();
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    appLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _onLanguageChanged() {
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
    } catch (_) {}
    if (mounted) setState(() => _refreshing = false);
  }

  void _confirmLogout(BuildContext context, AppColorScheme s) {
    final t = appLanguage.strings;
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: ConfirmActionSheet(
        s: s,
        message: t.settingsLogoutConfirmMessage,
        confirmLabel: t.settingsLogout,
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
    final t = appLanguage.strings;
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: EditFieldSheet(
        s: s,
        title: t.settingsEditNameTitle,
        label: t.settingsEditNameLabel,
        hint: t.settingsEditNameHint,
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
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: ChangePasswordSheet(s: s),
    );
  }

  void _confirmDeleteAllConversations(BuildContext context, AppColorScheme s) {
    final t = appLanguage.strings;
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: ConfirmActionSheet(
        s: s,
        message: t.settingsDeleteAllConversationsConfirmMessage,
        confirmLabel: t.settingsDeleteAllConversationsConfirmLabel,
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

  void _openLanguagePicker(BuildContext context, AppColorScheme s) {
    showLanguagePickerSheet(context, s);
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

  /// Comprime e envia um novo avatar. Erro fica visível através da
  /// exceção propagada — nenhum try/catch silencioso aqui.
  Future<void> _uploadAvatar(String sourcePath) async {
    setState(() => _avatarUploading = true);
    try {
      final b64 = await compressImageFileToBase64DataUrl(sourcePath);
      final token = authController.token;
      if (token == null) {
        throw Exception('Sessão não encontrada. Inicia sessão novamente.');
      }
      await ProfileApiService.updateAvatar(token, b64);
      authController.user = authController.user?.copyWith(avatar: b64);
      if (authController.user != null) {
        await SessionManager.updateUser(authController.user!);
      }
      authController.notifyListeners();
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _pickAvatarDirectly() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
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

    try {
      await _uploadAvatar(cropped.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.of(context).error,
          ),
        );
      }
    }
  }

  void _openAvatarViewer(BuildContext context, AppColorScheme s) {
    showAvatarViewerOverlay(
      context,
      s: s,
      onAvatarUpdated: (newAvatar) async {
        final token = authController.token;
        if (token == null) {
          throw Exception('Sessão não encontrada. Inicia sessão novamente.');
        }
        await ProfileApiService.updateAvatar(token, newAvatar);
        authController.user =
            authController.user?.copyWith(avatar: newAvatar);
        if (authController.user != null) {
          await SessionManager.updateUser(authController.user!);
        }
        authController.notifyListeners();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final t = appLanguage.strings;
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
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 48)),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: _AvatarBlock(
                          s: s,
                          user: user,
                          loading: _refreshing || _avatarUploading,
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
                            SectionLabel(
                                s: s, label: t.settingsSectionGeneral),
                            const SizedBox(height: 10),
                            SettingsGroup(s: s, rows: [
                              SettingsRow(
                                s: s,
                                iconAsset: 'paintbrush',
                                label: t.settingsAppearance,
                                onTap: () =>
                                    _openAppearance(context, s),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'sliders',
                                label: t.settingsPersonalization,
                                onTap: () =>
                                    _openPersonalization(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'database',
                                label: t.settingsMemory,
                                onTap: () =>
                                    _openMemory(context, s),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'briefcase',
                                label: t.settingsWorkspace,
                                onTap: () =>
                                    _openWorkspace(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'globe',
                                label: t.settingsLanguage,
                                onTap: () =>
                                    _openLanguagePicker(context, s),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      appLanguage.language.flagEmoji,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      appLanguage.language.nativeName,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: s.onSurfaceVariant),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 4),
                                    AppIcon('chevron_forward',
                                        size: 16,
                                        color: s.onSurfaceVariant),
                                  ],
                                ),
                              ),
                            ]),
                            const SizedBox(height: 28),
                            SectionLabel(
                                s: s, label: t.settingsSectionAccount),
                            const SizedBox(height: 10),
                            SettingsGroup(s: s, rows: [
                              SettingsRow(
                                s: s,
                                iconAsset: 'person',
                                label: t.settingsName,
                                onTap: () =>
                                    _editName(context, s),
                                trailing: Text(t.commonChange,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: s.primary,
                                        fontWeight:
                                            FontWeight.w500)),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'mail',
                                label: t.settingsEmail,
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
                                label: t.settingsPassword,
                                onTap: () =>
                                    _editPassword(context, s),
                                trailing: Text(t.commonChange,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: s.primary,
                                        fontWeight:
                                            FontWeight.w500)),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'credit',
                                label: t.settingsCredits,
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
                            SectionLabel(s: s, label: t.settingsSectionAbout),
                            const SizedBox(height: 10),
                            SettingsGroup(s: s, rows: [
                              SettingsRow(
                                s: s,
                                iconAsset: 'info',
                                label: t.settingsVersion,
                                onTap: () {},
                                trailing: Text('1.0.0',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: s.onSurfaceVariant)),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'license',
                                label: t.settingsTerms,
                                onTap: () => _openTerms(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'shield',
                                label: t.settingsPrivacyPolicy,
                                onTap: () => _openPrivacyPolicy(context),
                                trailing: AppIcon('chevron_forward',
                                    size: 16,
                                    color: s.onSurfaceVariant),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'comment',
                                label: t.settingsSendFeedback,
                                onTap: () {},
                                trailing: const SizedBox.shrink(),
                              ),
                              SettingsRow(
                                s: s,
                                iconAsset: 'question',
                                label: t.settingsHelpSupport,
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
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  color: s.pageBackground,
                  child: Row(children: [
                    CircularBackButton(
                      s: s,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.settingsTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: s.onSurface,
                      ),
                    ),
                  ]),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  color: s.pageBackground,
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
                            key: ValueKey(avatarBytes.lengthInBytes),
                            width: innerSize,
                            height: innerSize,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _AvatarFallback(
                                    s: s, size: avatarSize),
                          )
                        : _AvatarFallback(s: s, size: avatarSize),
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

class _AvatarFallback extends StatelessWidget {
  final AppColorScheme s;
  final double size;
  const _AvatarFallback({required this.s, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        color: s.primary,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/icons/png/avatar.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
}