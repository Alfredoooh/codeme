// ══════════════════════════════════════════════════════════════
// FILE: lib/auth_service.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// TODO: depende de api_service.dart (split futuro); manter este import para a etapa futura de split.
import 'api_service.dart';


// ══════════════════════════════════════════════════════════════
// USER MODEL
// ══════════════════════════════════════════════════════════════

class AppUser {
  final String id;
  final String name;
  final String? email;
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
    this.avatar,
    this.provider = 'email',
    this.credits = 0,
    this.preferences = const {},
    this.profile = const {},
    this.isAdmin = false,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? avatar,
    int? credits,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? profile,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
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
        avatar: j['avatar']?.toString(),
        provider: j['provider']?.toString() ?? 'email',
        credits: (j['credits'] is num) ? (j['credits'] as num).toInt() : 0,
        preferences: (j['preferences'] is Map) ? Map<String, dynamic>.from(j['preferences']) : {},
        profile: (j['profile'] is Map) ? Map<String, dynamic>.from(j['profile']) : {},
        isAdmin: j['isAdmin'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
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

class AuthController extends ChangeNotifier {
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
      // Refresca dados do utilizador em segundo plano, sem bloquear a UI.
      _refreshMeSilently();
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _refreshMeSilently() async {
    if (token == null) return;
    try {
      final me = await ProfileApiService.getMe(token!);
      user = AppUser.fromJson(me);
      await SessionManager.updateUser(user!);
      notifyListeners();
    } catch (_) {
      // Token pode ter expirado ou sessão foi revogada — não força logout
      // aqui automaticamente para não interromper o utilizador a meio de
      // um uso offline; o próximo pedido autenticado que falhar trata disso.
    }
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final data = await AuthApiService.login(email.trim(), password);
      token = data['token']?.toString();
      user = AppUser(
        id: data['id']?.toString() ?? '',
        name: data['name']?.toString() ?? 'Utilizador',
        email: data['email']?.toString(),
        credits: (data['credits'] is num) ? (data['credits'] as num).toInt() : 0,
        preferences: (data['preferences'] is Map) ? Map<String, dynamic>.from(data['preferences']) : {},
      );
      if (token == null || token!.isEmpty) {
        lastError = 'Resposta inválida do servidor';
        busy = false;
        notifyListeners();
        return false;
      }
      await SessionManager.save(token!, user!);
      status = AuthStatus.authenticated;
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = e is ApiException ? e.message : 'Erro ao iniciar sessão';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    int? age,
    String? country,
    String? state,
    String? city,
    String? occupation,
    String? occupationDetail,
  }) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final data = await AuthApiService.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
        age: age,
        country: country,
        state: state,
        city: city,
        occupation: occupation,
        occupationDetail: occupationDetail,
      );
      token = data['token']?.toString();
      user = AppUser(
        id: data['id']?.toString() ?? '',
        name: data['name']?.toString() ?? name.trim(),
        email: data['email']?.toString() ?? email.trim(),
        credits: (data['credits'] is num) ? (data['credits'] as num).toInt() : 0,
      );
      if (token == null || token!.isEmpty) {
        lastError = 'Resposta inválida do servidor';
        busy = false;
        notifyListeners();
        return false;
      }
      await SessionManager.save(token!, user!);
      status = AuthStatus.authenticated;
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = e is ApiException ? e.message : 'Erro ao criar conta';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      await AuthApiService.forgotPassword(email.trim());
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = e is ApiException ? e.message : 'Erro ao pedir recuperação';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    if (token != null) {
      await AuthApiService.logout(token!);
    }
    token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    await SessionManager.clear();
    notifyListeners();
  }

  Future<void> logoutAllDevices() async {
    if (token == null) return;
    await AuthApiService.logoutAll(token!);
    await logout();
  }

  Future<void> refreshBalance() async {
    if (token == null) return;
    final balance = await CreditsApiService.getBalance(token!);
    if (balance != null && balance['credits'] is num) {
      user = user?.copyWith(credits: (balance['credits'] as num).toInt());
      if (user != null) await SessionManager.updateUser(user!);
      notifyListeners();
    }
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }
}

final AuthController authController = AuthController();
