import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';
import '../auth/login_screen.dart';
import 'student_face_profile_screen.dart';
import 'student_face_screen.dart';
import 'student_geofence_screen.dart';
import 'student_liveness_screen.dart';
import 'student_scan_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({
    super.key,
  });

  @override
  State<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends State<StudentDashboardScreen> {
  final StudentService _studentService =
      StudentService();

  bool _isLoading = true;

  String? _errorMessage;

  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _faceStatus;
  Map<String, dynamic>? _activeAttendanceAttempt;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _studentService.dispose();
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
      final dashboard =
          await _studentService.getDashboard();

      final faceStatus =
          await _studentService.getFaceStatus();

      Map<String, dynamic>? activeAttempt;

      try {
        final activeResponse =
            await _studentService
                .getActiveAttendanceAttempt();

        if (activeResponse[
                'has_active_attempt'] ==
            true) {
          final rawAttempt =
              activeResponse['attempt'];

          if (rawAttempt
              is Map<String, dynamic>) {
            activeAttempt = rawAttempt;
          } else if (rawAttempt is Map) {
            activeAttempt =
                Map<String, dynamic>.from(
              rawAttempt,
            );
          }
        }
      } catch (_) {
        // Keep dashboard usable if resume lookup temporarily fails.
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboardData = dashboard;
        _faceStatus = faceStatus;
        _activeAttendanceAttempt =
            activeAttempt;
        _isLoading = false;
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
        builder: (_) =>
            const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // OPEN QR SCANNER
  // ============================================================

  Future<void> _openScanner() async {
    Map<String, dynamic>? activeAttempt;

    try {
      final activeResponse =
          await _studentService
              .getActiveAttendanceAttempt();

      if (activeResponse[
              'has_active_attempt'] ==
          true) {
        final rawAttempt =
            activeResponse['attempt'];

        if (rawAttempt
            is Map<String, dynamic>) {
          activeAttempt = rawAttempt;
        } else if (rawAttempt is Map) {
          activeAttempt =
              Map<String, dynamic>.from(
            rawAttempt,
          );
        }
      }

      if (mounted) {
        setState(() {
          _activeAttendanceAttempt =
              activeAttempt;
        });
      }
    } catch (_) {
      // Scanner remains a safe fallback because rescanning the same
      // QR returns the existing PENDING attendance_id.
    }

    if (!mounted) {
      return;
    }

    Widget destination =
        const StudentScanScreen();

    if (activeAttempt != null) {
      final attendanceId =
          _toIntValue(
        activeAttempt['attendance_id'],
      );

      final nextStep =
          activeAttempt[
                  'next_verification_step']
              ?.toString()
              .trim()
              .toUpperCase();

      if (attendanceId > 0) {
        switch (nextStep) {
          case 'GEOFENCE':
            destination =
                StudentGeofenceScreen(
              attendanceId: attendanceId,
              attendanceData:
                  activeAttempt,
            );
            break;

          case 'FACE':
            destination =
                StudentFaceScreen(
              attendanceId: attendanceId,
              attendanceData:
                  activeAttempt,
            );
            break;

          case 'LIVENESS':
            destination =
                StudentLivenessScreen(
              attendanceId: attendanceId,
            );
            break;
        }
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => destination,
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  int _toIntValue(dynamic value) {
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

  // ============================================================
  // OPEN FACE PROFILE
  // ============================================================

  Future<void> _openFaceProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const StudentFaceProfileScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    // Refresh face registration status after
    // returning from face profile registration.
    await _loadDashboard();
  }

  // ============================================================
  // TEMPORARY FEATURE MESSAGE
  // ============================================================

  void _showFeatureMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
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
    final value =
        _dashboardData?[key];

    if (value == null) {
      return fallback;
    }

    final result =
        value.toString().trim();

    if (result.isEmpty) {
      return fallback;
    }

    return result;
  }

  int _intValue(
    String key,
  ) {
    final value =
        _dashboardData?[key];

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

  double _doubleValue(
    String key,
  ) {
    final value =
        _dashboardData?[key];

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  // ============================================================
  // FACE PROFILE STATUS
  // ============================================================

  bool _faceRegistered() {
    final status =
        _faceStatus;

    if (status == null) {
      return false;
    }

    return status['registered'] == true &&
        status['is_verified'] == true &&
        status['is_active'] == true;
  }

  // ============================================================
  // ERROR CLEANUP
  // ============================================================

  String _cleanErrorMessage(
    Object error,
  ) {
    final message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 760;
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
                  onRefresh: _loadDashboard,
                  child: SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(
                      contentPadding,
                    ),
                    child: _buildContent(),
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
                        child: mainContent(),
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
      color:
          AppColors.primaryDark,
      child: SafeArea(
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
                bottom:
                    BorderSide(
                  color: AppColors.white
                      .withValues(
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
                    color:
                        AppColors.white,
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .school_rounded,
                    color:
                        Color(
                      0xFF19295C,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                const Expanded(
                  child: Text(
                    'GHRCE Attendance',
                    style:
                        TextStyle(
                      color:
                          AppColors.white,
                      fontSize: 16,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          // ----------------------------------------------------------
          // DASHBOARD
          // ----------------------------------------------------------

          _sidebarItem(
            icon:
                Icons.dashboard_rounded,
            title: 'Dashboard',
            selected: true,
            onTap: () {},
          ),

          // ----------------------------------------------------------
          // SCAN ATTENDANCE
          // ----------------------------------------------------------

          _sidebarItem(
            icon: Icons
                .qr_code_scanner_rounded,
            title:
                'Scan Attendance',
            onTap: _openScanner,
          ),

          // ----------------------------------------------------------
          // MY ATTENDANCE
          // ----------------------------------------------------------

          _sidebarItem(
            icon:
                Icons.fact_check_rounded,
            title: 'My Attendance',
            onTap: () {
              _showFeatureMessage(
                'My Attendance screen will be connected next.',
              );
            },
          ),

          // ----------------------------------------------------------
          // FACE PROFILE
          // ----------------------------------------------------------

          _sidebarItem(
            icon: Icons
                .face_retouching_natural,
            title: 'Face Profile',
            onTap:
                _openFaceProfile,
          ),

          const Spacer(),

          // ----------------------------------------------------------
          // LOGOUT
          // ----------------------------------------------------------

          Container(
            decoration:
                BoxDecoration(
              border: Border(
                top:
                    BorderSide(
                  color: AppColors.white
                      .withValues(
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
              icon:
                  Icons.logout_rounded,
              title: 'Logout',
              onTap: _logout,
            ),
          ),
        ],
        ),
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
            ? const Color(
                0xFF405080,
              )
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                ),

                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? AppColors.white
                      : AppColors.white
                          .withValues(
                          alpha:
                              0.75,
                        ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      color: selected
                          ? Colors
                              .white
                          : Colors
                              .white
                              .withValues(
                              alpha:
                                  0.75,
                            ),
                      fontSize: 13,
                      fontWeight:
                          selected
                              ? FontWeight
                                  .w600
                              : FontWeight
                                  .w500,
                    ),
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
    required bool compact,
  }) {
    return Container(
      height: 62,
      color: AppColors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 20,
      ),
      child: Row(
        children: [
          if (onMenuTap != null) ...[
            IconButton(
              tooltip: 'Menu',
              onPressed: onMenuTap,
              icon: const Icon(
                Icons.menu_rounded,
              ),
            ),
            const SizedBox(
              width: 2,
            ),
          ],
          Expanded(
            child: Text(
              'Student Dashboard',
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
            onPressed: _isLoading
                ? null
                : _loadDashboard,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(
            width: 2,
          ),
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
            const SizedBox(
              width: 10,
            ),
            Flexible(
              child: Text(
                _value(
                  'full_name',
                  fallback: 'Student',
                ),
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors
                      .grey.shade800,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding:
            EdgeInsets.symmetric(
          vertical: 100,
        ),
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${_value(
            'full_name',
            fallback: 'Student',
          )}',
          style: const TextStyle(
            fontSize: 26,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          'Mark your attendance securely using QR, location, face, and liveness verification.',
          style: TextStyle(
            fontSize: 14,
            color:
                AppColors.textSecondary,
          ),
        ),

        const SizedBox(
          height: 24,
        ),

        if (_errorMessage !=
            null) ...[
          _buildErrorBanner(),

          const SizedBox(
            height: 16,
          ),
        ],

        _buildScanCard(),

        const SizedBox(
          height: 18,
        ),

        _buildStatistics(),

        const SizedBox(
          height: 18,
        ),

        _buildAttendanceSummary(),

        const SizedBox(
          height: 18,
        ),

        _buildStudentInformation(),
      ],
    );
  }

  // ============================================================
  // SCAN CARD
  // ============================================================

  Widget _buildScanCard() {
    final faceRegistered =
        _faceRegistered();

    final activeAttempt =
        _activeAttendanceAttempt;

    final hasActiveAttempt =
        activeAttempt != null;

    final resumeStep =
        activeAttempt?[
                'next_verification_step']
            ?.toString()
            .trim()
            .toUpperCase();

    Widget iconBox() {
      return Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: const Color(
            0xFFE8EAF8,
          ),
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.qr_code_scanner_rounded,
          color: Color(
            0xFF4658B7,
          ),
          size: 34,
        ),
      );
    }

    Widget details() {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Mark Attendance',
            style: TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            hasActiveAttempt
                ? 'Attendance verification is in progress. '
                  'Continue from ${resumeStep ?? 'the next step'}.'
                : 'Scan the QR code displayed by your faculty.',
            style: TextStyle(
              fontSize: 13,
              color:
                  Colors.grey.shade600,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Row(
            children: [
              Icon(
                faceRegistered
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: faceRegistered
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(
                width: 6,
              ),
              Flexible(
                child: Text(
                  faceRegistered
                      ? 'Face profile ready'
                      : 'Face profile not registered',
                  style: TextStyle(
                    fontSize: 11,
                    color: faceRegistered
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(
            0xFFE7E4ED,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    iconBox(),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child: details(),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                FilledButton.icon(
                  onPressed: _openScanner,
                  icon: Icon(
                    hasActiveAttempt
                        ? Icons.play_circle_outline_rounded
                        : Icons.qr_code_scanner_rounded,
                  ),
                  label: Text(
                    hasActiveAttempt
                        ? 'Resume Attendance'
                        : 'Scan QR',
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              iconBox(),
              const SizedBox(
                width: 18,
              ),
              Expanded(
                child: details(),
              ),
              const SizedBox(
                width: 16,
              ),
              FilledButton.icon(
                onPressed: _openScanner,
                icon: Icon(
                  hasActiveAttempt
                      ? Icons.play_circle_outline_rounded
                      : Icons.qr_code_scanner_rounded,
                ),
                label: Text(
                  hasActiveAttempt
                      ? 'Resume Attendance'
                      : 'Scan QR',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final compact =
            constraints.maxWidth < 700;

        final cards = [
          _statCard(
            icon: Icons.menu_book_rounded,
            title: 'Subjects',
            value: _intValue(
              'subject_count',
            ).toString(),
            compact: compact,
          ),
          _statCard(
            icon: Icons.groups_rounded,
            title: 'Classes',
            value: _intValue(
              'class_count',
            ).toString(),
            compact: compact,
          ),
          _statCard(
            icon: Icons.fact_check_rounded,
            title: 'Attendance',
            value: _intValue(
              'attendance_count',
            ).toString(),
            compact: compact,
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (int i = 0;
                  i < cards.length;
                  i++) ...[
                cards[i],
                if (i != cards.length - 1)
                  const SizedBox(
                    height: 12,
                  ),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0;
                i < cards.length;
                i++) ...[
              Expanded(
                child: cards[i],
              ),
              if (i != cards.length - 1)
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
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 18,
        vertical: compact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(
            0xFFE7E4ED,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 46 : 42,
            height: compact ? 46 : 42,
            decoration: BoxDecoration(
              color: const Color(
                0xFFE8EAF8,
              ),
              borderRadius:
                  BorderRadius.circular(
                compact ? 12 : 10,
              ),
            ),
            child: Icon(
              icon,
              color: const Color(
                0xFF4658B7,
              ),
              size: compact ? 23 : 22,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: compact
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors
                                .grey.shade600,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
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
                  )
                : Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey.shade600,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
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
  // ATTENDANCE SUMMARY
  // ============================================================

  Widget _buildAttendanceSummary() {
    final present =
        _intValue(
      'present_count',
    );

    final pending =
        _intValue(
      'pending_count',
    );

    final rejected =
        _intValue(
      'rejected_count',
    );

    final percentage =
        _doubleValue(
      'attendance_percentage',
    );

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.white,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE7E4ED,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance Summary',
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _summaryChip(
                icon: Icons
                    .check_circle_rounded,
                label:
                    'Present',
                value:
                    '$present',
                color:
                    AppColors.success,
              ),
              _summaryChip(
                icon:
                    Icons.schedule_rounded,
                label:
                    'Pending',
                value:
                    '$pending',
                color:
                    AppColors.warning,
              ),
              _summaryChip(
                icon:
                    Icons.cancel_rounded,
                label:
                    'Rejected',
                value:
                    '$rejected',
                color:
                    AppColors.error,
              ),
              _summaryChip(
                icon:
                    Icons.percent_rounded,
                label:
                    'Attendance',
                value:
                    '${percentage.toStringAsFixed(1)}%',
                color:
                    const Color(
                  0xFF4658B7,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              color.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),

          const SizedBox(
            width: 8,
          ),

          Text(
            '$label: ',
            style:
                TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),

          Text(
            value,
            style:
                TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT INFORMATION
  // ============================================================

  Widget _buildStudentInformation() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF9F7FD,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFE7E4ED,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Student Information',
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          _infoRow(
            'Enrollment',
            _value(
              'enrollment_number',
            ),
          ),

          _infoRow(
            'Roll Number',
            _value(
              'roll_number',
            ),
          ),

          _infoRow(
            'Email',
            _value(
              'email',
            ),
          ),

          _infoRow(
            'Phone',
            _value(
              'phone',
            ),
          ),

          _infoRow(
            'Semester',
            _value(
              'semester_name',
            ),
          ),

          _infoRow(
            'Section',
            _value(
              'section_name',
            ),
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
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelStyle = TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          );
          const valueStyle = TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );

          if (constraints.maxWidth < 320) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: labelStyle,
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  value,
                  softWrap: true,
                  style: valueStyle,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: labelStyle,
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  value,
                  softWrap: true,
                  style: valueStyle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ERROR BANNER
  // ============================================================

  Widget _buildErrorBanner() {
    return Container(
      width:
          double.infinity,
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
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              AppColors.error.withValues(
            alpha: 0.22,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons
                .error_outline_rounded,
            color:
                AppColors.error,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              _errorMessage ??
                  'Unable to load dashboard.',
              style:
                  const TextStyle(
                color:
                    AppColors.error,
                fontSize: 13,
              ),
            ),
          ),

          TextButton(
            onPressed:
                _isLoading
                    ? null
                    : _loadDashboard,
            child:
                const Text(
              'Retry',
            ),
          ),
        ],
      ),
    );
  }
}