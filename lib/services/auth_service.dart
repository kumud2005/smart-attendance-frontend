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
        'email': email.trim().toLowerCase(),
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
  // PASSWORD RESET - REQUEST
  // ============================================================

  Future<Map<String, dynamic>>
      requestPasswordReset({
    required String email,
  }) async {
    final response =
        await _apiClient.post(
      '/auth/password-reset/request',
      body: {
        'email':
            email.trim().toLowerCase(),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid password reset response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // PASSWORD RESET - CONFIRM
  // ============================================================

  Future<Map<String, dynamic>>
      confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    final response =
        await _apiClient.post(
      '/auth/password-reset/confirm',
      body: {
        'reset_token':
            resetToken.trim(),
        'new_password':
            newPassword,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid password reset confirmation received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // REGISTRATION OPTIONS
  // ============================================================

  Future<Map<String, dynamic>> getRegistrationOptions({
    int? semesterId,
  }) async {
    var endpoint = '/auth/registration-options';

    if (semesterId != null) {
      endpoint =
          '$endpoint?semester_id=$semesterId';
    }

    final response = await _apiClient.get(
      endpoint,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid registration options response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // STUDENT REGISTRATION
  // ============================================================

  Future<Map<String, dynamic>> registerStudent({
    required String email,
    required String password,
    required String fullName,
    required int programId,
    required int branchId,
    required String enrollmentNumber,
    required String rollNumber,
    required String dateOfBirth,
    required String abcId,
    required int studentSectionId,
    String? phone,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'role_name': 'STUDENT',
        'email': email.trim().toLowerCase(),
        'password': password,
        'full_name': _toTitleCase(fullName),
        if (phone != null &&
            phone.trim().isNotEmpty)
          'phone': phone.trim(),
        'program_id': programId,
        'branch_id': branchId,
        'enrollment_number':
            enrollmentNumber.trim(),
        'roll_number': rollNumber.trim(),
        'date_of_birth': dateOfBirth,
        'abc_id': abcId.trim(),
        'student_section_id':
            studentSectionId,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid student registration response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // FACULTY REGISTRATION
  // ============================================================

  Future<Map<String, dynamic>> registerFaculty({
    required String email,
    required String password,
    required String fullName,
    required int programId,
    required int branchId,
    required String employeeId,
    required String designation,
    required List<Map<String, dynamic>>
        facultyAssignments,
    String? phone,
  }) async {
    if (facultyAssignments.isEmpty) {
      throw Exception(
        'Please select at least one academic assignment.',
      );
    }

    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'role_name': 'FACULTY',
        'email': email.trim().toLowerCase(),
        'password': password,
        'full_name': _toTitleCase(fullName),
        if (phone != null &&
            phone.trim().isNotEmpty)
          'phone': phone.trim(),
        'program_id': programId,
        'branch_id': branchId,
        'employee_id': employeeId.trim(),
        'designation': designation.trim(),
        'faculty_assignments':
            facultyAssignments,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid faculty registration response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // REGISTRATION NORMALIZATION
  // ============================================================

  String _toTitleCase(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);

    return words.map((word) {
      final lower = word.toLowerCase();
      if (lower.length == 1) return lower.toUpperCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _apiClient.dispose();
  }
}