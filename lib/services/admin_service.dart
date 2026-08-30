
import '../core/network/api_client.dart';
import '../models/admin_dashboard_stats.dart';
import '../models/admin_user.dart';

class AdminService {
  AdminService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // ============================================================
  // DASHBOARD
  // ============================================================

  Future<AdminDashboardStats> getDashboardStatistics() async {
    final response = await _apiClient.get(
      '/admin/dashboard',
    );

    if (response is Map<String, dynamic>) {
      return AdminDashboardStats.fromJson(response);
    }

    throw Exception(
      'Invalid dashboard response received from server.',
    );
  }

  // ============================================================
  // ALL USERS
  // ============================================================

  Future<List<AdminUser>> getUsers({
    String? roleName,
    String? accountStatus,
  }) async {
    final queryParameters = <String, String>{};

    if (roleName != null && roleName.isNotEmpty) {
      queryParameters['role_name'] = roleName;
    }

    if (accountStatus != null && accountStatus.isNotEmpty) {
      queryParameters['account_status'] = accountStatus;
    }

    final query = Uri(
      queryParameters: queryParameters,
    ).query;

    final endpoint = query.isEmpty
        ? '/admin/users'
        : '/admin/users?$query';

    final response = await _apiClient.get(
      endpoint,
    );

    return _parseUserList(response);
  }

  // ============================================================
  // PENDING USERS
  // ============================================================

  Future<List<AdminUser>> getPendingUsers() async {
    final response = await _apiClient.get(
      '/admin/users/pending',
    );

    return _parseUserList(response);
  }

  // ============================================================
  // PARSE USER LIST
  // ============================================================

  List<AdminUser> _parseUserList(
    dynamic response,
  ) {
    // API returned a direct JSON array.
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) => AdminUser.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    // API returned:
    // {
    //   "users": [...]
    // }
    if (response is Map<String, dynamic>) {
      final users = response['users'];

      if (users is List) {
        return users
            .whereType<Map>()
            .map(
              (item) => AdminUser.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
    }

    throw Exception(
      'Invalid users response received from server.',
    );
  }

  // ============================================================
  // USER DETAILS
  // ============================================================

  Future<Map<String, dynamic>> getUserDetails(
    int userId,
  ) async {
    final response = await _apiClient.get(
      '/admin/users/$userId',
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid user details response received from server.',
    );
  }

  // ============================================================
  // ACTIVATE
  // ============================================================

  Future<Map<String, dynamic>> activateUser(
    int userId,
  ) async {
    final response = await _apiClient.patch(
      '/admin/users/$userId/activate',
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid activate-user response received from server.',
    );
  }

  // ============================================================
  // SUSPEND
  // ============================================================

  Future<Map<String, dynamic>> suspendUser(
    int userId,
  ) async {
    final response = await _apiClient.patch(
      '/admin/users/$userId/suspend',
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid suspend-user response received from server.',
    );
  }

  // ============================================================
  // DEACTIVATE
  // ============================================================

  Future<Map<String, dynamic>> deactivateUser(
    int userId,
  ) async {
    final response = await _apiClient.patch(
      '/admin/users/$userId/deactivate',
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid deactivate-user response received from server.',
    );
  }

  // ============================================================
  // REACTIVATE
  // ============================================================

  Future<Map<String, dynamic>> reactivateUser(
    int userId,
  ) async {
    final response = await _apiClient.patch(
      '/admin/users/$userId/reactivate',
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid reactivate-user response received from server.',
    );
  }

  // ============================================================
  // CHANGE STATUS
  // ============================================================

  Future<Map<String, dynamic>> changeUserStatus({
    required int userId,
    required String status,
  }) async {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return activateUser(userId);

      case 'SUSPENDED':
        return suspendUser(userId);

      case 'INACTIVE':
        return deactivateUser(userId);

      case 'REACTIVATE':
        return reactivateUser(userId);

      default:
        throw Exception(
          'Unsupported account status: $status',
        );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _apiClient.dispose();
  }
}