DateTime _parseServerDateTime(dynamic value) {
  final raw = value?.toString().trim() ?? '';

  if (raw.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // Railway/backend timestamps are currently returned without
  // an explicit timezone. The production backend runs in UTC,
  // so timezone-less timestamps must be interpreted as UTC.
  final hasTimezone = RegExp(
    r'(Z|[+-]\d{2}:\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw);

  final normalized = hasTimezone ? raw : '${raw}Z';

  final parsed = DateTime.tryParse(normalized);

  if (parsed == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // Keep frontend values in the device/browser local timezone.
  return parsed.toLocal();
}


DateTime? _parseNullableServerDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  final raw = value.toString().trim();

  if (raw.isEmpty) {
    return null;
  }

  final hasTimezone = RegExp(
    r'(Z|[+-]\d{2}:\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw);

  final normalized = hasTimezone ? raw : '${raw}Z';

  return DateTime.tryParse(normalized)?.toLocal();
}


// ============================================================================
// ATTENDANCE SESSION
// ============================================================================

class AttendanceSession {
  final int sessionId;
  final int facultyId;
  final int subjectId;
  final int sectionId;
  final int classroomId;
  final String sessionToken;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime qrExpiresAt;
  final String sessionStatus;
  final DateTime createdAt;

  const AttendanceSession({
    required this.sessionId,
    required this.facultyId,
    required this.subjectId,
    required this.sectionId,
    required this.classroomId,
    required this.sessionToken,
    required this.startedAt,
    required this.endedAt,
    required this.qrExpiresAt,
    required this.sessionStatus,
    required this.createdAt,
  });

  factory AttendanceSession.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendanceSession(
      sessionId: _toInt(json['session_id']),
      facultyId: _toInt(json['faculty_id']),
      subjectId: _toInt(json['subject_id']),
      sectionId: _toInt(json['section_id']),
      classroomId: _toInt(json['classroom_id']),
      sessionToken:
          json['session_token']?.toString() ?? '',
      startedAt:
          _parseServerDateTime(json['started_at']),
      endedAt:
          _parseNullableServerDateTime(json['ended_at']),
      qrExpiresAt:
          _parseServerDateTime(json['qr_expires_at']),
      sessionStatus:
          json['session_status']?.toString() ?? '',
      createdAt:
          _parseServerDateTime(json['created_at']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}


// ============================================================================
// ATTENDANCE SESSION QR
// ============================================================================

class AttendanceSessionQR {
  final int sessionId;
  final int subjectId;
  final String subjectName;
  final int sectionId;
  final String sectionName;
  final int classroomId;
  final String sessionStatus;
  final DateTime startedAt;
  final DateTime qrExpiresAt;
  final String qrData;
  final String qrCodeBase64;
  final String qrImageDataUri;

  const AttendanceSessionQR({
    required this.sessionId,
    required this.subjectId,
    required this.subjectName,
    required this.sectionId,
    required this.sectionName,
    required this.classroomId,
    required this.sessionStatus,
    required this.startedAt,
    required this.qrExpiresAt,
    required this.qrData,
    required this.qrCodeBase64,
    required this.qrImageDataUri,
  });

  factory AttendanceSessionQR.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendanceSessionQR(
      sessionId: _toInt(json['session_id']),
      subjectId: _toInt(json['subject_id']),
      subjectName:
          json['subject_name']?.toString() ?? '',
      sectionId: _toInt(json['section_id']),
      sectionName:
          json['section_name']?.toString() ?? '',
      classroomId: _toInt(json['classroom_id']),
      sessionStatus:
          json['session_status']?.toString() ?? '',
      startedAt:
          _parseServerDateTime(json['started_at']),
      qrExpiresAt:
          _parseServerDateTime(json['qr_expires_at']),
      qrData:
          json['qr_data']?.toString() ?? '',
      qrCodeBase64:
          json['qr_code_base64']?.toString() ?? '',
      qrImageDataUri:
          json['qr_image_data_uri']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}