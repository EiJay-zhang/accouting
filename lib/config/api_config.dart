import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const _storageKey = 'api_base_url';
  static final ValueNotifier<String> baseUrlNotifier =
      ValueNotifier<String>(resolveDefaultBaseUrl());

  static String get baseUrl => baseUrlNotifier.value;

  static String resolveDefaultBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    baseUrlNotifier.value =
        saved != null && saved.isNotEmpty ? saved : resolveDefaultBaseUrl();
  }

  static Future<void> saveBaseUrl(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      await resetBaseUrl();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, normalized);
    baseUrlNotifier.value = normalized;
  }

  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    baseUrlNotifier.value = resolveDefaultBaseUrl();
  }
}
