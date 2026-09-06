import 'package:flutter/material.dart';
import 'package:public_file_saver/public_file_saver.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/semantic_action_styles.dart';

import '../../models/admin_attendance_report.dart';
import '../../services/admin_attendance_report_service.dart';

class AdminAttendanceReportScreen extends StatefulWidget {
  const AdminAttendanceReportScreen({
    super.key,
  });

  @override
  State<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

class _AdminAttendanceReportScreenState
    extends State<AdminAttendanceReportScreen> {
  final AdminAttendanceReportService _service =
      AdminAttendanceReportService();

  final PublicFileSaver _fileSaver =
      PublicFileSaver();

  bool _isDownloadingExcel = false;
  bool _isDownloadingPdf = false;

  bool _isLoading = true;
  String? _errorMessage;

  AdminAttendanceReport? _masterReport;
  AdminAttendanceReport? _report;

  int? _selectedSemesterId;
  int? _selectedFacultyId;
  int? _selectedSectionId;
  int? _selectedSubjectId;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  _ReportView _selectedView =
      _ReportView.faculty;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Keep one unfiltered copy. It is used to build all
      // dropdown options even after a filtered report is loaded.
      final report =
          await _service.getAttendanceReport();

      if (!mounted) return;

      setState(() {
        _masterReport = report;
        _report = report;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _loadFilteredReport() async {
    if (_dateFrom != null &&
        _dateTo != null &&
        _dateFrom!.isAfter(_dateTo!)) {
      _showMessage(
        'Date From cannot be later than Date To.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report =
          await _service.getAttendanceReport(
        semesterId: _selectedSemesterId,
        facultyId: _selectedFacultyId,
        sectionId: _selectedSectionId,
        subjectId: _selectedSubjectId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      if (!mounted) return;

      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            _cleanErrorMessage(error);
      });
    }
  }

  Future<void> _refreshAll() async {
    await _initialize();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _selectedSemesterId = null;
      _selectedFacultyId = null;
      _selectedSectionId = null;
      _selectedSubjectId = null;
      _dateFrom = null;
      _dateTo = null;
    });

    await _loadFilteredReport();
  }

  // ============================================================
  // FILTER OPTIONS
  // ============================================================

  List<_LookupOption> get _semesterOptions {
    final records =
        _masterReport?.records ?? const [];

    final values = <int, String>{};

    for (final row in records) {
      final id = _intOrNull(
        row['semester_id'],
      );

      if (id != null) {
        values[id] = 'Semester $id';
      }
    }

    return _sortedOptions(values);
  }

  List<_LookupOption> get _facultyOptions {
    final records =
        _masterReport?.records ?? const [];

    final values = <int, String>{};

    for (final row in records) {
      final id = _intOrNull(
        row['faculty_id'],
      );

      if (id == null) continue;

      final name =
          _text(row['faculty_name']);
      final employeeId =
          _text(row['faculty_employee_id']);

      values[id] = employeeId == '-'
          ? name
          : '$name ($employeeId)';
    }

    return _sortedOptions(
      values,
      sortByLabel: true,
    );
  }

  List<_LookupOption> get _sectionOptions {
    final records =
        _masterReport?.records ?? const [];

    final values = <int, String>{};

    for (final row in records) {
      if (_selectedSemesterId != null &&
          _intOrNull(row['semester_id']) !=
              _selectedSemesterId) {
        continue;
      }

      if (_selectedFacultyId != null &&
          _intOrNull(row['faculty_id']) !=
              _selectedFacultyId) {
        continue;
      }

      final id =
          _intOrNull(row['section_id']);

      if (id == null) continue;

      values[id] =
          _text(row['section_name']);
    }

    return _sortedOptions(
      values,
      sortByLabel: true,
    );
  }

  List<_LookupOption> get _subjectOptions {
    final records =
        _masterReport?.records ?? const [];

    final values = <int, String>{};

    for (final row in records) {
      if (_selectedSemesterId != null &&
          _intOrNull(row['semester_id']) !=
              _selectedSemesterId) {
        continue;
      }

      if (_selectedFacultyId != null &&
          _intOrNull(row['faculty_id']) !=
              _selectedFacultyId) {
        continue;
      }

      if (_selectedSectionId != null &&
          _intOrNull(row['section_id']) !=
              _selectedSectionId) {
        continue;
      }

      final id =
          _intOrNull(row['subject_id']);

      if (id == null) continue;

      final code =
          _text(row['subject_code']);
      final name =
          _text(row['subject_name']);

      values[id] = code == '-'
          ? name
          : '$code - $name';
    }

    return _sortedOptions(
      values,
      sortByLabel: true,
    );
  }

  List<_LookupOption> _sortedOptions(
    Map<int, String> values, {
    bool sortByLabel = false,
  }) {
    final result = values.entries
        .map(
          (entry) => _LookupOption(
            id: entry.key,
            label: entry.value,
          ),
        )
        .toList();

    if (sortByLabel) {
      result.sort(
        (a, b) => a.label
            .toLowerCase()
            .compareTo(
              b.label.toLowerCase(),
            ),
      );
    } else {
      result.sort(
        (a, b) => a.id.compareTo(b.id),
      );
    }

    return result;
  }

  void _onSemesterChanged(int? value) {
    setState(() {
      _selectedSemesterId = value;
      _selectedSectionId = null;
      _selectedSubjectId = null;
    });
  }

  void _onFacultyChanged(int? value) {
    setState(() {
      _selectedFacultyId = value;
      _selectedSectionId = null;
      _selectedSubjectId = null;
    });
  }

  void _onSectionChanged(int? value) {
    setState(() {
      _selectedSectionId = value;
      _selectedSubjectId = null;
    });
  }

  // ============================================================
  // EXPORTS
  // ============================================================

  Future<void> _downloadExcel() async {
    if (_isDownloadingExcel) return;

    if (_dateFrom != null &&
        _dateTo != null &&
        _dateFrom!.isAfter(_dateTo!)) {
      _showMessage(
        'Date From cannot be later than Date To.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isDownloadingExcel = true;
    });

    try {
      final bytes =
          await _service.downloadAttendanceReportExcel(
        semesterId: _selectedSemesterId,
        facultyId: _selectedFacultyId,
        sectionId: _selectedSectionId,
        subjectId: _selectedSubjectId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      final result =
          await _fileSaver.saveBytes(
        bytes: bytes,
        fileName:
            _exportFileName('xlsx'),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;

      if (result == null ||
          !result.isSuccess) {
        throw Exception(
          'The Excel report could not be saved.',
        );
      }

      _showMessage(
        'Excel report saved successfully.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingExcel = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_isDownloadingPdf) return;

    if (_dateFrom != null &&
        _dateTo != null &&
        _dateFrom!.isAfter(_dateTo!)) {
      _showMessage(
        'Date From cannot be later than Date To.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isDownloadingPdf = true;
    });

    try {
      final bytes =
          await _service.downloadAttendanceReportPdf(
        semesterId: _selectedSemesterId,
        facultyId: _selectedFacultyId,
        sectionId: _selectedSectionId,
        subjectId: _selectedSubjectId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      final result =
          await _fileSaver.saveBytes(
        bytes: bytes,
        fileName:
            _exportFileName('pdf'),
        mimeType: 'application/pdf',
      );

      if (!mounted) return;

      if (result == null ||
          !result.isSuccess) {
        throw Exception(
          'The PDF report could not be saved.',
        );
      }

      _showMessage(
        'PDF report saved successfully.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
        });
      }
    }
  }

  String _exportFileName(
    String extension,
  ) {
    final now = DateTime.now();

    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';

    return 'admin_attendance_report_$stamp.$extension';
  }

  // ============================================================
  // DATES
  // ============================================================

  Future<void> _pickDateFrom() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _dateFrom = picked;
    });
  }

  Future<void> _pickDateTo() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _dateTo = picked;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Admin Attendance Reports',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        surfaceTintColor: AppColors.primary,
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed:
                _isLoading ? null : _refreshAll,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final report = _report;

    if (report == null) {
      return _buildErrorState(
        message:
            'No attendance report was received.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 18),
            _buildFilterCard(),
            const SizedBox(height: 18),
            _buildSummaryGrid(report.summary),
            const SizedBox(height: 22),
            _buildReportViewSelector(),
            const SizedBox(height: 14),
            _buildSelectedReportTable(report),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Color(0xFF4F5FBF),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'System-wide Attendance Report',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Audit attendance across faculty, subjects, sections, sessions, students and anti-proxy verification checks.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
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
  // FILTERS
  // ============================================================

  Widget _buildFilterCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final width =
                    constraints.maxWidth;

                final itemWidth =
                    width >= 1350
                        ? (width - 64) / 5
                        : width >= 900
                            ? (width - 32) / 3
                            : width >= 620
                                ? (width - 16) / 2
                                : width;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child:
                          _buildLookupDropdown(
                        label: 'Semester',
                        value:
                            _selectedSemesterId,
                        allLabel:
                            'All Semesters',
                        options:
                            _semesterOptions,
                        onChanged:
                            _onSemesterChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child:
                          _buildLookupDropdown(
                        label: 'Faculty',
                        value:
                            _selectedFacultyId,
                        allLabel:
                            'All Faculty',
                        options:
                            _facultyOptions,
                        onChanged:
                            _onFacultyChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child:
                          _buildLookupDropdown(
                        label: 'Section',
                        value:
                            _selectedSectionId,
                        allLabel:
                            'All Sections',
                        options:
                            _sectionOptions,
                        onChanged:
                            _onSectionChanged,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child:
                          _buildLookupDropdown(
                        label: 'Subject',
                        value:
                            _selectedSubjectId,
                        allLabel:
                            'All Subjects',
                        options:
                            _subjectOptions,
                        onChanged: (value) {
                          setState(() {
                            _selectedSubjectId =
                                value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildDateField(
                        label: 'Date From',
                        value: _dateFrom,
                        onTap: _pickDateFrom,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildDateField(
                        label: 'Date To',
                        value: _dateTo,
                        onTap: _pickDateTo,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed:
                      _loadFilteredReport,
                  icon: const Icon(
                    Icons.filter_alt_rounded,
                  ),
                  label:
                      const Text('Apply Filters'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(
                    Icons.filter_alt_off_rounded,
                  ),
                  label:
                      const Text('Clear Filters'),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      _isDownloadingExcel
                          ? null
                          : _downloadExcel,
                  icon: _isDownloadingExcel
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.table_view_rounded,
                          size: 19,
                        ),
                  label: Text(
                    _isDownloadingExcel
                        ? 'Saving Excel...'
                        : 'Download Excel',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      _isDownloadingPdf
                          ? null
                          : _downloadPdf,
                  icon: _isDownloadingPdf
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 19,
                        ),
                  label: Text(
                    _isDownloadingPdf
                        ? 'Saving PDF...'
                        : 'Download PDF',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLookupDropdown({
    required String label,
    required int? value,
    required String allLabel,
    required List<_LookupOption> options,
    required ValueChanged<int?> onChanged,
  }) {
    final validValue =
        value != null &&
                options.any(
                  (item) => item.id == value,
                )
            ? value
            : null;

    return DropdownButtonFormField<int?>(
      key: ValueKey(
        '$label-$validValue',
      ),
      initialValue: validValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border:
            const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(allLabel),
        ),
        for (final option in options)
          DropdownMenuItem<int?>(
            value: option.id,
            child: Text(
              option.label,
              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
          suffixIcon: const Icon(
            Icons.calendar_month_rounded,
          ),
        ),
        child: Text(
          value == null
              ? 'All dates'
              : _formatDate(value),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummaryGrid(
    AdminAttendanceSummary summary,
  ) {
    final cards = <_SummaryCardData>[
      _SummaryCardData(
        title: 'Sessions',
        value:
            summary.totalSessions.toString(),
        icon: Icons.event_note_rounded,
      ),
      _SummaryCardData(
        title: 'Students',
        value:
            summary.totalStudents.toString(),
        icon: Icons.groups_rounded,
      ),
      _SummaryCardData(
        title: 'Faculty',
        value:
            summary.totalFaculty.toString(),
        icon: Icons.person_rounded,
      ),
      _SummaryCardData(
        title: 'Opportunities',
        value: summary
            .attendanceOpportunities
            .toString(),
        icon:
            Icons.fact_check_rounded,
      ),
      _SummaryCardData(
        title: 'Records',
        value: summary
            .attendanceRecords
            .toString(),
        icon:
            Icons.receipt_long_rounded,
      ),
      _SummaryCardData(
        title: 'Present',
        value: summary.present.toString(),
        icon:
            Icons.check_circle_rounded,
      ),
      _SummaryCardData(
        title: 'Pending',
        value: summary.pending.toString(),
        icon:
            Icons.pending_actions_rounded,
      ),
      _SummaryCardData(
        title: 'Rejected',
        value:
            summary.rejected.toString(),
        icon: Icons.cancel_rounded,
      ),
      _SummaryCardData(
        title: 'Not Marked',
        value:
            summary.notMarked.toString(),
        icon:
            Icons.remove_circle_outline_rounded,
      ),
      _SummaryCardData(
        title: 'Attendance',
        value:
            '${summary.attendancePercentage.toStringAsFixed(2)}%',
        icon: Icons.percent_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final width =
            constraints.maxWidth;

        final columns =
            width >= 1400
                ? 5
                : width >= 1000
                    ? 4
                    : width >= 700
                        ? 3
                        : width >= 450
                            ? 2
                            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio:
                columns == 1 ? 4.2 : 2.5,
          ),
          itemBuilder: (
            context,
            index,
          ) {
            return _buildSummaryCard(
              cards[index],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
    _SummaryCardData data,
  ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    AppColors.surfaceSoft,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                data.icon,
                color:
                    AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
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
  // VIEW SELECTOR
  // ============================================================

  Widget _buildReportViewSelector() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _viewChip(
              _ReportView.faculty,
              'Faculty Wise',
              Icons.person_search_rounded,
            ),
            _viewChip(
              _ReportView.subject,
              'Subject Wise',
              Icons.menu_book_rounded,
            ),
            _viewChip(
              _ReportView.section,
              'Section Wise',
              Icons.class_rounded,
            ),
            _viewChip(
              _ReportView.day,
              'Day Wise',
              Icons.calendar_view_day_rounded,
            ),
            _viewChip(
              _ReportView.session,
              'Session Wise',
              Icons.event_available_rounded,
            ),
            _viewChip(
              _ReportView.records,
              'Detailed Records',
              Icons.security_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewChip(
    _ReportView view,
    String label,
    IconData icon,
  ) {
    final selected =
        _selectedView == view;

    return ChoiceChip(
      selected: selected,
      avatar: Icon(
        icon,
        size: 18,
      ),
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedView = view;
        });
      },
    );
  }

  // ============================================================
  // REPORT TABLE
  // ============================================================

  Widget _buildSelectedReportTable(
    AdminAttendanceReport report,
  ) {
    switch (_selectedView) {
      case _ReportView.faculty:
        return _reportCard(
          title: 'Faculty Wise',
          subtitle:
              'Attendance grouped by faculty member.',
          child:
              _buildFacultyTable(
            report.facultyWise,
          ),
        );

      case _ReportView.subject:
        return _reportCard(
          title: 'Subject Wise',
          subtitle:
              'Attendance grouped by subject.',
          child:
              _buildSubjectTable(
            report.subjectWise,
          ),
        );

      case _ReportView.section:
        return _reportCard(
          title: 'Section Wise',
          subtitle:
              'Attendance grouped by semester and section.',
          child:
              _buildSectionTable(
            report.sectionWise,
          ),
        );

      case _ReportView.day:
        return _reportCard(
          title: 'Day Wise',
          subtitle:
              'Attendance performance by date.',
          child:
              _buildDayTable(
            report.dayWise,
          ),
        );

      case _ReportView.session:
        return _reportCard(
          title: 'Session Wise',
          subtitle:
              'Every attendance session with expected and marked students.',
          child:
              _buildSessionTable(
            report.sessionWise,
          ),
        );

      case _ReportView.records:
        return _reportCard(
          title: 'Detailed Attendance Records',
          subtitle:
              'Student-level audit including QR, geofence, face and liveness verification.',
          child:
              _buildDetailedTable(
            report.records,
          ),
        );
    }
  }

  Widget _reportCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyTable(
    List<Map<String, dynamic>> rows,
  ) {
    return _groupedTable(
      rows: rows,
      leadingColumns: const [
        _ColumnSpec(
          'Employee ID',
          'faculty_employee_id',
        ),
        _ColumnSpec(
          'Faculty',
          'faculty_name',
        ),
        _ColumnSpec(
          'Department',
          'faculty_department',
        ),
        _ColumnSpec(
          'Designation',
          'faculty_designation',
        ),
      ],
    );
  }

  Widget _buildSubjectTable(
    List<Map<String, dynamic>> rows,
  ) {
    return _groupedTable(
      rows: rows,
      leadingColumns: const [
        _ColumnSpec(
          'Code',
          'subject_code',
        ),
        _ColumnSpec(
          'Subject',
          'subject_name',
        ),
      ],
    );
  }

  Widget _buildSectionTable(
    List<Map<String, dynamic>> rows,
  ) {
    return _groupedTable(
      rows: rows,
      leadingColumns: const [
        _ColumnSpec(
          'Semester',
          'semester_id',
          prefix: 'Semester ',
        ),
        _ColumnSpec(
          'Section',
          'section_name',
        ),
      ],
    );
  }

  Widget _buildDayTable(
    List<Map<String, dynamic>> rows,
  ) {
    return _groupedTable(
      rows: rows,
      leadingColumns: const [
        _ColumnSpec(
          'Date',
          'date',
        ),
      ],
    );
  }

  Widget _groupedTable({
    required List<Map<String, dynamic>> rows,
    required List<_ColumnSpec> leadingColumns,
  }) {
    if (rows.isEmpty) {
      return _emptyTableMessage();
    }

    final columns = <DataColumn>[
      for (final spec in leadingColumns)
        DataColumn(
          label: Text(spec.label),
        ),
      const DataColumn(
        label: Text('Sessions'),
      ),
      const DataColumn(
        label: Text('Students'),
      ),
      const DataColumn(
        label: Text('Opportunities'),
      ),
      const DataColumn(
        label: Text('Records'),
      ),
      const DataColumn(
        label: Text('Present'),
      ),
      const DataColumn(
        label: Text('Pending'),
      ),
      const DataColumn(
        label: Text('Rejected'),
      ),
      const DataColumn(
        label: Text('Not Marked'),
      ),
      const DataColumn(
        label: Text('Attendance %'),
      ),
    ];

    return _horizontalTable(
      DataTable(
        columns: columns,
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                for (final spec
                    in leadingColumns)
                  DataCell(
                    Text(
                      '${spec.prefix}${_text(row[spec.key])}',
                    ),
                  ),
                DataCell(
                  Text(
                    _int(
                      row['session_count'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['student_count'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row[
                          'attendance_opportunities'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['attendance_records'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['present'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['pending'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['rejected'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['not_marked'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _percentage(
                      row[
                          'attendance_percentage'],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSessionTable(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return _emptyTableMessage();
    }

    return _horizontalTable(
      DataTable(
        columns: const [
          DataColumn(
            label: Text('Date'),
          ),
          DataColumn(
            label: Text('Session'),
          ),
          DataColumn(
            label: Text('Faculty'),
          ),
          DataColumn(
            label: Text('Subject'),
          ),
          DataColumn(
            label: Text('Section'),
          ),
          DataColumn(
            label: Text('QR Status'),
          ),
          DataColumn(
            label: Text('Expected'),
          ),
          DataColumn(
            label: Text('Records'),
          ),
          DataColumn(
            label: Text('Present'),
          ),
          DataColumn(
            label: Text('Pending'),
          ),
          DataColumn(
            label: Text('Rejected'),
          ),
          DataColumn(
            label: Text('Not Marked'),
          ),
          DataColumn(
            label: Text('Attendance %'),
          ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    _text(row['date']),
                  ),
                ),
                DataCell(
                  Text(
                    _text(row['session_id']),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['faculty_name'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_text(row['subject_code'])} - '
                    '${_text(row['subject_name'])}',
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['section_name'],
                    ),
                  ),
                ),
                DataCell(
                  _statusBadge(
                    _text(
                      row['qr_status'] ??
                          row['session_status'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['expected_students'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['attendance_records'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['present'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['pending'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['rejected'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _int(
                      row['not_marked'],
                    ).toString(),
                  ),
                ),
                DataCell(
                  Text(
                    _percentage(
                      row[
                          'attendance_percentage'],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedTable(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return _emptyTableMessage();
    }

    return _horizontalTable(
      DataTable(
        columns: const [
          DataColumn(
            label: Text('Date'),
          ),
          DataColumn(
            label: Text('Session'),
          ),
          DataColumn(
            label: Text('Faculty'),
          ),
          DataColumn(
            label: Text('Subject'),
          ),
          DataColumn(
            label: Text('Section'),
          ),
          DataColumn(
            label: Text('Student'),
          ),
          DataColumn(
            label: Text('Enrollment'),
          ),
          DataColumn(
            label: Text('Roll No.'),
          ),
          DataColumn(
            label: Text('QR Status'),
          ),
          DataColumn(
            label: Text('Attendance Status'),
          ),
          DataColumn(
            label: Text('QR Verified'),
          ),
          DataColumn(
            label: Text('Geofence'),
          ),
          DataColumn(
            label: Text('Face'),
          ),
          DataColumn(
            label: Text('Liveness'),
          ),
          DataColumn(
            label: Text('Distance (m)'),
          ),
          DataColumn(
            label: Text('Marked At'),
          ),
          DataColumn(
            label:
                Text('Rejection Reason'),
          ),
          DataColumn(
            label:
                Text('Result Explanation'),
          ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    _text(row['date']),
                  ),
                ),
                DataCell(
                  Text(
                    _text(row['session_id']),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['faculty_name'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '${_text(row['subject_code'])} - '
                    '${_text(row['subject_name'])}',
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['section_name'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['student_name'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['enrollment_number'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _text(
                      row['roll_number'],
                    ),
                  ),
                ),
                DataCell(
                  _statusBadge(
                    _text(
                      row['qr_status'] ??
                          row['session_status'],
                    ),
                  ),
                ),
                DataCell(
                  _attendanceStatusBadge(
                    attendanceStatus:
                        _text(
                      row['attendance_status'],
                    ),
                    qrStatus:
                        _text(
                      row['qr_status'] ??
                          row['session_status'],
                    ),
                  ),
                ),
                DataCell(
                  _verificationBadge(
                    row['qr_verified'],
                  ),
                ),
                DataCell(
                  _verificationBadge(
                    row['geofence_verified'],
                  ),
                ),
                DataCell(
                  _verificationBadge(
                    row['face_verified'],
                  ),
                ),
                DataCell(
                  _verificationBadge(
                    row['liveness_verified'],
                  ),
                ),
                DataCell(
                  Text(
                    _distance(
                      row[
                          'distance_from_classroom_meters'],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _dateTimeText(
                      row['marked_at'],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      _text(
                        row[
                            'rejection_reason'],
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      _resultExplanation(
                        row,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _horizontalTable(
    Widget child,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    );
  }

  Widget _emptyTableMessage() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 40,
        horizontal: 18,
      ),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 42,
            color: Colors.black38,
          ),
          SizedBox(height: 10),
          Text(
            'No attendance data matches the selected filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BADGES
  // ============================================================

  Widget _verificationBadge(
    dynamic value,
  ) {
    final verified = _bool(value);

    return Tooltip(
      message:
          verified ? 'Verified' : 'Not verified',
      child: Icon(
        verified
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded,
        color: verified
            ? AppColors.success
            : AppColors.error,
        size: 21,
      ),
    );
  }

  Widget _attendanceStatusBadge({
    required String attendanceStatus,
    required String qrStatus,
  }) {
    final normalizedQr =
        qrStatus.toUpperCase();

    // A cancelled QR/session is visible for audit. If the student
    // has no attendance row, show the original NOT_MARKED status
    // with a tooltip explaining that it does not count against them.
    if (normalizedQr == 'CANCELLED' &&
        attendanceStatus.toUpperCase() ==
            'NOT_MARKED') {
      return Tooltip(
        message:
            'The faculty cancelled this QR/session. '
            'This NOT_MARKED entry is audit-only and '
            'does not reduce attendance.',
        child: _statusBadge(
          attendanceStatus,
        ),
      );
    }

    return _statusBadge(
      attendanceStatus,
    );
  }

  Widget _statusBadge(String status) {
    final normalized =
        status.toUpperCase();

    Color background;
    Color foreground;

    switch (normalized) {
      case 'PRESENT':
      case 'ACTIVE':
      case 'COMPLETED':
      case 'APPROVED':
      case 'VERIFIED':
        background =
            SemanticActionStyles.positive.withValues(alpha: 0.08);
        foreground =
            SemanticActionStyles.positive;
        break;

      case 'PENDING':
      case 'RUNNING':
      case 'INACTIVE':
      case 'SUSPENDED':
        background =
            SemanticActionStyles.caution.withValues(alpha: 0.10);
        foreground =
            SemanticActionStyles.caution;
        break;

      case 'REJECTED':
      case 'CANCELLED':
      case 'FAILED':
      case 'ERROR':
        background =
            SemanticActionStyles.destructive.withValues(alpha: 0.08);
        foreground =
            SemanticActionStyles.destructive;
        break;

      default:
        background =
            AppColors.surfaceSoft;
        foreground =
            AppColors.textSecondary;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight:
              FontWeight.w600,
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
        'Unable to load attendance report.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Card(
          child: Padding(
            padding:
                const EdgeInsets.all(30),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 54,
                  color:
                      AppColors.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Attendance report unavailable',
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
                    maxWidth: 620,
                  ),
                  child: Text(
                    error,
                    textAlign:
                        TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _initialize,
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
  // HELPERS
  // ============================================================

  String _resultExplanation(
    Map<String, dynamic> row,
  ) {
    final attendanceStatus =
        _text(
      row['attendance_status'],
    ).toUpperCase();

    final qrStatus =
        _text(
      row['qr_status'] ??
          row['session_status'],
    ).toUpperCase();

    final rejectionReason =
        _text(
      row['rejection_reason'],
    );

    if (qrStatus == 'CANCELLED') {
      return 'QR/session was cancelled by faculty. '
          'This row is kept for audit and is not counted '
          'against attendance.';
    }

    if (attendanceStatus == 'PRESENT') {
      return 'Attendance accepted after QR, geofence, '
          'face and liveness verification passed.';
    }

    if (attendanceStatus == 'REJECTED') {
      if (rejectionReason != '-') {
        return rejectionReason;
      }

      if (!_bool(row['qr_verified'])) {
        return 'Attendance rejected because QR verification failed.';
      }

      if (!_bool(row['geofence_verified'])) {
        return 'Attendance rejected because geofence verification failed.';
      }

      if (!_bool(row['face_verified'])) {
        return 'Attendance rejected because face verification failed.';
      }

      if (!_bool(row['liveness_verified'])) {
        return 'Attendance rejected because liveness verification failed.';
      }

      return 'Attendance attempt was rejected by the verification workflow.';
    }

    if (attendanceStatus == 'PENDING') {
      if (!_bool(row['qr_verified'])) {
        return 'Attendance verification is pending at the QR step.';
      }

      if (!_bool(row['geofence_verified'])) {
        return 'QR passed; geofence verification is pending.';
      }

      if (!_bool(row['face_verified'])) {
        return 'QR and geofence passed; face verification is pending.';
      }

      if (!_bool(row['liveness_verified'])) {
        return 'QR, geofence and face passed; liveness verification is pending.';
      }

      return 'Attendance verification is still in progress.';
    }

    if (attendanceStatus == 'NOT_MARKED') {
      if (qrStatus == 'COMPLETED') {
        return 'QR/session completed before this student successfully '
            'marked attendance.';
      }

      if (qrStatus == 'ACTIVE') {
        return 'QR/session is still active and attendance has not been '
            'marked yet.';
      }

      return 'No successful attendance attempt was recorded.';
    }

    return 'Attendance result recorded by the system.';
  }

  String _cleanErrorMessage(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  String _text(dynamic value) {
    if (value == null) return '-';

    final text =
        value.toString().trim();

    return text.isEmpty ? '-' : text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }

  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) {
      return value != 0;
    }

    final text = value
        ?.toString()
        .trim()
        .toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  String _percentage(dynamic value) {
    double number = 0;

    if (value is num) {
      number = value.toDouble();
    } else {
      number = double.tryParse(
            value?.toString() ?? '',
          ) ??
          0;
    }

    return '${number.toStringAsFixed(2)}%';
  }

  String _distance(dynamic value) {
    if (value == null) return '-';

    final number = value is num
        ? value.toDouble()
        : double.tryParse(
            value.toString(),
          );

    if (number == null) return '-';

    return number.toStringAsFixed(2);
  }

  String _dateTimeText(dynamic value) {
    if (value == null) return '-';

    final raw = value.toString();

    final parsed =
        DateTime.tryParse(raw);

    if (parsed == null) {
      return raw;
    }

    final date = _formatDate(parsed);

    final hour = parsed.hour
        .toString()
        .padLeft(2, '0');
    final minute = parsed.minute
        .toString()
        .padLeft(2, '0');

    return '$date $hour:$minute';
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

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? AppColors.error
              : null,
        ),
      );
  }
}

enum _ReportView {
  faculty,
  subject,
  section,
  day,
  session,
  records,
}

class _LookupOption {
  const _LookupOption({
    required this.id,
    required this.label,
  });

  final int id;
  final String label;
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _ColumnSpec {
  const _ColumnSpec(
    this.label,
    this.key, {
    this.prefix = '',
  });

  final String label;
  final String key;
  final String prefix;
}
