import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../services/faculty_service.dart';
import '../auth/login_screen.dart';
import 'faculty_attendance_screen.dart';
import 'faculty_reports_screen.dart';
import 'faculty_subjects_screen.dart';
import 'faculty_classes_screen.dart';
import 'faculty_students_screen.dart';
import 'faculty_profile_screen.dart';

class FacultyDashboardScreen extends StatefulWidget {
  const FacultyDashboardScreen({
    super.key,
  });

  @override
  State<FacultyDashboardScreen> createState() =>
      _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState
    extends State<FacultyDashboardScreen> {
  final FacultyService _facultyService =
      FacultyService();

  bool _isLoading = true;
  bool _isAutoRefreshing = false;

  String? _errorMessage;

  Map<String, dynamic>? _dashboardData;

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();

    _loadDashboard();

    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _refreshDashboardSilently();
      },
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _facultyService.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await _facultyService.getDashboard();

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboardData = response;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _refreshDashboardSilently({
    bool force = false,
  }) async {
    if (!mounted ||
        _isLoading ||
        _isAutoRefreshing) {
      return;
    }

    if (!force &&
        ModalRoute.of(context)?.isCurrent !=
            true) {
      return;
    }

    _isAutoRefreshing = true;

    try {
      final response =
          await _facultyService.getDashboard();

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboardData = response;
        _errorMessage = null;
      });
    } catch (_) {
      // Keep the currently displayed dashboard during a temporary
      // background refresh failure. Manual refresh still surfaces
      // request errors normally.
    } finally {
      _isAutoRefreshing = false;
    }
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    try {
      await TokenStorage.clearToken();
    } catch (_) {
      // Continue to login even if token cleanup fails.
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // FACULTY NAVIGATION
  // ============================================================

  Future<void> _openAttendance() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FacultyAttendanceScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refreshDashboardSilently(
      force: true,
    );
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FacultyReportsScreen(),
      ),
    );
  }

  void _openSubjects() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FacultySubjectsScreen(),
      ),
    );
  }

  void _openClasses() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FacultyClassesScreen(),
      ),
    );
  }

  void _openStudents() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FacultyStudentsScreen(),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const FacultyProfileScreen(),
      ),
    );
  }

  // ============================================================
  // VALUE HELPERS
  // ============================================================

  String _value(
    String key, {
    String fallback = '-',
  }) {
    final value = _dashboardData?[key];

    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  int _intValue(String key) {
    final value = _dashboardData?[key];

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

  List<dynamic> _listValue(String key) {
    final value = _dashboardData?[key];

    if (value is List) {
      return value;
    }

    return const [];
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 900;
        final contentPadding =
            compact ? 14.0 : 24.0;

        Widget mainContent({
          VoidCallback? onMenuTap,
        }) {
          return Column(
            children: [
              _buildTopBar(
                onMenuTap: onMenuTap,
                compact: compact,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh:
                      _loadDashboard,
                  child:
                      SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(
                      contentPadding,
                    ),
                    child:
                        _buildContent(),
                  ),
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
                  width: 280,
                  child: _buildSidebar(
                    width: double.infinity,
                  ),
                )
              : null,
          body: SafeArea(
            child: compact
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
                      _buildSidebar(),
                      Expanded(
                        child:
                            mainContent(),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _buildSidebar({
    double width = 205,
  }) {
    return Container(
      width: width,
      color: AppColors.primaryDark,
      child: Column(
        children: [
          Container(
            height: 128,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            decoration:
                BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color:
                      AppColors.white.withValues(
                    alpha: 0.15,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    color: AppColors.white,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color:
                        AppColors.primaryDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'GHRCE Attendance',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ------------------------------------------------------
          // DASHBOARD
          // ------------------------------------------------------

          _sidebarItem(
            icon:
                Icons.dashboard_rounded,
            title: 'Dashboard',
            selected: true,
            onTap: () {},
          ),

          // ------------------------------------------------------
          // ATTENDANCE
          // ------------------------------------------------------

          _sidebarItem(
            icon:
                Icons.fact_check_rounded,
            title: 'Attendance',
            onTap: _openAttendance,
          ),

          _sidebarItem(
            icon:
                Icons.assessment_rounded,
            title: 'Reports',
            onTap: _openReports,
          ),

          // ------------------------------------------------------
          // SUBJECTS
          // ------------------------------------------------------

          _sidebarItem(
            icon:
                Icons.menu_book_rounded,
            title: 'Subjects',
            onTap: _openSubjects,
          ),

          // ------------------------------------------------------
          // CLASSES
          // ------------------------------------------------------

          _sidebarItem(
            icon:
                Icons.groups_rounded,
            title: 'Classes',
            onTap: _openClasses,
          ),

          // ------------------------------------------------------
          // STUDENTS
          // ------------------------------------------------------

          _sidebarItem(
            icon:
                Icons.school_rounded,
            title: 'Students',
            onTap: _openStudents,
          ),

          // ------------------------------------------------------
          // PROFILE
          // ------------------------------------------------------

          _sidebarItem(
            icon:
                Icons.person_rounded,
            title: 'My Profile',
            onTap: _openProfile,
          ),

          const Spacer(),

          // ------------------------------------------------------
          // LOGOUT
          // ------------------------------------------------------

          Container(
            decoration:
                BoxDecoration(
              border: Border(
                top: BorderSide(
                  color:
                      AppColors.white.withValues(
                    alpha: 0.15,
                  ),
                ),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: _sidebarItem(
              icon: Icons.logout_rounded,
              title: 'Logout',
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String title,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      child: Material(
        color: selected
            ? AppColors.accent
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(10),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? AppColors.white
                      : AppColors.white.withValues(
                          alpha: 0.75,
                        ),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: TextStyle(
                    color: selected
                        ? AppColors.white
                        : AppColors.white
                            .withValues(
                            alpha: 0.75,
                          ),
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
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

  Widget _buildTopBar({
    VoidCallback? onMenuTap,
    bool compact = false,
  }) {
    return Container(
      height: 62,
      color: AppColors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 20,
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
              'Faculty Dashboard',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize:
                    compact ? 17 : 20,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isLoading
                    ? null
                    : _loadDashboard,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 22,
            ),
          ),

          if (!compact)
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_none_rounded,
                size: 22,
              ),
            ),

          const SizedBox(width: 4),

          const CircleAvatar(
            radius: 17,
            backgroundColor:
                AppColors.surfaceSoft,
            child: Icon(
              Icons.person_rounded,
              color:
                  AppColors.primary,
              size: 20,
            ),
          ),

          if (!compact) ...[
            const SizedBox(width: 10),

            Flexible(
              child: Text(
                _value(
                  'full_name',
                  fallback: 'Faculty',
                ),
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color:
                      AppColors.textPrimary,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${_value(
            'full_name',
            fallback: 'Faculty',
          )}',
          style: const TextStyle(
            fontSize: 26,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Here is your Faculty Dashboard.',
          style: TextStyle(
            fontSize: 14,
            color:
                AppColors.textSecondary,
          ),
        ),

        const SizedBox(height: 24),

        if (_errorMessage != null)
          _buildErrorBanner(),

        if (_errorMessage != null)
          const SizedBox(height: 16),

        if (_isLoading)
          _buildLoadingState()
        else ...[
          _buildStatistics(),

          const SizedBox(height: 18),

          _buildDashboardCards(),
        ],
      ],
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 70,
      ),
      child: const Center(
        child:
            CircularProgressIndicator(),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.error.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              AppColors.error.withValues(
            alpha: 0.22,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 22,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _errorMessage ??
                  'Unable to load dashboard.',
              style:
                  const TextStyle(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(width: 8),

          TextButton(
            onPressed:
                _isLoading
                    ? null
                    : _loadDashboard,
            child:
                const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final cards = [
          _statCard(
            icon:
                Icons.menu_book_rounded,
            title: 'My Subjects',
            value:
                _intValue(
              'subject_count',
            ).toString(),
          ),

          _statCard(
            icon:
                Icons.groups_rounded,
            title: 'My Classes',
            value:
                _intValue(
              'section_count',
            ).toString(),
          ),

          _statCard(
            icon:
                Icons.school_rounded,
            title: 'Students',
            value:
                _intValue(
              'student_count',
            ).toString(),
          ),

          _statCard(
            icon:
                Icons.fact_check_rounded,
            title: 'Attendance',
            value:
                _intValue(
              'attendance_count',
            ).toString(),
          ),
        ];

        if (constraints.maxWidth <
            700) {
          return Column(
            children: [
              for (
                int i = 0;
                i < cards.length;
                i++
              ) ...[
                cards[i],

                if (i !=
                    cards.length - 1)
                  const SizedBox(
                    height: 12,
                  ),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (
              int i = 0;
              i < cards.length;
              i++
            ) ...[
              Expanded(
                child:
                    cards[i],
              ),

              if (i !=
                  cards.length - 1)
                const SizedBox(
                  width: 12,
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x10000000),
            blurRadius: 2,
            offset:
                Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  AppColors.surfaceSoft,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              color:
                  AppColors.primary,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DASHBOARD CARDS
  // ============================================================

  Widget _buildDashboardCards() {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final isWide =
            constraints.maxWidth >=
                900;

        final quickActions =
            _buildQuickActions();

        final facultyInformation =
            _buildFacultyInformation();

        final recentSessions =
            _buildRecentSessions();

        if (isWide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Expanded(
                    flex: 3,
                    child:
                        quickActions,
                  ),

                  const SizedBox(
                    width: 16,
                  ),

                  Expanded(
                    flex: 2,
                    child:
                        facultyInformation,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              recentSessions,
            ],
          );
        }

        return Column(
          children: [
            quickActions,

            const SizedBox(
              height: 16,
            ),

            facultyInformation,

            const SizedBox(
              height: 16,
            ),

            recentSessions,
          ],
        );
      },
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(height: 14),

          _quickAction(
            icon:
                Icons.fact_check_rounded,
            title: 'Attendance',
            subtitle:
                'Manage attendance sessions',
            onTap:
                _openAttendance,
          ),

          const SizedBox(height: 10),

          _quickAction(
            icon:
                Icons.assessment_rounded,
            title: 'Attendance Reports',
            subtitle:
                'View, filter, and export attendance reports',
            onTap:
                _openReports,
          ),

          const SizedBox(height: 10),

          _quickAction(
            icon:
                Icons.menu_book_rounded,
            title: 'My Subjects',
            subtitle:
                'View assigned subjects',
            onTap:
                _openSubjects,
          ),

          const SizedBox(height: 10),

          _quickAction(
            icon:
                Icons.groups_rounded,
            title: 'My Classes',
            subtitle:
                'View assigned classes and sections',
            onTap:
                _openClasses,
          ),

          const SizedBox(height: 10),

          _quickAction(
            icon:
                Icons.school_rounded,
            title: 'Students',
            subtitle:
                'View students in your assigned sections',
            onTap:
                _openStudents,
          ),

          const SizedBox(height: 10),

          _quickAction(
            icon:
                Icons.person_rounded,
            title: 'My Profile',
            subtitle:
                'View your faculty profile',
            onTap:
                _openProfile,
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius:
          BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(10),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.surfaceSoft,
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      AppColors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FACULTY INFORMATION
  // ============================================================

  Widget _buildFacultyInformation() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Faculty Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          _infoRow(
            'Employee ID',
            _value('employee_id'),
          ),

          _infoRow(
            'Name',
            _value('full_name'),
          ),

          _infoRow(
            'Email',
            _value('email'),
          ),

          _infoRow(
            'Phone',
            _value('phone'),
          ),

          _infoRow(
            'Department',
            _value('department'),
          ),

          _infoRow(
            'Designation',
            _value('designation'),
          ),

          _infoRow(
            'Status',
            _value('account_status'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    AppColors.textSecondary,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECENT ATTENDANCE SESSIONS
  // ============================================================

  Widget _buildRecentSessions() {
    final sessions =
        _listValue(
      'recent_sessions',
    );

    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Attendance Sessions',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          if (sessions.isEmpty)
            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 18,
              ),
              child: Center(
                child: Text(
                  'No attendance sessions found.',
                  style: TextStyle(
                    color:
                        AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...sessions
                .take(5)
                .map(_sessionRow),
        ],
      ),
    );
  }

  Widget _sessionRow(
    dynamic data,
  ) {
    if (data is! Map) {
      return const SizedBox.shrink();
    }

    final subject =
        data['subject_name']
            ?.toString()
            .trim();

    final section =
        data['section_name']
            ?.toString()
            .trim();

    final status =
        data['session_status']
            ?.toString()
            .trim();

    final attendance =
        data['attendance_count']
            ?.toString()
            .trim();

    final subjectText =
        subject == null ||
                subject.isEmpty
            ? '-'
            : subject;

    final sectionText =
        section == null ||
                section.isEmpty
            ? '-'
            : section;

    final statusText =
        status == null ||
                status.isEmpty
            ? '-'
            : status;

    final attendanceText =
        attendance == null ||
                attendance.isEmpty
            ? '0'
            : attendance;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            AppColors.surfaceSoft,
        borderRadius:
            BorderRadius.circular(
          9,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color:
                  AppColors.surfaceSoft,
              borderRadius:
                  BorderRadius.circular(
                9,
              ),
            ),
            child:
                const Icon(
              Icons.fact_check_rounded,
              color:
                  AppColors.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  subjectText,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  'Section: $sectionText',
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .end,
            children: [
              Text(
                statusText,
                style:
                    const TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                '$attendanceText attendance',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON CARD
  // ============================================================

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color:
            AppColors.surfaceSoft,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x10000000),
            blurRadius: 2,
            offset:
                Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}