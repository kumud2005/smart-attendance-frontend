import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/admin_attendance_report.dart';

class AdminAttendanceReportService {
  AdminAttendanceReportService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // ============================================================
  // SYSTEM-WIDE ADMIN ATTENDANCE REPORT
  // ============================================================

  Future<AdminAttendanceReport> getAttendanceReport({
    int? semesterId,
    int? sectionId,
    int? subjectId,
    int? facultyId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final endpoint = _buildAttendanceReportEndpoint(
      semesterId: semesterId,
      sectionId: sectionId,
      subjectId: subjectId,
      facultyId: facultyId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    final response = await _apiClient.get(endpoint);

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid admin attendance report response received from server.',
      );
    }

    return AdminAttendanceReport.fromJson(response);
  }

  // ============================================================
  // ADMIN ATTENDANCE REPORT - EXCEL
  // ============================================================

  Future<Uint8List> downloadAttendanceReportExcel({
    int? semesterId,
    int? sectionId,
    int? subjectId,
    int? facultyId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final endpoint = _buildAttendanceReportEndpoint(
      suffix: '/excel',
      semesterId: semesterId,
      sectionId: sectionId,
      subjectId: subjectId,
      facultyId: facultyId,
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
  // ADMIN ATTENDANCE REPORT - PDF
  // ============================================================

  Future<Uint8List> downloadAttendanceReportPdf({
    int? semesterId,
    int? sectionId,
    int? subjectId,
    int? facultyId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final endpoint = _buildAttendanceReportEndpoint(
      suffix: '/pdf',
      semesterId: semesterId,
      sectionId: sectionId,
      subjectId: subjectId,
      facultyId: facultyId,
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
    String suffix = '',
    int? semesterId,
    int? sectionId,
    int? subjectId,
    int? facultyId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final query = <String, String>{};

    if (semesterId != null) {
      query['semester_id'] = semesterId.toString();
    }

    if (sectionId != null) {
      query['section_id'] = sectionId.toString();
    }

    if (subjectId != null) {
      query['subject_id'] = subjectId.toString();
    }

    if (facultyId != null) {
      query['faculty_id'] = facultyId.toString();
    }

    if (dateFrom != null) {
      query['date_from'] = _formatDate(dateFrom);
    }

    if (dateTo != null) {
      query['date_to'] = _formatDate(dateTo);
    }

    final uri = Uri(
      path: '/admin/attendance/report$suffix',
      queryParameters: query.isEmpty ? null : query,
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

  void dispose() {
    _apiClient.dispose();
  }
}
