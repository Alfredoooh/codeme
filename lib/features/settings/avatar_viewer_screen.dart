import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/colors.dart';
import '../../services/auth_service.dart';
import 'avatar_upload_utils.dart';

class AvatarViewerScreen extends StatefulWidget {
  final AppColorScheme s;
  final Future<void> Function(String base64Avatar) onAvatarUpdated;
  /// Fecha o overlay com a animação reversa (fade+scale). Substitui
  /// o antigo Navigator.pop — este widget já não é uma rota.
  final Future<void> Function() onRequestClose;
  const AvatarViewerScreen({
    super.key,
    required this.s,
    required this.onAvatarUpdated,
    required this.onRequestClose,
  });

  @override
  State<AvatarViewerScreen> createState() => _AvatarViewerScreenState();
}

class _AvatarViewerScreenState extends State<AvatarViewerScreen> {
  bool _uploading = false;
  String? _error;

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
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
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

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final b64 = await compressImageFileToBase64DataUrl(cropped.path);
      await widget.onAvatarUpdated(b64);
      if (mounted) await widget.onRequestClose();
    } catch (e) {
      // Erro agora fica VISÍVEL em vez de falhar em silêncio — é
      // isto que te vai dizer exatamente porque o upload não pega:
      // se for o servidor a recusar (imagem grande demais mesmo
      // após compressão), a rede, ou a sessão expirada, o texto
      // abaixo do botão mostra a causa real.
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final user = authController.user;
    final avatarBytes = _decodeAvatar(user?.avatar);
    final squareSize = MediaQuery.of(context).size.width - 32;

    return GestureDetector(
      onTap: widget.onRequestClose,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: squareSize,
                height: squareSize,
                decoration: BoxDecoration(
                  color: s.primary,
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
                    // key baseada nos próprios bytes: garante que o
                    // Flutter repinta quando o avatar muda, mesmo
                    // que o widget pai não tenha sido recriado.
                    ? Image.memory(
                        avatarBytes,
                        key: ValueKey(avatarBytes.lengthInBytes),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/png/avatar.png',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        'assets/icons/png/avatar.png',
                        fit: BoxFit.cover,
                      ),
              ),
              if (_error != null)
                Container(
                  width: squareSize,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: s.error.withOpacity(0.12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: s.error),
                  ),
                ),
              GestureDetector(
                onTap: _uploading ? null : _pickAndEdit,
                child: Container(
                  width: squareSize,
                  height: 56,
                  color: s.isDark ? Colors.white : s.primary,
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
                            color: s.isDark ? Colors.black : s.onPrimary,
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
    );
  }
}