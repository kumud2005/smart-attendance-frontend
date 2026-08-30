
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();

  static const String _accessTokenKey = 'access_token';

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
  // GET ACCESS TOKEN
  // ============================================================

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(
      _accessTokenKey,
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
  // CHECK TOKEN
  // ============================================================

  static Future<bool> hasAccessToken() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
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
    await clearAccessToken();
  }

  static Future<bool> hasToken() async {
    return hasAccessToken();
  }
}