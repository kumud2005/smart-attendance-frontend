class AdminUser {
  final int userId;
  final String email;
  final String fullName;
  final String? phone;
  final String roleName;
  final String accountStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  const AdminUser({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.roleName,
    required this.accountStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLoginAt,
  });

  factory AdminUser.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminUser(
      userId: _toInt(json['user_id']),
      email: json['email']?.toString() ?? '',
      fullName:
          json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      roleName:
          json['role_name']?.toString() ?? '',
      accountStatus:
          json['account_status']?.toString() ?? '',
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

    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
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