import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();

  static const String _accessTokenKey = 'access_token';
  static const String _roleKey = 'role_name';

  static const Set<String> _supportedRoles = {
    'ADMIN',
    'FACULTY',
    'STUDENT',
  };

  // ============================================================
  // SAVE ACCESS TOKEN
  // ============================================================

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _accessTokenKey,
      token,
    );
  }

  // ============================================================
  // SAVE COMPLETE SESSION
  // ============================================================

  static Future<void> saveSession({
    required String token,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final normalizedRole = _normalizeRole(role);

    if (normalizedRole == null ||
        !_supportedRoles.contains(normalizedRole)) {
      throw Exception(
        'Cannot save session because the account role is invalid.',
      );
    }

    await prefs.setString(
      _accessTokenKey,
      token,
    );

    await prefs.setString(
      _roleKey,
      normalizedRole,
    );
  }

  // ============================================================
  // GET ACCESS TOKEN
  // ============================================================

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(
      _accessTokenKey,
    );
  }

  // ============================================================
  // GET SAVED ROLE
  // ============================================================

  static Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();

    return _normalizeRole(
      prefs.getString(_roleKey),
    );
  }

  // ============================================================
  // CLEAR ACCESS TOKEN
  // ============================================================

  static Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(
      _accessTokenKey,
    );
  }

  // ============================================================
  // CLEAR COMPLETE SESSION
  // ============================================================

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(
      _accessTokenKey,
    );

    await prefs.remove(
      _roleKey,
    );
  }

  // ============================================================
  // CHECK TOKEN
  // ============================================================

  static Future<bool> hasAccessToken() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
  }

  // ============================================================
  // RESTORE VALID SESSION
  // ============================================================

  static Future<Map<String, String>?> getValidSession() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString(
      _accessTokenKey,
    );

    if (token == null ||
        token.trim().isEmpty) {
      return null;
    }

    final payload = _decodeJwtPayload(
      token.trim(),
    );

    if (payload == null) {
      await clearSession();
      return null;
    }

    // This client-side JWT decode is used only for startup routing
    // and expiry checks. Protected API requests are still verified
    // by the FastAPI backend using the JWT signature.
    if (payload['type']?.toString() != 'access') {
      await clearSession();
      return null;
    }

    final expiry =
        _readUnixTimestamp(payload['exp']);

    if (expiry == null) {
      await clearSession();
      return null;
    }

    final nowSeconds =
        DateTime.now()
                .toUtc()
                .millisecondsSinceEpoch ~/
            1000;

    if (nowSeconds >= expiry) {
      await clearSession();
      return null;
    }

    var role = _normalizeRole(
      prefs.getString(_roleKey),
    );

    // Backward compatibility:
    // Users who logged in before this Phase 3 update may have only
    // an access token saved. Recover their role from the JWT.
    role ??= _normalizeRole(
      payload['role']?.toString(),
    );

    if (role == null ||
        !_supportedRoles.contains(role)) {
      await clearSession();
      return null;
    }

    // Persist the recovered role so future starts do not need the
    // migration fallback.
    await prefs.setString(
      _roleKey,
      role,
    );

    return {
      'access_token': token.trim(),
      'role_name': role,
    };
  }

  // ============================================================
  // JWT HELPERS
  // ============================================================

  static Map<String, dynamic>? _decodeJwtPayload(
    String token,
  ) {
    try {
      final parts = token.split('.');

      if (parts.length != 3) {
        return null;
      }

      final normalized =
          base64Url.normalize(parts[1]);

      final decodedBytes =
          base64Url.decode(normalized);

      final decodedJson =
          utf8.decode(decodedBytes);

      final payload =
          jsonDecode(decodedJson);

      if (payload is! Map) {
        return null;
      }

      return Map<String, dynamic>.from(
        payload,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _readUnixTimestamp(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value != null) {
      return int.tryParse(
        value.toString(),
      );
    }

    return null;
  }

  static String? _normalizeRole(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    var normalized =
        value.trim().toUpperCase();

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains('.')) {
      normalized =
          normalized.split('.').last;
    }

    return normalized;
  }

  // ============================================================
  // BACKWARD-COMPATIBILITY ALIASES
  // ============================================================

  static Future<void> saveToken(String token) async {
    await saveAccessToken(token);
  }

  static Future<String?> getToken() async {
    return getAccessToken();
  }

  static Future<void> clearToken() async {
    await clearSession();
  }

  static Future<bool> hasToken() async {
    return hasAccessToken();
  }
}
