import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _client.get(_uri(path, query));
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _client.get(_uri(path, query));
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      _uri(path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeObject(response);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final body = _decodeBody(response);
    if (body is! Map<String, dynamic>) {
      throw ApiException(response.statusCode, 'Expected JSON object');
    }
    return body;
  }

  List<dynamic> _decodeList(http.Response response) {
    final body = _decodeBody(response);
    if (body is! List<dynamic>) {
      throw ApiException(response.statusCode, 'Expected JSON array');
    }
    return body;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return jsonDecode(response.body);
    }

    String message = response.reasonPhrase ?? 'Request failed';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {}

    throw ApiException(response.statusCode, message);
  }
}
