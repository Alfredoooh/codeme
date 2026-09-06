// ══════════════════════════════════════════════════════════════
// FILE: lib/services/local_accounts_service.dart
// Guarda localmente (SharedPreferences) uma lista leve de contas
// já usadas neste dispositivo — nome + identificador (email ou
// telemóvel) + avatar. NUNCA guarda password. Serve apenas para
// mostrar o seletor de "contas guardadas" ao continuar com email,
// à semelhança do que a app do Facebook faz.
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAccount {
  final String identifier; // email ou telemóvel
  final String name;
  final String? avatar;
  final bool isEmail;

  const LocalAccount({
    required this.identifier,
    required this.name,
    this.avatar,
    required this.isEmail,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'name': name,
        'avatar': avatar,
        'isEmail': isEmail,
      };

  factory LocalAccount.fromJson(Map<String, dynamic> j) => LocalAccount(
        identifier: j['identifier']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        avatar: j['avatar']?.toString(),
        isEmail: j['isEmail'] == true,
      );
}

class LocalAccountsService {
  static const _kKey = 'nexa_local_accounts';
  static const _kMax = 5;

  /// Devolve as contas guardadas, mais recente primeiro.
  static Future<List<LocalAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((m) => LocalAccount.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Adiciona (ou promove para o topo) uma conta após login/registo
  /// bem-sucedido.
  static Future<void> remember({
    required String identifier,
    required String name,
    String? avatar,
    required bool isEmail,
  }) async {
    if (identifier.trim().isEmpty) return;
    final current = await load();
    current.removeWhere(
        (a) => a.identifier.toLowerCase() == identifier.toLowerCase());
    current.insert(
      0,
      LocalAccount(
        identifier: identifier,
        name: name,
        avatar: avatar,
        isEmail: isEmail,
      ),
    );
    final trimmed = current.take(_kMax).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(trimmed.map((a) => a.toJson()).toList()),
    );
  }

  /// Remove uma conta específica da lista local.
  static Future<void> forget(String identifier) async {
    final current = await load();
    current.removeWhere(
        (a) => a.identifier.toLowerCase() == identifier.toLowerCase());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(current.map((a) => a.toJson()).toList()),
    );
  }

  /// Limpa todas as contas guardadas neste dispositivo.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}