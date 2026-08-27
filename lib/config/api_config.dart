import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Android 模拟器访问本机服务用 10.0.2.2，其他平台用 localhost。
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }
}
