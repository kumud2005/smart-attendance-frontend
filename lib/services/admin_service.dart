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
  // LEGACY / GENERIC PENDING USERS
  // ============================================================
  //
  // Keep this endpoint for general account-management screens.
  // Public Student/Faculty registrations MUST be reviewed through
  // the dedicated registration-request methods below.
  // ============================================================

  Future<List<AdminUser>> getPendingUsers() async {
    final response = await _apiClient.get(
      '/admin/users/pending',
    );

    return _parseUserList(response);
  }

  // ============================================================
  // STUDENT REGISTRATION REQUESTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getStudentRegistrationRequests({
    String requestStatus = 'PENDING',
  }) async {
    final query = Uri(
      queryParameters: {
        'request_status': requestStatus,
      },
    ).query;

    final response = await _apiClient.get(
      '/admin/student-registration-requests?$query',
    );

    return _parseMapList(
      response,
      errorMessage:
          'Invalid student registration requests response received from server.',
    );
  }

  Future<Map<String, dynamic>>
      approveStudentRegistration({
    required int userId,
    String? note,
  }) async {
    final response = await _apiClient.patch(
      '/admin/student-registration-requests/$userId/approve',
      body: {
        if (note != null && note.trim().isNotEmpty)
          'note': note.trim(),
      },
    );

    return _parseMapResponse(
      response,
      'Invalid student approval response received from server.',
    );
  }

  Future<Map<String, dynamic>>
      rejectStudentRegistration({
    required int userId,
    String? note,
  }) async {
    final response = await _apiClient.patch(
      '/admin/student-registration-requests/$userId/reject',
      body: {
        if (note != null && note.trim().isNotEmpty)
          'note': note.trim(),
      },
    );

    return _parseMapResponse(
      response,
      'Invalid student rejection response received from server.',
    );
  }

  // ============================================================
  // FACULTY REGISTRATION REQUESTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getFacultyRegistrationRequests({
    String requestStatus = 'PENDING',
  }) async {
    final query = Uri(
      queryParameters: {
        'request_status': requestStatus,
      },
    ).query;

    final response = await _apiClient.get(
      '/admin/faculty-registration-requests?$query',
    );

    return _parseMapList(
      response,
      errorMessage:
          'Invalid faculty registration requests response received from server.',
    );
  }

  Future<Map<String, dynamic>>
      approveFacultyRegistration({
    required int userId,
    String? note,
  }) async {
    final response = await _apiClient.patch(
      '/admin/faculty-registration-requests/$userId/approve',
      body: {
        if (note != null && note.trim().isNotEmpty)
          'note': note.trim(),
      },
    );

    return _parseMapResponse(
      response,
      'Invalid faculty approval response received from server.',
    );
  }

  Future<Map<String, dynamic>>
      rejectFacultyRegistration({
    required int userId,
    String? note,
  }) async {
    final response = await _apiClient.patch(
      '/admin/faculty-registration-requests/$userId/reject',
      body: {
        if (note != null && note.trim().isNotEmpty)
          'note': note.trim(),
      },
    );

    return _parseMapResponse(
      response,
      'Invalid faculty rejection response received from server.',
    );
  }

  // ============================================================
  // PARSE RESPONSES
  // ============================================================

  List<AdminUser> _parseUserList(
    dynamic response,
  ) {
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

  List<Map<String, dynamic>> _parseMapList(
    dynamic response, {
    required String errorMessage,
  }) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(
              item,
            ),
          )
          .toList();
    }

    if (response is Map<String, dynamic>) {
      for (final key in const [
        'requests',
        'items',
        'data',
      ]) {
        final value = response[key];

        if (value is List) {
          return value
              .whereType<Map>()
              .map(
                (item) =>
                    Map<String, dynamic>.from(
                  item,
                ),
              )
              .toList();
        }
      }
    }

    throw Exception(errorMessage);
  }

  Map<String, dynamic> _parseMapResponse(
    dynamic response,
    String errorMessage,
  ) {
    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(errorMessage);
  }

  // ============================================================
  // FACULTY ASSIGNMENT MANAGEMENT
  // ============================================================

  Future<Map<String, dynamic>>
      getFacultyAssignmentOptions({
    int? semesterId,
  }) async {
    var endpoint =
        '/admin/faculty-assignments/options';

    if (semesterId != null) {
      endpoint =
          '$endpoint?semester_id=$semesterId';
    }

    final response =
        await _apiClient.get(endpoint);

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid faculty-assignment options response received from server.',
    );
  }

  Future<List<Map<String, dynamic>>>
      getFacultyAssignments({
    int? facultyId,
    int? semesterId,
    bool activeOnly = false,
  }) async {
    final queryParameters =
        <String, String>{};

    if (facultyId != null) {
      queryParameters['faculty_id'] =
          facultyId.toString();
    }

    if (semesterId != null) {
      queryParameters['semester_id'] =
          semesterId.toString();
    }

    queryParameters['active_only'] =
        activeOnly.toString();

    final query = Uri(
      queryParameters: queryParameters,
    ).query;

    final response =
        await _apiClient.get(
      '/admin/faculty-assignments?$query',
    );

    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) =>
                Map<String, dynamic>.from(
              item,
            ),
          )
          .toList();
    }

    throw Exception(
      'Invalid faculty assignments response received from server.',
    );
  }

  Future<Map<String, dynamic>>
      createFacultyAssignment({
    required int facultyId,
    required int semesterId,
    required int sectionId,
    required int subjectId,
  }) async {
    final response =
        await _apiClient.post(
      '/admin/faculty-assignments',
      body: {
        'faculty_id': facultyId,
        'semester_id': semesterId,
        'section_id': sectionId,
        'subject_id': subjectId,
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid create faculty-assignment response received from server.',
    );
  }

  Future<Map<String, dynamic>>
      deactivateFacultyAssignment(
    int assignmentId,
  ) async {
    final response =
        await _apiClient.patch(
      '/admin/faculty-assignments/$assignmentId/deactivate',
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid deactivate faculty-assignment response received from server.',
    );
  }

  // ============================================================
  // CREATE ADMINISTRATOR
  // ============================================================

  Future<Map<String, dynamic>> createAdmin({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    String? phone,
    String? designation,
  }) async {
    final response = await _apiClient.post(
      '/admin/admins',
      body: {
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        if (phone != null && phone.trim().isNotEmpty)
          'phone': phone.trim(),
        'employee_id': employeeId.trim(),
        if (designation != null &&
            designation.trim().isNotEmpty)
          'designation': designation.trim(),
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid create-administrator response received from server.',
    );
  }

  // ============================================================
  // STUDENT FACE MANAGEMENT
  // ============================================================

  Future<Map<String, dynamic>> getStudentFaceProfile(
    int studentId,
  ) async {
    if (studentId <= 0) {
      throw Exception('Invalid student ID.');
    }

    final response = await _apiClient.get(
      '/admin/students/$studentId/face-profile',
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid student face-profile response received from server.',
    );
  }

  Future<Map<String, dynamic>> deleteStudentFaceProfile(
    int studentId,
  ) async {
    if (studentId <= 0) {
      throw Exception('Invalid student ID.');
    }

    final response = await _apiClient.delete(
      '/admin/students/$studentId/face-profile',
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception(
      'Invalid delete student face-profile response received from server.',
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
