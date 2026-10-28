import '../config/auth_config.dart';
import '../models/app_user.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<bool> hasUsers() async {
    final json = await _client.getJson('/api/auth/status');
    return json['has_users'] == true;
  }

  Future<AuthSession> register({
    required String username,
    required String password,
    String? displayName,
  }) {
    return _session('/api/auth/register', username, password, displayName);
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    return _session('/api/auth/login', username, password, null);
  }

  Future<void> logout() {
    return _client.postJson('/api/auth/logout', {});
  }

  Future<AppUser> updateProfile({
    String? displayName,
    String? currentPassword,
    String? newPassword,
  }) async {
    final json = await _client.putJson('/api/auth/me', {
      'display_name': ?displayName,
      'current_password': ?currentPassword,
      'new_password': ?newPassword,
    });
    return AppUser.fromJson(json);
  }

  Future<List<AppUser>> listUsers() async {
    final json = await _client.getJsonList('/api/users');
    return json.map((item) => AppUser.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<AppUser> createUser({
    required String username,
    required String password,
    String? displayName,
  }) async {
    final json = await _client.postJson('/api/users', {
      'username': username,
      'password': password,
      if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
    });
    return AppUser.fromJson(json);
  }

  Future<void> deleteUser(int id) {
    return _client.delete('/api/users/$id');
  }

  Future<AuthSession> _session(
    String path,
    String username,
    String password,
    String? displayName,
  ) async {
    final json = await _client.postJson(path, {
      'username': username,
      'password': password,
      if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
    });
    return AuthSession(
      token: json['token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
