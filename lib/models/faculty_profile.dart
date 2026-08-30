class FacultyProfile {
  final int userId;
  final int facultyId;
  final String employeeId;

  final String email;
  final String fullName;
  final String? phone;

  final String roleName;
  final String accountStatus;

  final String? department;
  final String? designation;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  const FacultyProfile({
    required this.userId,
    required this.facultyId,
    required this.employeeId,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.roleName,
    required this.accountStatus,
    required this.department,
    required this.designation,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLoginAt,
  });

  factory FacultyProfile.fromJson(
    Map<String, dynamic> json,
  ) {
    return FacultyProfile(
      userId: _toInt(json['user_id']),
      facultyId: _toInt(json['faculty_id']),
      employeeId:
          json['employee_id']?.toString() ?? '',
      email:
          json['email']?.toString() ?? '',
      fullName:
          json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      roleName:
          json['role_name']?.toString() ?? '',
      accountStatus:
          json['account_status']?.toString() ?? '',
      department:
          json['department']?.toString(),
      designation:
          json['designation']?.toString(),
      createdAt:
          _toDateTime(json['created_at']),
      updatedAt:
          _toDateTime(json['updated_at']),
      lastLoginAt:
          _toNullableDateTime(
        json['last_login_at'],
      ),
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

  static DateTime _toDateTime(dynamic value) {
    final parsed = DateTime.tryParse(
      value?.toString() ?? '',
    );

    return parsed ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _toNullableDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
    
  }
}