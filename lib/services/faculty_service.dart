import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/attendance_session.dart';
import '../models/faculty_profile.dart';

class FacultyService {
  FacultyService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // ============================================================
  // FACULTY PROFILE
  // ============================================================

  Future<FacultyProfile> getProfile() async {
    final response =
        await _apiClient.get('/faculty/profile');

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid faculty profile response received from server.',
      );
    }

    return FacultyProfile.fromJson(response);
  }

  // ============================================================
  // FACULTY DASHBOARD
  // ============================================================

  Future<Map<String, dynamic>> getDashboard() async {
    final response =
        await _apiClient.get('/faculty/dashboard');

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid faculty dashboard response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // FACULTY ATTENDANCE REPORT
  // ============================================================

  Future<Map<String, dynamic>>
      getAttendanceReport({
    int? semesterId,
    int? sectionId,
    int? subjectId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final endpoint = _buildAttendanceReportEndpoint(
      suffix: '',
      semesterId: semesterId,
      sectionId: sectionId,
      subjectId: subjectId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    final response =
        await _apiClient.get(endpoint);

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid faculty attendance report response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // FACULTY ATTENDANCE REPORT - EXCEL
  // ============================================================

  Future<Uint8List> downloadAttendanceReportExcel({
    int? semesterId,
    int? sectionId,
    int? subjectId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final endpoint = _buildAttendanceReportEndpoint(
      suffix: '/excel',
      semesterId: semesterId,
      sectionId: sectionId,
      subjectId: subjectId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    return _apiClient.getBytes(
      endpoint,
      headers: const {
        'Accept':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
    );
  }

  // ============================================================
  // FACULTY ATTENDANCE REPORT - PDF
  // ============================================================

  Future<Uint8List> downloadAttendanceReportPdf({
    int? semesterId,
    int? sectionId,
    int? subjectId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final endpoint = _buildAttendanceReportEndpoint(
      suffix: '/pdf',
      semesterId: semesterId,
      sectionId: sectionId,
      subjectId: subjectId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    return _apiClient.getBytes(
      endpoint,
      headers: const {
        'Accept': 'application/pdf',
      },
    );
  }

  String _buildAttendanceReportEndpoint({
    required String suffix,
    int? semesterId,
    int? sectionId,
    int? subjectId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final query = <String, String>{};

    if (semesterId != null) {
      query['semester_id'] =
          semesterId.toString();
    }

    if (sectionId != null) {
      query['section_id'] =
          sectionId.toString();
    }

    if (subjectId != null) {
      query['subject_id'] =
          subjectId.toString();
    }

    if (dateFrom != null) {
      query['date_from'] =
          _formatDate(dateFrom);
    }

    if (dateTo != null) {
      query['date_to'] =
          _formatDate(dateTo);
    }

    final uri = Uri(
      path: '/faculty/attendance/report$suffix',
      queryParameters:
          query.isEmpty ? null : query,
    );

    return uri.toString();
  }

  String _formatDate(DateTime value) {
    final year =
        value.year.toString().padLeft(4, '0');
    final month =
        value.month.toString().padLeft(2, '0');
    final day =
        value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ============================================================
  // FACULTY SEMESTERS
  // ============================================================

  Future<List<Map<String, dynamic>>> getSemesters() async {
    final response =
        await _apiClient.get('/faculty/semesters');

    if (response is! List) {
      throw Exception(
        'Invalid semester response received from server.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // ============================================================
  // FACULTY SECTIONS FOR SEMESTER
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getSectionsForSemester(
    int semesterId,
  ) async {
    if (semesterId <= 0) {
      throw Exception(
        'Invalid semester selected.',
      );
    }

    final response =
        await _apiClient.get(
      '/faculty/sections?semester_id=$semesterId',
    );

    if (response is! List) {
      throw Exception(
        'Invalid section response received from server.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // ============================================================
  // FACULTY SUBJECTS FOR SEMESTER + SECTION
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getSubjectsForSection({
    required int semesterId,
    required int sectionId,
  }) async {
    if (semesterId <= 0) {
      throw Exception(
        'Invalid semester selected.',
      );
    }

    if (sectionId <= 0) {
      throw Exception(
        'Invalid section selected.',
      );
    }

    final response =
        await _apiClient.get(
      '/faculty/subjects'
      '?semester_id=$semesterId'
      '&section_id=$sectionId',
    );

    if (response is! List) {
      throw Exception(
        'Invalid subject response received from server.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // ============================================================
  // FACULTY CLASSROOMS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getClassrooms() async {
    final response =
        await _apiClient.get(
      '/faculty/classrooms',
    );

    if (response is! List) {
      throw Exception(
        'Invalid classroom response received from server.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // ============================================================
  // FACULTY STUDENTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getStudents() async {
    final response =
        await _apiClient.get(
      '/faculty/students',
    );

    if (response is! List) {
      throw Exception(
        'Invalid faculty students response received from server.',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // ============================================================
  // CREATE ATTENDANCE SESSION
  // ============================================================

  Future<AttendanceSession>
      createAttendanceSession({
    required int semesterId,
    required int subjectId,
    required int sectionId,
    required int classroomId,
    required int qrValidityMinutes,
    required double geofenceRadiusMeters,
  }) async {
    if (semesterId <= 0) {
      throw Exception(
        'Please select a semester.',
      );
    }

    if (sectionId <= 0) {
      throw Exception(
        'Please select a section.',
      );
    }

    if (subjectId <= 0) {
      throw Exception(
        'Please select a subject.',
      );
    }

    if (classroomId <= 0) {
      throw Exception(
        'Please select a classroom.',
      );
    }

    if (qrValidityMinutes < 1 ||
        qrValidityMinutes > 15) {
      throw Exception(
        'QR validity must be between 1 and 15 minutes.',
      );
    }

    if (geofenceRadiusMeters < 10 ||
        geofenceRadiusMeters > 500) {
      throw Exception(
        'Geofence radius must be between 10 and 500 meters.',
      );
    }

    final response =
        await _apiClient.post(
      '/faculty/attendance/session',
      body: {
        'semester_id': semesterId,
        'subject_id': subjectId,
        'section_id': sectionId,
        'classroom_id': classroomId,
        'qr_validity_minutes':
            qrValidityMinutes,
        'geofence_radius_meters':
            geofenceRadiusMeters,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid attendance session response received from server.',
      );
    }

    return AttendanceSession.fromJson(
      response,
    );
  }

  // ============================================================
  // CURRENT ACTIVE ATTENDANCE SESSION
  // ============================================================

  Future<Map<String, dynamic>?>
      getActiveAttendanceSession() async {
    final response =
        await _apiClient.get(
      '/faculty/attendance/session/active',
    );

    if (response == null) {
      return null;
    }

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid active attendance session response received from server.',
      );
    }

    return response;
  }

  // ============================================================
  // GENERATE ATTENDANCE QR
  // ============================================================

  Future<AttendanceSessionQR>
      generateAttendanceSessionQr(
    int sessionId,
  ) async {
    if (sessionId <= 0) {
      throw Exception(
        'Invalid attendance session.',
      );
    }

    final response =
        await _apiClient.post(
      '/faculty/attendance/session/$sessionId/qr',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid QR response received from server.',
      );
    }

    return AttendanceSessionQR.fromJson(
      response,
    );
  }

  // ============================================================
  // COMPLETE ATTENDANCE SESSION
  // ============================================================

  Future<void> completeAttendanceSession(
    int sessionId,
  ) async {
    if (sessionId <= 0) {
      throw Exception(
        'Invalid attendance session.',
      );
    }

    final response =
        await _apiClient.post(
      '/faculty/attendance/session/$sessionId/complete',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid complete-session response received from server.',
      );
    }

    final sessionStatus =
        response['session_status']
            ?.toString()
            .toUpperCase();

    if (sessionStatus != 'COMPLETED') {
      throw Exception(
        'Session was not completed.',
      );
    }
  }

  // ============================================================
  // CANCEL ATTENDANCE SESSION
  // ============================================================

  Future<void> cancelAttendanceSession(
    int sessionId,
  ) async {
    if (sessionId <= 0) {
      throw Exception(
        'Invalid attendance session.',
      );
    }

    final response =
        await _apiClient.post(
      '/faculty/attendance/session/$sessionId/cancel',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid cancel-session response received from server.',
      );
    }

    final sessionStatus =
        response['session_status']
            ?.toString()
            .toUpperCase();

    if (sessionStatus != 'CANCELLED') {
      throw Exception(
        'Session was not cancelled.',
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
