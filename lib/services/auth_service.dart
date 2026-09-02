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
    required String enrollmentNumber,
    required String rollNumber,
    required String dateOfBirth,
    required int studentSectionId,
    String? phone,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'role_name': 'STUDENT',
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        if (phone != null &&
            phone.trim().isNotEmpty)
          'phone': phone.trim(),
        'enrollment_number':
            enrollmentNumber.trim(),
        'roll_number': rollNumber.trim(),
        'date_of_birth': dateOfBirth,
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
    required String employeeId,
    required String department,
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
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        if (phone != null &&
            phone.trim().isNotEmpty)
          'phone': phone.trim(),
        'employee_id': employeeId.trim(),
        'department': department.trim(),
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
  // DISPOSE
  // ============================================================

  void dispose() {
    _apiClient.dispose();
  }
}