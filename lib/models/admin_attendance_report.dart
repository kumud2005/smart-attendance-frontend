class AdminAttendanceSummary {
  const AdminAttendanceSummary({
    required this.totalSessions,
    required this.totalStudents,
    required this.totalFaculty,
    required this.attendanceOpportunities,
    required this.attendanceRecords,
    required this.present,
    required this.pending,
    required this.rejected,
    required this.notMarked,
    required this.attendancePercentage,
  });

  final int totalSessions;
  final int totalStudents;
  final int totalFaculty;
  final int attendanceOpportunities;
  final int attendanceRecords;
  final int present;
  final int pending;
  final int rejected;
  final int notMarked;
  final double attendancePercentage;

  factory AdminAttendanceSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminAttendanceSummary(
      totalSessions: _asInt(json['total_sessions']),
      totalStudents: _asInt(json['total_students']),
      totalFaculty: _asInt(json['total_faculty']),
      attendanceOpportunities:
          _asInt(json['attendance_opportunities']),
      attendanceRecords:
          _asInt(json['attendance_records']),
      present: _asInt(json['present']),
      pending: _asInt(json['pending']),
      rejected: _asInt(json['rejected']),
      notMarked: _asInt(json['not_marked']),
      attendancePercentage:
          _asDouble(json['attendance_percentage']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

class AdminAttendanceReport {
  const AdminAttendanceReport({
    required this.filters,
    required this.summary,
    required this.facultyWise,
    required this.subjectWise,
    required this.sectionWise,
    required this.dayWise,
    required this.sessionWise,
    required this.records,
  });

  final Map<String, dynamic> filters;
  final AdminAttendanceSummary summary;
  final List<Map<String, dynamic>> facultyWise;
  final List<Map<String, dynamic>> subjectWise;
  final List<Map<String, dynamic>> sectionWise;
  final List<Map<String, dynamic>> dayWise;
  final List<Map<String, dynamic>> sessionWise;
  final List<Map<String, dynamic>> records;

  factory AdminAttendanceReport.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminAttendanceReport(
      filters: _asMap(json['filters']),
      summary: AdminAttendanceSummary.fromJson(
        _asMap(json['summary']),
      ),
      facultyWise: _asMapList(json['faculty_wise']),
      subjectWise: _asMapList(json['subject_wise']),
      sectionWise: _asMapList(json['section_wise']),
      dayWise: _asMapList(json['day_wise']),
      sessionWise: _asMapList(json['session_wise']),
      records: _asMapList(json['records']),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asMapList(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }
}
