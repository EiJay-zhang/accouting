import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class AuthSession {
  final String token;
  final AppUser user;

  const AuthSession({required this.token, required this.user});
}

class AuthConfig {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static final ValueNotifier<AuthSession?> session = ValueNotifier(null);

  static String? get token => session.value?.token;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (token == null || token.isEmpty || raw == null || raw.isEmpty) {
      return;
    }
    session.value = AuthSession(
      token: token,
      user: AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>),
    );
  }

  static Future<void> save(AuthSession value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, value.token);
    await prefs.setString(_userKey, jsonEncode(value.user.toJson()));
    session.value = value;
  }

  static Future<void> updateUser(AppUser user) async {
    final current = session.value;
    if (current == null) return;
    await save(AuthSession(token: current.token, user: user));
  }

  static Future<void> clear() async {
    session.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
