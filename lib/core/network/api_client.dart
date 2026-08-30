import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}$endpoint',
    );

    final authHeaders = await _buildHeaders(
      headers: headers,
    );

    final response = await _client.get(
      uri,
      headers: authHeaders,
    );

    return _handleResponse(response);
  }

  Future<Uint8List> getBytes(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}$endpoint',
    );

    final authHeaders = await _buildHeaders(
      headers: headers,
    );

    final response = await _client.get(
      uri,
      headers: authHeaders,
    );

    return _handleBinaryResponse(response);
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}$endpoint',
    );

    final authHeaders = await _buildHeaders(
      headers: headers,
      includeJsonContentType: true,
    );

    final response = await _client.post(
      uri,
      headers: authHeaders,
      body: body == null
          ? null
          : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}$endpoint',
    );

    final authHeaders = await _buildHeaders(
      headers: headers,
      includeJsonContentType: true,
    );

    final response = await _client.patch(
      uri,
      headers: authHeaders,
      body: body == null
          ? null
          : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? headers,
    bool includeJsonContentType = false,
  }) async {
    final accessToken =
        await TokenStorage.getToken();

    final result = <String, String>{
      'Accept': 'application/json',
    };

    if (includeJsonContentType) {
      result['Content-Type'] =
          'application/json';
    }

    if (accessToken != null &&
        accessToken.isNotEmpty) {
      result['Authorization'] =
          'Bearer $accessToken';
    }

    if (headers != null) {
      result.addAll(headers);
    }

    return result;
  }

  dynamic _handleResponse(
    http.Response response,
  ) {
    final body = response.body.trim();

    if (body.isEmpty) {
      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return <String, dynamic>{};
      }

      throw Exception(
        'Request failed with status ${response.statusCode}.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw Exception(
        'Invalid response received from server.',
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic> &&
        decoded['detail'] != null) {
      throw Exception(
        decoded['detail'].toString(),
      );
    }

    if (decoded is Map<String, dynamic> &&
        decoded['message'] != null) {
      throw Exception(
        decoded['message'].toString(),
      );
    }

    throw Exception(
      'Request failed with status ${response.statusCode}.',
    );
  }

  Uint8List _handleBinaryResponse(
    http.Response response,
  ) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return response.bodyBytes;
    }

    final body = utf8
        .decode(
          response.bodyBytes,
          allowMalformed: true,
        )
        .trim();

    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);

        if (decoded is Map<String, dynamic> &&
            decoded['detail'] != null) {
          throw Exception(
            decoded['detail'].toString(),
          );
        }

        if (decoded is Map<String, dynamic> &&
            decoded['message'] != null) {
          throw Exception(
            decoded['message'].toString(),
          );
        }
      } on Exception {
        rethrow;
      } catch (_) {}
    }

    throw Exception(
      'Request failed with status ${response.statusCode}.',
    );
  }

  void dispose() {
    _client.close();
  }
}
