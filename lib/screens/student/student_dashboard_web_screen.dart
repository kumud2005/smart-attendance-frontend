import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';

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
  bool _isReportLoading = false;

  String? _errorMessage;
  String? _reportErrorMessage;

  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _reportData;

  int _selectedPage = 0;
  int _selectedReportTab = 0;

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

      if (!mounted) {
        return;
      }

      setState(() {
        _dashboardData = dashboard;
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
  // LOAD COMPLETE ATTENDANCE REPORT
  // ============================================================

  Future<void> _loadAttendanceReport({
    bool force = false,
  }) async {
    if (!mounted) {
      return;
    }

    if (!force && _reportData != null) {
      return;
    }

    setState(() {
      _isReportLoading = true;
      _reportErrorMessage = null;
    });

    try {
      final report =
          await _studentService.getAttendanceReport();

      if (!mounted) {
        return;
      }

      setState(() {
        _reportData = report;
        _isReportLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isReportLoading = false;
        _reportErrorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _openReports() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPage = 1;
    });

    await _loadAttendanceReport();
  }

  Future<void> _refreshCurrentPage() async {
    if (_selectedPage == 0) {
      await _loadDashboard();
      return;
    }

    await _loadAttendanceReport(
      force: true,
    );
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

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  // ============================================================
  // DASHBOARD VALUE HELPERS
  // ============================================================

  String _value(
    String key, {
    String fallback = '-',
  }) {
    final value = _dashboardData?[key];

    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty
        ? fallback
        : result;
  }

  int _intValue(
    String key,
  ) {
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

  double _doubleValue(
    String key,
  ) {
    final value = _dashboardData?[key];

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
  // REPORT VALUE HELPERS
  // ============================================================

  Map<String, dynamic> _mapValue(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapListValue(
    dynamic value,
  ) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  int _reportInt(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];

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

  double _reportDouble(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];

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

  String _textValue(
    Map<String, dynamic> map,
    String key, {
    String fallback = '-',
  }) {
    final value = map[key];

    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    return text.isEmpty
        ? fallback
        : text;
  }

  bool _boolValue(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return value
            ?.toString()
            .toLowerCase() ==
        'true';
  }

  String _cleanErrorMessage(
    Object error,
  ) {
    final message = error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  String _formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(raw);

    if (date == null) {
      return raw;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  String _formatDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(raw);

    if (date == null) {
      return raw;
    }

    final dateText = _formatDate(raw);

    return '$dateText '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
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
                      _refreshCurrentPage,
                  child:
                      SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(
                      contentPadding,
                    ),
                    child:
                        _selectedPage == 0
                            ? _buildDashboardContent()
                            : _buildReportsContent(),
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
      color:
          AppColors.primaryDark,
      child: Column(
        children: [
          Container(
            height: 128,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.white
                      .withValues(
                    alpha: 0.15,
                  ),
                ),
              ),
            ),
            child: const Row(
              children: [
                _BrandIcon(),
                SizedBox(width: 10),
                Expanded(
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
          const SizedBox(
            height: 18,
          ),
          _sidebarItem(
            icon:
                Icons.dashboard_rounded,
            title: 'Dashboard',
            selected:
                _selectedPage == 0,
            onTap: () {
              setState(() {
                _selectedPage = 0;
              });
            },
          ),
          _sidebarItem(
            icon:
                Icons.assessment_rounded,
            title: 'Attendance Reports',
            selected:
                _selectedPage == 1,
            onTap: () {
              _openReports();
            },
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
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
                          alpha: 0.75,
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
                    style: TextStyle(
                      color: selected
                          ? AppColors.white
                          : AppColors.white
                              .withValues(
                              alpha: 0.75,
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
              _selectedPage == 0
                  ? 'Student Dashboard'
                  : 'Attendance Reports',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 17 : 20,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                (_selectedPage == 0 &&
                            _isLoading) ||
                        (_selectedPage == 1 &&
                            _isReportLoading)
                    ? null
                    : _refreshCurrentPage,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(
            width: 4,
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
                style: const TextStyle(
                  fontSize: 13,
                  color:
                      AppColors.textPrimary,
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
  // DASHBOARD CONTENT
  // ============================================================

  Widget _buildDashboardContent() {
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
          'View your attendance information and reports here. '
          'Attendance marking is available through the mobile app.',
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
          _buildDashboardErrorBanner(),
          const SizedBox(
            height: 16,
          ),
        ],
        _buildWebAccessCard(),
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

  Widget _buildWebAccessCard() {
    Widget infoRow() {
      return Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color:
                  AppColors.surfaceSoft,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: const Icon(
              Icons.assessment_rounded,
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
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View overall, subject-wise, day-wise and detailed '
                  'attendance records. Attendance marking remains mobile-only.',
                  style: TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          if (constraints.maxWidth <
              560) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                infoRow(),
                const SizedBox(
                  height: 16,
                ),
                OutlinedButton.icon(
                  onPressed:
                      _openReports,
                  icon: const Icon(
                    Icons.visibility_rounded,
                  ),
                  label: const Text(
                    'View Report',
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: infoRow(),
              ),
              const SizedBox(
                width: 12,
              ),
              OutlinedButton.icon(
                onPressed:
                    _openReports,
                icon: const Icon(
                  Icons.visibility_rounded,
                ),
                label: const Text(
                  'View Report',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // DASHBOARD STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final cards = [
          _statCard(
            icon:
                Icons.menu_book_rounded,
            title: 'Subjects',
            value: _intValue(
              'subject_count',
            ).toString(),
          ),
          _statCard(
            icon:
                Icons.groups_rounded,
            title: 'Classes',
            value: _intValue(
              'class_count',
            ).toString(),
          ),
          _statCard(
            icon:
                Icons.fact_check_rounded,
            title: 'Attendance',
            value: _intValue(
              'attendance_count',
            ).toString(),
          ),
        ];

        if (constraints.maxWidth <
            700) {
          return Column(
            children: [
              for (int i = 0;
                  i < cards.length;
                  i++) ...[
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
            for (int i = 0;
                i < cards.length;
                i++) ...[
              Expanded(
                child: cards[i],
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
          const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  const Color(
                0xFFE8EAF8,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              color:
                  const Color(
                0xFF4658B7,
              ),
              size: 22,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
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
  // DASHBOARD ATTENDANCE SUMMARY
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
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
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
            style: TextStyle(
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
                icon:
                    Icons.check_circle_rounded,
                label: 'Present',
                value: '$present',
                color: AppColors.success,
              ),
              _summaryChip(
                icon:
                    Icons.schedule_rounded,
                label: 'Pending',
                value: '$pending',
                color: AppColors.warning,
              ),
              _summaryChip(
                icon:
                    Icons.cancel_rounded,
                label: 'Rejected',
                value: '$rejected',
                color: AppColors.error,
              ),
              _summaryChip(
                icon:
                    Icons.percent_rounded,
                label: 'Attendance',
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
      decoration: BoxDecoration(
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
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
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
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
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
            style: TextStyle(
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
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
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
  // REPORT CONTENT
  // ============================================================

  Widget _buildReportsContent() {
    if (_isReportLoading &&
        _reportData == null) {
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

    if (_reportErrorMessage != null &&
        _reportData == null) {
      return _buildReportErrorBanner();
    }

    final report =
        _reportData;

    if (report == null) {
      return Center(
        child: OutlinedButton.icon(
          onPressed:
              _loadAttendanceReport,
          icon: const Icon(
            Icons.refresh_rounded,
          ),
          label: const Text(
            'Load Attendance Report',
          ),
        ),
      );
    }

    final student =
        _mapValue(
      report['student'],
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance Reports',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    '${_textValue(student, 'full_name', fallback: _value('full_name', fallback: 'Student'))} • '
                    '${_textValue(student, 'enrollment_number')} • '
                    '${_textValue(student, 'section_name')}',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_isReportLoading)
              const Padding(
                padding:
                    EdgeInsets.only(
                  top: 8,
                ),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(
          height: 20,
        ),
        if (_reportErrorMessage !=
            null) ...[
          _buildReportErrorBanner(),
          const SizedBox(
            height: 16,
          ),
        ],
        _buildReportTabs(),
        const SizedBox(
          height: 18,
        ),
        _buildSelectedReportTab(
          report,
        ),
      ],
    );
  }

  Widget _buildReportTabs() {
    final tabs = [
      (
        icon: Icons.dashboard_rounded,
        label: 'Overview',
      ),
      (
        icon: Icons.menu_book_rounded,
        label: 'Subject Wise',
      ),
      (
        icon: Icons.calendar_month_rounded,
        label: 'Day Wise',
      ),
      (
        icon: Icons.table_rows_rounded,
        label: 'Detailed Records',
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (int index = 0;
            index < tabs.length;
            index++)
          _selectedReportTab ==
                  index
              ? FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedReportTab =
                          index;
                    });
                  },
                  icon: Icon(
                    tabs[index].icon,
                  ),
                  label: Text(
                    tabs[index].label,
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedReportTab =
                          index;
                    });
                  },
                  icon: Icon(
                    tabs[index].icon,
                  ),
                  label: Text(
                    tabs[index].label,
                  ),
                ),
      ],
    );
  }

  Widget _buildSelectedReportTab(
    Map<String, dynamic> report,
  ) {
    switch (_selectedReportTab) {
      case 1:
        return _buildSubjectWiseReport(
          report,
        );
      case 2:
        return _buildDayWiseReport(
          report,
        );
      case 3:
        return _buildDetailedRecords(
          report,
        );
      default:
        return _buildReportOverview(
          report,
        );
    }
  }

  // ============================================================
  // REPORT OVERVIEW
  // ============================================================

  Widget _buildReportOverview(
    Map<String, dynamic> report,
  ) {
    final summary =
        _mapValue(
      report['summary'],
    );

    final total =
        _reportInt(
      summary,
      'total_classes',
    );
    final records =
        _reportInt(
      summary,
      'attendance_records',
    );
    final present =
        _reportInt(
      summary,
      'present',
    );
    final pending =
        _reportInt(
      summary,
      'pending',
    );
    final rejected =
        _reportInt(
      summary,
      'rejected',
    );
    final notMarked =
        _reportInt(
      summary,
      'not_marked',
    );
    final percentage =
        _reportDouble(
      summary,
      'attendance_percentage',
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder:
              (context, constraints) {
            final width =
                constraints.maxWidth;

            final cardWidth =
                width >= 1050
                    ? (width - 36) / 4
                    : width >= 700
                        ? (width - 12) / 2
                        : width;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _reportMetricCard(
                  width: cardWidth,
                  title: 'Total Classes',
                  value: '$total',
                  icon:
                      Icons.groups_rounded,
                  color:
                      const Color(
                    0xFF4658B7,
                  ),
                ),
                _reportMetricCard(
                  width: cardWidth,
                  title: 'Attendance Records',
                  value: '$records',
                  icon:
                      Icons.fact_check_rounded,
                  color:
                      const Color(
                    0xFF4658B7,
                  ),
                ),
                _reportMetricCard(
                  width: cardWidth,
                  title: 'Present',
                  value: '$present',
                  icon:
                      Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                _reportMetricCard(
                  width: cardWidth,
                  title: 'Pending',
                  value: '$pending',
                  icon:
                      Icons.schedule_rounded,
                  color: AppColors.warning,
                ),
                _reportMetricCard(
                  width: cardWidth,
                  title: 'Rejected',
                  value: '$rejected',
                  icon:
                      Icons.cancel_rounded,
                  color: AppColors.error,
                ),
                _reportMetricCard(
                  width: cardWidth,
                  title: 'Not Marked',
                  value: '$notMarked',
                  icon:
                      Icons.remove_circle_outline_rounded,
                  color: Colors.grey,
                ),
                _reportMetricCard(
                  width: cardWidth,
                  title: 'Attendance %',
                  value:
                      '${percentage.toStringAsFixed(1)}%',
                  icon:
                      Icons.percent_rounded,
                  color:
                      const Color(
                    0xFF4658B7,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(
          height: 18,
        ),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(
            20,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
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
                'How attendance is calculated',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                'Attendance percentage = Present classes ÷ Total classes × 100. '
                'A class without an attendance record is shown as Not Marked.',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reportMetricCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding:
            const EdgeInsets.all(
          18,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
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
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    color.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
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
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUBJECT-WISE REPORT
  // ============================================================

  Widget _buildSubjectWiseReport(
    Map<String, dynamic> report,
  ) {
    final rows =
        _mapListValue(
      report['subject_wise'],
    );

    if (rows.isEmpty) {
      return _emptyReportCard(
        icon:
            Icons.menu_book_rounded,
        title:
            'No subject-wise attendance available.',
      );
    }

    return _reportTableCard(
      title: 'Subject-wise Attendance',
      subtitle:
          'Attendance totals grouped by subject.',
      child: DataTable(
        columns: const [
          DataColumn(
            label: Text(
              'Subject',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Classes',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Present',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Pending',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Rejected',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Not Marked',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Attendance %',
            ),
          ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(
                  Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        _textValue(
                          row,
                          'subject_code',
                        ),
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      Text(
                        _textValue(
                          row,
                          'subject_name',
                        ),
                        style:
                            TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'total_classes')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'present')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'pending')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'rejected')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'not_marked')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportDouble(row, 'attendance_percentage').toStringAsFixed(1)}%',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ============================================================
  // DAY-WISE REPORT
  // ============================================================

  Widget _buildDayWiseReport(
    Map<String, dynamic> report,
  ) {
    final rows =
        _mapListValue(
      report['day_wise'],
    );

    if (rows.isEmpty) {
      return _emptyReportCard(
        icon:
            Icons.calendar_month_rounded,
        title:
            'No day-wise attendance available.',
      );
    }

    return _reportTableCard(
      title: 'Day-wise Attendance',
      subtitle:
          'Attendance totals grouped by class date.',
      child: DataTable(
        columns: const [
          DataColumn(
            label: Text(
              'Date',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Classes',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Present',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Pending',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Rejected',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Not Marked',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Attendance %',
            ),
          ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    _formatDate(
                      row['date'],
                    ),
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'total_classes')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'present')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'pending')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'rejected')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportInt(row, 'not_marked')}',
                  ),
                ),
                DataCell(
                  Text(
                    '${_reportDouble(row, 'attendance_percentage').toStringAsFixed(1)}%',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAILED RECORDS
  // ============================================================

  Widget _buildDetailedRecords(
    Map<String, dynamic> report,
  ) {
    final records =
        _mapListValue(
      report['records'],
    );

    if (records.isEmpty) {
      return _emptyReportCard(
        icon:
            Icons.table_rows_rounded,
        title:
            'No attendance records available.',
      );
    }

    return _reportTableCard(
      title: 'Detailed Attendance Records',
      subtitle:
          'Click a row or View to inspect that class attendance record.',
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(
            label: Text(
              'Date',
            ),
          ),
          DataColumn(
            label: Text(
              'Subject',
            ),
          ),
          DataColumn(
            numeric: true,
            label: Text(
              'Session',
            ),
          ),
          DataColumn(
            label: Text(
              'Status',
            ),
          ),
          DataColumn(
            label: Text(
              'QR',
            ),
          ),
          DataColumn(
            label: Text(
              'Geo',
            ),
          ),
          DataColumn(
            label: Text(
              'Face',
            ),
          ),
          DataColumn(
            label: Text(
              'Live',
            ),
          ),
          DataColumn(
            label: Text(
              'Details',
            ),
          ),
        ],
        rows: [
          for (final record
              in records)
            DataRow(
              onSelectChanged: (_) {
                _showRecordDetails(
                  record,
                );
              },
              cells: [
                DataCell(
                  Text(
                    _formatDate(
                      record['date'],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 190,
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _textValue(
                            record,
                            'subject_code',
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        Text(
                          _textValue(
                            record,
                            'subject_name',
                          ),
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _textValue(
                      record,
                      'session_id',
                    ),
                  ),
                ),
                DataCell(
                  _statusBadge(
                    _textValue(
                      record,
                      'attendance_status',
                      fallback:
                          'NOT_MARKED',
                    ),
                  ),
                ),
                DataCell(
                  _verificationIcon(
                    _boolValue(
                      record,
                      'qr_verified',
                    ),
                  ),
                ),
                DataCell(
                  _verificationIcon(
                    _boolValue(
                      record,
                      'geofence_verified',
                    ),
                  ),
                ),
                DataCell(
                  _verificationIcon(
                    _boolValue(
                      record,
                      'face_verified',
                    ),
                  ),
                ),
                DataCell(
                  _verificationIcon(
                    _boolValue(
                      record,
                      'liveness_verified',
                    ),
                  ),
                ),
                DataCell(
                  TextButton.icon(
                    onPressed: () {
                      _showRecordDetails(
                        record,
                      );
                    },
                    icon: const Icon(
                      Icons.visibility_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'View',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _verificationIcon(
    bool verified,
  ) {
    return Tooltip(
      message: verified
          ? 'Verified'
          : 'Not verified',
      child: Icon(
        verified
            ? Icons.check_circle_rounded
            : Icons.cancel_outlined,
        size: 20,
        color: verified
            ? AppColors.success
            : Colors.grey.shade500,
      ),
    );
  }

  Widget _statusBadge(
    String rawStatus,
  ) {
    final status =
        rawStatus.toUpperCase();

    Color color;
    String label;

    switch (status) {
      case 'PRESENT':
        color = AppColors.success;
        label = 'Present';
        break;
      case 'PENDING':
        color = AppColors.warning;
        label = 'Pending';
        break;
      case 'REJECTED':
        color = AppColors.error;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = 'Not Marked';
        break;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(
          999,
        ),
        border: Border.all(
          color:
              color.withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight:
              FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // RECORD DETAILS DIALOG
  // ============================================================

  void _showRecordDetails(
    Map<String, dynamic> record,
  ) {
    final status =
        _textValue(
      record,
      'attendance_status',
      fallback: 'NOT_MARKED',
    );

    showDialog<void>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Attendance Details',
                ),
              ),
              _statusBadge(
                status,
              ),
            ],
          ),
          content:
              SingleChildScrollView(
            child: SizedBox(
              width: 540,
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _detailRow(
                    'Subject',
                    '${_textValue(record, 'subject_code')} — '
                    '${_textValue(record, 'subject_name')}',
                  ),
                  _detailRow(
                    'Section',
                    _textValue(
                      record,
                      'section_name',
                    ),
                  ),
                  _detailRow(
                    'Date',
                    _formatDate(
                      record['date'],
                    ),
                  ),
                  _detailRow(
                    'Session ID',
                    _textValue(
                      record,
                      'session_id',
                    ),
                  ),
                  _detailRow(
                    'Session Status',
                    _textValue(
                      record,
                      'session_status',
                    ),
                  ),
                  _detailRow(
                    'Started',
                    _formatDateTime(
                      record[
                          'started_at'],
                    ),
                  ),
                  _detailRow(
                    'Ended',
                    _formatDateTime(
                      record[
                          'ended_at'],
                    ),
                  ),
                  _detailRow(
                    'Marked At',
                    _formatDateTime(
                      record[
                          'marked_at'],
                    ),
                  ),
                  const Divider(
                    height: 28,
                  ),
                  _verificationDetailRow(
                    'QR Verified',
                    _boolValue(
                      record,
                      'qr_verified',
                    ),
                  ),
                  _verificationDetailRow(
                    'Geofence Verified',
                    _boolValue(
                      record,
                      'geofence_verified',
                    ),
                  ),
                  _verificationDetailRow(
                    'Face Verified',
                    _boolValue(
                      record,
                      'face_verified',
                    ),
                  ),
                  _verificationDetailRow(
                    'Liveness Verified',
                    _boolValue(
                      record,
                      'liveness_verified',
                    ),
                  ),
                  const Divider(
                    height: 28,
                  ),
                  _detailRow(
                    'Distance',
                    record[
                                'distance_from_classroom_meters'] ==
                            null
                        ? '-'
                        : '${record['distance_from_classroom_meters']} m',
                  ),
                  _detailRow(
                    'Rejection Reason',
                    _textValue(
                      record,
                      'rejection_reason',
                      fallback:
                          status.toUpperCase() ==
                                  'NOT_MARKED'
                              ? 'Attendance not marked'
                              : '-',
                    ),
                  ),
                ],
              ),
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
                  const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
            child: Text(
              label,
              style: TextStyle(
                color:
                    AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationDetailRow(
    String label,
    bool verified,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 155,
            child: Text(
              label,
              style: TextStyle(
                color:
                    AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Icon(
            verified
                ? Icons.check_circle_rounded
                : Icons.cancel_outlined,
            size: 20,
            color: verified
                ? AppColors.success
                : Colors.grey.shade500,
          ),
          const SizedBox(
            width: 7,
          ),
          Text(
            verified
                ? 'Yes'
                : 'No',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REPORT TABLE / EMPTY CARDS
  // ============================================================

  Widget _reportTableCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
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
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color:
                  AppColors.textSecondary,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _emptyReportCard({
    required IconData icon,
    required String title,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 42,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
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
        children: [
          Icon(
            icon,
            size: 40,
            color:
                Colors.grey.shade400,
          ),
          const SizedBox(
            height: 12,
          ),
          Text(
            title,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR BANNERS
  // ============================================================

  Widget _buildDashboardErrorBanner() {
    return _errorBanner(
      message:
          _errorMessage ??
              'Unable to load dashboard.',
      onRetry:
          _isLoading
              ? null
              : _loadDashboard,
    );
  }

  Widget _buildReportErrorBanner() {
    return _errorBanner(
      message:
          _reportErrorMessage ??
              'Unable to load attendance report.',
      onRetry:
          _isReportLoading
              ? null
              : () {
                  _loadAttendanceReport(
                    force: true,
                  );
                },
    );
  }

  Widget _errorBanner({
    required String message,
    required VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
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
            Icons.error_outline_rounded,
            color: AppColors.error,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              message,
              style:
                  const TextStyle(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
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

class _BrandIcon extends StatelessWidget {
  const _BrandIcon();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
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
      ),
    );
  }
}
