import '../core/network/api_client.dart';

class AuthService {
  AuthService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid login response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        if (phone != null &&
            phone.trim().isNotEmpty)
          'phone': phone.trim(),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid registration response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _apiClient.dispose();
  }
}