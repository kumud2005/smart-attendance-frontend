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
  // ACADEMIC PROGRAM / COURSE-BRANCH MANAGEMENT
  // ============================================================

  Future<List<Map<String, dynamic>>> getPrograms({
    bool activeOnly = false,
  }) async {
    final response = await _apiClient.get(
      '/admin/programs?active_only=$activeOnly',
    );

    return _parseMapList(
      response,
      errorMessage:
          'Invalid academic-program list response received from server.',
    );
  }

  Future<Map<String, dynamic>> createProgram({
    required String programCode,
    required String programName,
    String? description,
  }) async {
    final response = await _apiClient.post(
      '/admin/programs',
      body: {
        'program_code': programCode.trim(),
        'program_name': programName.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );

    return _parseMapResponse(
      response,
      'Invalid create-program response received from server.',
    );
  }

  Future<Map<String, dynamic>> activateProgram(int programId) async {
    final response = await _apiClient.patch(
      '/admin/programs/$programId/activate',
    );
    return _parseMapResponse(
      response,
      'Invalid activate-program response received from server.',
    );
  }

  Future<Map<String, dynamic>> deactivateProgram(int programId) async {
    final response = await _apiClient.patch(
      '/admin/programs/$programId/deactivate',
    );
    return _parseMapResponse(
      response,
      'Invalid deactivate-program response received from server.',
    );
  }

  Future<Map<String, dynamic>> deleteProgram(int programId) async {
    final response = await _apiClient.delete(
      '/admin/programs/$programId',
    );
    return _parseMapResponse(
      response,
      'Invalid delete-program response received from server.',
    );
  }

  Future<List<Map<String, dynamic>>> getBranches({
    int? programId,
    bool activeOnly = false,
  }) async {
    final query = <String, String>{
      'active_only': activeOnly.toString(),
      if (programId != null) 'program_id': programId.toString(),
    };

    final response = await _apiClient.get(
      '/admin/branches?${Uri(queryParameters: query).query}',
    );

    return _parseMapList(
      response,
      errorMessage:
          'Invalid course/branch list response received from server.',
    );
  }

  Future<Map<String, dynamic>> createBranch({
    required int programId,
    required String branchCode,
    required String branchName,
  }) async {
    final response = await _apiClient.post(
      '/admin/branches',
      body: {
        'program_id': programId,
        'branch_code': branchCode.trim(),
        'branch_name': branchName.trim(),
      },
    );

    return _parseMapResponse(
      response,
      'Invalid create-course/branch response received from server.',
    );
  }

  Future<Map<String, dynamic>> activateBranch(int branchId) async {
    final response = await _apiClient.patch(
      '/admin/branches/$branchId/activate',
    );
    return _parseMapResponse(
      response,
      'Invalid activate-course/branch response received from server.',
    );
  }

  Future<Map<String, dynamic>> deactivateBranch(int branchId) async {
    final response = await _apiClient.patch(
      '/admin/branches/$branchId/deactivate',
    );
    return _parseMapResponse(
      response,
      'Invalid deactivate-course/branch response received from server.',
    );
  }

  Future<Map<String, dynamic>> deleteBranch(int branchId) async {
    final response = await _apiClient.delete(
      '/admin/branches/$branchId',
    );
    return _parseMapResponse(
      response,
      'Invalid delete-course/branch response received from server.',
    );
  }


  // ============================================================
  // SUBJECT MANAGEMENT
  // ============================================================

  Future<Map<String, dynamic>> getSubjectManagementOptions() async {
    final response = await _apiClient.get(
      '/admin/subjects/options',
    );

    return _parseMapResponse(
      response,
      'Invalid subject-management options response received from server.',
    );
  }

  Future<List<Map<String, dynamic>>> getSubjects({
    int? programId,
    int? branchId,
    int? semesterId,
    bool activeOnly = false,
  }) async {
    final queryParameters = <String, String>{
      'active_only': activeOnly.toString(),
    };

    if (programId != null) {
      queryParameters['program_id'] = programId.toString();
    }

    if (branchId != null) {
      queryParameters['branch_id'] = branchId.toString();
    }

    if (semesterId != null) {
      queryParameters['semester_id'] = semesterId.toString();
    }

    final query = Uri(
      queryParameters: queryParameters,
    ).query;

    final response = await _apiClient.get(
      '/admin/subjects?$query',
    );

    return _parseMapList(
      response,
      errorMessage:
          'Invalid subject list response received from server.',
    );
  }

  Future<Map<String, dynamic>> createSubject({
    required int programId,
    required int branchId,
    required int semesterId,
    required String subjectCode,
    required String subjectName,
    double? credits,
  }) async {
    final response = await _apiClient.post(
      '/admin/subjects',
      body: {
        'program_id': programId,
        'branch_id': branchId,
        'semester_id': semesterId,
        'subject_code': subjectCode.trim(),
        'subject_name': subjectName.trim(),
        'credits': ?credits,
      },
    );

    return _parseMapResponse(
      response,
      'Invalid create-subject response received from server.',
    );
  }

  Future<Map<String, dynamic>> activateSubject(
    int subjectId,
  ) async {
    if (subjectId <= 0) {
      throw Exception('Invalid subject ID.');
    }

    final response = await _apiClient.patch(
      '/admin/subjects/$subjectId/activate',
    );

    return _parseMapResponse(
      response,
      'Invalid activate-subject response received from server.',
    );
  }

  Future<Map<String, dynamic>> deactivateSubject(
    int subjectId,
  ) async {
    if (subjectId <= 0) {
      throw Exception('Invalid subject ID.');
    }

    final response = await _apiClient.patch(
      '/admin/subjects/$subjectId/deactivate',
    );

    return _parseMapResponse(
      response,
      'Invalid deactivate-subject response received from server.',
    );
  }

  Future<Map<String, dynamic>> deleteSubject(
    int subjectId,
  ) async {
    if (subjectId <= 0) {
      throw Exception('Invalid subject ID.');
    }

    final response = await _apiClient.delete(
      '/admin/subjects/$subjectId',
    );

    return _parseMapResponse(
      response,
      'Invalid delete-subject response received from server.',
    );
  }


  // ============================================================
  // CLASSROOM MANAGEMENT
  // ============================================================

  Future<List<Map<String, dynamic>>> getClassrooms({
    bool activeOnly = false,
  }) async {
    final response = await _apiClient.get(
      '/admin/classrooms?active_only=$activeOnly',
    );

    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    throw Exception(
      'Invalid classroom list response received from server.',
    );
  }

  Future<Map<String, dynamic>> createClassroom({
    required String buildingName,
    required String roomNumber,
    required double latitude,
    required double longitude,
    required double geofenceRadiusMeters,
    bool isActive = true,
  }) async {
    final response = await _apiClient.post(
      '/admin/classrooms',
      body: {
        'building_name': buildingName.trim(),
        'room_number': roomNumber.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'geofence_radius_meters':
            geofenceRadiusMeters,
        'is_active': isActive,
      },
    );

    return _parseMapResponse(
      response,
      'Invalid create-classroom response received from server.',
    );
  }

  Future<Map<String, dynamic>> updateClassroom({
    required int classroomId,
    required String buildingName,
    required String roomNumber,
    required double latitude,
    required double longitude,
    required double geofenceRadiusMeters,
  }) async {
    if (classroomId <= 0) {
      throw Exception('Invalid classroom ID.');
    }

    final response = await _apiClient.patch(
      '/admin/classrooms/$classroomId',
      body: {
        'building_name': buildingName.trim(),
        'room_number': roomNumber.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'geofence_radius_meters':
            geofenceRadiusMeters,
      },
    );

    return _parseMapResponse(
      response,
      'Invalid update-classroom response received from server.',
    );
  }

  Future<Map<String, dynamic>> activateClassroom(
    int classroomId,
  ) async {
    if (classroomId <= 0) {
      throw Exception('Invalid classroom ID.');
    }

    final response = await _apiClient.patch(
      '/admin/classrooms/$classroomId/activate',
    );

    return _parseMapResponse(
      response,
      'Invalid activate-classroom response received from server.',
    );
  }

  Future<Map<String, dynamic>> deactivateClassroom(
    int classroomId,
  ) async {
    if (classroomId <= 0) {
      throw Exception('Invalid classroom ID.');
    }

    final response = await _apiClient.patch(
      '/admin/classrooms/$classroomId/deactivate',
    );

    return _parseMapResponse(
      response,
      'Invalid deactivate-classroom response received from server.',
    );
  }

  Future<Map<String, dynamic>> deleteClassroom(
    int classroomId,
  ) async {
    if (classroomId <= 0) {
      throw Exception('Invalid classroom ID.');
    }

    final response = await _apiClient.delete(
      '/admin/classrooms/$classroomId',
    );

    return _parseMapResponse(
      response,
      'Invalid delete-classroom response received from server.',
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
