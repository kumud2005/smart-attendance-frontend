import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../models/admin_dashboard_stats.dart';
import '../../services/admin_service.dart';
import '../auth/login_screen.dart';
import 'admin_users_screen.dart';
import 'admin_attendance_report_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
  });

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();

  AdminDashboardStats? _stats;

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardStatistics();
  }

  @override
  void dispose() {
    _adminService.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD DASHBOARD STATISTICS
  // ============================================================

  Future<void> _loadDashboardStatistics() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats =
          await _adminService.getDashboardStatistics();

      if (!mounted) {
        return;
      }

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // NAVIGATION
  //
  // IMPORTANT:
  // Every user-management page is awaited.
  // When it closes, dashboard statistics are loaded again.
  // Therefore status changes immediately appear on dashboard.
  // ============================================================

  Future<void> _openAllUsers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  Future<void> _openPendingUsers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(
          initialStatus: 'PENDING',
          title: 'Pending Users',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  Future<void> _openStudents() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(
          initialRole: 'STUDENT',
          title: 'Students',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  Future<void> _openFaculty() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(
          initialRole: 'FACULTY',
          title: 'Faculty',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  Future<void> _openAdministrators() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(
          initialRole: 'ADMIN',
          title: 'Administrators',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  Future<void> _openActiveUsers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(
          initialStatus: 'ACTIVE',
          title: 'Active Users',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  Future<void> _openSuspendedUsers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(
          initialStatus: 'SUSPENDED',
          title: 'Suspended Users',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  Future<void> _openInactiveUsers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(
          initialStatus: 'INACTIVE',
          title: 'Inactive Users',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  // ============================================================
  // ATTENDANCE REPORTS
  // ============================================================

  Future<void> _openAttendanceReports() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AdminAttendanceReportScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboardStatistics();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    /*
     * We intentionally do not call a TokenStorage method here
     * because the exact clearing method in your project has not
     * been provided.
     *
     * Navigation removes the dashboard from the navigation stack.
     */

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 960;

        Widget mainContent({
          VoidCallback? onMenuTap,
        }) {
          return Column(
            children: [
              _buildTopBar(
                context,
                onMenuTap: onMenuTap,
                compact: compact,
              ),
              Expanded(
                child:
                    _buildDashboardContent(
                  context,
                  compact: compact,
                ),
              ),
            ],
          );
        }

        return Scaffold(
          backgroundColor:
              AppColors.background,
          drawer: compact
              ? Drawer(
                  width: 290,
                  child: _buildSidebar(
                    context,
                    width: double.infinity,
                  ),
                )
              : null,
          body: compact
              ? Builder(
                  builder: (
                    scaffoldContext,
                  ) {
                    return mainContent(
                      onMenuTap: () {
                        Scaffold.of(
                          scaffoldContext,
                        ).openDrawer();
                      },
                    );
                  },
                )
              : Row(
                  children: [
                    _buildSidebar(
                      context,
                    ),
                    Expanded(
                      child:
                          mainContent(),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _buildSidebar(
    BuildContext context, {
    double width = 250,
  }) {
    return Container(
      width: width,
      color: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: AppColors.primaryDark,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'GHRCE Attendance',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              color: Colors.white24,
              height: 1,
            ),

            const SizedBox(height: 20),

            _buildSidebarItem(
              icon: Icons.dashboard_rounded,
              title: 'Dashboard',
              selected: true,
              onTap: () {},
            ),

            _buildSidebarItem(
              icon: Icons.people_alt_rounded,
              title: 'All Users',
              selected: false,
              onTap: _openAllUsers,
            ),

            _buildSidebarItem(
              icon:
                  Icons.pending_actions_rounded,
              title: 'Pending Users',
              selected: false,
              onTap: _openPendingUsers,
            ),

            _buildSidebarItem(
              icon: Icons.school_rounded,
              title: 'Students',
              selected: false,
              onTap: _openStudents,
            ),

            _buildSidebarItem(
              icon: Icons.person_rounded,
              title: 'Faculty',
              selected: false,
              onTap: _openFaculty,
            ),

            _buildSidebarItem(
              icon: Icons.analytics_rounded,
              title: 'Attendance Reports',
              selected: false,
              onTap: _openAttendanceReports,
            ),

            const Spacer(),

            const Divider(
              color: Colors.white24,
              height: 1,
            ),

            // ==================================================
            // LOGOUT
            // ==================================================

            _buildSidebarItem(
              icon: Icons.logout_rounded,
              title: 'Logout',
              selected: false,
              onTap: _logout,
            ),

            // ==================================================
            // ADMIN PROFILE
            // ==================================================

            InkWell(
              onTap: _showAdminProfile,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor:
                          AppColors.white,
                      child: Icon(
                        Icons
                            .admin_panel_settings_rounded,
                        color:
                            AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administrator',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SIDEBAR ITEM
  // ============================================================

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      child: Material(
        color: selected
            ? AppColors.accent
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.white
                      : Colors.white70,
                  size: 21,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? AppColors.white
                          : Colors.white70,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (!selected)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar(
    BuildContext context, {
    VoidCallback? onMenuTap,
    bool compact = false,
  }) {
    return Container(
      height: compact ? 64 : 76,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 28,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          if (onMenuTap != null)
            IconButton(
              tooltip: 'Open menu',
              onPressed: onMenuTap,
              icon: const Icon(
                Icons.menu_rounded,
              ),
            ),

          Expanded(
            child: Text(
              'Admin Dashboard',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize:
                    compact ? 18 : 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _isLoading
                ? null
                : _loadDashboardStatistics,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),

          if (!compact) ...[
            const SizedBox(width: 4),

            IconButton(
              tooltip: 'Notifications',
              onPressed:
                  _showNotifications,
              icon: const Icon(
                Icons.notifications_none_rounded,
              ),
            ),

            const SizedBox(width: 8),
          ],

          InkWell(
            onTap: _showAdminProfile,
            borderRadius:
                BorderRadius.circular(25),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    child: Icon(
                      Icons.person_rounded,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    const Text(
                      'Administrator',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(
            width:
                compact ? 4 : 20,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DASHBOARD CONTENT
  // ============================================================

  Widget _buildDashboardContent(
    BuildContext context, {
    bool compact = false,
  }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_stats == null) {
      return _buildErrorState(
        message:
            'No dashboard data received from the server.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardStatistics,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(
          compact ? 14 : 28,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Administrator',
              style: TextStyle(
                fontSize:
                    compact ? 22 : 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Here is an overview of the GHRCE Smart Attendance System.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 28),

            _buildStatisticsGrid(),

            const SizedBox(height: 32),

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                      _buildSystemOverview(),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child:
                          _buildQuickActions(),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child:
                          _buildSystemOverview(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            _buildManagementBanner(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState({
    String? message,
  }) {
    final error = message ??
        _errorMessage ??
        'Unable to load dashboard statistics.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 58,
                  color: AppColors.error,
                ),

                const SizedBox(height: 18),

                const Text(
                  'Dashboard data unavailable',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 500,
                  ),
                  child: Text(
                    error,
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                FilledButton.icon(
                  onPressed:
                      _loadDashboardStatistics,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label:
                      const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATISTICS GRID
  // ============================================================

  Widget _buildStatisticsGrid() {
    final stats = _stats!;

    final cards = [
      _DashboardStatData(
        title: 'Total Users',
        value: stats.totalUsers.toString(),
        icon: Icons.people_alt_rounded,
        onTap: _openAllUsers,
      ),
      _DashboardStatData(
        title: 'Pending Users',
        value: stats.pendingUsers.toString(),
        icon:
            Icons.pending_actions_rounded,
        onTap: _openPendingUsers,
      ),
      _DashboardStatData(
        title: 'Active Users',
        value: stats.activeUsers.toString(),
        icon: Icons.check_circle_rounded,
        onTap: _openActiveUsers,
      ),
      _DashboardStatData(
        title: 'Suspended Users',
        value:
            stats.suspendedUsers.toString(),
        icon: Icons.block_rounded,
        onTap: _openSuspendedUsers,
      ),
      _DashboardStatData(
        title: 'Inactive Users',
        value:
            stats.inactiveUsers.toString(),
        icon: Icons.pause_circle_rounded,
        onTap: _openInactiveUsers,
      ),
      _DashboardStatData(
        title: 'Students',
        value:
            stats.totalStudents.toString(),
        icon: Icons.school_rounded,
        onTap: _openStudents,
      ),
      _DashboardStatData(
        title: 'Faculty',
        value:
            stats.totalFaculty.toString(),
        icon: Icons.person_rounded,
        onTap: _openFaculty,
      ),
      _DashboardStatData(
        title: 'Administrators',
        value:
            stats.totalAdmins.toString(),
        icon:
            Icons.admin_panel_settings_rounded,
        onTap: _openAdministrators,
      ),
    ];

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final width = constraints.maxWidth;

        // On phones, avoid GridView childAspectRatio entirely.
        // The old ratio produced a fractional card height on some
        // Android devices, which caused the 0.286 px bottom overflow.
        if (width < 600) {
          return Column(
            children: [
              for (int i = 0;
                  i < cards.length;
                  i++) ...[
                _buildStatCard(
                  cards[i],
                  compact: true,
                ),
                if (i != cards.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          );
        }

        final columns =
            width >= 1200 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (
            context,
            index,
          ) {
            return _buildStatCard(
              cards[index],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard(
    _DashboardStatData data, {
    bool compact = false,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 14 : 20,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 46 : 52,
                height: compact ? 46 : 52,
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    compact ? 12 : 14,
                  ),
                ),
                child: Icon(
                  data.icon,
                  color: AppColors.primary,
                  size: compact ? 23 : 27,
                ),
              ),

              SizedBox(
                width: compact ? 12 : 16,
              ),

              Expanded(
                child: compact
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.title,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            data.value,
                            style:
                                const TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Text(
                            data.title,
                            style: TextStyle(
                              color: AppColors
                                  .textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            data.value,
                            style:
                                const TextStyle(
                              fontSize: 26,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),

              SizedBox(
                width: compact ? 6 : 0,
              ),

              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: compact ? 20 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            _buildActionButton(
              icon:
                  Icons.people_alt_rounded,
              title: 'View All Users',
              subtitle:
                  'Manage registered users',
              onTap: _openAllUsers,
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              icon:
                  Icons.pending_actions_rounded,
              title: 'Pending Users',
              subtitle:
                  'Review accounts awaiting activation',
              onTap: _openPendingUsers,
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              icon: Icons.school_rounded,
              title: 'Students',
              subtitle:
                  'View student accounts',
              onTap: _openStudents,
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              icon: Icons.person_rounded,
              title: 'Faculty',
              subtitle:
                  'View faculty accounts',
              onTap: _openFaculty,
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              icon: Icons.analytics_rounded,
              title: 'Attendance Reports',
              subtitle:
                  'Audit system-wide attendance and anti-proxy verification',
              onTap: _openAttendanceReports,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceSoft,
      borderRadius:
          BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      AppColors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: TextStyle(
                        color:
                            AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SYSTEM OVERVIEW
  // ============================================================

  Widget _buildSystemOverview() {
    final stats = _stats!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            _buildOverviewRow(
              icon: Icons.school_rounded,
              title: 'Students',
              value:
                  stats.totalStudents.toString(),
              onTap: _openStudents,
            ),

            const Divider(height: 24),

            _buildOverviewRow(
              icon: Icons.person_rounded,
              title: 'Faculty',
              value:
                  stats.totalFaculty.toString(),
              onTap: _openFaculty,
            ),

            const Divider(height: 24),

            _buildOverviewRow(
              icon:
                  Icons.admin_panel_settings_rounded,
              title: 'Administrators',
              value:
                  stats.totalAdmins.toString(),
              onTap: _openAdministrators,
            ),

            const Divider(height: 24),

            _buildOverviewRow(
              icon:
                  Icons.check_circle_rounded,
              title: 'Active Accounts',
              value:
                  stats.activeUsers.toString(),
              onTap: _openActiveUsers,
            ),

            const Divider(height: 24),

            _buildOverviewRow(
              icon:
                  Icons.pending_actions_rounded,
              title: 'Pending Accounts',
              value:
                  stats.pendingUsers.toString(),
              onTap: _openPendingUsers,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OVERVIEW ROW
  // ============================================================

  Widget _buildOverviewRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 5,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 22,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),

              Text(
                value,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color:
                    AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MANAGEMENT BANNER
  // ============================================================

  Widget _buildManagementBanner() {
    return Card(
      child: InkWell(
        onTap: _openAllUsers,
        borderRadius:
            BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 600;

            if (compact) {
              return Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              BoxDecoration(
                            color: AppColors
                                .primary
                                .withValues(
                              alpha: 0.10,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .manage_accounts_rounded,
                            color:
                                AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        const Expanded(
                          child: Text(
                            'User Management',
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'View, search and manage all registered student, faculty and administrator accounts.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed:
                            _openAllUsers,
                        icon: const Icon(
                          Icons
                              .arrow_forward_rounded,
                        ),
                        label: const Text(
                          'Manage Users',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding:
                  const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration:
                        BoxDecoration(
                      color: AppColors.primary
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .manage_accounts_rounded,
                      color:
                          AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'User Management',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'View, search and manage all registered student, faculty and administrator accounts.',
                          style: TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  FilledButton.icon(
                    onPressed:
                        _openAllUsers,
                    icon: const Icon(
                      Icons
                          .arrow_forward_rounded,
                    ),
                    label: const Text(
                      'Manage Users',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  void _showNotifications() {
    final pending =
        _stats?.pendingUsers ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.notifications_rounded,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('Notifications'),
            ],
          ),

          content: pending > 0
              ? Text(
                  'There are $pending pending user account(s) waiting for review.',
                )
              : const Text(
                  'You have no new notifications.',
                ),

          actions: [
            if (pending > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop();

                  _openPendingUsers();
                },
                child: const Text(
                  'View Pending Users',
                ),
              ),

            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ADMIN PROFILE
  // ============================================================

  void _showAdminProfile() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Administrator Profile',
          ),

          content: const SizedBox(
            width: 400,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 38,
                  child: Icon(
                    Icons.person_rounded,
                    size: 40,
                  ),
                ),

                SizedBox(height: 18),

                Text(
                  'Administrator',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 6),

                Text(
                  'System Administrator',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                SizedBox(height: 20),

                Divider(),

                SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Administrator access',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      Icons.dashboard_rounded,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dashboard access enabled',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// DASHBOARD STATISTICS DATA
// ============================================================

class _DashboardStatData {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardStatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });
}