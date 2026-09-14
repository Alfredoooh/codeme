// ══════════════════════════════════════════════════════════════
// FILE: lib/features/settings/avatar_upload_utils.dart
// Compressão automática de avatar antes do upload. O servidor
// (worker/index.js, handleUpdateAvatar) aceita até
// AVATAR_MAX_BASE64_CHARS caracteres em base64 — ver esse ficheiro
// para o valor espelhado. Este utilitário garante que o Flutter
// nunca envia acima disso, comprimindo automaticamente em loop
// antes de tentar o upload.
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Limite real de bytes de IMAGEM (antes da conversão para base64)
/// que o servidor aceita. Tem de bater com AVATAR_MAX_IMAGE_BYTES
/// em worker/index.js (handleUpdateAvatar) — se subires o limite
/// lá, sobe também aqui.
const int kAvatarMaxImageBytes = 1 * 1024 * 1024; // 1MB

/// Margem de segurança abaixo do limite real, porque a codificação
/// base64 acrescenta ~33% de overhead sobre o tamanho binário.
const int kAvatarTargetImageBytes = 900 * 1024; // ~900KB de margem

/// Lê o ficheiro de imagem em [sourcePath] (já cortado/editado pelo
/// image_cropper), comprime em loop reduzindo qualidade e depois
/// dimensões até caber em kAvatarTargetImageBytes, e devolve como
/// data URL base64 pronto para enviar ao servidor.
///
/// Lança uma Exception com mensagem legível se não conseguir
/// comprimir o suficiente — essa mensagem chega até à UI (ver
/// avatar_viewer_screen.dart) para o utilizador ver a causa real.
Future<String> compressImageFileToBase64DataUrl(String sourcePath) async {
  final original = File(sourcePath);
  if (!await original.exists()) {
    throw Exception('Ficheiro de imagem não encontrado após o recorte.');
  }
  var bytes = await original.readAsBytes();

  if (bytes.length <= kAvatarTargetImageBytes) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  const qualitySteps = [85, 70, 55, 40];
  for (final quality in qualitySteps) {
    final compressed = await FlutterImageCompress.compressWithFile(
      sourcePath,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) continue;
    bytes = compressed;
    if (bytes.length <= kAvatarTargetImageBytes) {
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  }

  const resolutionSteps = [1080, 800, 600, 400];
  for (final maxSide in resolutionSteps) {
    final compressed = await FlutterImageCompress.compressWithFile(
      sourcePath,
      quality: 70,
      minWidth: maxSide,
      minHeight: maxSide,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) continue;
    bytes = compressed;
    if (bytes.length <= kAvatarTargetImageBytes) {
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  }

  if (bytes.length <= kAvatarMaxImageBytes) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  throw Exception(
    'Não foi possível comprimir a imagem abaixo do limite do servidor (~1MB). Tenta uma foto mais simples.',
  );
}