import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/colors.dart';
import '../../services/auth_service.dart';

class AvatarViewerScreen extends StatefulWidget {
  final AppColorScheme s;
  final Future<void> Function(String base64Avatar) onAvatarUpdated;
  const AvatarViewerScreen({
    super.key,
    required this.s,
    required this.onAvatarUpdated,
  });

  @override
  State<AvatarViewerScreen> createState() => _AvatarViewerScreenState();
}

class _AvatarViewerScreenState extends State<AvatarViewerScreen> {
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