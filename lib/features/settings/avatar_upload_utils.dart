// ══════════════════════════════════════════════════════════════
// FILE: lib/features/settings/avatar_upload_utils.dart
// Compressão automática de avatar antes do upload. O servidor
// (worker/index.js, handleUpdateAvatar) aceita agora até
// kAvatarMaxBase64Chars caracteres em base64 — ver esse ficheiro
// para o valor espelhado (kAvatarUploadLimitBytes ~1MB de imagem).
// Este ficheiro garante que o Flutter nunca envia acima disso,
// comprimindo automaticamente em loop antes de tentar o upload.
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Limite real de bytes de IMAGEM (antes da conversão para base64)
/// que o servidor aceita. Tem de bater com kAvatarUploadLimitBytes
/// em worker/index.js (handleUpdateAvatar) — se um dia subires o
/// limite lá, sobe também aqui.
const int kAvatarMaxImageBytes = 1 * 1024 * 1024; // 1MB

/// Corta uma margem de segurança do limite acima, porque a
/// codificação base64 acrescenta ~33% de overhead sobre o tamanho
/// binário da imagem — visamos ficar bem abaixo do limite real do
/// servidor mesmo depois dessa expansão.
const int kAvatarTargetImageBytes = 900 * 1024; // ~900KB de margem

/// Lê o ficheiro de imagem em [sourcePath] (já cortado/editado pelo
/// image_cropper), comprime em loop reduzindo qualidade e depois
/// dimensões até caber em kAvatarTargetImageBytes, e devolve como
/// data URL base64 pronto para enviar ao servidor.
///
/// Lança uma exceção se não conseguir comprimir o suficiente após
/// todas as tentativas (caso extremo, praticamente não deve
/// acontecer com fotos normais de telemóvel).
Future<String> compressImageFileToBase64DataUrl(String sourcePath) async {
  final original = File(sourcePath);
  var bytes = await original.readAsBytes();

  if (bytes.length <= kAvatarTargetImageBytes) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  // Passo 1: reduz qualidade em degraus, mantendo a resolução.
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

  // Passo 2: se ainda estiver acima do limite (imagem muito grande
  // em dimensões), reduz também a resolução, mantendo qualidade
  // moderada.
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
    // Não chegou ao alvo confortável mas cabe no limite real —
    // aceitável, envia mesmo assim.
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  throw Exception(
    'Não foi possível comprimir a imagem abaixo de $kAvatarMaxImageBytes bytes.',
  );
}