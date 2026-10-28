import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/auth_config.dart';

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

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    final token = AuthConfig.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _client.get(_uri(path, query), headers: _headers());
    return _decodeObject(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _client.get(_uri(path, query), headers: _headers());
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required List<int> bytes,
    required String filename,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    request.headers.addAll(_headers());
    if (fields != null) {
      request.fields.addAll(fields);
    }
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.put(
      _uri(path),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );
    return _decodeObject(response);
  }

  Future<List<int>> getBytes(String path) async {
    final response = await _client.get(_uri(path), headers: _headers());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(response.statusCode, _errorMessage(response));
  }

  Future<void> delete(String path) async {
    final response = await _client.delete(_uri(path), headers: _headers());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(response.statusCode, _errorMessage(response));
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

    throw ApiException(response.statusCode, _errorMessage(response));
  }

  String _errorMessage(http.Response response) {
    if (response.statusCode == 401 && AuthConfig.token != null) {
      AuthConfig.clear();
    }
    String message = response.reasonPhrase ?? 'Request failed';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {}
    return message;
  }
}
