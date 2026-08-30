
class AdminDashboardStats {
  final int totalUsers;
  final int pendingUsers;
  final int activeUsers;
  final int suspendedUsers;
  final int inactiveUsers;
  final int totalStudents;
  final int totalFaculty;
  final int totalAdmins;

  const AdminDashboardStats({
    required this.totalUsers,
    required this.pendingUsers,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.inactiveUsers,
    required this.totalStudents,
    required this.totalFaculty,
    required this.totalAdmins,
  });

  factory AdminDashboardStats.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminDashboardStats(
      totalUsers: _toInt(json['total_users']),
      pendingUsers: _toInt(json['pending_users']),
      activeUsers: _toInt(json['active_users']),
      suspendedUsers: _toInt(json['suspended_users']),
      inactiveUsers: _toInt(json['inactive_users']),
      totalStudents: _toInt(json['total_students']),
      totalFaculty: _toInt(json['total_faculty']),
      totalAdmins: _toInt(json['total_admins']),
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