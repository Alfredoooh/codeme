// ══════════════════════════════════════════════════════════════
// FILE: lib/services/auth_service.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════
// USER MODEL
// ══════════════════════════════════════════════════════════════

class AppUser {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatar;
  final String provider;
  final int credits;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> profile;
  final bool isAdmin;

  const AppUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatar,
    this.provider = 'password',
    this.credits = 0,
    this.preferences = const {},
    this.profile = const {},
    this.isAdmin = false,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatar,
    int? credits,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? profile,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatar: avatar ?? this.avatar,
        provider: provider,
        credits: credits ?? this.credits,
        preferences: preferences ?? this.preferences,
        profile: profile ?? this.profile,
        isAdmin: isAdmin,
      );

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Utilizador',
        email: j['email']?.toString(),
        phone: j['phone']?.toString(),
        avatar: j['avatar']?.toString(),
        provider: j['provider']?.toString() ?? 'password',
        credits: (j['credits'] is num) ? (j['credits'] as num).toInt() : 0,
        preferences: (j['preferences'] is Map)
            ? Map<String, dynamic>.from(j['preferences'])
            : {},
        profile: (j['profile'] is Map)
            ? Map<String, dynamic>.from(j['profile'])
            : {},
        isAdmin: j['isAdmin'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'provider': provider,
        'credits': credits,
        'preferences': preferences,
        'profile': profile,
        'isAdmin': isAdmin,
      };
}

// ══════════════════════════════════════════════════════════════
// SESSION MANAGER — persistência local do token + user
// ══════════════════════════════════════════════════════════════

class SessionManager {
  static const _kToken = 'nexa_auth_token';
  static const _kUser = 'nexa_auth_user';

  static Future<void> save(String token, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  static Future<void> updateUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  static Future<(String, AppUser)?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final userRaw = prefs.getString(_kUser);
    if (token == null || userRaw == null) return null;
    try {
      final userJson = jsonDecode(userRaw);
      if (userJson is! Map<String, dynamic>) return null;
      return (token, AppUser.fromJson(userJson));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}

// ══════════════════════════════════════════════════════════════
// AUTH CONTROLLER — estado global de sessão
// ══════════════════════════════════════════════════════════════

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Identificador de login: ou email, ou número de telemóvel.
enum LoginIdentifierType { email, phone }

class AuthController extends ChangeNotifier {
  static const String _baseUrl = 'https://nexaai.alfredopjonas.workers.dev';

  AuthStatus status = AuthStatus.unknown;
  String? token;
  AppUser? user;
  String? lastError;
  bool busy = false;

  AuthController() {
    _restore();
  }

  Future<void> _restore() async {
    final saved = await SessionManager.load();
    if (saved != null) {
      token = saved.$1;
      user = saved.$2;
      status = AuthStatus.authenticated;
      _refreshMeSilently();
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _refreshMeSilently() async {
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        user = AppUser.fromJson(data);
        await SessionManager.updateUser(user!);
        notifyListeners();
      } else {
        await _forceLogout();
      }
    } catch (_) {}
  }

  Future<void> _forceLogout() async {
    token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    await SessionManager.clear();
    notifyListeners();
  }

  /// Deteta automaticamente se o identificador parece email ou
  /// telemóvel, para decidir que campo mandar ao Worker.
  LoginIdentifierType _detectIdentifierType(String identifier) {
    return identifier.contains('@')
        ? LoginIdentifierType.email
        : LoginIdentifierType.phone;
  }

  /// Registo com email OU telemóvel + password.
  Future<bool> register({
    required String identifier,
    required String password,
    required String name,
  }) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final type = _detectIdentifierType(identifier);
      final body = <String, dynamic>{
        'password': password,
        'name': name.trim(),
      };
      if (type == LoginIdentifierType.email) {
        body['email'] = identifier.trim().toLowerCase();
      } else {
        body['phone'] = identifier.trim();
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        lastError = data['error']?.toString() ?? 'Erro ao registar.';
        busy = false;
        notifyListeners();
        return false;
      }

      final workerToken = data['token'] as String;
      final appUser = AppUser.fromJson(data);
      token = workerToken;
      user = appUser;
      status = AuthStatus.authenticated;
      await SessionManager.save(workerToken, appUser);
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'Erro de rede. Verifica a tua ligação.';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Login com email OU telemóvel + password.
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final type = _detectIdentifierType(identifier);
      final body = <String, dynamic>{'password': password};
      if (type == LoginIdentifierType.email) {
        body['email'] = identifier.trim().toLowerCase();
      } else {
        body['phone'] = identifier.trim();
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        lastError = data['error']?.toString() ??
            'Email/telemóvel ou password incorretos.';
        busy = false;
        notifyListeners();
        return false;
      }

      final workerToken = data['token'] as String;
      final appUser = AppUser.fromJson(data);
      token = workerToken;
      user = appUser;
      status = AuthStatus.authenticated;
      await SessionManager.save(workerToken, appUser);
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'Erro de rede. Verifica a tua ligação.';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Solicita código de 6 dígitos para reset de password.
  Future<bool> requestPasswordResetCode(String email) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );
      busy = false;
      if (response.statusCode != 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        lastError = data['error']?.toString() ?? 'Erro ao enviar código.';
        notifyListeners();
        return false;
      }
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'Erro de rede. Verifica a tua ligação.';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Confirma o código de reset e define a nova password.
  Future<bool> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'code': code,
          'password': newPassword,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      busy = false;
      if (response.statusCode != 200) {
        lastError = data['error']?.toString() ?? 'Código inválido.';
        notifyListeners();
        return false;
      }
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'Erro de rede. Verifica a tua ligação.';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Troca a password atual por uma nova, exigindo a password
  /// antiga por segurança.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (token == null) return false;
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/user/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'password': newPassword,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        lastError = data['error']?.toString() ?? 'Erro ao alterar password.';
        busy = false;
        notifyListeners();
        return false;
      }
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = 'Erro de rede. Verifica a tua ligação.';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  /// Termina sessão apenas neste dispositivo.
  Future<void> logout() async {
    if (token != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {}
    }
    token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    await SessionManager.clear();
    notifyListeners();
  }

  /// Termina sessão em todos os dispositivos.
  Future<void> logoutAllDevices() async {
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/auth/logout-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
    token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    await SessionManager.clear();
    notifyListeners();
  }

  /// Devolve o header Authorization pronto a usar noutras chamadas.
  Future<Map<String, String>> authHeaders() async {
    if (token == null) throw AuthException('Utilizador não autenticado.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Limpa o último erro.
  void clearError() {
    lastError = null;
    notifyListeners();
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

final AuthController authController = AuthController();